class_name ViewModel
extends Node3D
## The first-person gun (the art brief's top priority): the bench build at the lower right,
## two blocky gloves on it, and the motion that says what you're doing: bob, sway, recoil
## kick, the reload (the support hand pulls the magazine, brings a fresh one up, seats
## it and racks the action when the gun ran dry; tube guns and revolvers get loaded a
## round at a time), a lowered gun while sprinting, tilted on slides and wall runs,
## and aiming that puts the build's own sight in the middle of the screen.
##
## C5: drawn by its own camera (WeaponCam) on its own layer with its own field of view,
## like every mainstream shooter: the gun sits big in the lower right whatever the
## player's FOV is, and never pokes into walls (the world isn't in that picture).

const SCALE := 0.5
## The render layer only the weapon camera draws, and that camera's field of view.
const LAYER := 1 << 12
const FOV := 64.0
const HIP := Vector3(0.135, -0.155, -0.30)
## Long guns are drawn a little smaller so a 1.4 m rifle doesn't fill half the screen.
const REF_LENGTH := 0.75
const AIM_DEPTH := 0.34
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
var _reload_empty := false
## Reload pieces: the support hand (second glove), the gun's "Magazine" node and where
## things sit on this gun (gun space).
var _support: Node3D
var _support_pos := Vector3.ZERO
var _support_rot := Vector3.ZERO
var _mag: Node3D
var _mag_at := Vector3.ZERO
var _rack_at := Vector3.ZERO
var _port_at := Vector3.ZERO
var _reload_style := "mag"
var _round_prop: MeshInstance3D
var _seat := 0.0
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
## The weapon camera (set by the player) and the world camera it rides on.
var weapon_cam: Camera3D
var world_cam: Camera3D


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
	_setup_reload(slots)
	_no_shadow(_gun)


## Finds what the reload moves on this gun and how it loads:
##   mag     a detachable magazine (box, drum, cell, tank, belt box, coil)
##   rounds  a round at a time into a port (tube shotguns, revolvers, break actions, bows)
func _setup_reload(slots: Dictionary) -> void:
	_reload = 0.0
	_support = _hands.get_child(1) if _hands.get_child_count() > 1 else null
	if _support != null:
		_support_pos = _support.position
		_support_rot = _support.rotation
	_mag = _gun.get_node_or_null("Magazine")
	var style: String = _gun.get_meta("mag_style", "box")
	_reload_style = "mag" if _mag != null and not style in ["tube", "none"] else "rounds"
	_mag_at = slots.get("magazine", Vector3(0, -0.05, -0.06))
	_rack_at = slots.get("charging", slots.get("bolt", Vector3(0, 0.08, 0.05)))
	_port_at = slots.get("ammo", Vector3(0.03, 0.06, -0.05)) if style == "none" else _mag_at + Vector3(0, 0.02, 0)
	if _support != null:
		_round_prop = MeshInstance3D.new()
		_round_prop.mesh = GunKit.rod(0.0075 if style == "tube" else 0.005, 0.03, 8)
		_round_prop.material_override = Counterform.material("bare", Color("#B8925A"), false)
		_round_prop.position = Vector3(0, 0.03, -0.035)
		_round_prop.visible = false
		_support.add_child(_round_prop)


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
		sleeve = Counterform.material("polymer", Color("#525A4E"), false)
	var grip_at: Vector3 = slots.get("grip", Vector3(0, -0.03, 0.0))
	var front: Vector3 = slots.get("foregrip", slots.get("handguard", slots.get("underbarrel", Vector3(0, 0.02, -0.2))))
	if Settings.look == Faultprint.COUNTERFORM:
		_cf_hand(root, grip_at + Vector3(0.0, -0.022, 0.012), Vector3(-0.25, 0.0, 0.15), glove, cuff, sleeve, 1.0)
		_cf_hand(root, front + Vector3(-0.01, -0.016, 0.0), Vector3(0.0, -0.35, -0.4), glove, cuff, sleeve, -1.0)
		return root
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


