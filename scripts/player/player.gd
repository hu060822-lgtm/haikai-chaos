class_name Player
extends CharacterBody3D
## The first-person competitor: momentum movement with a full set of movement tech, and
## a custom gun from the bench. The gun's weight drives the movement (Player.mobility):
## a feather pistol makes you faster, kick off walls more and dash more often; a 12 kg
## machine gun keeps you mostly on the ground. That trade is the core of CHAOS.
##
## Movement tech:
##   sprint (Shift), crouch (Ctrl/C), jump (Space) with coyote time and a jump buffer
##   bunny hop    jumping the moment you land skips ground friction; air strafing (turn
##                while holding a side key in the air) adds speed, Quake-style
##   slide        crouch while running fast: a speed boost, low friction, faster downhill
##   slide jump   jump out of a slide and keep its speed
##   wall run     in the air beside an orange-banded wall, hold forward: run along it
##   wall jump    jump off a wall run, or kick off any wall in the air (a few per air time)
##   wall climb   run at a wall face-on and hold jump: run up it for a moment
##   mantle       reach a ledge while in the air (or climbing): pull yourself up onto it
##   dash         Q: a short burst in the direction you're moving (one charge, recharges)
##   slam         crouch in the air high up: drive into the ground, shock anyone close

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

const GRAVITY := 21.0
const RUN_SPEED := 6.4
const SPRINT_SPEED := 8.4
const CROUCH_SPEED := 3.2
const GROUND_ACCEL := 11.0
const FRICTION := 7.0
const STOP_SPEED := 2.5
const AIR_ACCEL := 70.0
const AIR_CAP := 1.0
const MAX_FLAT := 24.0
const JUMP := 7.3
const COYOTE := 0.12
const BUFFER := 0.14

const SLIDE_MIN := 6.2
const SLIDE_BOOST := 3.6
const SLIDE_FRICTION := 0.55
const SLIDE_TIME := 1.15
const SLIDE_COOLDOWN := 1.2

const WALLRUN_MIN := 4.5
const WALLRUN_SPEED := 9.2
const WALLRUN_TIME := 1.7
const WALLRUN_GRAVITY := 3.2
const WALL_REACH := 0.75
const WALL_KICK_OUT := 6.8
const WALL_KICK_UP := 7.2
const WALL_KICKS := 3

const CLIMB_SPEED := 6.2
const CLIMB_TIME := 0.6
const CLIMB_TIME_MARKED := 1.15
const MANTLE_MAX := 2.3
const MANTLE_TIME := 0.24

const DASH_SPEED := 14.0
const DASH_TIME := 0.15
const DASH_RECHARGE := 3.2

const SLAM_MIN_HEIGHT := 2.4
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

var move := Move.GROUND
var head: Node3D
var camera: Camera3D
var view: ViewModel
var base_fov := 96.0

var _pitch := 0.0
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _recoil_hold := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _crouching := false
var _shape: CapsuleShape3D
var _eye := EYE
var _slide_left := 0.0
var _slide_cd := 0.0
var _wall_normal := Vector3.ZERO
var _wall_node: Object = null
var _wall_left := 0.0
var _wall_ban: Object = null
var _wall_ban_left := 0.0
var _kicks := WALL_KICKS
var _climb_left := 0.0
var _climbed := false
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
var _dash_left := 0.0
var _dash_charge := 1.0
var _dash_dir := Vector3.ZERO
var _aim := 0.0
var _roll := 0.0
var _bob := 0.0
var _land_dip := 0.0
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
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.fov = base_fov
	camera.near = 0.03
	camera.far = 500.0
	head.add_child(camera)
	view = ViewModel.new()
	camera.add_child(view)
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
	return WALL_KICKS


func spawn_at(xform: Transform3D) -> void:
	_spawn = xform
	global_transform = Transform3D(Basis(Vector3.UP, xform.basis.get_euler().y), xform.origin)
	velocity = Vector3.ZERO
	_pitch = 0.0
	health = MAX_HEALTH
	alive = true
	move = Move.GROUND
	_set_crouch(false)
	_slow = 0.0
	_burn = 0.0
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
		var sens := MOUSE_SENS * lerpf(1.0, 1.0 / maxf(float(weapon.stats.zoom), 1.0), _aim)
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, deg_to_rad(-88), deg_to_rad(88))
		view.sway(event.relative)


