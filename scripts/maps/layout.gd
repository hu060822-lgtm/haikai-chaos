class_name Layout
extends RefCounted
## The floor plan of a big competitive map (C5), as a grid of cells. A map starts solid
## ('#') and carves its rooms, lanes and corridors out of it in world metres; the rest
## stays rock. The plan then does three jobs:
##
##   build    the solid cells become a few big wall blocks (rectangles merged greedily),
##            each with an invisible column above it up to CEILING, plus a lid over the
##            whole map: nothing can be climbed out of, whatever the movement does
##   nav      bots find their way on it (A* over open cells, then straightened), so they
##            can walk lanes and turn corners instead of walking into walls
##   draw     the plan as text (for tests and the minimap)
##
## Cell kinds: '#' solid, '.' open floor, 'x' open but built by hand (a map's own hall),
## 'o' blocked for bots but built by hand (a tower, a table), 'c' low cover (bots go round),
## anything else is open floor of a named area ('a' site A, 'b' site B, 's' spawn...).
## 'w' (C6) is a breakable panel in a gap of the rock: solid until a RAM goes through it.
## 'v' (C7) is a vault window: a sill and a lintel, jump through it (solid for bots).
## 'k' (C7) is a ledge block against a wall, 1.1 or 2.1 m high (solid for bots).
##
## C10 (THE LAST TESTAMENT): a plan can be mirrored north–south instead of turned half
## round (mirror_ns), and can have more than one floor for the bots: the ground's cells can
## sit at other heights (ramps, a sunken trench, a dais), decks over or under the ground
## (galleries, a crypt) have their own open cells, and links join them (the top of a
## stair, a drop off a gallery edge). path() then searches all floors at once; on a plan
## without any of that it is the same single-floor search as before.

const CEILING := 40.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
## The invisible barriers: bodies collide with them, shots and wall probes don't.
const BOUNDS_LAYER := Geo.BOUNDS

var rect: Rect2
var cell: float
var cols: int
var rows: int
var grid: PackedByteArray
## The breakable gaps: [cell (Vector2i), axis (Vector2i: the way through)].
var breaches: Array = []
## Twins mirrored north–south (z -> -z) instead of turned half round (C10).
var mirror_ns := false


func _init(area: Rect2, cell_size := 2.0) -> void:
	rect = area
	cell = cell_size
	cols = int(ceil(area.size.x / cell))
	rows = int(ceil(area.size.y / cell))
	grid = PackedByteArray()
	grid.resize(cols * rows)
	grid.fill("#".unicode_at(0))


func _index(c: int, r: int) -> int:
	return r * cols + c


func inside(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < cols and r < rows


func at(c: int, r: int) -> String:
	return char(grid[_index(c, r)]) if inside(c, r) else "#"


func set_cell(c: int, r: int, ch: String) -> void:
	if inside(c, r):
		grid[_index(c, r)] = ch.unicode_at(0)


func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor((pos.x - rect.position.x) / cell)), int(floor((pos.z - rect.position.y) / cell)))


func centre(c: int, r: int, y := 0.0) -> Vector3:
	return Vector3(rect.position.x + (c + 0.5) * cell, y, rect.position.y + (r + 0.5) * cell)


func kind_at(pos: Vector3) -> String:
	var g := cell_of(pos)
	return at(g.x, g.y)


## Sets every cell whose centre is in `area` (world x/z) to `ch`.
func carve(area: Rect2, ch := ".") -> void:
	var a := cell_of(Vector3(area.position.x + 0.01, 0, area.position.y + 0.01))
	var b := cell_of(Vector3(area.end.x - 0.01, 0, area.end.y - 0.01))
	for r in range(maxi(a.y, 0), mini(b.y + 1, rows)):
		for c in range(maxi(a.x, 0), mini(b.x + 1, cols)):
			set_cell(c, r, ch)


## carve() and the same turned half round the map's centre (the maps are fair that way),
## or mirrored north–south on a mirror_ns plan.
func carve2(area: Rect2, ch := ".") -> void:
	carve(area, ch)
	carve(turned(area), ch)


