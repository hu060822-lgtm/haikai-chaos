class_name MapDynamics
extends Node3D
## The map's moving parts (C12), laid out on any big map from its floor plan (Layout), in
## twin pairs like everything else on the plan, so both halves stay fair:
##
##   doors     MapDoor     sliding doors across narrow corridors: E opens or shuts them
##                         (bots open them as they walk), shots and blasts break them open
##   shutters  MapShutter  blast gates across wider lanes, in two groups: every SHIFT_EVERY
##                         seconds of fighting the closed group opens and the open one
##                         shuts (the map changes mid-round), with WARN seconds of lamps
##                         and sirens first. A plan is only used if no closing ever cuts a
##                         part of the map off.
##   lifts     MapLift     a platform column that rises out of the floor on a fixed cycle:
##                         a high angle for a few seconds, then gone again
##   cover     MapCover    concrete barriers you can shoot or blow apart
##
## Netplay: the plan comes from the layout only, so every machine builds the same parts
## with the same uids ("m:<n>"). Doors and cover change by Deploy events like the map's
## breakable panels; the shutters' phase and the lifts' clock come from the host
## (TeamMatch.map_tick_out every TICK s and on every change). A new round (Deploy
## .reset_round) puts everything back: doors shut, cover whole, phase 0.

const SHIFT_EVERY := 45.0
const WARN := 6.0
const TICK := 1.0
## How near (m) and how square on you have to be to work a door.
const DOOR_REACH := 2.8
const DOOR_PAIRS := 2
const COVER_PAIRS := 4

var map: Node3D
var layout: Layout
var wall_h := 9.0
var uid := "m:dyn"
var doors: Array[MapDoor] = []
var shutters: Array[MapShutter] = []
var lifts: Array[MapLift] = []
var covers: Array[MapCover] = []
var phase := 0
var next_in := SHIFT_EVERY
var lift_clock := 0.0
var _tick_t := 0.0
var _warned := false
var _bot_t := 0.0
var _picked: Array[Vector2i] = []


## The parts for `m`, or null if it has no floor plan (the movement lab).
static func for_map(m: Node3D) -> MapDynamics:
	var l = m.get("layout")
	if not (l is Layout):
		return null
	var d := MapDynamics.new()
	d.map = m
	d.layout = l
	var consts: Dictionary = m.get_script().get_script_constant_map() if m.get_script() != null else {}
	d.wall_h = float(consts.get("WALL_H", 9.0))
	return d


func _ready() -> void:
	name = "Dynamics"
	_plan()
	Deploy.register(uid, self)
	_apply_phase(true)


# --- Planning --------------------------------------------------------------------------

## A cell that is plain open floor: walkable, at ground height, not a spawn, not built by
## hand, and nothing special next to it.
func _plain(g: Vector2i, allow_sites := true) -> bool:
	var L := layout
	if not L.inside(g.x, g.y) or not L.walkable(g.x, g.y) or L._layered(g):
		return false
	var k := L.at(g.x, g.y)
	if k == "s" or k == "x" or (not allow_sites and (k == "a" or k == "b")):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := L.at(g.x + dx, g.y + dy)
			if n in ["w", "v", "k", "o", "x", "s", "c"]:
				return false
	return true


func _far(g: Vector2i, metres: float) -> bool:
	for q in _picked:
		if Vector2(q).distance_to(Vector2(g)) * layout.cell < metres:
			return false
	return true


## Cross-sections of corridors `lo`..`hi` cells wide: a row of plain cells with rock at both
## ends and open floor on both sides. [cells, axis (the way through), detour (m, 0 = none)].
func _sections(lo: int, hi: int, allow_sites: bool) -> Array:
	var L := layout
	var out := []
	for across in [Vector2i(1, 0), Vector2i(0, 1)]:
		var through := Vector2i(across.y, across.x)
		for r in range(2, (L.rows if across.x == 1 else L.cols) - 2):
			var i := 1
			var n := L.cols if across.x == 1 else L.rows
			while i < n - 1:
				var start := Vector2i(i, r) if across.x == 1 else Vector2i(r, i)
				var before: Vector2i = start - across
				if L.at(before.x, before.y) != "#" or not _plain(start, allow_sites):
					i += 1
					continue
				var w := 0
				var cells: Array[Vector2i] = []
				var q := start
				while _plain(q, allow_sites) and w <= hi:
					cells.append(q)
					w += 1
					q += across
				if L.at(q.x, q.y) == "#" and w >= lo and w <= hi:
					var ok := true
					for c in cells:
						for s in [through, -through, through * 2, -through * 2]:
							if not L.walkable(c.x + s.x, c.y + s.y):
								ok = false
					if ok:
						out.append([cells, through])
				i += maxi(w, 1)
	return out


