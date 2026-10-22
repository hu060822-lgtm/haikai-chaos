class_name ViewModel
extends Node3D
## The first-person gun (the art brief's top priority): the bench build at the lower right,
## two blocky gloves on it, and the motion that says what you're doing: bob, sway, recoil
## kick, the reload roll, a lowered gun while sprinting, tilted on slides and wall runs,
## and aiming that puts the build's own sight in the middle of the screen.
## Drawn small and close (SCALE) so it looks full size but almost never pokes into walls.

const SCALE := 0.46
const HIP := Vector3(0.13, -0.15, -0.29)
## Long guns are drawn a little smaller so a 1.4 m rifle doesn't fill half the screen.
const REF_LENGTH := 0.75
const AIM_DEPTH := 0.31
const SIGHT_LIFT := 0.028

var _rig: Node3D
var _gun: Node3D
var _hands: Node3D
var _muzzle := Vector3(0, 0.08, -0.6)
var _sight := Vector3(0, 0.1, 0)
var _scoped := false
var _kick := 0.0
var _kick_strength := 1.0
var _reload := 0.0
var _reload_total := 1.0
var _sway := Vector2.ZERO
var _bob := 0.0
var _lower := 0.0
var _tilt := 0.0
var _scale := SCALE
## Short knocks (landings, jumps, wall kicks) on a spring, so they settle the same way at
## any tick rate and never pile up.
var _jolt := Vector3.ZERO
var _jolt_speed := Vector3.ZERO
var _air_lag := 0.0


func _ready() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)


func set_build(build: Dictionary) -> void:
	if _gun != null:
		_gun.queue_free()
	if _hands != null:
		_hands.queue_free()
	_gun = GunModels.build(build)
	var length := float(Arsenal.stats(build).length) / 100.0
	_scale = SCALE * clampf(sqrt(REF_LENGTH / maxf(length, 0.2)), 0.7, 1.15)
	_gun.scale = Vector3.ONE * _scale
	_rig.add_child(_gun)
	_scoped = float(Arsenal.stats(build).zoom) >= 2.0
	_muzzle = _gun.get_meta("muzzle")
	var slots: Dictionary = _gun.get_meta("slots", {})
	_sight = slots.get("sight", Vector3(0, 0.1, 0))
	_hands = _make_hands(slots)
	_gun.add_child(_hands)
	_no_shadow(_gun)


## Gloves: carbon blocks with an orange cuff on the grip and on the front of the gun.
func _make_hands(slots: Dictionary) -> Node3D:
	var root := Node3D.new()
	var glove := Faultprint.gun(Faultprint.GRAPHITE, "panel")
	var cuff := Faultprint.gun(Faultprint.ORANGE, "panel")
	var sleeve := Faultprint.gun(Faultprint.CONCRETE, "rust_metal")
	if Settings.look == Faultprint.COUNTERFORM:
		# Rubberised gloves, an oxide-orange cuff tab, a grey-green technical sleeve.
		glove = Counterform.material("rubber", Color("#2A2C2E"), false)
		cuff = Counterform.material("paint", Counterform.OXIDE_ORANGE, false)
		sleeve = Counterform.material("polymer", Color("#4E5450"), false)
	var grip_at: Vector3 = slots.get("grip", Vector3(0, -0.03, 0.0))
	var front: Vector3 = slots.get("foregrip", slots.get("handguard", slots.get("underbarrel", Vector3(0, 0.02, -0.2))))
	for spec in [[grip_at + Vector3(0.0, -0.01, 0.01), Vector3(0.05, 0.075, 0.07), Vector3(-0.2, 0, 0.2)],
			[front + Vector3(-0.012, -0.012, 0.0), Vector3(0.05, 0.05, 0.085), Vector3(0, 0.25, -0.35)]]:
		var hand := MeshInstance3D.new()
		hand.mesh = LowPoly.chamfer_box(spec[1], 0.008)
		hand.material_override = glove
		hand.position = spec[0]
		hand.rotation = spec[2]
		root.add_child(hand)
		var band := MeshInstance3D.new()
		band.mesh = LowPoly.chamfer_box(Vector3(spec[1].x * 1.08, spec[1].y * 1.08, 0.018), 0.004)
		band.material_override = cuff
		band.position = Vector3(0, 0, spec[1].z / 2.0 + 0.008)
		hand.add_child(band)
		var arm := MeshInstance3D.new()
		arm.mesh = LowPoly.chamfer_box(Vector3(spec[1].x * 0.95, spec[1].y * 0.9, 0.28), 0.01)
		arm.material_override = sleeve
		arm.position = Vector3(0.02, -0.02, spec[1].z / 2.0 + 0.15)
		arm.rotation = Vector3(0.25, 0.2, 0)
		hand.add_child(arm)
	return root