func turned(area: Rect2) -> Rect2:
	var mid := rect.get_center()
	if mirror_ns:
		return Rect2(area.position.x, mid.y * 2.0 - area.end.y, area.size.x, area.size.y)
	return Rect2(mid * 2.0 - area.end, area.size)


## A point's twin on the other half (turned, or mirrored on a mirror_ns plan).
func twin(p: Vector3) -> Vector3:
	var mid := rect.get_center()
	if mirror_ns:
		return Vector3(p.x, p.y, mid.y * 2.0 - p.z)
	return turn(p, mid)


func twin_cell(g: Vector2i) -> Vector2i:
	return Vector2i(g.x, rows - 1 - g.y) if mirror_ns else Vector2i(cols - 1 - g.x, rows - 1 - g.y)


static func turn(p: Vector3, mid := Vector2.ZERO) -> Vector3:
	return Vector3(mid.x * 2.0 - p.x, p.y, mid.y * 2.0 - p.z)


func solid(c: int, r: int) -> bool:
	return at(c, r) == "#" or at(c, r) == "w" or at(c, r) == "v" or at(c, r) == "k"


func walkable(c: int, r: int) -> bool:
	var k := at(c, r)
	return k != "#" and k != "o" and k != "c" and k != "w" and k != "v" and k != "k"


## The cells of `chars` merged into rectangles (in cells): Rect2i(col, row, w, h).
func cell_rects(chars: String) -> Array[Rect2i]:
	var used := PackedByteArray()
	used.resize(cols * rows)
	var out: Array[Rect2i] = []
	for r in rows:
		for c in cols:
			if used[_index(c, r)] != 0 or not chars.contains(at(c, r)):
				continue
			var w := 1
			while c + w < cols and used[_index(c + w, r)] == 0 and chars.contains(at(c + w, r)):
				w += 1
			var h := 1
			var grow := true
			while grow and r + h < rows:
				for i in w:
					if used[_index(c + i, r + h)] != 0 or not chars.contains(at(c + i, r + h)):
						grow = false
						break
				if grow:
					h += 1
			for rr in h:
				for cc in w:
					used[_index(c + cc, r + rr)] = 1
			out.append(Rect2i(c, r, w, h))
	return out