## Steps round when `cells` are shut (m), or INF when shutting them cuts the way.
func _detour(cells: Array, through: Vector2i, limit_m := 160.0) -> float:
	var L := layout
	var saved := []
	for c in cells:
		saved.append(L.at(c.x, c.y))
		L.set_cell(c.x, c.y, "#")
	var a: Vector2i = cells[0] - through
	var b: Vector2i = cells[0] + through
	var steps := L._walk(a, b, int(limit_m / L.cell))
	for k in cells.size():
		L.set_cell(cells[k].x, cells[k].y, saved[k])
	return INF if steps >= (1 << 20) else steps * L.cell


func _twin_cells(cells: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(layout.twin_cell(c))
	return out


func _same_kind(cells: Array, through: Vector2i) -> bool:
	for c in cells:
		if not _plain(c, true):
			return false
		if not layout.walkable(c.x + through.x, c.y + through.y) or not layout.walkable(c.x - through.x, c.y - through.y):
			return false
	return true


func _plan() -> void:
	var n := [0]
	var next_uid := func() -> String:
		n[0] += 1
		return "m:%d" % n[0]
	# Shutters first (they need the most room), two groups of a twin pair each.
	var lanes := _sections(1, 3, false)
	var found := []
	for s in lanes:
		var d := _detour(s[0], s[1])
		if d >= 24.0 and d < INF:
			found.append([d, s])
	found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] if absf(x[0] - y[0]) > 0.1 else str(x[1][0][0]) < str(y[1][0][0]))
	var groups := 0
	for f in found:
		if groups >= 2:
			break
		var cells: Array = f[1][0]
		var through: Vector2i = f[1][1]
		var twin := _twin_cells(cells)
		var mid: Vector2i = cells[cells.size() / 2]
		var tmid: Vector2i = twin[twin.size() / 2]
		if not _far(mid, 22.0) or not _far(tmid, 22.0) or Vector2(mid).distance_to(Vector2(tmid)) * layout.cell < 16.0:
			continue
		if not _same_kind(twin, through):
			continue
		# Not on the same lane as the other group's gates (or one lane would never be open).
		if _same_lane(mid) or _same_lane(tmid):
			continue
		# Shut both at once: each side of each must still reach the other.
		var both: Array = cells + twin
		if _detour_all(both, [cells, twin], through) == INF:
			continue
		for set in [cells, twin]:
			var sh := MapShutter.new()
			sh.uid = next_uid.call()
			sh.group = groups
			sh.layout = layout
			sh.setup_cells(set, through, wall_h)
			add_child(sh)
			shutters.append(sh)
		_picked.append(mid)
		_picked.append(tmid)
		groups += 1
	# Doors across the narrow corridors (anywhere but the sites).
	var narrow := _sections(1, 1, false)
	var dn := 0
	for s in narrow:
		if dn >= DOOR_PAIRS:
			break
		var cells: Array = s[0]
		var through: Vector2i = s[1]
		var g: Vector2i = cells[0]
		var tw := layout.twin_cell(g)
		if not _far(g, 20.0) or not _far(tw, 20.0) or Vector2(g).distance_to(Vector2(tw)) * layout.cell < 12.0:
			continue
		if not _same_kind([tw], through):
			continue
		for c in [g, tw]:
			var door := MapDoor.new()
			door.uid = next_uid.call()
			door.setup_cell(layout, c, through, wall_h)
			add_child(door)
			doors.append(door)
		_picked.append(g)
		_picked.append(tw)
		dn += 1
	_plan_lift(next_uid)
	_plan_cover(next_uid)
	for p in doors + shutters + lifts + covers:
		Deploy.register(p.uid, p)


## Walking from `g` to a gate already picked is about as short as the straight line: the
## same lane.
func _same_lane(g: Vector2i) -> bool:
	for sh in shutters:
		var q: Vector2i = sh.cells[sh.cells.size() / 2]
		var straight := Vector2(q).distance_to(Vector2(g)) * layout.cell
		if straight > 60.0:
			continue
		var walk := layout._walk(g, q, int(straight * 2.0 / layout.cell) + 6) * layout.cell
		if walk < straight * 1.4 + 6.0:
			return true
	return false