## A sculpted glove round a grip: a padded palm, jointed fingers curled across the front
## with a knuckle plate over them, a thumb over the top, a strapped gauntlet and a real
## forearm (C4): flattened and tapered like an arm, in a pushed-up jacket sleeve with folds
## and a patch, running back out of view. `side` is 1 for the right hand on the pistol
## grip, -1 for the support hand (which also wears the wrist unit).
func _cf_hand(root: Node3D, at: Vector3, rot: Vector3, glove: Material, cuff: Material, sleeve: Material, side: float) -> void:
	var hand := Node3D.new()
	hand.position = at
	hand.rotation = rot
	root.add_child(hand)
	var plate := Counterform.material("polymer", Color("#1B1D1F"), false)
	var palm := MeshInstance3D.new()
	palm.mesh = LowPoly.chamfer_box(Vector3(0.05, 0.08, 0.062), 0.018)
	palm.material_override = glove
	palm.position = Vector3(side * 0.012, 0, 0.012)
	hand.add_child(palm)
	# Knuckle plate on the back of the hand.
	var knuckles := MeshInstance3D.new()
	knuckles.mesh = LowPoly.chamfer_box(Vector3(0.012, 0.07, 0.034), 0.004)
	knuckles.material_override = plate
	knuckles.position = Vector3(side * 0.04, 0.002, 0.0)
	hand.add_child(knuckles)
	# Fingers in two joints, curling round the grip.
	for i in 4:
		var length := 0.03 - absf(i - 1.5) * 0.003
		var base := MeshInstance3D.new()
		base.mesh = GunKit.rod(0.0098, length, 10)
		base.material_override = glove
		base.position = Vector3(side * 0.008, 0.028 - i * 0.0185, -0.024)
		base.rotation = Vector3(0, PI / 2.0 + side * 0.25, 0)
		hand.add_child(base)
		var tip := MeshInstance3D.new()
		tip.mesh = GunKit.rod(0.0088, length * 0.85, 10)
		tip.material_override = glove
		tip.position = Vector3(-side * 0.022, 0.028 - i * 0.0185, -0.036)
		tip.rotation = Vector3(0, PI / 2.0 - side * 0.75, 0)
		hand.add_child(tip)
	var thumb := MeshInstance3D.new()
	thumb.mesh = GunKit.rod(0.0105, 0.05, 10)
	thumb.material_override = glove
	thumb.position = Vector3(-side * 0.02, 0.045, -0.006)
	thumb.rotation = Vector3(0.3, side * 0.25, 0)
	hand.add_child(thumb)
	_forearm(hand, side, glove, cuff, sleeve)


## Gauntlet, wrist and forearm, along +Z from the heel of the hand (in hand space).
func _forearm(hand: Node3D, side: float, glove: Material, cuff: Material, sleeve: Material) -> void:
	var arm := Node3D.new()
	arm.position = Vector3(side * 0.012, -0.006, 0.04)
	arm.rotation = Vector3(0.32, 0.18, 0) if side > 0.0 else Vector3(0.55, -0.1, 0.0)
	hand.add_child(arm)
	# Flattened like a real forearm: wider across than deep.
	var flat := Vector3(1.14, 0.86, 1.0)
	var gauntlet := MeshInstance3D.new()
	gauntlet.mesh = GunKit.turned(PackedVector2Array([Vector2(0.0, 0.029), Vector2(0.01, 0.033), Vector2(0.07, 0.035),
		Vector2(0.085, 0.037), Vector2(0.09, 0.03)]), 18)
	gauntlet.material_override = glove
	gauntlet.scale = flat
	arm.add_child(gauntlet)
	# The strap across the gauntlet, with its orange pull tab.
	var strap := MeshInstance3D.new()
	strap.mesh = GunKit.turned(PackedVector2Array([Vector2(0.03, 0.0365), Vector2(0.05, 0.0365)]), 18)
	strap.material_override = Counterform.material("polymer", Color("#1B1D1F"), false)
	strap.scale = flat
	arm.add_child(strap)
	var tab := MeshInstance3D.new()
	tab.mesh = LowPoly.chamfer_box(Vector3(0.016, 0.008, 0.024), 0.003)
	tab.material_override = cuff
	tab.position = Vector3(side * 0.03, 0.022, 0.04)
	tab.rotation = Vector3(0, 0, side * -0.6)
	arm.add_child(tab)
	# The sleeve, pushed up: a rolled cuff, then the forearm swelling toward the elbow,
	# with soft folds. Long enough that its back end always leaves the frame.
	var sleeve_mesh := MeshInstance3D.new()
	sleeve_mesh.mesh = GunKit.turned(PackedVector2Array([
		Vector2(0.08, 0.034), Vector2(0.088, 0.043), Vector2(0.115, 0.044), Vector2(0.122, 0.039),
		Vector2(0.16, 0.041), Vector2(0.2, 0.046), Vector2(0.215, 0.0445), Vector2(0.26, 0.049),
		Vector2(0.3, 0.052), Vector2(0.315, 0.05), Vector2(0.38, 0.054), Vector2(0.5, 0.056),
		Vector2(0.6, 0.057), Vector2(0.61, 0.045)]), 22)
	sleeve_mesh.material_override = sleeve
	sleeve_mesh.scale = flat
	arm.add_child(sleeve_mesh)
	# A darker reinforcement panel on top of the sleeve.
	var panel := MeshInstance3D.new()
	panel.mesh = LowPoly.chamfer_box(Vector3(0.05, 0.004, 0.12), 0.002)
	panel.material_override = Counterform.material("polymer", Color("#444B40"), false)
	panel.position = Vector3(0.0, 0.047, 0.36)
	panel.rotation = Vector3(-0.02, 0, 0)
	arm.add_child(panel)
	if side < 0.0:
		# The wrist unit on the support arm: a small rugged screen showing the time.
		var unit := MeshInstance3D.new()
		unit.mesh = LowPoly.chamfer_box(Vector3(0.034, 0.012, 0.03), 0.004)
		unit.material_override = Counterform.material("polymer", Color("#202325"), false)
		unit.position = Vector3(0.0, 0.034, 0.06)
		arm.add_child(unit)
		var screen := MeshInstance3D.new()
		screen.mesh = LowPoly.chamfer_box(Vector3(0.024, 0.002, 0.02), 0.0005)
		screen.material_override = Counterform.material("paint", Color("#2A3326"), false, Counterform.SULFUR * 0.6)
		screen.position = Vector3(0.0, 0.0405, 0.06)
		arm.add_child(screen)