func gun_node() -> Node3D:
	return _gun if _gun != null else self


func muzzle_local() -> Vector3:
	return _muzzle + Vector3(0, 0, -0.01)


## Where shots leave the barrel, in world space (for tracers).
func muzzle_global() -> Vector3:
	if _gun == null or not is_inside_tree():
		return global_position
	return _gun.to_global(_muzzle)


func kick(recoil: float, _flash := 1.0) -> void:
	_kick = 1.0
	_kick_strength = clampf(recoil / 4.0, 0.25, 2.5)


func reload(seconds: float) -> void:
	_reload = seconds
	_reload_total = maxf(seconds, 0.01)


## A knock in view space (metres per second of push).
func jolt(push: Vector3) -> void:
	_jolt_speed += push * 12.0


## Landing: `strength` 0..1.
func land(strength: float) -> void:
	jolt(Vector3(0, -0.02 - 0.05 * strength, 0.01))


func sway(mouse: Vector2) -> void:
	_sway += Vector2(-mouse.x, mouse.y) * 0.0009


## Called by the player every physics frame with what it's doing.
func update_pose(delta: float, p: Dictionary) -> void:
	var aim: float = p.aim
	var speed: float = p.speed
	_kick = move_toward(_kick, 0.0, delta * 7.0)
	_reload = maxf(_reload - delta, 0.0)
	_sway = _sway.lerp(Vector2.ZERO, minf(delta * 9.0, 1.0))
	_sway = _sway.clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
	if p.floor and p.move == Player.Move.GROUND:
		_bob += delta * speed * 1.9
	var sprinting: bool = p.sprint
	_lower = move_toward(_lower, 1.0 if sprinting and aim < 0.1 else 0.0, delta * 5.0)
	var tilt_target := 0.0
	match p.move:
		Player.Move.SLIDE: tilt_target = 0.35
		Player.Move.WALLRUN: tilt_target = -float(p.roll) * 1.4
		Player.Move.CLIMB, Player.Move.MANTLE: tilt_target = 0.6
	_tilt = lerpf(_tilt, tilt_target, 1.0 - exp(-10.0 * delta))
	var steps := maxi(ceili(delta / 0.0042), 1)
	for i in steps:
		var h := delta / steps
		_jolt_speed += (-260.0 * _jolt - 26.0 * _jolt_speed) * h
		_jolt += _jolt_speed * h
	# In the air the gun lags the fall a little: up when falling, down when rising.
	var vy: float = p.get("vy", 0.0) if p.move == Player.Move.AIR else 0.0
	_air_lag = lerpf(_air_lag, clampf(-vy * 0.0016, -0.012, 0.018), 1.0 - exp(-8.0 * delta))
	var e := aim * aim * (3.0 - 2.0 * aim)
	var aim_pos := Vector3(0, 0, -AIM_DEPTH) - (_sight + Vector3(0, SIGHT_LIFT, 0)) * _scale
	var pos := HIP.lerp(aim_pos, e)
	var bob_amount := clampf(speed / 6.0, 0.0, 1.4) * (1.0 - e * 0.85)
	pos += Vector3(sin(_bob * 0.5) * 0.008, -absf(cos(_bob * 0.5)) * 0.008, 0.0) * bob_amount
	pos += Vector3(_sway.x, _sway.y, 0.0) * 0.03 * (1.0 - e * 0.7)
	var kick_curve := _kick * _kick
	pos.z += kick_curve * 0.035 * _kick_strength
	# At the hip the muzzle toes in a little toward the crosshair.
	var rot := Vector3(kick_curve * 0.22 * _kick_strength + 0.03 * (1.0 - e), _sway.x * 0.4 + 0.05 * (1.0 - e), 0.0)
	pos += Vector3(0.02, -0.05, 0.03) * _lower
	rot += Vector3(-0.35, 0.55, 0.15) * _lower
	pos += (_jolt + Vector3(0, _air_lag, 0)) * (1.0 - e * 0.7)
	rot.x += _jolt.y * 2.5 * (1.0 - e * 0.7)
	pos += Vector3(-0.015, -0.015, 0) * absf(_tilt)
	rot.z += _tilt * (1.0 - e * 0.6)
	if _reload > 0.0:
		var t := 1.0 - _reload / _reload_total
		var dip := sin(clampf(t, 0.0, 1.0) * PI)
		pos += Vector3(-0.02, -0.08, 0.02) * dip
		rot += Vector3(-0.55, 0.25, 0.95) * dip
	_rig.position = pos
	_rig.rotation = rot
	if _gun != null:
		_gun.visible = not (_scoped and aim > 0.92)


static func _no_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadow(child)