func _detour_all(all_cells: Array, sets: Array, through: Vector2i) -> float:
	var L := layout
	var saved := []
	for c in all_cells:
		saved.append(L.at(c.x, c.y))
		L.set_cell(c.x, c.y, "#")
	var worst := 0.0
	for set in sets:
		var a: Vector2i = set[0] - through
		var b: Vector2i = set[0] + through
		var steps := L._walk(a, b, int(220.0 / L.cell))
		worst = maxf(worst, INF if steps >= (1 << 20) else steps * L.cell)
	for k in all_cells.size():
		L.set_cell(all_cells[k].x, all_cells[k].y, saved[k])
	return worst


func _open_score(g: Vector2i, r: int) -> int:
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if layout.walkable(g.x + dx, g.y + dy):
				n += 1
	return n


## One twin pair of lifts in the roomiest open floor, away from everything else.
func _plan_lift(next_uid: Callable) -> void:
	var L := layout
	var best := Vector2i(-1, -1)
	var best_score := -1
	for r in range(3, L.rows - 4):
		for c in range(3, L.cols - 4):
			var g := Vector2i(c, r)
			var ok := true
			for dy in range(-1, 3):
				for dx in range(-1, 3):
					if not _plain(g + Vector2i(dx, dy), true):
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var tw := _twin_block(g)
			if Vector2(g).distance_to(Vector2(tw)) * L.cell < 20.0 or not _far(g, 14.0) or not _far(tw, 14.0):
				continue
			var k := L.at(c, r)
			var score := _open_score(g, 5) + (12 if k == "m" else 0)
			if score > best_score:
				best_score = score
				best = g
	if best.x < 0:
		return
	for g in [best, _twin_block(best)]:
		var lift := MapLift.new()
		lift.uid = next_uid.call()
		lift.dyn = self
		lift.setup_cells(L, g)
		add_child(lift)
		lifts.append(lift)
		_picked.append(g)


## The first cell of the 2 × 2 block that is the twin of the block from `g`.
func _twin_block(g: Vector2i) -> Vector2i:
	var a := layout.twin_cell(g)
	var b := layout.twin_cell(g + Vector2i(1, 1))
	return Vector2i(mini(a.x, b.x), mini(a.y, b.y))


## Barriers in open floor, sites first, spaced apart.
func _plan_cover(next_uid: Callable) -> void:
	var L := layout
	var found := []
	for r in range(2, L.rows - 2):
		for c in range(2, L.cols - 2):
			var g := Vector2i(c, r)
			var ok := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not _plain(g + Vector2i(dx, dy), true):
						ok = false
			if not ok:
				continue
			var k := L.at(c, r)
			var score := (3 if k == "a" or k == "b" else (2 if k == "m" else 0)) * 100 + _open_score(g, 3)
			found.append([score, g])
	found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] if x[0] != y[0] else (x[1].y * 1000 + x[1].x) < (y[1].y * 1000 + y[1].x))
	var pairs := 0
	for f in found:
		if pairs >= COVER_PAIRS:
			break
		var g: Vector2i = f[1]
		var tw := L.twin_cell(g)
		if not _far(g, 10.0) or not _far(tw, 10.0) or Vector2(g).distance_to(Vector2(tw)) * L.cell < 10.0 or not _plain(tw, true):
			continue
		# Across the longer open run through it, so it cuts the long sightline.
		var run_x := _run(g, Vector2i(1, 0))
		var run_z := _run(g, Vector2i(0, 1))
		for q in [g, tw]:
			var cov := MapCover.new()
			cov.uid = next_uid.call()
			cov.setup_cell(L, q, run_x >= run_z)
			add_child(cov)
			covers.append(cov)
			_picked.append(q)
		pairs += 1


func _run(g: Vector2i, step: Vector2i) -> int:
	var n := 0
	for s in [step, -step]:
		var q: Vector2i = g + s
		while layout.walkable(q.x, q.y) and n < 60:
			n += 1
			q += s
	return n


# --- Running ---------------------------------------------------------------------------

func _host() -> bool:
	return Deploy.runs_bots()


