class_name Player
extends CharacterBody3D
## The first-person competitor: momentum movement with a full set of movement tech, and
## a custom gun from the bench. The gun's weight drives the movement (Player.mobility):
## a feather pistol makes you faster, kick off walls more and dash more often; a 12 kg
## machine gun keeps you mostly on the ground. That trade is the core of CHAOS.
##
## Movement model (numbers in MoveTuning): velocity is the only truth. No state sets a
## fixed speed; each applies accelerations, friction and drag to the velocity it inherits,
## so speed carries through every transition. The core loop is
##   sprint -> slide -> slide jump -> steer in the air -> land (into a slide) -> again
## and the walls extend it:
##   wall run     in the air beside an orange-banded wall, input along it: run along it
##   wall jump    jump off a wall run (or just after leaving one): out along the wall's
##                normal plus your input, keeping the speed along the wall
##   wall kick    jump beside any wall in the air (a few per air time)
##   wall climb   jump at a wall face-on and hold jump: run up it for a moment
##   mantle       reach a ledge in the air: pull up onto it and keep going
##   dash         Q: a short burst in the direction you're moving (recharges)
##   slam         look down and crouch high in the air: drive into the ground
## Input is buffered (jump, crouch) and forgiving (coyote time off ledges and walls);
## animation never blocks a move. The debug panel (F4) shows all of it.

signal died(info: Dictionary)
signal hit_confirmed(info: Dictionary, killed: bool)
signal damaged(info: Dictionary)
signal fired()
signal weapon_changed()

const RADIUS := 0.38
const HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const EYE := 1.62
const CROUCH_EYE := 0.88
const WALL_KICKS := 3
const SLAM_SPEED := 30.0
const SLAM_RADIUS := 5.0
const SLAM_DAMAGE := 30.0
const MAX_HEALTH := 100.0
const MOUSE_SENS := 0.0022

## Movement state, for the HUD, the view model and the kill feed's move tags.
enum Move { GROUND, AIR, SLIDE, WALLRUN, CLIMB, MANTLE, DASH, SLAM }
const MOVE_NAMES := ["地面", "空中", "滑鏟", "牆跑", "攀牆", "翻越", "衝刺", "重踩"]

var display_name := "你"
var team := 0
var health := MAX_HEALTH
var alive := true
var input_enabled := true
var weapon: Weapon
var mobility := 1.0
var tune := MoveTuning.new()

var move := Move.GROUND
var head: Node3D
var camera: Camera3D
var view: ViewModel
var base_fov := 96.0

# What the debug panel shows (filled every tick; cheap).
var transitions: Array = []      # newest first: {t, from, to, why}
var failures: Array = []         # newest first: {t, why}
var landing := ""                # the last landing: 一般 / 高速 / 滑鏟 / 重 / 重踩
var limiter := ""                # what shaped the speed this tick
var accel := 0.0                 # horizontal acceleration, m/s² (smoothed)
var air_control := 0.0           # steering rate available now, deg/s
var wish_dir := Vector3.ZERO
var rays: Array = []             # this tick's wall probes: [from, to, hit, runnable]
var wall_info := {}              # nearest wall seen this tick
var clock := 0.0

var _pitch := 0.0
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _recoil_hold := 0.0
var _cam := CameraFx.new()
var _coyote := 0.0
var _buffer := 0.0
var _crouch_buf := 0.0
var _land_grace := 0.0
var _was_on_floor := true
var _half_g := false
var _slam_from := 0.0
var _slam_height := 0.0
var _slam_bounce := 0.0
var _render_prev := Vector3.ZERO
var _render_curr := Vector3.ZERO
var _wind: AudioStreamPlayer
var _crouching := false
var _shape: CapsuleShape3D
var _eye := EYE
var _eye_now := EYE
var _slide_t := 0.0
var _slide_cd := 0.0
var _wall_normal := Vector3.ZERO
var _wall_node: Object = null
var _wall_t := 0.0
var _wall_lost := 0.0
var _wall_idle := 0.0
var _wall_coyote := 0.0
var _last_wall_normal := Vector3.ZERO
var _last_wall_node: Object = null
var _wall_ban: Object = null
var _wall_ban_t := 0.0
var _kicks := WALL_KICKS
var _climb_left := 0.0
var _climbed := false
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
var _mantle_speed := 0.0
var _mantle_back := Vector3.ZERO
var _dash_left := 0.0
var _dash_charge := 1.0
var _dash_dir := Vector3.ZERO
var _aim := 0.0
var _slow := 0.0
var _burn := 0.0
var _last_attacker: Dictionary = {}
var damage_dealt := {}   # name -> damage you did to them (death screen)
var damage_taken := {}   # name -> damage they did to you
var _spawn := Transform3D.IDENTITY
var _hitboxes: Array[Area3D] = []


func _ready() -> void:
	add_to_group("hittable")
	add_to_group("player")
	collision_layer = Geo.BODIES
	collision_mask = Geo.WORLD
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48)
	var cs := CollisionShape3D.new()
	_shape = CapsuleShape3D.new()
	_shape.radius = RADIUS
	_shape.height = HEIGHT
	cs.shape = _shape
	cs.position.y = HEIGHT / 2.0
	cs.name = "Shape"
	add_child(cs)
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	# The head is placed by hand every rendered frame (see _process), between the last two
	# physics positions, so the view is smooth at any frame rate and mouse look is instant.
	head.top_level = true
	camera = Camera3D.new()
	camera.fov = base_fov
	camera.near = 0.03
	camera.far = 500.0
	head.add_child(camera)
	Faultprint.post(camera)
	view = ViewModel.new()
	camera.add_child(view)
	_wind = AudioStreamPlayer.new()
	_wind.stream = Sfx.wind()
	_wind.volume_db = -60.0
	add_child(_wind)
	base_fov = Settings.fov
	_add_hitboxes()
	if weapon == null:
		equip({"frame": "carbine", "parts": {}, "tune": {}})


func _add_hitboxes() -> void:
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


## Everything a shot from this player should not hit: its own hitboxes and body.
func exclusions() -> Array:
	var out := [get_rid()]
	for a in _hitboxes:
		out.append(a.get_rid())
	return out


func equip(build: Dictionary, gun_name := "") -> void:
	weapon = Weapon.new(build, gun_name)
	mobility = mobility_of(weapon.stats)
	if view:
		view.set_build(weapon.build)
	weapon_changed.emit()


## How a gun's weight moves you: 1.0 at about 3 kg, faster when lighter, down to 0.66.
static func mobility_of(stats: Dictionary) -> float:
	return clampf(1.12 - 0.04 * float(stats.weight), 0.66, 1.1)


