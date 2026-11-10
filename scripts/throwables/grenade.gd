class_name Grenade
extends Node3D
## One thrown thing (C12, see Throwables). Built on every machine through Deploy ("throw")
## from the same start (where it left the hand, its velocity, how long it was cooked), and
## flown here in fixed steps of DT against the map only, so it bounces the same way and
## lands in the same spot everywhere.
##
## Only the thrower's machine (where `user` is set) deals damage, exactly like a shot: the
## blast calls take_hit on what it reaches, and a hit on a remote player goes to the host
## to be judged. What isn't the same everywhere is sent by the thrower (Deploy.sync):
## a sticky that caught a person ("stick", with who), a mine that went off ("boom").
## Blinding and the kick's push are worked out on every machine for its own bodies (the
## local player, and the bots on the host), so they feel instant and need no packets.
## One hit of anything on a mine pops it everywhere (Deploy event "pop").

const DT := 1.0 / 120.0
const GRAVITY := 18.0
const BOUNCE := 0.38
const ROLL := 0.72
const R := 0.07
const MAX_FLIGHT := 6.0
## A floor mine goes off when an enemy comes this close; a wall mine's line reaches this far.
const MINE_NEAR := 2.2
const MINE_BEAM := 8.0
const MINE_LIFE := 90.0
const FLASH_MAX := 2.4

enum State { FLYING, RESTING, STUCK, DONE }

var uid := ""
var owner_id := ""
var team := 0
var kind := "frag"
## The thrower's node, on the thrower's machine only (Deploy sets it): this one deals damage.
var user: Node3D = null
var pos := Vector3.ZERO
var vel := Vector3.ZERO
## Seconds until it goes off (frag: what was left after cooking).
var fuse := 2.0
var t := 0.0
var state := State.FLYING
## Mine: armed, and the surface it sits on (its line points along it).
var armed := false
var normal := Vector3.UP
var beam_len := 0.0
var _acc := 0.0
var _stuck_to: Node3D = null
var _stuck_off := Vector3.ZERO
var _mesh: MeshInstance3D
var _light: MeshInstance3D
var _light_mat: StandardMaterial3D
var _beam: MeshInstance3D
var _bounces := 0


func setup(data: Dictionary) -> void:
	kind = Throwables.valid(str(data.get("kind", "frag")))
	pos = data.get("from", Vector3.ZERO)
	vel = data.get("vel", Vector3.ZERO)
	fuse = clampf(float(data.get("fuse", Throwables.info(kind).fuse)), 0.0, 4.0)


func _ready() -> void:
	add_to_group("deployables")
	add_to_group("grenades")
	top_level = true
	global_position = pos
	_mesh = MeshInstance3D.new()
	var c: Color = Throwables.info(kind).color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c.darkened(0.25)
	mat.metallic = 0.4
	mat.roughness = 0.5
	match kind:
		"frag":
			_mesh.mesh = LowPoly.blob(0.075, Vector3(1, 1.15, 1), 0)
			mat.albedo_color = Color("#4b5240")
		"flash":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.045
			cyl.bottom_radius = 0.045
			cyl.height = 0.2
			_mesh.mesh = cyl
			mat.albedo_color = Color("#9aa0a6")
		"sticky":
			_mesh.mesh = LowPoly.blob(0.08, Vector3(1, 0.9, 1), 0)
			mat.emission_enabled = true
			mat.emission = c * 0.5
		"smoke":
			var can := CylinderMesh.new()
			can.top_radius = 0.06
			can.bottom_radius = 0.06
			can.height = 0.22
			_mesh.mesh = can
			mat.albedo_color = Color("#6f7780")
		"mine":
			var puck := CylinderMesh.new()
			puck.top_radius = 0.11
			puck.bottom_radius = 0.13
			puck.height = 0.05
			_mesh.mesh = puck
			mat.albedo_color = Color("#2e3236")
		_:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.04
			ring.outer_radius = 0.1
			_mesh.mesh = ring
			mat.emission_enabled = true
			mat.emission = c * 0.6
	_mesh.material_override = mat
	add_child(_mesh)
	# A small lamp in the thrower's colour of the kind: blinks faster as it gets close.
	_light = MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.025
	lm.height = 0.05
	_light.mesh = lm
	_light_mat = StandardMaterial3D.new()
	_light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_mat.albedo_color = c if kind != "mine" else (FpUi.ally_color() if team == Deploy.viewer_team else Color("#ff3b2f"))
	_light.material_override = _light_mat
	_light.position = Vector3(0, 0.07, 0)
	add_child(_light)
	if kind == "mine":
		# The mine can be shot: one hit pops it.
		add_to_group("hittable")
		var area := Area3D.new()
		area.collision_layer = Geo.HITBOX
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("target", self)
		area.set_meta("zone", "body")
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.22
		cs.shape = sph
		area.add_child(cs)
		add_child(area)