## The same, in world metres (x/z).
func rects(chars: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for q in cell_rects(chars):
		out.append(Rect2(rect.position + Vector2(q.position) * cell, Vector2(q.size) * cell))
	return out


## The solid cells as walls: `make(size, centre)` builds each one (the map's own look),
## then the invisible columns above and the lid go on top.
func build_walls(parent: Node3D, height: float, make: Callable) -> void:
	for w in rects("#"):
		make.call(Vector3(w.size.x, height, w.size.y), Vector3(w.get_center().x, height / 2.0, w.get_center().y))
		barrier(parent, Vector3(w.size.x, CEILING - height, w.size.y), Vector3(w.get_center().x, (CEILING + height) / 2.0, w.get_center().y))
	for i in breaches.size():
		var g: Vector2i = breaches[i][0]
		var axis: Vector2i = breaches[i][1]
		var panel := Breakable.new()
		panel.name = "Breach%d" % i
		panel.uid = "w:%d" % i
		panel.layout = self
		panel.cell = g
		panel.build(cell, height, axis.y != 0)
		panel.position = centre(g.x, g.y)
		parent.add_child(panel)
		Deploy.register(panel.uid, panel)
		var top := centre(g.x, g.y, (CEILING + height) / 2.0)
		barrier(parent, Vector3(cell, CEILING - height, cell), top)
	for l in ledges:
		var g: Vector2i = l[0]
		var h: float = l[1]
		make.call(Vector3(cell, h, cell), centre(g.x, g.y, h / 2.0))
	for wnd in windows:
		var g: Vector2i = wnd[0]
		make.call(Vector3(cell, WINDOW_SILL, cell), centre(g.x, g.y, WINDOW_SILL / 2.0))
		make.call(Vector3(cell, height - WINDOW_TOP, cell), centre(g.x, g.y, (height + WINDOW_TOP) / 2.0))
		barrier(parent, Vector3(cell, CEILING - height, cell), centre(g.x, g.y, (CEILING + height) / 2.0))
	seal(parent)


## Picks `pairs` gaps in the rock for breakable panels (C6), each with its twin turned half
## round: a wall up to MAX_BREACH cells thick with open lane on both sides, where walking
## round is at least `min_detour` metres. A thicker wall gets a short tunnel cut through it
## with the panel in its middle. Spots far apart from each other, never into a spawn. Call
## it after carving and before build_walls.
const MAX_BREACH := 8

func mark_breaches(pairs := 2, min_detour := 30.0, max_detour := 110.0) -> void:
	for p in _pick_gaps(pairs, min_detour, max_detour, MAX_BREACH, 18.0):
		breaches.append([_cut(p, "w"), p[1]])


## C7: small open passages, 1 cell (2 m) wide, through walls up to `max_thick` cells,
## where they save at least `min_detour` metres of walking. Mirrored like everything else.
func cut_passages(pairs := 4, min_detour := 18.0, max_thick := 8) -> void:
	for p in _pick_gaps(pairs, min_detour, 200.0, max_thick, 12.0):
		_cut(p, ".")
		passages.append(p)


## C7: vault windows: a passage with a sill (WINDOW_SILL high) and a lintel (from
## WINDOW_TOP up) in its middle cell: jump or mantle through, bots go round.
const WINDOW_SILL := 0.95
const WINDOW_TOP := 2.95

func cut_windows(pairs := 2, min_detour := 14.0, max_thick := 5) -> void:
	for p in _pick_gaps(pairs, min_detour, 200.0, max_thick, 12.0):
		windows.append([_cut(p, "v"), p[1]])


## C7: a hand-placed passage in cells (and its twin turned half round), for maps whose
## walls are too thick for cut_passages to find one.
func carve_cells2(r: Rect2i, ch := ".") -> void:
	for rr in range(r.position.y, r.end.y):
		for cc in range(r.position.x, r.end.x):
			set_cell(cc, rr, ch)
			var t := twin_cell(Vector2i(cc, rr))
			set_cell(t.x, t.y, ch)
	var mid := r.get_center()
	_gaps.append(mid)
	_gaps.append(twin_cell(mid))


## C7: a vault window at cell `g` (and its twin), across a passage running along `axis`.
func window2(g: Vector2i, axis: Vector2i) -> void:
	for q in [g, twin_cell(g)]:
		set_cell(q.x, q.y, "v")
		windows.append([q, axis])


## C7: ledge blocks against the walls of wide lanes, two heights (LEDGE_HEIGHTS): a step
## up onto a wall run, a perch, a kick-off point. Bots walk round them ('k').
const LEDGE_HEIGHTS := [1.1, 2.1]
var ledges: Array = []

func add_ledges(pairs := 6) -> void:
	var found := []
	for r in range(2, rows - 2):
		for c in range(2, cols - 2):
			var g := Vector2i(c, r)
			if at(c, r) != "." or not _lane(g):
				continue
			for axis in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				# Rock behind, three open cells in front, open along the wall both ways.
				var back: Vector2i = g - axis
				if at(back.x, back.y) != "#":
					continue
				var ok := true
				for k in range(1, 4):
					var q: Vector2i = g + axis * k
					if at(q.x, q.y) != "." :
						ok = false
				var side := Vector2i(axis.y, axis.x)
				for q in [g + side, g - side]:
					if at(q.x, q.y) != ".":
						ok = false
				if ok:
					found.append(g)
					break
	# Spread out: deterministic shuffle by position, then keep far-apart ones.
	found.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return (x.x * 73856093 ^ x.y * 19349663) % 1000 < (y.x * 73856093 ^ y.y * 19349663) % 1000)
	for g in found:
		if ledges.size() >= pairs * 2:
			break
		var tw := twin_cell(g)
		if at(tw.x, tw.y) != "." or tw == g:
			continue
		var far := true
		for q in _gaps:
			if q.distance_to(g) * cell < 14.0 or q.distance_to(tw) * cell < 14.0:
				far = false
				break
		if not far:
			continue
		var h: float = LEDGE_HEIGHTS[ledges.size() / 2 % LEDGE_HEIGHTS.size()]
		for q in [g, tw]:
			set_cell(q.x, q.y, "k")
			ledges.append([q, h])
			_gaps.append(q)