## Wall kicks per air time: heavy guns get fewer.
func max_kicks() -> int:
	if mobility < 0.8:
		return 1
	if mobility < 0.92:
		return 2
	return tune.wall_kicks


func spawn_at(xform: Transform3D) -> void:
	_spawn = xform
	global_transform = Transform3D(Basis(Vector3.UP, xform.basis.get_euler().y), xform.origin)
	velocity = Vector3.ZERO
	# Fresh floor contact at the new spot (not the old one's).
	move_and_slide()
	apply_floor_snap()
	_pitch = 0.0
	_render_prev = global_position
	_render_curr = global_position
	health = MAX_HEALTH
	alive = true
	_set_move(Move.GROUND, "重生")
	_set_crouch(false)
	_slow = 0.0
	_burn = 0.0
	# Every movement timer back to its start, so a respawn behaves the same every time.
	_buffer = 0.0
	_crouch_buf = 0.0
	_coyote = 0.0
	_slide_cd = 0.0
	_slide_t = 0.0
	_dash_charge = 1.0
	_kicks = max_kicks()
	_climbed = false
	_wall_coyote = 0.0
	_wall_ban = null
	_wall_ban_t = 0.0
	_land_grace = 0.0
	_was_on_floor = is_on_floor()
	_half_g = false
	_aim = 0.0
	_recoil_pitch = 0.0
	_recoil_yaw = 0.0
	accel = 0.0
	damage_dealt.clear()
	damage_taken.clear()
	weapon.set_build(weapon.build, weapon.name)
	visible = true
	for a in _hitboxes:
		a.set_deferred("collision_layer", Geo.HITBOX)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * Settings.sens * lerpf(1.0, 1.0 / maxf(float(weapon.stats.zoom), 1.0), _aim)
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, deg_to_rad(-88), deg_to_rad(88))
		view.sway(event.relative)


# --- Frame ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not alive:
		return
	clock += delta
	_timers(delta)
	var wish := _wish_dir()
	wish_dir = wish
	var on_floor := is_on_floor()
	var speed_before := flat_speed()
	limiter = ""
	air_control = 0.0
	rays.clear()
	wall_info = {}
	if on_floor:
		_coyote = tune.coyote
		_kicks = max_kicks()
		_climbed = false
		_wall_ban = null
	if _want("jump", true):
		_buffer = tune.jump_buffer
	if _want("crouch", true):
		_crouch_buf = tune.crouch_buffer
	match move:
		Move.MANTLE:
			_do_mantle(delta)
		Move.DASH:
			_do_dash(delta)
		Move.CLIMB:
			_do_climb(delta, wish)
		Move.WALLRUN:
			_do_wallrun(delta, wish)
		Move.SLAM:
			_do_slam(delta)
		_:
			_do_free(delta, wish, on_floor)
	_safety_cap()
	var fall := -velocity.y
	if move != Move.MANTLE:
		move_and_slide()
	if _half_g:
		# Gravity in two halves around the move: jump arcs come out the same at any tick rate.
		_half_g = false
		if not is_on_floor():
			_gravity_half()
			_half_g = false
	_after_move(fall)
	_render_prev = _render_curr
	_render_curr = global_position
	accel = lerpf(accel, (flat_speed() - speed_before) / delta, 1.0 - exp(-12.0 * delta))
	_place_head(global_position)
	_weapon_frame(delta)
	_camera_frame(delta)


func _timers(delta: float) -> void:
	_coyote -= delta
	_buffer -= delta
	_crouch_buf -= delta
	_slide_cd -= delta
	_land_grace -= delta
	_slam_bounce -= delta
	_wall_coyote -= delta
	_wall_ban_t -= delta
	if _wall_ban_t <= 0.0:
		_wall_ban = null
	_dash_charge = minf(_dash_charge + delta / (tune.dash_recharge / mobility), 1.0)
	_slow = maxf(_slow - delta, 0.0)
	if _burn > 0.0:
		_burn -= delta
		_apply_damage(6.0 * delta, _last_attacker, false)


func _want(action: String, just := false) -> bool:
	if not input_enabled:
		return false
	return Input.is_action_just_pressed(action) if just else Input.is_action_pressed(action)


func _wish_dir() -> Vector3:
	if not input_enabled:
		return Vector3.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := global_basis * Vector3(v.x, 0, v.y)
	dir.y = 0
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


func _speed_mult() -> float:
	return mobility * (0.6 if _slow > 0.0 else 1.0)


func _flat() -> Vector3:
	return Vector3(velocity.x, 0, velocity.z)


func _set_flat(h: Vector3) -> void:
	velocity.x = h.x
	velocity.z = h.z


func _look_flat() -> Vector3:
	var look := -global_basis.z
	look.y = 0
	return look.normalized()


## Every state change goes through here, with the reason, for the debug panel. `event`
## logs it even without a change of state (a jump from the air is still air).
func _set_move(to: Move, why: String, event := false) -> void:
	if to == move and not event:
		return
	transitions.push_front({"t": clock, "from": move, "to": to, "why": why})
	if transitions.size() > 8:
		transitions.resize(8)
	move = to


## A move the player tried that didn't happen, and why (for the debug panel).
func _fail(why: String) -> void:
	if not failures.is_empty() and failures[0].why == why and clock - float(failures[0].t) < 1.0:
		failures[0].t = clock
		return
	failures.push_front({"t": clock, "why": why})
	if failures.size() > 6:
		failures.resize(6)


## Half a tick of gravity (the other half comes after the move).
func _gravity_half() -> void:
	velocity.y = maxf(velocity.y - tune.gravity * get_physics_process_delta_time() * 0.5, -tune.terminal_fall)
	_half_g = true


## Set the vertical speed for a launch (jumps, kicks) on this tick.
func _launch(vy: float) -> void:
	velocity.y = vy
	_gravity_half()


func _safety_cap() -> void:
	var h := _flat()
	if h.length() > tune.hard_cap:
		_set_flat(h.normalized() * tune.hard_cap)
		_fail("速度超過安全上限 %.0f m/s（這是 bug）" % tune.hard_cap)


# --- Velocity helpers ------------------------------------------------------------------

## Quake friction on the horizontal velocity.
func _friction(h: Vector3, amount: float, delta: float) -> Vector3:
	var speed := h.length()
	if speed < 0.01:
		return Vector3.ZERO
	var drop := maxf(speed, tune.stop_speed) * amount * delta
	return h * (maxf(speed - drop, 0.0) / speed)


## Push `h` along `wish` until its speed in that direction reaches `wishspeed`, at most
## `rate` m/s² (never pulls it down: going faster than wishspeed costs nothing here).
func _accelerate(h: Vector3, wish: Vector3, wishspeed: float, rate: float, delta: float) -> Vector3:
	if wish == Vector3.ZERO:
		return h
	var add := wishspeed - h.dot(wish)
	if add <= 0.0:
		return h
	return h + wish * minf(rate * delta, add)