## Mines are "hittable" so blasts and shots find them; they aren't anyone to fight.
var alive: bool:
	get:
		return state != State.DONE


func _physics_process(delta: float) -> void:
	if state == State.DONE:
		return
	t += delta
	if _stuck_to != null:
		if is_instance_valid(_stuck_to) and _stuck_to.is_inside_tree() and _stuck_to.visible:
			pos = _stuck_to.global_transform * _stuck_off
		else:
			_stuck_to = null
	_acc += delta
	while _acc >= DT and state == State.FLYING:
		_acc -= DT
		_step()
	if state != State.FLYING:
		_acc = 0.0
	global_position = pos
	if state == State.FLYING and vel.length() > 0.5:
		_mesh.rotation += Vector3(delta * 11.0, delta * 5.0, 0)
	_blink()
	match kind:
		"mine":
			_mine_tick()
		_:
			if t >= fuse or (kind == "sticky" and t >= MAX_FLIGHT):
				explode(pos)


func _blink() -> void:
	var left := fuse - t if kind != "mine" else 1.0
	var rate := 2.0 if kind == "mine" else lerpf(14.0, 3.0, clampf(left / 2.0, 0.0, 1.0))
	if kind == "mine" and not armed:
		rate = 12.0
	_light.visible = fmod(t * rate, 1.0) < 0.5


## One fixed step of flight.
func _step() -> void:
	vel.y -= GRAVITY * DT
	var next := pos + vel * DT
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos, next, Geo.WORLD | Geo.BOUNDS)
	# The thrower's machine also sees people (a sticky catches them); never its own thrower.
	if kind == "sticky" and user != null and is_instance_valid(user):
		q.collision_mask |= Geo.HITBOX
		q.collide_with_areas = true
		q.exclude = user.exclusions() if user.has_method("exclusions") else []
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		pos = next
		if t > MAX_FLIGHT and kind != "sticky":
			_rest(pos, Vector3.UP)
		return
	var n: Vector3 = hit.normal
	var at: Vector3 = hit.position + n * R
	var col: Object = hit.get("collider")
	match kind:
		"sticky":
			var who: Node = col.get_meta("target") if col is Area3D and (col as Area3D).has_meta("target") else null
			if who is Node3D and who != user:
				_stick_to(who as Node3D, at)
				var id := Deploy.id_of(who)
				Deploy.sync(uid, {"what": "stick", "who": id, "at": at})
			else:
				_stick(at, n)
			return
		"mine":
			_stick(at, n)
			return
		"kick":
			explode(at)
			return
	# Frag and flash bounce, then roll to a stop.
	var vn := n * vel.dot(n)
	var vt := vel - vn
	vel = vt * ROLL - vn * BOUNCE
	pos = at
	_bounces += 1
	if _bounces <= 4 and vn.length() > 2.0:
		Sfx.play(self, "nade_bounce", -14.0 + minf(vn.length(), 8.0), 30.0)
	if n.y > 0.65 and vel.length() < 1.2:
		_rest(at, n)