# --- Frame ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_timers(delta)
	var wish := _wish_dir()
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE
		_kicks = max_kicks()
		_climbed = false
		_wall_ban = null
		if _dash_charge < 1.0 and _dash_left <= 0.0:
			pass
	if _want("jump", true):
		_buffer = BUFFER
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
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > MAX_FLAT:
		flat = flat.normalized() * MAX_FLAT
		velocity.x = flat.x
		velocity.z = flat.y
	var fall := -velocity.y
	if move != Move.MANTLE:
		move_and_slide()
	_after_move(fall)
	_weapon_frame(delta)
	_camera_frame(delta)


func _timers(delta: float) -> void:
	_coyote -= delta
	_buffer -= delta
	_slide_cd -= delta
	_wall_ban_left -= delta
	if _wall_ban_left <= 0.0:
		_wall_ban = null
	_dash_charge = minf(_dash_charge + delta / (DASH_RECHARGE / mobility), 1.0)
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


# --- Free movement: ground, air, slide -------------------------------------------------

func _do_free(delta: float, wish: Vector3, on_floor: bool) -> void:
	var crouch_held := _want("crouch")
	# Dash and slam come first: they override everything.
	if _want("dash", true) and _dash_charge >= 1.0:
		_start_dash(wish)
		return
	if not on_floor and _want("crouch", true) and _height_above_ground() >= SLAM_MIN_HEIGHT:
		move = Move.SLAM
		velocity = Vector3(velocity.x * 0.25, -SLAM_SPEED, velocity.z * 0.25)
		return
	if on_floor:
		var flat_speed := Vector2(velocity.x, velocity.z).length()
		if move == Move.SLIDE:
			_slide_left -= delta
			_slide_ground(delta)
			var slope := get_floor_normal().y < 0.97
			if not crouch_held or (flat_speed < 3.6 and not slope) or (_slide_left <= 0.0 and not slope):
				move = Move.GROUND
		elif crouch_held and flat_speed >= SLIDE_MIN * mobility * 0.95 and _slide_cd <= 0.0 \
				and Input.is_action_just_pressed("crouch"):
			_start_slide()
		else:
			move = Move.GROUND
			_set_crouch(crouch_held or not _can_stand())
			var target := RUN_SPEED
			if _crouching:
				target = CROUCH_SPEED
			elif _want("sprint") and _aim < 0.5:
				target = SPRINT_SPEED
			if _buffer > 0.0:
				# Bunny hop: skip friction on the frame you jump out of a landing.
				pass
			else:
				_friction(delta, FRICTION)
			_accelerate(wish, target * _speed_mult(), GROUND_ACCEL, delta)
		if _buffer > 0.0 and (_can_stand() or move == Move.SLIDE):
			_jump()
	else:
		if move == Move.SLIDE or move == Move.GROUND:
			move = Move.AIR
		if _coyote > 0.0 and _buffer > 0.0 and velocity.y <= 0.5:
			_jump()
			return
		velocity.y -= GRAVITY * delta
		_accelerate(wish, AIR_CAP * _speed_mult(), AIR_ACCEL, delta, RUN_SPEED * 1.0)
		_set_crouch(crouch_held and _height_above_ground() < SLAM_MIN_HEIGHT)
		# Ledge, wall run, wall climb, wall kick: in that order.
		if (_want("move_forward") or _want("jump")) and _try_mantle(false):
			return
		var wall := _find_wall(wish)
		if not wall.is_empty():
			if _buffer > 0.0 and _kicks > 0:
				_wall_kick(wall.normal)
				return
			if _can_wallrun(wall, wish):
				_start_wallrun(wall)
				return
			if _can_climb(wall) and _want("jump"):
				_start_climb(wall)
				return


func _friction(delta: float, amount: float) -> void:
	var flat := Vector3(velocity.x, 0, velocity.z)
	var speed := flat.length()
	if speed < 0.01:
		return
	var drop := maxf(speed, STOP_SPEED) * amount * delta
	var scale := maxf(speed - drop, 0.0) / speed
	velocity.x *= scale
	velocity.z *= scale


## Quake-style acceleration. In the air `wishspeed` is tiny (AIR_CAP), so pressing the
## direction you're already going adds nothing, but turning into a side key adds speed:
## that is air strafing. `cap` limits the gain a little so it stays a skill, not a cheat.
func _accelerate(wish: Vector3, wishspeed: float, accel: float, delta: float, _cap := 0.0) -> void:
	if wish == Vector3.ZERO:
		return
	var current := Vector3(velocity.x, 0, velocity.z).dot(wish)
	var add := wishspeed - current
	if add <= 0.0:
		return
	var gain := minf(accel * maxf(wishspeed, 1.0) * delta, add)
	velocity += wish * gain


