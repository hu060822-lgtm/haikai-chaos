class_name Avatar
extends Node3D
## Someone simulated on another machine (a remote player, or a host's bot on a client),
## drawn here from the states its owner sends: an athlete holding their real gun, placed
## INTERP seconds in the past between the two states around that time, so it moves
## smoothly whatever the packet timing. It has the same hitboxes as a player; a hit on
## it is sent to its owner (TeamMatch.send_hit), who decides what the hit does.

const INTERP := 0.1
const KEEP := 1.0

var id := ""
var team := 0
var display_name := "?"
var health := 100.0
var alive := true
var marked := 0.0
## Player.Move of the owner (bots read it to aim; the kill feed reads move tags).
var move := 0
var build := {}
var gun_name := ""
var match_node: Node

var _states: Array = []   # [time, pos, yaw, pitch, move, vel]
var _vel := Vector3.ZERO
var _model: CompetitorRig
var _prev_pos := Vector3.ZERO
var _seen_vel := Vector3.ZERO
var _pitch := 0.0
var _gun: Node3D
var _hitboxes: Array[Area3D] = []
var _ally := false
var _rng := RandomNumberGenerator.new()


func setup(new_id: String, new_team: int, new_name: String, ally: bool) -> void:
	id = new_id
	team = new_team
	display_name = new_name
	_ally = ally
	name = "Avatar_" + new_id
	_rng.seed = hash(new_id)


func _ready() -> void:
	add_to_group("hittable")
	add_to_group("combatants")
	add_to_group("avatars")
	for spec in [["head", SphereShape3D, Vector3(0, 1.62, 0), 0.17], ["body", BoxShape3D, Vector3(0, 1.1, 0), Vector3(0.5, 0.7, 0.32)],
			["legs", BoxShape3D, Vector3(0, 0.4, 0), Vector3(0.42, 0.8, 0.3)]]:
		var area := Area3D.new()
		area.collision_layer = Geo.HITBOX
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("target", self)
		area.set_meta("zone", spec[0])
		var cs := CollisionShape3D.new()
		var shape: Shape3D = spec[1].new()
		if shape is SphereShape3D:
			shape.radius = spec[3]
		else:
			shape.size = spec[3]
		cs.shape = shape
		area.position = spec[2]
		area.add_child(cs)
		add_child(area)
		_hitboxes.append(area)
	_new_model()


func _new_model() -> void:
	_model = CompetitorModel.build(FpUi.ally_color() if _ally else Faultprint.INFO_ENEMY, not _ally, _rng)
	add_child(_model)
	_gun = null
	if not build.is_empty():
		set_build(build, gun_name)


func set_build(new_build: Dictionary, new_name: String) -> void:
	build = new_build
	gun_name = new_name
	if _model == null:
		return
	if _gun != null:
		_gun.queue_free()
	_gun = GunModels.build(build)
	_model.find_child("GunHand", true, false).add_child(_gun)


## A state from the owner (20 times a second).
func push_state(pos: Vector3, yaw: float, pitch: float, new_move: int, vel: Vector3, hp: float, new_marked: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _states.is_empty():
		global_position = pos
		rotation.y = yaw
	_states.append([now, pos, yaw, pitch, new_move, vel])
	while _states.size() > 2 and now - float(_states[0][0]) > KEEP:
		_states.pop_front()
	health = hp
	marked = new_marked
	move = new_move
	_vel = vel


func _process(delta: float) -> void:
	marked = maxf(marked - delta, 0.0)
	if _states.is_empty() or not alive:
		return
	var t := Time.get_ticks_msec() / 1000.0 - INTERP
	var a: Array = _states[0]
	var b: Array = _states[-1]
	for i in range(_states.size() - 1):
		if float(_states[i][0]) <= t and float(_states[i + 1][0]) >= t:
			a = _states[i]
			b = _states[i + 1]
			break
	var span := maxf(float(b[0]) - float(a[0]), 0.001)
	var k := clampf((t - float(a[0])) / span, 0.0, 1.0)
	if t > float(b[0]):
		# Late packets: carry on a little along the last velocity, never far.
		global_position = (b[1] as Vector3) + (b[5] as Vector3) * minf(t - float(b[0]), 0.15)
		rotation.y = float(b[2])
	else:
		global_position = (a[1] as Vector3).lerp(b[1], k)
		rotation.y = lerp_angle(float(a[2]), float(b[2]), k)
	# The body moves the way it was seen to move (what's drawn, not the raw packets).
	if delta > 0.0:
		_seen_vel = _seen_vel.lerp((global_position - _prev_pos) / delta, 1.0 - exp(-15.0 * delta))
	_prev_pos = global_position
	_pitch = lerpf(float(a[3]), float(b[3]), k)
	if _model != null:
		var m: int = int(b[4])
		_model.pose(delta, _seen_vel, m != Player.Move.AIR and m != Player.Move.WALLRUN,
			0.0, m == Player.Move.SLIDE,
			0 if m != Player.Move.WALLRUN else 1, _pitch)


func flat_speed() -> float:
	return Vector2(_vel.x, _vel.z).length()


func exclusions() -> Array:
	var out := []
	for a in _hitboxes:
		out.append(a.get_rid())
	return out


## The muzzle, for drawing this avatar's shots.
func muzzle() -> Vector3:
	if _gun != null and _gun.is_inside_tree():
		return _gun.to_global(_gun.get_meta("muzzle", Vector3.ZERO))
	return global_position + Vector3(0, 1.4, 0)


## A hit from someone on this machine: the owner decides. Returns the predicted kill (so
## kill-triggered parts like the hourglass magazine answer at once).
func take_hit(info: Dictionary) -> bool:
	if not alive:
		return false
	if int(info.get("team", -1)) == team and info.get("attacker") != self:
		return false
	if SafeZone.blocks(info, team, global_position):
		return false
	if match_node != null:
		match_node.send_hit(id, info)
	var e: Dictionary = info.get("effects", {})
	if e.has("mark"):
		marked = maxf(marked, float(e.mark))
	if _model != null and info.get("dir") is Vector3:
		_model.flinch(info.dir, clampf(float(info.get("damage", 20.0)) / 30.0, 0.3, 1.5))
	return float(info.get("damage", 0.0)) >= health


func die(dir := Vector3.ZERO) -> void:
	if alive and visible and _model != null and not _states.is_empty():
		CompetitorRig.leave_corpse(_model, dir)
		_model = null
		_gun = null
	alive = false
	visible = false
	_states.clear()
	for a in _hitboxes:
		a.set_deferred("collision_layer", 0)


func respawn(pos: Vector3, yaw: float) -> void:
	if _model == null:
		_new_model()
	alive = true
	visible = true
	_prev_pos = pos
	health = 100.0
	_states.clear()
	global_position = pos
	rotation.y = yaw
	for a in _hitboxes:
		a.set_deferred("collision_layer", Geo.HITBOX)