## The gaps picked so far (any kind), so later ones keep away from them.
var _gaps: Array[Vector2i] = []
## Open passages [cell, axis, thickness] and windows [cell, axis] (C7).
var passages: Array = []
var windows: Array = []


func _pick_gaps(pairs: int, min_detour: float, max_detour: float, max_thick: int, spacing: float) -> Array:
	var found := []
	for r in range(1, rows - 1):
		for c in range(1, cols - 1):
			if at(c, r) != "#":
				continue
			for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
				var g := Vector2i(c, r)
				var a: Vector2i = g - axis
				if not _lane(a):
					continue
				var t := _thickness(g, axis, max_thick)
				if t == 0:
					continue
				var b: Vector2i = g + axis * t
				var d := _walk(a, b, int(max_detour / cell) + 4) * cell
				if d >= min_detour and d <= max_detour:
					found.append([d - t * cell * 2.0, g, axis, t])
	# Longest detour saved first; a thin wall beats a long tunnel for the same saving.
	found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var picked := []
	for f in found:
		if picked.size() >= pairs * 2:
			break
		var g: Vector2i = f[1]
		var axis: Vector2i = f[2]
		var t: int = f[3]
		# The twin starts from the far end, so it is the same strip turned round (mirrored
		# north–south, only a strip running north–south starts from its far end).
		var tw := twin_cell(g + axis * (t - 1)) if not mirror_ns or axis.y != 0 else twin_cell(g)
		if _thickness(tw, axis, max_thick) != t or g.distance_to(tw) < 6.0:
			continue
		var far := true
		for q in _gaps:
			if q.distance_to(g) * cell < spacing or q.distance_to(tw) * cell < spacing:
				far = false
				break
		if not far:
			continue
		_gaps.append(g)
		_gaps.append(tw)
		picked.append([g, axis, t])
		picked.append([tw, axis, t])
	return picked


## Cuts a picked gap open; its middle cell becomes `middle`. Returns the middle cell.
func _cut(p: Array, middle: String) -> Vector2i:
	var g: Vector2i = p[0]
	var axis: Vector2i = p[1]
	var t: int = p[2]
	for k in t:
		var q: Vector2i = g + axis * k
		set_cell(q.x, q.y, middle if k == t / 2 else ".")
	return g + axis * (t / 2)


## How many solid cells from `g` along `axis` to open lane (1..MAX_BREACH), with rock on
## both sides of every one of them; 0 if it isn't a gap like that.
func _thickness(g: Vector2i, axis: Vector2i, max_thick := MAX_BREACH) -> int:
	var perp := Vector2i(axis.y, axis.x)
	for t in range(1, max_thick + 1):
		var q: Vector2i = g + axis * (t - 1)
		if at(q.x, q.y) != "#" or _layered(q) or not (solid(q.x + perp.x, q.y + perp.y) and solid(q.x - perp.x, q.y - perp.y)):
			return 0
		if _lane(q + axis):
			return t
	return 0


func _lane(g: Vector2i) -> bool:
	var k := at(g.x, g.y)
	return walkable(g.x, g.y) and k != "s" and k != "x" and not _layered(g)


## A cell on a slope, or over or under a deck: no gaps cut through or next to it.
func _layered(g: Vector2i) -> bool:
	if not inside(g.x, g.y):
		return false
	if not heights.is_empty() and heights[_index(g.x, g.y)] != 0.0:
		return true
	for d in decks:
		if (d.open as PackedByteArray)[_index(g.x, g.y)] != 0:
			return true
	return false


## Steps on open cells (4-way) from a to b, or a big number past `limit`.
func _walk(a: Vector2i, b: Vector2i, limit: int) -> int:
	var dist := {a: 0}
	var front: Array[Vector2i] = [a]
	while not front.is_empty():
		var next: Array[Vector2i] = []
		for cur in front:
			var d: int = dist[cur]
			if d >= limit:
				continue
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cur + step
				if dist.has(n) or not walkable(n.x, n.y):
					continue
				if n == b:
					return d + 1
				dist[n] = d + 1
				next.append(n)
		front = next
	return 1 << 20