func _jump() -> void:
	_buffer = 0.0
	_coyote = 0.0
	velocity.y = JUMP * sqrt(mobility) * (0.75 if _slow > 0.0 else 1.0)
	if move == Move.SLIDE:
		# Slide jump: keep the slide's speed and leave a little lower.
		velocity.y *= 0.92
	move = Move.AIR
	_set_crouch(false)
	Sfx.play(self, "jump")


func _start_slide() -> void:
	move = Move.SLIDE
	_slide_left = SLIDE_TIME
	_slide_cd = SLIDE_COOLDOWN
	_set_crouch(true)
	var flat := Vector3(velocity.x, 0, velocity.z)
	velocity += flat.normalized() * SLIDE_BOOST * mobility
	Sfx.play(self, "slide")


func _slide_ground(delta: float) -> void:
	_friction(delta, SLIDE_FRICTION)
	# Downhill pulls you faster: gravity along the slope.
	var n := get_floor_normal()
	var along := Vector3.DOWN - n * n.dot(Vector3.DOWN)
	velocity += along * GRAVITY * delta * 0.9


# --- Walls -------------------------------------------------------------------------------

## The closest wall around the chest, preferring the sides of the way you're moving.
## Returns {normal, collider, point, side} or {} (side: 1 = right of you, -1 = left, 0 = ahead).
func _find_wall(wish: Vector3) -> Dictionary:
	var flat := Vector3(velocity.x, 0, velocity.z)
	var fwd := flat.normalized() if flat.length() > 1.0 else -global_basis.z
	var right := fwd.cross(Vector3.UP).normalized()
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var best := {}
	var best_d := INF
	for pair in [[right, 1], [-right, -1], [fwd, 0], [-global_basis.z, 0]]:
		var dir: Vector3 = pair[0]
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * (RADIUS + WALL_REACH), Geo.WORLD, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf(hit.normal.y) > 0.25:
			continue
		var d := from.distance_to(hit.position)
		if d < best_d:
			best_d = d
			best = {"normal": hit.normal, "collider": hit.collider, "point": hit.position, "side": pair[1]}
	return best


func _is_runnable(collider: Object) -> bool:
	return collider is CollisionObject3D and (collider.collision_layer & Geo.RUNNABLE) != 0


func _can_wallrun(wall: Dictionary, wish: Vector3) -> bool:
	if wall.side == 0 or not _is_runnable(wall.collider) or wall.collider == _wall_ban:
		return false
	if not _want("move_forward") or _height_above_ground() < 0.7:
		return false
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() < WALLRUN_MIN:
		return false
	# Moving along the wall, not straight into it or away from it.
	return absf(flat.normalized().dot(wall.normal)) < 0.75


func _start_wallrun(wall: Dictionary) -> void:
	move = Move.WALLRUN
	_wall_normal = wall.normal
	_wall_node = wall.collider
	_wall_left = WALLRUN_TIME * mobility
	velocity.y = maxf(velocity.y, 1.6)
	Sfx.play(self, "wallrun")


func _do_wallrun(delta: float, wish: Vector3) -> void:
	_wall_left -= delta
	var wall := _find_wall(wish)
	var stays: bool = not wall.is_empty() and wall.collider == _wall_node and wall.side != 0
	if stays:
		_wall_normal = wall.normal
	if _buffer > 0.0:
		_wall_jump()
		return
	if not stays or _wall_left <= 0.0 or is_on_floor() or not _want("move_forward"):
		_leave_wall()
		return
	var along := _wall_normal.cross(Vector3.UP).normalized()
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.dot(along) < 0.0:
		along = -along
	var speed := maxf(flat.length(), WALLRUN_SPEED * _speed_mult())
	# Looking off the wall steers a little; the run line is the wall.
	var steer := (-global_basis.z).dot(along)
	speed *= lerpf(0.85, 1.0, clampf(steer, 0.0, 1.0))
	var stick := -_wall_normal * 2.0
	var vy := velocity.y - WALLRUN_GRAVITY * delta * (1.0 + 2.0 * (1.0 - _wall_left / (WALLRUN_TIME * mobility)))
	velocity = along * speed + stick + Vector3(0, vy, 0)