## Rotate `h` toward `wish` by at most `deg_per_s`, keeping its length.
func _turn_toward(h: Vector3, wish: Vector3, deg_per_s: float, delta: float) -> Vector3:
	var speed := h.length()
	if speed < 0.01 or wish == Vector3.ZERO:
		return h
	var angle := (h / speed).angle_to(wish)
	var step := minf(angle, deg_to_rad(deg_per_s) * delta)
	if step < 0.00001:
		return h
	var turn_sign := signf((h / speed).cross(wish).y)
	if turn_sign == 0.0:
		turn_sign = 1.0
	return h.rotated(Vector3.UP, step * turn_sign)


# --- Free movement: ground, slide, air ----------------------------------------------------

func _do_free(delta: float, wish: Vector3, on_floor: bool) -> void:
	var crouch_held := _want("crouch")
	# Dash and slam come first: they override everything.
	if _want("dash", true):
		if _dash_charge >= 1.0:
			_start_dash(wish)
			return
		_fail("衝刺還在充能（%d%%）" % roundi(_dash_charge * 100.0))
	if not on_floor and _want("crouch", true) and _pitch <= deg_to_rad(tune.slam_pitch):
		if _height_above_ground() >= tune.slam_min_height:
			_set_move(Move.SLAM, "空中低頭按蹲")
			_slam_from = global_position.y
			velocity = Vector3(velocity.x * 0.25, -SLAM_SPEED, velocity.z * 0.25)
			return
		_fail("離地太低，不能重踩")
	if on_floor:
		_ground_frame(delta, wish, crouch_held)
	else:
		_air_frame(delta, wish, crouch_held)


func _ground_frame(delta: float, wish: Vector3, crouch_held: bool) -> void:
	if move == Move.SLIDE:
		_slide_frame(delta, wish, crouch_held)
		if _buffer > 0.0:
			_jump()
		return
	if move != Move.GROUND:
		_set_move(Move.GROUND, "在地面上")
	var speed := flat_speed()
	# A slide starts when crouch is pressed (or was, just before) while fast enough.
	if crouch_held and _crouch_buf > 0.0:
		if speed >= tune.slide_min * mobility:
			_start_slide(false)
			_slide_frame(delta, wish, crouch_held)
			if _buffer > 0.0:
				_jump()
			return
		if _want("crouch", true) and speed > tune.run_speed * mobility * 0.6:
			_fail("速度不足，不能滑鏟（%.1f < %.1f）" % [speed, tune.slide_min * mobility])
	_set_crouch(crouch_held or not _can_stand())
	var target := tune.run_speed
	if _crouching:
		target = tune.crouch_speed
	elif _want("sprint") and _aim < 0.5:
		target = tune.sprint_speed
	target *= _speed_mult()
	# Jump before friction: a jump on the tick you land keeps all your speed (bunny hop).
	if _buffer > 0.0:
		if _can_stand():
			_jump()
			return
		_fail("頭頂空間不足，不能跳")
	_set_flat(_ground_move(_flat(), wish, target, delta))


func _ground_move(h: Vector3, wish: Vector3, target: float, delta: float) -> Vector3:
	var speed := h.length()
	if _land_grace > 0.0 and speed > target:
		limiter = "落地寬限（不減速）"
		return _turn_toward(h, wish, tune.ground_turn, delta)
	if speed > target + 0.05 and wish != Vector3.ZERO and h.dot(wish) > 0.5 * speed:
		# Faster than you can run, still going that way: bleed off evenly, don't brake.
		limiter = "超速衰減"
		h = _turn_toward(h, wish, tune.ground_turn, delta)
		return h.normalized() * maxf(speed - tune.overspeed_drag * delta, target)
	limiter = "地面摩擦"
	h = _friction(h, tune.friction, delta)
	return _accelerate(h, wish, target, tune.ground_accel * maxf(target, 1.0), delta)


func _start_slide(from_landing: bool) -> void:
	var why := "落地接滑鏟" if from_landing else "跑動中按蹲"
	_slide_t = 0.0
	_crouch_buf = 0.0
	_set_crouch(true)
	var h := _flat()
	var speed := h.length()
	if _slide_cd <= 0.0 and speed > 0.1:
		var fade := clampf((tune.slide_boost_fade - speed) / (tune.slide_boost_fade - tune.sprint_speed), 0.0, 1.0)
		var boost := tune.slide_boost * mobility * fade
		_set_flat(h / speed * (speed + boost))
		_slide_cd = tune.slide_cooldown
		why += "（加速 +%.1f）" % boost
	else:
		why += "（加速冷卻中，保留速度）"
	_set_move(Move.SLIDE, why)
	Sfx.play(self, "slide")


func _slide_frame(delta: float, wish: Vector3, crouch_held: bool) -> void:
	_slide_t += delta
	var h := _flat()
	var speed := h.length()
	var n := get_floor_normal()
	var downhill := Vector3.DOWN - n * n.dot(Vector3.DOWN)
	var slope := Vector3(downhill.x, 0, downhill.z) * tune.gravity * tune.slide_slope
	var going_down := speed > 0.1 and slope.dot(h / speed) > 0.5
	var decel := tune.slide_decel + speed * tune.slide_friction
	if going_down:
		# Downhill is where slides make speed: little drag, and the slide stays fresh so
		# it carries on across the flat at the bottom.
		decel = tune.slide_decel * 0.3 + speed * tune.slide_downhill_friction
		_slide_t = minf(_slide_t, 0.3)
		limiter = "下坡加速"
	else:
		decel += tune.slide_settle_decel * clampf((_slide_t - tune.slide_settle) / 0.5, 0.0, 1.0)
		limiter = "滑鏟阻力"
	if speed > 0.0:
		h = h / speed * maxf(speed - decel * delta, 0.0)
	h += slope * delta
	h = _turn_toward(h, wish, tune.slide_turn, delta) if wish != Vector3.ZERO and h.length() > 0.1 and h.angle_to(wish) < deg_to_rad(100.0) else h
	speed = h.length()
	if speed > tune.slide_soft_cap:
		h *= (speed - (speed - tune.slide_soft_cap) * 1.5 * delta) / speed
		limiter = "滑鏟上限"
	_set_flat(h)
	if not crouch_held:
		_set_move(Move.GROUND, "放開蹲")
	elif speed < tune.slide_exit and not going_down:
		_set_move(Move.GROUND, "滑鏟速度用完")