func gun_node() -> Node3D:
	return _gun if _gun != null else self


func muzzle_local() -> Vector3:
	return _muzzle + Vector3(0, 0, -0.01)


## Where shots leave the barrel, in world space (for tracers). With the weapon camera on,
## that's the world point behind where the muzzle is drawn on screen.
func muzzle_global() -> Vector3:
	if _gun == null or not is_inside_tree():
		return global_position
	var p := _gun.to_global(_muzzle)
	if weapon_cam == null or world_cam == null or not weapon_cam.is_inside_tree():
		return p
	var depth := -(world_cam.global_transform.affine_inverse() * p).z
	if depth < 0.02:
		return p
	return world_cam.project_position(weapon_cam.unproject_position(p), depth)


## Everything under `n` onto the weapon camera's layer (muzzle flashes too, which are added
## to the gun as it fires).
static func tag(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = LAYER
	for c in n.get_children():
		tag(c)


func _process(_delta: float) -> void:
	if weapon_cam != null:
		tag(self)


func kick(recoil: float, _flash := 1.0) -> void:
	_kick = 1.0
	_kick_strength = clampf(recoil / 4.0, 0.25, 2.5)


func reload(seconds: float, empty := false) -> void:
	_reload = seconds
	_reload_total = maxf(seconds, 0.01)
	_reload_empty = empty


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
		# The gun turns its magazine well (or loading port) toward you and dips a little;
		# the seat of a new magazine knocks it up once.
		var dip := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.86, 1.0, t))
		pos += Vector3(-0.055, -0.005, 0.03) * dip
		rot += Vector3(0.3, 0.38, -0.6) * dip
		_animate_reload(t)
	elif _support != null and _support.position != _support_pos:
		_rest_reload()
	_seat = move_toward(_seat, 0.0, delta * 9.0)
	pos.y += _seat * 0.012
	rot.x += _seat * 0.06
	_rig.position = pos
	_rig.rotation = rot
	if _gun != null:
		_gun.visible = not (_scoped and aim > 0.92)


## The support hand and magazine at reload progress `t` (0..1), in gun space.
func _animate_reload(t: float) -> void:
	if _support == null:
		return
	if _reload_style == "mag":
		_mag_reload(t)
	else:
		_round_reload(t)