## A lid over the map and walls round its edge, all invisible.
func seal(parent: Node3D, margin := 2.0) -> void:
	var r := rect.grow(margin)
	barrier(parent, Vector3(r.size.x, 1.0, r.size.y), Vector3(r.get_center().x, CEILING + 0.5, r.get_center().y))
	for side in 4:
		var horizontal := side < 2
		var size := Vector3(r.size.x + 2.0, CEILING + 20.0, 1.0) if horizontal else Vector3(1.0, CEILING + 20.0, r.size.y + 2.0)
		var at_edge := Vector3(r.get_center().x, CEILING / 2.0 - 10.0, r.position.y - 0.5 if side == 0 else r.end.y + 0.5) if horizontal \
			else Vector3(r.position.x - 0.5 if side == 2 else r.end.x + 0.5, CEILING / 2.0 - 10.0, r.get_center().y)
		barrier(parent, size, at_edge)


static func barrier(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = BOUNDS_LAYER
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


# --- Finding the way -------------------------------------------------------------------

## Points from `from` to `to` (world), corners only. Empty when there's no way.
func path(from: Vector3, to: Vector3) -> Array[Vector3]:
	if layered():
		return _path_levels(from, to)
	var s := _nearest_open(cell_of(from))
	var g := _nearest_open(cell_of(to))
	var out: Array[Vector3] = []
	if s.x < 0 or g.x < 0:
		return out
	if s == g:
		out.append(to)
		return out
	var n_cells := cols * rows
	var cost := PackedFloat32Array()
	cost.resize(n_cells)
	cost.fill(INF)
	var came := PackedInt32Array()
	came.resize(n_cells)
	came.fill(-1)
	var done := PackedByteArray()
	done.resize(n_cells)
	var si := _index(s.x, s.y)
	var gi := _index(g.x, g.y)
	cost[si] = 0.0
	var heap := _Heap.new()
	heap.push(_h(s, g), si)
	var found := false
	while not heap.empty():
		var ci := heap.pop()
		if done[ci] != 0:
			continue
		done[ci] = 1
		if ci == gi:
			found = true
			break
		var cur := Vector2i(ci % cols, ci / cols)
		for d in DIRS:
			var n: Vector2i = cur + d
			if not walkable(n.x, n.y):
				continue
			if d.x != 0 and d.y != 0 and (not walkable(cur.x + d.x, cur.y) or not walkable(cur.x, cur.y + d.y)):
				continue
			var ni := _index(n.x, n.y)
			# Hug walls less: a cell next to rock costs a bit more.
			var step := (1.41421 if d.x != 0 and d.y != 0 else 1.0) + (0.6 if _near_rock(n) else 0.0)
			var c2 := cost[ci] + step
			if c2 < cost[ni]:
				cost[ni] = c2
				came[ni] = ci
				heap.push(c2 + _h(n, g), ni)
	if not found:
		return out
	var cells: Array[Vector2i] = [g]
	var k := gi
	while k != si:
		k = came[k]
		cells.append(Vector2i(k % cols, k / cols))
	cells.reverse()
	# Straighten: keep a corner only where the straight line to the next one is blocked.
	var keep: Array[Vector2i] = [cells[0]]
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not clear(keep[-1], cells[j]):
			j -= 1
		keep.append(cells[j])
		i = j
	for q in range(1, keep.size()):
		out.append(centre(keep[q].x, keep[q].y, to.y))
	out[-1] = to
	return out


func _h(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


func _near_rock(n: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not walkable(n.x + d.x, n.y + d.y):
			return true
	return false


## True when a bot can walk straight from cell a to cell b (a body-wide line of open cells).
func clear(a: Vector2i, b: Vector2i) -> bool:
	var pa := Vector2(a) + Vector2(0.5, 0.5)
	var pb := Vector2(b) + Vector2(0.5, 0.5)
	var n := int(ceil(pa.distance_to(pb) * 3.0)) + 1
	var side := (pb - pa).normalized().orthogonal() * 0.3
	for k in n + 1:
		var p := pa.lerp(pb, float(k) / n)
		for q in [p, p + side, p - side]:
			if not walkable(int(floor(q.x)), int(floor(q.y))):
				return false
	return true


func _nearest_open(g: Vector2i) -> Vector2i:
	if walkable(g.x, g.y):
		return g
	for radius in range(1, 6):
		for r in range(g.y - radius, g.y + radius + 1):
			for c in range(g.x - radius, g.x + radius + 1):
				if walkable(c, r):
					return Vector2i(c, r)
	return Vector2i(-1, -1)


## Open cells spread over the plan (at least `spacing` cells apart), for bots to wander.
## On a plan with decks, their cells too (at their height).
func wander_points(spacing := 5) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for level in decks.size() + 1:
		# Decks are smaller: closer together there.
		var step := spacing if level == 0 else maxi(spacing - 2, 2)
		for r in range(step / 2, rows, step):
			for c in range(step / 2, cols, step):
				var g := Vector2i(c, r)
				if level == 0 and walkable(c, r) and not _near_rock(g):
					out.append(centre(c, r, height(0, g)))
				elif level > 0 and open_on(level, g) and _all_open(level, g):
					out.append(centre(c, r, height(level, g)))
	return out


func _all_open(level: int, g: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not open_on(level, g + d):
			return false
	return true


## The plan as text, one line per row (north at the top).
func draw() -> String:
	var lines := PackedStringArray()
	for r in rows:
		var line := ""
		for c in cols:
			line += at(c, r)
		lines.append(line)
	return "\n".join(lines)


## A binary min-heap of [priority, value] for the path search.
class _Heap:
	var keys := PackedFloat32Array()
	var vals := PackedInt32Array()

	func empty() -> bool:
		return keys.is_empty()

	func push(key: float, val: int) -> void:
		keys.append(key)
		vals.append(val)
		var i := keys.size() - 1
		while i > 0:
			var up := (i - 1) / 2
			if keys[up] <= keys[i]:
				break
			_swap(i, up)
			i = up

	func pop() -> int:
		var top := vals[0]
		var last := keys.size() - 1
		_swap(0, last)
		keys.resize(last)
		vals.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < last and keys[l] < keys[m]:
				m = l
			if r < last and keys[r] < keys[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var k := keys[a]
		keys[a] = keys[b]
		keys[b] = k
		var v := vals[a]
		vals[a] = vals[b]
		vals[b] = v


# --- More than one floor (C10) -----------------------------------------------------------

## How far apart (m) two neighbouring cells of the ground can be in height and still be
## walked between: a ramp of 2 m cells rises about 1 m a cell, a dais edge 1.2 m doesn't.
const STEP_RISE := 1.05

## The ground's height per cell (empty: all 0).
var heights := PackedFloat32Array()
## Floors other than the ground: {"y": height, "open": PackedByteArray per cell}. Level 0
## is the ground, deck i is level i + 1.
var decks: Array = []
## Links between floors: node -> [[node, cost]], a node being level * cols * rows + cell.
var links := {}


func layered() -> bool:
	return not decks.is_empty() or not heights.is_empty()


## The ground's cells in `area` sit at `y`.
func set_height(area: Rect2, y: float) -> void:
	_heights_on()
	for g in _cells_in(area):
		heights[_index(g.x, g.y)] = y


## The ground's cells in `area` slope from `from_y` to `to_y` along `axis` (the way it
## rises or falls: Vector2i(1, 0) means from the west edge to the east edge).
func set_slope(area: Rect2, axis: Vector2i, from_y: float, to_y: float) -> void:
	_heights_on()
	for g in _cells_in(area):
		var p := centre(g.x, g.y)
		var t := 0.0
		if axis.x != 0:
			t = (p.x - area.position.x) / area.size.x
			if axis.x < 0:
				t = 1.0 - t
		else:
			t = (p.z - area.position.y) / area.size.y
			if axis.y < 0:
				t = 1.0 - t
		heights[_index(g.x, g.y)] = lerpf(from_y, to_y, t)


func _heights_on() -> void:
	if heights.is_empty():
		heights.resize(cols * rows)
		heights.fill(0.0)


func _cells_in(area: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a := cell_of(Vector3(area.position.x + 0.01, 0, area.position.y + 0.01))
	var b := cell_of(Vector3(area.end.x - 0.01, 0, area.end.y - 0.01))
	for r in range(maxi(a.y, 0), mini(b.y + 1, rows)):
		for c in range(maxi(a.x, 0), mini(b.x + 1, cols)):
			out.append(Vector2i(c, r))
	return out


## A new deck at height `y` with no open cells yet; returns its level.
func add_deck(y: float) -> int:
	var open := PackedByteArray()
	open.resize(cols * rows)
	decks.append({"y": y, "open": open})
	return decks.size()


## Opens (or closes) the deck's cells in `area`.
func open_deck(level: int, area: Rect2, open := true) -> void:
	var m: PackedByteArray = decks[level - 1].open
	for g in _cells_in(area):
		m[_index(g.x, g.y)] = 1 if open else 0


## The same with its twin.
func open_deck2(level: int, area: Rect2, open := true) -> void:
	open_deck(level, area, open)
	open_deck(level, turned(area), open)


## A way between floors: from `a` on `la` to `b` on `lb` (a stair top, a drop), both ways
## unless `both` is false.
func link(la: int, a: Vector3, lb: int, b: Vector3, both := true) -> void:
	var na := _node(la, cell_of(a))
	var nb := _node(lb, cell_of(b))
	var cost := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) / cell + 0.5
	links[na] = links.get(na, []) + [[nb, cost]]
	if both:
		links[nb] = links.get(nb, []) + [[na, cost]]


## link() and its twin.
func link2(la: int, a: Vector3, lb: int, b: Vector3, both := true) -> void:
	link(la, a, lb, b, both)
	link(la, twin(a), lb, twin(b), both)


func open_on(level: int, g: Vector2i) -> bool:
	if not inside(g.x, g.y):
		return false
	if level == 0:
		return walkable(g.x, g.y)
	return (decks[level - 1].open as PackedByteArray)[_index(g.x, g.y)] != 0


func height(level: int, g: Vector2i) -> float:
	if level > 0:
		return float(decks[level - 1].y)
	if heights.is_empty() or not inside(g.x, g.y):
		return 0.0
	return heights[_index(g.x, g.y)]


## Which floor someone at `pos` is on: the highest one open there at or below their feet.
func level_at(pos: Vector3) -> int:
	var g := cell_of(pos)
	var best := -1
	var best_y := -INF
	for level in decks.size() + 1:
		var y := height(level, g)
		if y <= pos.y + 1.0 and y > best_y and (open_on(level, g) or level == 0):
			best = level
			best_y = y
	return maxi(best, 0)


func _node(level: int, g: Vector2i) -> int:
	return level * cols * rows + _index(g.x, g.y)


func _step_ok(level: int, a: Vector2i, b: Vector2i) -> bool:
	return level > 0 or heights.is_empty() or absf(heights[_index(a.x, a.y)] - heights[_index(b.x, b.y)]) <= STEP_RISE


func _nearest_on(level: int, g: Vector2i) -> Vector2i:
	if open_on(level, g):
		return g
	for radius in range(1, 6):
		for r in range(g.y - radius, g.y + radius + 1):
			for c in range(g.x - radius, g.x + radius + 1):
				if open_on(level, Vector2i(c, r)):
					return Vector2i(c, r)
	return Vector2i(-1, -1)


## path() over every floor: A* over (floor, cell) and the links, straightened floor by
## floor; each point is at its floor's height there.
func _path_levels(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var ls := level_at(from)
	var lg := level_at(to)
	var s := _nearest_on(ls, cell_of(from))
	var g := _nearest_on(lg, cell_of(to))
	if s.x < 0 or g.x < 0:
		return out
	var si := _node(ls, s)
	var gi := _node(lg, g)
	if si == gi:
		out.append(to)
		return out
	var per := cols * rows
	var n_nodes := per * (decks.size() + 1)
	var cost := PackedFloat32Array()
	cost.resize(n_nodes)
	cost.fill(INF)
	var came := PackedInt32Array()
	came.resize(n_nodes)
	came.fill(-1)
	var done := PackedByteArray()
	done.resize(n_nodes)
	cost[si] = 0.0
	var heap := _Heap.new()
	heap.push(_h(s, g), si)
	var found := false
	while not heap.empty():
		var ni0 := heap.pop()
		if done[ni0] != 0:
			continue
		done[ni0] = 1
		if ni0 == gi:
			found = true
			break
		var level := ni0 / per
		var ci := ni0 % per
		var cur := Vector2i(ci % cols, ci / cols)
		for d in DIRS:
			var n: Vector2i = cur + d
			if not open_on(level, n) or not _step_ok(level, cur, n):
				continue
			if d.x != 0 and d.y != 0 and (not open_on(level, Vector2i(cur.x + d.x, cur.y)) or not open_on(level, Vector2i(cur.x, cur.y + d.y))):
				continue
			var nn := level * per + _index(n.x, n.y)
			var step := (1.41421 if d.x != 0 and d.y != 0 else 1.0) + (0.6 if level == 0 and _near_rock(n) else 0.0)
			var c2 := cost[ni0] + step
			if c2 < cost[nn]:
				cost[nn] = c2
				came[nn] = ni0
				heap.push(c2 + _h(n, g), nn)
		for l in links.get(ni0, []):
			var nn: int = l[0]
			var c2: float = cost[ni0] + float(l[1])
			if c2 < cost[nn]:
				cost[nn] = c2
				came[nn] = ni0
				var nc := nn % per
				heap.push(c2 + _h(Vector2i(nc % cols, nc / cols), g), nn)
	if not found:
		return out
	var nodes: Array[int] = [gi]
	var k := gi
	while k != si:
		k = came[k]
		nodes.append(k)
	nodes.reverse()
	# Split into runs on one floor, straighten each, keep both ends of every run.
	var run_start := 0
	for i in range(1, nodes.size() + 1):
		var cut := i == nodes.size() or nodes[i] / per != nodes[i - 1] / per \
			or not _adjacent(nodes[i] % per, nodes[i - 1] % per)
		if not cut:
			continue
		var level: int = nodes[run_start] / per
		var cells: Array[Vector2i] = []
		for j in range(run_start, i):
			var ci: int = nodes[j] % per
			cells.append(Vector2i(ci % cols, ci / cols))
		var keep: Array[Vector2i] = [cells[0]]
		var a := 0
		while a < cells.size() - 1:
			var b := cells.size() - 1
			while b > a + 1 and not clear_on(level, keep[-1], cells[b]):
				b -= 1
			keep.append(cells[b])
			a = b
		for q in range(0 if run_start > 0 else 1, keep.size()):
			out.append(centre(keep[q].x, keep[q].y, height(level, keep[q])))
		run_start = i
	if out.is_empty():
		out.append(to)
	else:
		out[-1] = to
	return out


func _adjacent(a: int, b: int) -> bool:
	return absi(a % cols - b % cols) <= 1 and absi(a / cols - b / cols) <= 1


## clear() on any floor; on the ground also no step up or down steeper than a ramp.
func clear_on(level: int, a: Vector2i, b: Vector2i) -> bool:
	var pa := Vector2(a) + Vector2(0.5, 0.5)
	var pb := Vector2(b) + Vector2(0.5, 0.5)
	var n := int(ceil(pa.distance_to(pb) * 3.0)) + 1
	var side := (pb - pa).normalized().orthogonal() * 0.3
	var last := [Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1)]
	for k in n + 1:
		var p := pa.lerp(pb, float(k) / n)
		var lane := 0
		for q in [p, p + side, p - side]:
			var g := Vector2i(int(floor(q.x)), int(floor(q.y)))
			if not open_on(level, g):
				return false
			if level == 0 and last[lane].x >= 0 and last[lane] != g and not _step_ok(0, last[lane], g):
				return false
			last[lane] = g
			lane += 1
	return true