func _jump() -> void:
	var from_slide := move == Move.SLIDE
	var why := "滑鏟跳" if from_slide else ("衝刺跳（保留衝刺速度）" if move == Move.DASH else "跳躍")
	_buffer = 0.0
	_coyote = 0.0
	var up := tune.jump_speed * sqrt(mobility) * (0.75 if _slow > 0.0 else 1.0)
	if from_slide:
		up *= tune.slide_jump_mult
	if _slam_bounce > 0.0:
		# Slam bounce (ULTRAKILL): jump right after a slam lands and the fall comes back as height.
		up = maxf(up, minf(sqrt(2.0 * tune.gravity * (_slam_height * tune.slam_bounce + 1.3)), tune.slam_bounce_max))
		why = "重踩彈跳（%.1f m）" % _slam_height
		_slam_bounce = 0.0
	# A ramp's lip adds a little of the speed you had going up it.
	_launch(up + maxf(velocity.y, 0.0) * 0.3)
	_set_move(Move.AIR, why, true)
	_set_crouch(false)
	_cam.jump()
	view.jolt(Vector3(0, -0.012, 0.01))
	Sfx.play(self, "jump")


func _air_frame(delta: float, wish: Vector3, crouch_held: bool) -> void:
	if move == Move.SLIDE or move == Move.GROUND:
		_set_move(Move.AIR, "離開地面")
	# Jumps first: off the ground you just left, then off the wall you just left.
	if _buffer > 0.0:
		if _coyote > 0.0 and velocity.y <= 0.5:
			_jump()
			return
		if _wall_coyote > 0.0:
			_wall_jump(wish, _last_wall_normal, _last_wall_node, "離牆後蹬牆跳（寬限）")
			return
	_gravity_half()
	_set_flat(_air_move(_flat(), wish, delta))
	_set_crouch(crouch_held)
	# Ledge, then walls: kick, run, climb.
	if (_want("move_forward") or _want("jump")) and _try_mantle(false):
		return
	var wall := _find_wall()
	if wall.is_empty():
		return
	if _buffer > 0.0:
		if _kicks > 0:
			_wall_kick(wall)
			return
		_fail("踢牆次數用完（落地回復）")
	var why := _wallrun_block(wall, wish)
	if why == "":
		_start_wallrun(wall)
		return
	if _can_climb(wall) and _want("jump"):
		_start_climb(wall)
		return
	if wall.runnable or _want("move_forward"):
		_fail(why)


func _air_move(h: Vector3, wish: Vector3, delta: float) -> Vector3:
	var speed := h.length()
	limiter = "空中（無阻力）"
	if wish != Vector3.ZERO:
		var braking := false
		if speed > 0.5:
			var angle := (h / speed).angle_to(wish)
			air_control = tune.air_turn * clampf(tune.air_turn_ref / speed, tune.air_turn_min, 1.0)
			if angle <= deg_to_rad(tune.air_turn_max_angle):
				h = _turn_toward(h, wish, air_control, delta)
				var cap := tune.air_strafe_cap * mobility
				if angle > deg_to_rad(12.0) and speed < cap:
					h = h.normalized() * minf(speed + tune.air_strafe_gain * delta, cap)
					limiter = "空中轉向（加速）"
				else:
					limiter = "空中轉向"
			else:
				braking = true
				h = h / speed * maxf(speed - tune.air_brake * delta, 0.0)
				limiter = "空中煞車"
		if not braking or h.length() < tune.air_speed * mobility:
			h = _accelerate(h, wish, tune.air_speed * mobility, tune.air_accel, delta)
	speed = h.length()
	if speed > tune.air_soft_cap:
		h *= (speed - (speed - tune.air_soft_cap) * tune.air_soft_drag * delta) / speed
		limiter = "空中軟上限"
	return h


# --- Walls -------------------------------------------------------------------------------

## The closest wall around the body, probed at waist and chest height to the sides of the
## way you're moving and ahead. Returns {normal, collider, point, side, distance, runnable}
## or {} (side: 1 = right of you, -1 = left, 0 = ahead).
func _find_wall() -> Dictionary:
	var h := _flat()
	var fwd := h.normalized() if h.length() > 1.0 else _look_flat()
	var right := fwd.cross(Vector3.UP).normalized()
	var best := {}
	var best_d := INF
	for pair in [[right, 1], [-right, -1], [fwd, 0], [_look_flat(), 0]]:
		for y in [0.55, 1.25]:
			var hit := _probe(Vector3(0, y, 0), pair[0], RADIUS + tune.wall_reach)
			if hit.is_empty():
				continue
			var d := (global_position + Vector3(0, y, 0)).distance_to(hit.position)
			if d < best_d:
				best_d = d
				var n: Vector3 = hit.normal
				n.y = 0
				best = {"normal": n.normalized(), "collider": hit.collider, "point": hit.position, "side": pair[1],
					"distance": d - RADIUS, "runnable": _is_runnable(hit.collider)}
	wall_info = best
	return best


## One ray from the body (offset from the feet) along `dir`; only walls count.
func _probe(offset: Vector3, dir: Vector3, length: float) -> Dictionary:
	var from := global_position + offset
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, Geo.WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var wall := not hit.is_empty() and absf(hit.normal.y) <= 0.25
	rays.append([from, hit.position if wall else from + dir * length, wall, wall and _is_runnable(hit.collider)])
	return hit if wall else {}


func _is_runnable(collider: Object) -> bool:
	return collider is CollisionObject3D and (collider.collision_layer & Geo.RUNNABLE) != 0


## The direction along a wall (normal `n`) that `h` is going.
func _along(n: Vector3, h: Vector3) -> Vector3:
	var a := n.cross(Vector3.UP).normalized()
	return -a if h.dot(a) < 0.0 else a


## Why a wall run can't start on this wall now ("" = it can).
func _wallrun_block(wall: Dictionary, wish: Vector3) -> String:
	if wall.side == 0:
		return "正面撞牆：牆跑要沿著牆跑"
	if not wall.runnable:
		return "這面牆不能牆跑（沒有橘色線）"
	if wall.collider == _wall_ban:
		return "剛離開這面牆（落地或換一面牆後重置）"
	var h := _flat()
	var along := _along(wall.normal, h)
	var speed := h.dot(along)
	if speed < tune.wallrun_min:
		return "沿牆速度不足（%.1f < %.1f）" % [speed, tune.wallrun_min]
	if absf(h.normalized().dot(wall.normal)) > tune.wallrun_angle:
		return "切入角度太正"
	if wish == Vector3.ZERO or wish.dot(along) < 0.2:
		return "方向鍵沒有朝著沿牆的方向"
	if _height_above_ground() < tune.wallrun_min_height:
		return "離地太低"
	return ""