func _mag_reload(t: float) -> void:
	var grab := _mag_at + Vector3(-0.012, -0.03, 0.006)
	var away := grab + Vector3(-0.06, -0.34, 0.12)
	var cup := Vector3(-0.5, 0.2, 0.5)  # hand rolled palm-up under the magazine
	var hand := _support_pos
	var hand_rot := _support_rot
	var mag_off := Vector3.ZERO
	var rack_end := 1.0 if not _reload_empty else 0.68
	if t < 0.14:
		var k := smoothstep(0.0, 0.14, t)
		hand = _support_pos.lerp(grab, k)
		hand_rot = _support_rot.lerp(cup, k)
	elif t < 0.32:
		# Old magazine out and down, out of view.
		var k := smoothstep(0.14, 0.32, t)
		hand = grab.lerp(away, k)
		hand_rot = cup
		mag_off = hand - grab
	elif t < 0.4:
		hand = away
		hand_rot = cup
		mag_off = away - grab
	elif t < 0.62:
		# The fresh one comes up from below, nose first.
		var k := smoothstep(0.4, 0.62, t)
		hand = away.lerp(grab, k)
		hand_rot = cup
		mag_off = hand - grab + Vector3(0, -0.012, 0) * (1.0 - k)
		if k >= 0.999 and _seat <= 0.0:
			_seat = 1.0
	elif t < rack_end - 0.0001 and _reload_empty:
		# Dry gun: up to the charging handle, pull it back, let it go.
		var rack := _rack_at + Vector3(-0.02, 0.012, 0.01)
		if t < 0.78:
			var k := smoothstep(0.62, 0.78, t)
			hand = grab.lerp(rack, k)
			hand_rot = cup.lerp(Vector3(0.3, -0.4, -0.2), k)
		elif t < 0.86:
			var k := smoothstep(0.78, 0.86, t)
			hand = rack + Vector3(0, 0.004, 0.055) * sin(k * PI)
			hand_rot = Vector3(0.3, -0.4, -0.2)
		else:
			var k := smoothstep(0.86, 1.0, t)
			hand = rack.lerp(_support_pos, k)
			hand_rot = Vector3(0.3, -0.4, -0.2).lerp(_support_rot, k)
	else:
		var k := smoothstep(0.62, 1.0, t)
		hand = grab.lerp(_support_pos, k)
		hand_rot = cup.lerp(_support_rot, k)
	_support.position = hand
	_support.rotation = hand_rot
	if _mag != null:
		_mag.position = mag_off


## One round (shell, cartridge, bolt) at a time: down to the belt, up to the port, push.
func _round_reload(t: float) -> void:
	var pushes := clampi(roundi(_reload_total / 0.42), 2, 6)
	var port := _port_at + Vector3(-0.015, -0.02, 0.0)
	var belt := port + Vector3(-0.06, -0.16, 0.08)
	var hand := _support_pos
	var hand_rot := _support_rot
	var carrying := false
	if t < 0.1:
		var k := smoothstep(0.0, 0.1, t)
		hand = _support_pos.lerp(belt, k)
		hand_rot = _support_rot.lerp(Vector3(-0.4, 0.2, 0.4), k)
	elif t < 0.9:
		var c := (t - 0.1) / 0.8 * pushes
		var k := c - floorf(c)
		hand_rot = Vector3(-0.4, 0.2, 0.4)
		if k < 0.45:
			hand = belt.lerp(port, smoothstep(0.0, 0.45, k))
			carrying = true
		elif k < 0.65:
			# Thumb it in.
			hand = port + Vector3(0, 0.012, -0.02) * sin(smoothstep(0.45, 0.65, k) * PI)
			carrying = k < 0.55
			if k > 0.55 and _seat < 0.2:
				_seat = 0.35
		else:
			hand = port.lerp(belt, smoothstep(0.65, 1.0, k))
	else:
		var k := smoothstep(0.9, 1.0, t)
		hand = belt.lerp(_support_pos, k)
		hand_rot = Vector3(-0.4, 0.2, 0.4).lerp(_support_rot, k)
	_support.position = hand
	_support.rotation = hand_rot
	if _round_prop != null:
		_round_prop.visible = carrying


func _rest_reload() -> void:
	_support.position = _support_pos
	_support.rotation = _support_rot
	if _mag != null:
		_mag.position = Vector3.ZERO
	if _round_prop != null:
		_round_prop.visible = false


## Reload progress 0..1 (1 when not reloading), for tests and the HUD.
func reload_progress() -> float:
	return 1.0 - _reload / _reload_total if _reload > 0.0 else 1.0


func support_offset() -> Vector3:
	return _support.position - _support_pos if _support != null else Vector3.ZERO


func mag_offset() -> Vector3:
	return _mag.position if _mag != null else Vector3.ZERO


static func _no_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadow(child)