func _rest(at: Vector3, n: Vector3) -> void:
	state = State.RESTING
	pos = at
	normal = n
	vel = Vector3.ZERO


func _stick(at: Vector3, n: Vector3) -> void:
	state = State.STUCK
	pos = at
	normal = n
	vel = Vector3.ZERO
	if kind == "sticky":
		t = maxf(t, 0.0)
		fuse = t + float(Throwables.info("sticky").fuse)
		Sfx.play(self, "sticky_stick", -8.0, 30.0)
	else:
		Sfx.play(self, "mine_arm", -10.0, 24.0)
		_mesh.look_at_from_position(pos, pos + n, Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD)
		_mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		_mesh.position = Vector3.ZERO
		global_position = pos
		_light.position = n * 0.04
		fuse = t + float(Throwables.info("mine").fuse)
		if n.y < 0.65:
			_make_beam(n)


func _stick_to(who: Node3D, at: Vector3) -> void:
	state = State.STUCK
	vel = Vector3.ZERO
	_stuck_to = who
	_stuck_off = who.global_transform.affine_inverse() * at
	pos = at
	fuse = t + float(Throwables.info("sticky").fuse)
	Sfx.play(self, "sticky_stick", -4.0, 30.0)


## A wall mine's line, straight out of the wall until it meets something (MINE_BEAM at most).
func _make_beam(n: Vector3) -> void:
	var to := pos + n * MINE_BEAM
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos + n * 0.05, to, Geo.WORLD))
	beam_len = (pos.distance_to(hit.position) if not hit.is_empty() else MINE_BEAM)
	_beam = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, beam_len)
	_beam.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(_light_mat.albedo_color, 0.0)
	_beam.material_override = m
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_beam.global_transform = Transform3D(Basis.looking_at(n, Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD), pos + n * beam_len / 2.0)


func _mine_tick() -> void:
	if state != State.STUCK:
		return
	if not armed and t >= fuse:
		armed = true
		Sfx.play(self, "mine_beep", -12.0, 20.0)
	if _beam != null:
		var m := _beam.material_override as StandardMaterial3D
		m.albedo_color.a = (0.55 + 0.15 * sin(t * 6.0)) if armed else 0.15
	if t >= fuse + MINE_LIFE:
		_fizzle()
		return
	# The thrower's machine watches it and says when it goes.
	if not armed or user == null:
		return
	for c in get_tree().get_nodes_in_group("combatants"):
		if not (c is Node3D) or not c.get("alive") or c.get("team") == null or int(c.team) == team:
			continue
		if _trips(c as Node3D):
			Deploy.sync(uid, {"what": "boom", "at": pos})
			return


func _trips(c: Node3D) -> bool:
	var feet := c.global_position
	if _beam != null:
		var a := pos
		var b := pos + normal * beam_len
		for h in [0.2, 0.9, 1.6]:
			if Geometry3D.get_closest_point_to_segment(feet + Vector3(0, h, 0), a, b).distance_to(feet + Vector3(0, h, 0)) < 0.4:
				return true
		return false
	var chest := feet + Vector3(0, 0.9, 0)
	if chest.distance_to(pos) > MINE_NEAR:
		return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos + normal * 0.15, chest, Geo.WORLD))
	return hit.is_empty()


## What the thrower's machine sends.
func on_sync(data: Dictionary) -> void:
	if state == State.DONE:
		return
	match str(data.get("what", "")):
		"stick":
			var who := Deploy.node_of(str(data.get("who", "")))
			var at: Vector3 = data.get("at", pos)
			if who != null:
				_stick_to(who, at)
			else:
				_stick(at, Vector3.UP)
		"boom":
			explode(data.get("at", pos))


func on_event(what: String, _amount: float) -> void:
	if what == "pop" or what == "clear":
		_fizzle()