func _start_wallrun(wall: Dictionary) -> void:
	var n: Vector3 = wall.normal
	_wall_normal = n
	_wall_node = wall.collider
	_wall_t = 0.0
	_wall_lost = 0.0
	_wall_idle = 0.0
	var h := _flat()
	var along := _along(n, h)
	# Keep the speed along the wall, and turn a little of the speed into it.
	var speed := h.dot(along) + absf(h.dot(n)) * 0.3
	# Catching the wall stops a fall; a rising jump carries on up a little.
	velocity = along * speed - n * 0.5 + Vector3(0, clampf(velocity.y * 0.5 + 1.0, 0.0, 3.5), 0)
	if _wall_ban != _wall_node:
		_wall_ban = null
	_set_move(Move.WALLRUN, "貼上可牆跑的牆（%s側）" % ("右" if wall.side > 0 else "左"))
	Sfx.play(self, "wallrun")


## The wall we're running on, if it's still there: rays straight at it (with a longer reach
## than catching it, so the edge of the reach doesn't flicker in and out). A collinear
## neighbouring runnable piece counts as the same wall.
func _wall_contact() -> Dictionary:
	var best := {}
	for y in [0.55, 1.25]:
		var hit := _probe(Vector3(0, y, 0), -_wall_normal, RADIUS + tune.wall_reach_hold)
		if hit.is_empty() or not _is_runnable(hit.collider):
			continue
		var n: Vector3 = hit.normal
		n.y = 0
		n = n.normalized()
		if n.dot(_wall_normal) > 0.9:
			best = {"normal": n, "collider": hit.collider, "point": hit.position, "side": 1 if global_basis.x.dot(-n) > 0.0 else -1,
				"distance": (global_position + Vector3(0, y, 0)).distance_to(hit.position) - RADIUS, "runnable": true}
	wall_info = best
	return best


func _do_wallrun(delta: float, wish: Vector3) -> void:
	_wall_t += delta
	var contact := _wall_contact()
	if contact.is_empty():
		_wall_lost += delta
	else:
		_wall_lost = 0.0
		_wall_normal = contact.normal
		_wall_node = contact.collider
	if _buffer > 0.0:
		_wall_jump(wish, _wall_normal, _wall_node, "蹬牆跳")
		return
	if _want("crouch", true):
		_leave_wall("按蹲離牆")
		return
	if is_on_floor():
		_leave_wall("碰到地面")
		return
	var limit := tune.wallrun_time * mobility
	if _wall_t >= limit:
		_leave_wall("牆跑時間到")
		return
	if _wall_lost > tune.wall_grace:
		_leave_wall("牆面結束")
		return
	var along := _along(_wall_normal, _flat())
	_wall_idle = _wall_idle + delta if wish == Vector3.ZERO or wish.dot(along) < -0.1 else 0.0
	if _wall_idle > tune.wall_release:
		_leave_wall("放開方向鍵")
		return
	var speed := _flat().dot(along)
	var target := tune.wallrun_speed * _speed_mult()
	if speed < target:
		speed = minf(speed + tune.wallrun_accel * delta, target)
		limiter = "牆跑加速"
	elif speed > tune.wallrun_max:
		speed -= (speed - tune.wallrun_max) * delta
		limiter = "牆跑上限"
	else:
		limiter = "牆跑保持速度"
	var late := smoothstep(tune.wallrun_late_from, 1.0, _wall_t / limit)
	var g := lerpf(tune.wallrun_gravity, tune.wallrun_gravity_late, late)
	var vy := velocity.y - g * delta
	if vy > 0.0:
		# The hop onto the wall fades into a short rise instead of carrying you up the wall.
		vy *= exp(-tune.wallrun_rise_damp * delta)
	vy = maxf(vy, -tune.wallrun_max_fall)
	velocity = along * speed - _wall_normal * 1.0 + Vector3(0, vy, 0)


## Off the wall, keeping the speed along it. For a moment after, jump still wall-jumps.
func _leave_wall(why: String) -> void:
	var along := _along(_wall_normal, _flat())
	var vy := velocity.y
	velocity = along * _flat().dot(along) + _wall_normal * 0.6 + Vector3(0, vy, 0)
	_wall_coyote = tune.wall_coyote
	_last_wall_normal = _wall_normal
	_last_wall_node = _wall_node
	_ban_wall(_wall_node)
	_set_move(Move.AIR, why)


## Jump off a wall with normal `n` in the direction of your INPUT (the keys, not the view):
## the direction is only bent enough to leave the wall, and you keep your speed (at least
## wall_jump_speed). No input: off the wall, carrying on along it.
func _wall_jump(wish: Vector3, n: Vector3, node: Object, why: String) -> void:
	_buffer = 0.0
	_wall_coyote = 0.0
	var h := _flat()
	var dir := _off_wall_dir(wish, n, h)
	velocity = dir * maxf(h.length() * tune.wall_jump_keep, tune.wall_jump_speed * mobility)
	_ensure_out(n, tune.wall_jump_out * mobility)
	_launch(tune.wall_jump_up * sqrt(mobility))
	_ban_wall(node)
	_cam.wall_kick(signf(global_basis.x.dot(-n)))
	view.jolt(global_basis.inverse() * n * 0.015)
	_set_move(Move.AIR, why, true)
	Sfx.play(self, "kick")


## Kick off any wall: same rule as the wall jump (input direction, bent off the wall), a
## little slower, a little higher.
func _wall_kick(wall: Dictionary) -> void:
	_buffer = 0.0
	_kicks -= 1
	var n: Vector3 = wall.normal
	var h := _flat()
	var dir := _off_wall_dir(_wish_dir(), n, h)
	velocity = dir * maxf(h.length() * tune.wall_kick_keep, tune.wall_kick_out * mobility)
	_ensure_out(n, tune.wall_kick_out * mobility * 0.6)
	_launch(tune.wall_kick_up * sqrt(mobility))
	_cam.wall_kick(signf(global_basis.x.dot(-n)))
	view.jolt(global_basis.inverse() * n * 0.015)
	_set_move(Move.AIR, "踢牆（剩 %d 次）" % _kicks, true)
	Sfx.play(self, "kick")


## The direction to leave a wall (normal `n`): the input, bent until it leaves the wall at
## least wall_jump_min_out; no input = along your current motion, off the wall.
func _off_wall_dir(wish: Vector3, n: Vector3, h: Vector3) -> Vector3:
	var dir := wish
	if dir == Vector3.ZERO:
		var along := h - n * h.dot(n)
		dir = (along.normalized() if along.length() > 0.5 else Vector3.ZERO) + n * 0.8
	dir = dir.normalized()
	var m := tune.wall_jump_min_out
	if dir.dot(n) < m:
		var tangent := dir - n * dir.dot(n)
		dir = n if tangent.length() < 0.01 else tangent.normalized() * sqrt(1.0 - m * m) + n * m
	return dir