func _wall_jump() -> void:
	_buffer = 0.0
	var flat := Vector3(velocity.x, 0, velocity.z)
	var look := -global_basis.z
	look.y = 0
	# Off the wall, toward where you look (but never back into the wall).
	var away := (_wall_normal * 0.8 + look.normalized() * 0.6).normalized()
	if away.dot(_wall_normal) < 0.2:
		away = _wall_normal
	velocity = flat * 0.75 + away * WALL_KICK_OUT * mobility
	velocity.y = WALL_KICK_UP * sqrt(mobility)
	_ban_wall(_wall_node)
	move = Move.AIR
	Sfx.play(self, "kick")


func _wall_kick(normal: Vector3) -> void:
	_buffer = 0.0
	_kicks -= 1
	var flat := Vector3(velocity.x, 0, velocity.z)
	# Cancel the part of the speed going into the wall, then push off it.
	var into := minf(flat.dot(normal), 0.0)
	flat -= normal * into
	velocity = flat * 0.85 + normal * WALL_KICK_OUT * mobility
	velocity.y = WALL_KICK_UP * sqrt(mobility)
	move = Move.AIR
	Sfx.play(self, "kick")


func _leave_wall() -> void:
	_ban_wall(_wall_node)
	move = Move.AIR


func _ban_wall(node: Object) -> void:
	_wall_ban = node
	_wall_ban_left = 0.45


func _can_climb(wall: Dictionary) -> bool:
	if _climbed or wall.side != 0:
		return false
	var look := -global_basis.z
	look.y = 0
	return look.normalized().dot(-wall.normal) > 0.75 and velocity.y > -6.0


func _start_climb(wall: Dictionary) -> void:
	move = Move.CLIMB
	_climbed = true
	_wall_normal = wall.normal
	_wall_node = wall.collider
	var marked := wall.collider is Node and (wall.collider as Node).is_in_group("climbable")
	_climb_left = (CLIMB_TIME_MARKED if marked else CLIMB_TIME) * mobility
	Sfx.play(self, "climb")


func _do_climb(delta: float, wish: Vector3) -> void:
	_climb_left -= delta
	if _try_mantle(true):
		return
	var wall := _find_wall(wish)
	if _buffer > 0.0 and _kicks > 0:
		_wall_kick(_wall_normal)
		return
	if wall.is_empty() or _climb_left <= 0.0 or not _want("jump"):
		move = Move.AIR
		velocity.y = minf(velocity.y, 2.0)
		return
	velocity = -_wall_normal * 1.0 + Vector3(0, CLIMB_SPEED * sqrt(mobility), 0)


## Looks for a ledge in front: a floor between knee height and MANTLE_MAX above the feet,
## with room to stand on it. Starts the pull-up when found.
func _try_mantle(climbing: bool) -> bool:
	if velocity.y > 4.0 and not climbing:
		return false
	var look := -global_basis.z
	look.y = 0
	look = look.normalized()
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
	var probe := global_position + look * (RADIUS + 0.75) + Vector3(0, MANTLE_MAX + 0.4, 0)
	q = PhysicsRayQueryParameters3D.create(probe, probe + Vector3(0, -(MANTLE_MAX + 0.4), 0), Geo.WORLD, [get_rid()])
	var top := space.intersect_ray(q)
	if top.is_empty() or top.normal.y < 0.7:
		return false
	var rise: float = top.position.y - global_position.y
	if rise < 0.45 or rise > MANTLE_MAX:
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
		return false
	move = Move.MANTLE
	_mantle_from = global_position
	_mantle_to = top.position + Vector3(0, 0.02, 0)
	_mantle_t = 0.0
	_set_crouch(true)
	Sfx.play(self, "mantle")
	return true


func _do_mantle(delta: float) -> void:
	_mantle_t += delta / (MANTLE_TIME * (1.15 - 0.15 * mobility))
	var t := clampf(_mantle_t, 0.0, 1.0)
	# Up first, then over the lip.
	var up := minf(t * 1.6, 1.0)
	var over := clampf((t - 0.35) / 0.65, 0.0, 1.0)
	var p := _mantle_from
	p.y = lerpf(_mantle_from.y, _mantle_to.y, up)
	p.x = lerpf(_mantle_from.x, _mantle_to.x, over)
	p.z = lerpf(_mantle_from.z, _mantle_to.z, over)
	global_position = p
	velocity = Vector3.ZERO
	if t >= 1.0:
		move = Move.GROUND
		var look := -global_basis.z
		look.y = 0
		velocity = look.normalized() * 4.0 * mobility