## Shot (or caught in a blast): a mine pops harmlessly; teammates' shots pass it by.
func take_hit(info: Dictionary) -> bool:
	if kind != "mine" or state == State.DONE:
		return false
	if int(info.get("team", -1)) == team:
		return false
	info.blocked = true
	Deploy.event(uid, "pop")
	return false


func _fizzle() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	if is_inside_tree():
		Sfx.play(self, "decoy_pop", -8.0, 30.0)
		PrintFx.impact(get_tree().current_scene, pos, normal, "odd", false)
	queue_free()


## Live and about to go off within `seconds`: how far to stay away (bots dodge), else 0.
func danger(seconds := 1.6) -> float:
	if state == State.DONE or kind in ["flash", "kick", "mine", "smoke"]:
		return 0.0
	if fuse - t > seconds:
		return 0.0
	return float(Throwables.info(kind).radius) + 1.0


# --- Going off -------------------------------------------------------------------------

func explode(at: Vector3) -> void:
	if state == State.DONE:
		return
	state = State.DONE
	pos = at
	var info := Throwables.info(kind)
	var radius := float(info.radius)
	var root := get_tree().current_scene
	match kind:
		"flash":
			_flash_fx(root, at)
			_blind_all(at)
		"smoke":
			# Every machine flew the same canister to the same spot: each grows the cloud
			# itself (registered like VEIL's, so sight checks and a new round find it).
			Sfx.play(self, "smoke_pop", -2.0, 60.0)
			var floor_at := at
			var space := get_world_3d().direct_space_state
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at - Vector3(0, 6, 0), Geo.WORLD))
			if not down.is_empty():
				floor_at = down.position
			Deploy.create(root, "smoke", uid + "s", owner_id, {"from": at, "to": floor_at, "flight": 0.02,
				"team": team, "radius": radius, "life": float(info.life), "canister": false})
		"kick":
			Sfx.play(self, "kick_boom", -2.0, 70.0)
			PrintFx.landing(root, at, 1.4, true)
			Deploy.blast(at, radius)
			_push_all(at, radius)
		_:
			Sfx.play(self, "nade_boom", 0.0, 110.0)
			BotLevel.heard(self)
			PrintFx.explosion(root, at, radius * 0.7)
			Deploy.blast(at, radius)
			if user != null and is_instance_valid(user):
				_damage(at, radius, float(info.damage))
	queue_free()


## The blast on everything it reaches, from the thrower's machine. Walls stop it.
func _damage(at: Vector3, radius: float, damage: float) -> void:
	var space := get_world_3d().direct_space_state
	var mult := float(user.get("damage_mult")) if user is Bot else 1.0
	var exclude: Array = []
	var name_of := str(user.get("display_name")) if user.get("display_name") != null else "?"
	for tg in get_tree().get_nodes_in_group("hittable"):
		if tg == self or not (tg is Node3D) or not tg.get("alive"):
			continue
		var chest := (tg as Node3D).global_position + (Vector3(0, 1.0, 0) if not (tg is Grenade) else Vector3.ZERO)
		var d := chest.distance_to(at)
		if d > radius:
			continue
		var from := at + (chest - at).normalized() * 0.1 + Vector3(0, 0.15, 0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, chest, Geo.WORLD, exclude)).is_empty():
			continue
		var hit := {
			"damage": damage * mult * clampf(1.0 - d / radius, 0.2, 1.0), "zone": "body", "distance": 0.0,
			"point": chest, "dir": (chest - at).normalized(), "attacker": user, "attacker_name": name_of,
			"team": team, "gun_name": str(Throwables.info(kind).name), "build": {}, "effects": {}, "moves": [],
			"through_wall": false, "blast": true, "throw": kind, "from_safe": false, "version": 0,
		}
		if tg == user:
			hit.damage = float(hit.damage) * 0.5
			hit.self_hit = true
		tg.take_hit(hit)
	# Barricades, doors and the map's breakable cover take it too (everywhere, as events).
	for g in ["barricades", "map_cover", "map_doors"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and (n as Node3D).global_position.distance_to(at) < radius + 1.5 and str(n.get("uid")) != "":
				Deploy.event(str(n.uid), "hit", damage * 2.0)


func _flash_fx(root: Node, at: Vector3) -> void:
	Sfx.play(self, "flash_bang", 0.0, 90.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.98, 0.92)
	light.light_energy = 12.0
	light.omni_range = 18.0
	root.add_child(light)
	light.global_position = at + Vector3(0, 0.3, 0)
	var ball := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.2
	ball.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 0.95, 0.9)
	ball.material_override = m
	root.add_child(ball)
	ball.global_position = at
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.parallel().tween_property(ball, "scale", Vector3.ONE * 3.0, 0.25)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(light.queue_free)
	tw.tween_callback(ball.queue_free)