## At least `speed` straight off the wall `n`.
func _ensure_out(n: Vector3, speed: float) -> void:
	var out := _flat().dot(n)
	if out < speed:
		_set_flat(_flat() + n * (speed - out))


func _ban_wall(node: Object) -> void:
	_wall_ban = node
	_wall_ban_t = tune.wall_rearm


func _can_climb(wall: Dictionary) -> bool:
	if _climbed or wall.side != 0:
		return false
	return _look_flat().dot(-wall.normal) > 0.75 and velocity.y > -6.0


func _start_climb(wall: Dictionary) -> void:
	_climbed = true
	_wall_normal = wall.normal
	_wall_node = wall.collider
	var marked: bool = wall.collider is Node and (wall.collider as Node).is_in_group("climbable")
	_climb_left = (tune.climb_time_marked if marked else tune.climb_time) * mobility
	_set_move(Move.CLIMB, "面對牆按住跳")
	Sfx.play(self, "climb")


func _do_climb(delta: float, wish: Vector3) -> void:
	_climb_left -= delta
	if _try_mantle(true):
		return
	if _buffer > 0.0 and _kicks > 0:
		_wall_kick({"normal": _wall_normal})
		return
	var contact := _probe(Vector3(0, 1.0, 0), -_wall_normal, RADIUS + tune.wall_reach_hold)
	var why := ""
	if contact.is_empty():
		why = "牆面結束"
	elif _climb_left <= 0.0:
		why = "攀牆時間到"
	elif not _want("jump"):
		why = "放開跳"
	if why != "":
		velocity.y = minf(velocity.y, 2.0)
		_set_move(Move.AIR, why)
		return
	velocity = -_wall_normal * 1.0 + Vector3(0, tune.climb_speed * sqrt(mobility), 0)


## Looks for a ledge in front: a floor between knee height and mantle_max above the feet,
## with room to stand on it. Starts the pull-up when found.
func _try_mantle(climbing: bool) -> bool:
	if velocity.y > 4.0 and not climbing:
		return false
	var look := _look_flat()
	var space := get_world_3d().direct_space_state
	var chest := global_position + Vector3(0, 0.9, 0)
	var q := PhysicsRayQueryParameters3D.create(chest, chest + look * (RADIUS + 0.6), Geo.WORLD, [get_rid()])
	var front := space.intersect_ray(q)
	var low := global_position + Vector3(0, 0.35, 0)
	if front.is_empty():
		q = PhysicsRayQueryParameters3D.create(low, low + look * (RADIUS + 0.6), Geo.WORLD, [get_rid()])
		front = space.intersect_ray(q)
		if front.is_empty():
			return false
	var probe := global_position + look * (RADIUS + 0.75) + Vector3(0, tune.mantle_max + 0.4, 0)
	q = PhysicsRayQueryParameters3D.create(probe, probe + Vector3(0, -(tune.mantle_max + 0.4), 0), Geo.WORLD, [get_rid()])
	var top := space.intersect_ray(q)
	if top.is_empty() or top.normal.y < 0.7:
		return false
	var rise: float = top.position.y - global_position.y
	if rise < 0.45 or rise > tune.mantle_max:
		return false
	# Room to stand?
	var params := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS * 0.9
	cap.height = CROUCH_HEIGHT
	params.shape = cap
	params.collision_mask = Geo.WORLD
	params.transform = Transform3D(Basis.IDENTITY, top.position + Vector3(0, CROUCH_HEIGHT / 2.0 + 0.05, 0))
	if not space.intersect_shape(params, 1).is_empty():
		_fail("邊緣上方空間不足，不能翻越")
		return false
	_mantle_from = global_position
	_mantle_to = top.position + Vector3(0, 0.02, 0)
	_mantle_t = 0.0
	_mantle_speed = flat_speed()
	# Lean back a little while rising so the head clears trims and lips that stick out.
	_mantle_back = -look * 0.18
	_set_crouch(true)
	_set_move(Move.MANTLE, "手碰到邊緣（高 %.1f m）" % rise)
	Sfx.play(self, "mantle")
	return true


func _do_mantle(delta: float) -> void:
	_mantle_t += delta / (tune.mantle_time * (1.15 - 0.15 * mobility))
	var t := clampf(_mantle_t, 0.0, 1.0)
	# Up first, then over the lip once the feet are clear of it (moving over earlier drags
	# the capsule through the ledge at high entry speeds).
	var up := minf(t * 2.0, 1.0)
	var over := clampf((t - 0.45) / 0.55, 0.0, 1.0)
	var p := _mantle_from
	p.y = lerpf(_mantle_from.y, _mantle_to.y, up)
	p.x = lerpf(_mantle_from.x, _mantle_to.x, over)
	p.z = lerpf(_mantle_from.z, _mantle_to.z, over)
	p += _mantle_back * minf(t * 6.0, 1.0) * (1.0 - over)
	# The pull-up moves you directly; velocity mirrors it (for the HUD and the graph).
	velocity = (p - global_position) / delta
	global_position = p
	if t >= 1.0:
		# Out of the pull-up with most of the speed you came in with. A jump pressed during
		# the pull-up still happens (coyote).
		velocity = _look_flat() * maxf(tune.mantle_exit * mobility, _mantle_speed * tune.mantle_keep)
		_coyote = tune.coyote
		_set_move(Move.GROUND, "翻越完成")


func _start_dash(wish: Vector3) -> void:
	_dash_charge = 0.0
	var dir := wish if wish != Vector3.ZERO else _look_flat()
	_dash_dir = dir
	_dash_left = tune.dash_time
	var keep := maxf(_flat().dot(dir), 0.0)
	velocity = dir * maxf(keep, tune.dash_speed * mobility)
	_set_move(Move.DASH, "按 Q")
	Sfx.play(self, "dash")


func _do_dash(delta: float) -> void:
	_dash_left -= delta
	velocity.y = 0.0
	# Dash jump (ULTRAKILL): jump during a dash on the ground and keep the whole burst.
	if _buffer > 0.0 and (is_on_floor() or _coyote > 0.0):
		_jump()
		return
	if _dash_left <= 0.0:
		var flat := _flat()
		var cap := tune.run_speed * 1.4 * mobility
		if flat.length() > cap and flat.length() <= tune.dash_speed * mobility + 0.1:
			# Bleed most of the burst so dashing is a dodge, not a free speed source.
			_set_flat(flat.normalized() * lerpf(cap, flat.length(), 0.35))
		_set_move(Move.GROUND if is_on_floor() else Move.AIR, "衝刺結束")