## The shift timer only runs while there's a fight on (not in a build phase).
func counting() -> bool:
	var tm = Deploy.net
	if tm == null:
		return true
	if not tm.running:
		return false
	if tm.rules != null:
		return tm.rules.fighting()
	return true


func _physics_process(delta: float) -> void:
	lift_clock += delta
	if not shutters.is_empty() and counting():
		next_in -= delta
		if next_in <= WARN and not _warned:
			_warned = true
			for s in shutters:
				s.warn(true)
			_say("⚠ %d 秒後閘門輪替：關著的會打開、開著的會關上（閃黃燈的閘門）" % int(WARN), 4.0)
		if _host() and next_in <= 0.0:
			phase += 1
			next_in = SHIFT_EVERY
			_apply_phase(false)
			_send()
	if _host():
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = TICK
			_send()
		_bot_t -= delta
		if _bot_t <= 0.0:
			_bot_t = 0.25
			_bots_open_doors()
	_player_doors()


func _send() -> void:
	var tm = Deploy.net
	if tm != null:
		tm.map_tick_out([lift_clock, phase, next_in])


## A tick from the host: its clock and phase win.
func from_host(data: Array) -> void:
	if data.size() < 3:
		return
	var host_clock := float(data[0])
	if absf(host_clock - lift_clock) > 0.25:
		lift_clock = host_clock
	else:
		lift_clock = lerpf(lift_clock, host_clock, 0.3)
	var p := int(data[1])
	next_in = float(data[2])
	if p != phase:
		phase = p
		_apply_phase(false)
	elif next_in > WARN and _warned:
		_warned = false
		for s in shutters:
			s.warn(false)


## Group (phase % 2) shut, the other open.
func _apply_phase(instant: bool) -> void:
	_warned = false
	for s in shutters:
		s.warn(false)
		s.set_closed(s.group == phase % 2, instant)
	if not instant and not shutters.is_empty():
		_say("地圖變動：閘門輪替", 2.5)


func restore() -> void:
	phase = 0
	next_in = SHIFT_EVERY
	_apply_phase(true)


func _say(text: String, seconds: float) -> void:
	var main := get_tree().current_scene
	if main != null and main.get("hud") != null and main.hud != null:
		main.hud.show_hint(text, seconds)


## E near a door, facing it: open or shut it (for everyone).
func _player_doors() -> void:
	var main := get_tree().current_scene
	var p = main.get("player") if main != null else null
	if not (p is Player) or not p.alive or not p.input_enabled or not Input.is_action_just_pressed("interact"):
		return
	var d := door_for(p)
	if d != null:
		d.toggle()


## The door `p` can work right now, or null.
func door_for(p: Player) -> MapDoor:
	var eye: Transform3D = p.camera.global_transform
	var best: MapDoor = null
	var best_d := DOOR_REACH
	for d in doors:
		if d.broken:
			continue
		var c := d.global_position + Vector3(0, 1.4, 0)
		var dist := eye.origin.distance_to(c)
		if dist < best_d and (-eye.basis.z).dot((c - eye.origin).normalized()) > 0.3:
			best = d
			best_d = dist
	return best


## Bots walk through doors: a closed one in front of a bot opens.
func _bots_open_doors() -> void:
	for b in get_tree().get_nodes_in_group("bots"):
		if not (b is Bot) or not b.alive or b.frozen:
			continue
		for d in doors:
			if not d.open and not d.broken and not d.pending and (b as Node3D).global_position.distance_to(d.global_position) < 2.2:
				d.toggle()


## Bodies this machine moves itself: the local player, and the bots where it runs them.
static func local_bodies(tree: SceneTree) -> Array:
	var out := []
	var main := tree.current_scene
	var p = main.get("player") if main != null else null
	if p is Player and p.alive:
		out.append(p)
	if Deploy.runs_bots():
		for b in tree.get_nodes_in_group("bots"):
			if b is Bot and b.alive:
				out.append(b)
	return out


## A lamp: a small glowing box.
static func lamp(parent: Node3D, at: Vector3, size: Vector3) -> StandardMaterial3D:
	var m := MeshInstance3D.new()
	m.mesh = LowPoly.chamfer_box(size, 0.01)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return mat


## A shootable face for `parent` (shots meet it, and the parent takes them).
static func hit_area(parent: Node3D, size: Vector3, at: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = Geo.HITBOX
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("target", parent)
	area.set_meta("zone", "body")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	area.add_child(cs)
	area.position = at
	parent.add_child(area)
	return area