## Seconds of white for someone with their eye at `eye` looking along `fwd`.
static func flash_seconds(space: PhysicsDirectSpaceState3D, eye: Vector3, fwd: Vector3, at: Vector3) -> float:
	var reach := float(Throwables.info("flash").radius)
	var d := eye.distance_to(at)
	if d > reach:
		return 0.0
	var lift := at + Vector3(0, 0.15, 0)
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(lift, eye, Geo.WORLD)).is_empty():
		return 0.0
	var facing := fwd.normalized().dot((at - eye).normalized())
	var look := 1.0 if facing > 0.5 else (lerpf(0.15, 1.0, (facing + 0.3) / 0.8) if facing > -0.3 else 0.12)
	var near := clampf(1.0 - d / reach, 0.0, 1.0)
	var s := FLASH_MAX * look * sqrt(near)
	return s if s > 0.2 else 0.0


## Everyone this machine runs: the local player, and bots where this machine owns them.
func _locals() -> Array:
	var out := []
	var main := get_tree().current_scene
	var p = main.get("player") if main != null else null
	if p is Player and p.alive:
		out.append(p)
	if Deploy.runs_bots():
		for b in get_tree().get_nodes_in_group("bots"):
			if b is Bot and b.alive and b.is_inside_tree():
				out.append(b)
	return out


func _blind_all(at: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	for who in _locals():
		var eye: Transform3D = who.ability_aim()
		var s := flash_seconds(space, eye.origin, -eye.basis.z, at)
		if s > 0.0:
			who.flashed(s)


func _push_all(at: Vector3, radius: float) -> void:
	var push := 15.0
	for who in _locals():
		var centre: Vector3 = (who as Node3D).global_position + Vector3(0, 0.9, 0)
		var d := centre.distance_to(at)
		if d > radius:
			continue
		var k := clampf(1.0 - d / radius, 0.25, 1.0)
		var dir := (centre - at).normalized() if d > 0.05 else Vector3.UP
		who.launch(dir * push * k + Vector3(0, 5.0 * k, 0))


# --- Aiming ----------------------------------------------------------------------------

## The arc from `from` at `v`, as points, up to the first thing it touches (preview, bots).
## Returns [points (PackedVector3Array), where it touches (or the end), the touch normal].
static func predict(space: PhysicsDirectSpaceState3D, from: Vector3, v: Vector3, exclude: Array, seconds := 2.5) -> Array:
	var pts := PackedVector3Array([from])
	var p := from
	var step := 1.0 / 30.0
	var tt := 0.0
	while tt < seconds:
		v.y -= GRAVITY * step
		var next := p + v * step
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, next, Geo.WORLD | Geo.BOUNDS, exclude))
		if not hit.is_empty():
			pts.append(hit.position)
			return [pts, hit.position, hit.normal]
		p = next
		pts.append(p)
		tt += step
	return [pts, p, Vector3.UP]