func _do_slam(_delta: float) -> void:
	velocity.y = -SLAM_SPEED


func _land_slam() -> void:
	_set_move(Move.GROUND, "重踩落地")
	_slam_height = maxf(_slam_from - global_position.y, 0.0)
	_slam_bounce = tune.slam_bounce_window
	PrintFx.landing(get_tree().current_scene, global_position, 1.0, true)
	_cam.slam()
	view.kick(4.0, 0.0)
	for t in get_tree().get_nodes_in_group("hittable"):
		if t == self or not (t is Node3D):
			continue
		var d := (t as Node3D).global_position.distance_to(global_position)
		if d > SLAM_RADIUS:
			continue
		var info := {"damage": SLAM_DAMAGE * (1.0 - d / SLAM_RADIUS * 0.6), "zone": "body", "distance": d,
			"point": (t as Node3D).global_position, "dir": ((t as Node3D).global_position - global_position).normalized(),
			"attacker": self, "attacker_name": display_name, "team": team, "gun_name": "重踩",
			"build": {}, "effects": {"knock": 4.0}, "moves": ["重踩"], "through_wall": false}
		var killed: bool = t.take_hit(info)
		hit_confirmed.emit(info, killed)
	Sfx.play(self, "slam")


func _height_above_ground() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.1, 0), global_position + Vector3(0, -30, 0), Geo.WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return 30.0 if hit.is_empty() else global_position.y - hit.position.y


func _after_move(fall_before: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_on_land(fall_before)
	_was_on_floor = on_floor


## Three kinds of landing: into a slide (crouch held and fast: the speed carries on), fast
## (no friction for a moment, time to jump or slide) and normal.
func _on_land(fall: float) -> void:
	if move == Move.SLAM:
		landing = "重踩"
		_land_slam()
		return
	if move == Move.WALLRUN:
		_leave_wall("碰到地面")
	var speed := flat_speed()
	var strength := clampf((fall - 4.0) / 18.0, 0.0, 1.0)
	_cam.land(strength)
	view.land(strength)
	if fall > 7.0:
		PrintFx.landing(get_tree().current_scene, global_position, clampf(fall / 20.0, 0.2, 1.0))
		Sfx.play(self, "land")
	if _want("crouch") and speed >= tune.slide_land_min * mobility and move != Move.SLIDE and move != Move.DASH:
		landing = "滑鏟落地"
		_start_slide(true)
		return
	if move != Move.GROUND and move != Move.SLIDE:
		_set_move(Move.GROUND, "落地")
	if speed > tune.sprint_speed * mobility * 1.05:
		_land_grace = tune.land_grace
		landing = "高速落地（%.1f m/s）" % speed
	elif fall > 14.0:
		landing = "重落地"
	else:
		landing = "一般落地"


func _set_crouch(on: bool) -> void:
	if on == _crouching:
		return
	if not on and not _can_stand():
		return
	_crouching = on
	_shape.height = CROUCH_HEIGHT if on else HEIGHT
	($Shape as CollisionShape3D).position.y = _shape.height / 2.0
	_eye = CROUCH_EYE if on else EYE
	# Hitboxes squash with you.
	for a in _hitboxes:
		var base: float = {"head": 1.62, "body": 1.1, "legs": 0.4}[a.get_meta("zone")]
		a.position.y = base * (0.58 if on else 1.0)


func _can_stand() -> bool:
	if not _crouching:
		return true
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, CROUCH_HEIGHT, 0), global_position + Vector3(0, HEIGHT + 0.05, 0), Geo.WORLD, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Short names of what the player is doing right now, for kill feed tags.
func move_tags() -> Array:
	var tags := []
	match move:
		Move.WALLRUN: tags.append("牆跑")
		Move.SLIDE: tags.append("滑鏟")
		Move.DASH: tags.append("衝刺")
		Move.CLIMB: tags.append("攀牆")
		Move.AIR, Move.SLAM:
			if _height_above_ground() > 1.2:
				tags.append("空中")
	return tags


func flat_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func dash_ready() -> float:
	return _dash_charge


func kicks_left() -> int:
	return _kicks


func wall_time_left() -> float:
	return clampf(1.0 - _wall_t / (tune.wallrun_time * mobility), 0.0, 1.0) if move == Move.WALLRUN else 0.0


## Input windows still open, for the debug panel: {jump, coyote, crouch, wall_coyote, grace}.
func windows() -> Dictionary:
	return {"jump": maxf(_buffer, 0.0), "coyote": maxf(_coyote, 0.0), "crouch": maxf(_crouch_buf, 0.0),
		"wall_coyote": maxf(_wall_coyote, 0.0), "grace": maxf(_land_grace, 0.0)}


# --- Shooting ------------------------------------------------------------------------------

func _weapon_frame(delta: float) -> void:
	weapon.tick(delta)
	var aiming := input_enabled and _want("aim") and not weapon.is_reloading() and move != Move.MANTLE
	var aim_rate := delta / maxf(float(weapon.stats.aim_time), 0.05)
	_aim = move_toward(_aim, 1.0 if aiming else 0.0, aim_rate)
	if not input_enabled:
		return
	if _want("reload", true) and weapon.start_reload():
		view.reload(weapon.reload_time())
	if _want("fire_mode", true):
		weapon.cycle_mode()
	var held := _want("fire") and move != Move.MANTLE
	var just := _want("fire", true) and move != Move.MANTLE
	var released := Input.is_action_just_released("fire")
	if weapon.wants_fire(held, just, released):
		_shoot()
	elif weapon.ammo == 0 and not weapon.is_reloading() and weapon.reserve > 0 and weapon.cooldown <= 0.0:
		if weapon.start_reload():
			view.reload(weapon.reload_time())


## Cone of fire now, in degrees. Moving and being airborne widen the hip cone; aiming uses
## the gun's precision. Wall running is steadier than flying, a reward for using the route.
func current_spread() -> float:
	var hip := float(weapon.stats.spread)
	var speed := flat_speed()
	var move_mult := 1.0 + speed / 14.0
	match move:
		Move.AIR, Move.DASH, Move.SLAM: move_mult = 1.8
		Move.SLIDE: move_mult = 1.3
		Move.WALLRUN: move_mult = 1.25
		Move.CLIMB, Move.MANTLE: move_mult = 2.2
	if _crouching and move == Move.GROUND:
		move_mult *= 0.75
	var aimed := float(weapon.stats.aim_spread) + float(weapon.stats.sway) * 0.6 + speed * 0.05
	return lerpf(hip * move_mult, aimed * (1.0 + (move_mult - 1.0) * 0.5), _aim)