func _start_dash(wish: Vector3) -> void:
	_dash_charge = 0.0
	var dir := wish if wish != Vector3.ZERO else Vector3(-global_basis.z.x, 0, -global_basis.z.z).normalized()
	_dash_dir = dir
	_dash_left = DASH_TIME
	move = Move.DASH
	var flat := Vector3(velocity.x, 0, velocity.z)
	var keep := maxf(flat.dot(dir), 0.0)
	velocity = dir * maxf(keep, DASH_SPEED * mobility)
	Sfx.play(self, "dash")


func _do_dash(delta: float) -> void:
	_dash_left -= delta
	velocity.y = 0.0
	if _dash_left <= 0.0:
		move = Move.AIR if not is_on_floor() else Move.GROUND
		var flat := Vector3(velocity.x, 0, velocity.z)
		var cap := maxf(RUN_SPEED * 1.4 * mobility, 0.0)
		if flat.length() > cap and flat.length() <= DASH_SPEED * mobility + 0.1:
			# Bleed most of the burst so dashing is a dodge, not a free speed source.
			flat = flat.normalized() * lerpf(cap, flat.length(), 0.35)
			velocity.x = flat.x
			velocity.z = flat.z


func _do_slam(_delta: float) -> void:
	velocity.y = -SLAM_SPEED
	if is_on_floor():
		_land_slam()


func _land_slam() -> void:
	move = Move.GROUND
	PrintFx.landing(get_tree().current_scene, global_position, 1.0, true)
	_land_dip = 0.35
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
		if move == Move.SLAM:
			_land_slam()
		elif fall_before > 7.0:
			_land_dip = clampf(fall_before / 40.0, 0.04, 0.2)
			PrintFx.landing(get_tree().current_scene, global_position, clampf(fall_before / 20.0, 0.2, 1.0))
			Sfx.play(self, "land")
		if move == Move.AIR or move == Move.DASH:
			move = Move.GROUND
		# Land into a slide if crouch is held and you're fast: keep the momentum.
		if _want("crouch") and Vector2(velocity.x, velocity.z).length() >= SLIDE_MIN * mobility * 0.9 and move == Move.GROUND:
			_start_slide()
	_was_on_floor = on_floor


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
	return clampf(_wall_left / (WALLRUN_TIME * mobility), 0.0, 1.0) if move == Move.WALLRUN else 0.0


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


func _camera_frame(delta: float) -> void:
	_recoil_hold -= delta
	if _recoil_hold <= 0.0:
		var rec := 7.0 * float(weapon.stats.recovery)
		_recoil_pitch = move_toward(_recoil_pitch, 0.0, deg_to_rad(rec) * delta * (1.0 + rad_to_deg(_recoil_pitch) * 0.6))
		_recoil_yaw = move_toward(_recoil_yaw, 0.0, deg_to_rad(rec) * delta)
	head.rotation = Vector3(_pitch + _recoil_pitch, _recoil_yaw, 0)
	# Roll away from the wall on a wall run; a small dip on hard landings.
	var roll_target := 0.0
	if move == Move.WALLRUN:
		var right := global_basis.x
		roll_target = deg_to_rad(11.0) * -signf(right.dot(_wall_normal))
	elif move == Move.SLIDE:
		roll_target = deg_to_rad(-3.0)
	_roll = lerpf(_roll, roll_target, 1.0 - exp(-10.0 * delta))
	camera.rotation.z = _roll
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.9)
	head.position.y = lerpf(head.position.y, _eye - _land_dip, 1.0 - exp(-14.0 * delta))
	var speed_fov := clampf((flat_speed() - RUN_SPEED) / 10.0, 0.0, 1.0) * 7.0
	var zoom := float(weapon.stats.zoom)
	var fov := (base_fov + speed_fov) / lerpf(1.0, maxf(zoom, 1.0), _aim)
	camera.fov = lerpf(camera.fov, fov, 1.0 - exp(-14.0 * delta))
	view.update_pose(delta, {"aim": _aim, "speed": flat_speed(), "move": move, "floor": is_on_floor(),
		"roll": _roll, "reloading": weapon.is_reloading(), "sprint": _want("sprint") and move == Move.GROUND and flat_speed() > RUN_SPEED})


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
	damaged.emit(info)
	return _apply_damage(float(info.damage), info, true)


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
	move = Move.GROUND
	velocity = Vector3.ZERO
	PrintFx.takedown(get_tree().current_scene, global_position, Faultprint.INFO_ALLY)
	for a in _hitboxes:
		a.set_deferred("collision_layer", 0)
	died.emit(info)