func _shoot() -> void:
	var context := {"attacker": self, "name": display_name, "team": team, "exclude": exclusions(), "moves": move_tags()}
	var aim := camera.global_basis
	var origin := camera.global_position
	var results := weapon.fire(self, origin, aim, current_spread(), context)
	var muzzle := view.muzzle_global()
	view.kick(float(weapon.stats.recoil), 1.0)
	PrintFx.muzzle(view.gun_node(), view.muzzle_local(), weapon.klass, 1.0)
	var world := get_tree().current_scene
	for r in results:
		PrintFx.tracer(world, muzzle, r.to, weapon.klass)
		if r.has("target"):
			PrintFx.impact(world, r.to, r.normal, weapon.klass, true)
			if r.target != self:
				var dmg: float = r.get("damage", 0.0)
				var key: String = r.target.get("display_name") if r.target.get("display_name") != null else "?"
				damage_dealt[key] = damage_dealt.get(key, 0.0) + dmg
				hit_confirmed.emit({"zone": r.get("zone", "body"), "damage": dmg, "target": r.target}, r.get("kill", false))
		elif r.to.distance_to(r.from) < float(weapon.stats.range) * 1.39:
			PrintFx.impact(world, r.to, r.normal, weapon.klass, false)
	# Recoil: a kick up and a wobble sideways, recovered over time (the gun's ergonomics).
	var kick := float(weapon.stats.recoil) * 0.36 * lerpf(1.0, 0.75, _aim)
	if weapon.stats.effects.get("bipod", false) and _aim > 0.5 and flat_speed() < 0.5:
		kick *= 0.35
	_recoil_pitch += deg_to_rad(kick)
	_recoil_yaw += deg_to_rad(randf_range(-1.0, 1.0) * float(weapon.stats.recoil_h) * 0.3)
	_recoil_hold = 0.08
	Sfx.shot(self, weapon.klass, weapon.stats.get("suppressed", false))
	fired.emit()


func _process(_delta: float) -> void:
	if alive:
		_place_head(_render_prev.lerp(_render_curr, Engine.get_physics_interpolation_fraction()))


## The view: body yaw (turned straight from the mouse), pitch, recoil and feel effects,
## at the eye above `origin`.
func _place_head(origin: Vector3) -> void:
	var look := Basis.from_euler(Vector3(_pitch + _recoil_pitch + _cam.pitch + _cam.shake.y, _recoil_yaw + _cam.shake.x, 0))
	head.global_transform = Transform3D(Basis(Vector3.UP, rotation.y) * look, origin + Vector3(0, _eye_now + _cam.height, 0))


func _camera_frame(delta: float) -> void:
	_recoil_hold -= delta
	if _recoil_hold <= 0.0:
		var rec := 7.0 * float(weapon.stats.recovery)
		_recoil_pitch = move_toward(_recoil_pitch, 0.0, deg_to_rad(rec) * delta * (1.0 + rad_to_deg(_recoil_pitch) * 0.6))
		_recoil_yaw = move_toward(_recoil_yaw, 0.0, deg_to_rad(rec) * delta)
	# Feel effects (CameraFx): roll away from the wall on a wall run, a little on slides,
	# a few degrees of FOV at high speed, springs for landings, jumps and kicks.
	var roll_target := 0.0
	if move == Move.WALLRUN:
		roll_target = deg_to_rad(8.0) * -signf(global_basis.x.dot(_wall_normal))
	elif move == Move.SLIDE:
		roll_target = deg_to_rad(-3.0)
	var fov_target := clampf((flat_speed() - tune.run_speed) / 14.0, 0.0, 1.0) * 12.0
	_cam.update(delta, roll_target, fov_target, _aim)
	camera.rotation.z = _cam.roll
	_eye_now = lerpf(_eye_now, _eye, 1.0 - exp(-14.0 * delta))
	_place_head(global_position)
	# Wind rises with speed: the ear's half of the speed feel.
	var rush := clampf((velocity.length() - tune.sprint_speed) / 12.0, 0.0, 1.0)
	_wind.volume_db = lerpf(-60.0, -9.0, sqrt(rush)) if rush > 0.0 else -60.0
	_wind.pitch_scale = 0.8 + rush * 0.6
	if rush > 0.0 and not _wind.playing:
		_wind.play()
	var zoom := float(weapon.stats.zoom)
	var fov := (base_fov + _cam.fov) / lerpf(1.0, maxf(zoom, 1.0), _aim)
	camera.fov = lerpf(camera.fov, fov, 1.0 - exp(-14.0 * delta))
	view.update_pose(delta, {"aim": _aim, "speed": flat_speed(), "move": move, "floor": is_on_floor(),
		"roll": _cam.roll, "vy": velocity.y, "reloading": weapon.is_reloading(),
		"sprint": _want("sprint") and move == Move.GROUND and flat_speed() > tune.run_speed * mobility})


# --- Damage --------------------------------------------------------------------------------

func take_hit(info: Dictionary) -> bool:
	if not alive:
		return false
	if info.get("team", -1) == team and info.get("attacker") != self:
		return false
	var effects: Dictionary = info.get("effects", {})
	if effects.has("knock"):
		velocity += (info.dir as Vector3) * float(effects.knock) * 2.0 + Vector3(0, 2.0, 0)
	if effects.has("slow"):
		_slow = maxf(_slow, float(effects.slow))
	if effects.has("stun"):
		_slow = maxf(_slow, float(effects.stun))
	if effects.has("burn") or effects.has("bleed"):
		_burn = maxf(_burn, float(effects.get("burn", effects.get("bleed", 0.0))))
	if info.get("attacker") != self:
		_last_attacker = info
		var who: String = info.get("attacker_name", "?")
		damage_taken[who] = damage_taken.get(who, 0.0) + float(info.damage)
		var from: Vector3 = -(info.get("dir", Vector3.FORWARD) as Vector3)
		_cam.hurt(signf(global_basis.x.dot(from)))
	damaged.emit(info)
	return _apply_damage(float(info.damage), info, true)


## A kill with a kill_dash gun: the dash is ready again.
func refill_dash() -> void:
	_dash_charge = 1.0


func _apply_damage(amount: float, info: Dictionary, _direct: bool) -> bool:
	if not alive:
		return false
	health -= amount
	if health <= 0.0:
		health = 0.0
		_die(info if not info.is_empty() else _last_attacker)
		return true
	return false


func _die(info: Dictionary) -> void:
	alive = false
	_set_move(Move.GROUND, "死亡")
	velocity = Vector3.ZERO
	PrintFx.takedown(get_tree().current_scene, global_position, Faultprint.INFO_ALLY)
	for a in _hitboxes:
		a.set_deferred("collision_layer", 0)
	died.emit(info)
