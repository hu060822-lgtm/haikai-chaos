class_name Bot
extends CharacterBody3D
## A sparring bot for the prototype: it wanders the ground floor, fights when it sees
## you, and carries a random custom gun (so the kill feed and death screen have
## something to show). It is deliberately beatable by moving: its aim error grows with
## how fast you go, so the movement tech pays off.

signal died(bot: Bot, info: Dictionary)

const SPEED := 5.2
const GRAVITY := 21.0
const MAX_HEALTH := 100.0
const REACTION := Vector2(0.32, 0.6)
const SIGHT := 70.0
## Bots hit softer than you: this is a sparring partner.
const DAMAGE_MULT := 0.45
const NAMES := ["灰板", "模具", "套色", "網點", "鉚釘", "楔形", "印版", "斷層", "鋼架", "骨白"]

var display_name := "陪練"
var team := 1
var health := MAX_HEALTH
var alive := true
var weapon: Weapon
var waypoints: Array[Vector3] = []
var target: Player
var passive := false
var marked := 0.0

var _model: Node3D
var _gun: Node3D
var _hitboxes: Array[Area3D] = []
var _goal := Vector3.ZERO
var _see := false
var _reaction := 0.0
var _think := 0.0
var _strafe := 1.0
var _strafe_left := 0.0
var _last_seen := Vector3.INF
var _slow := 0.0
var _burn := 0.0
var _burn_info := {}
var _flash := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("hittable")
	add_to_group("bots")
	collision_layer = Geo.BODIES
	collision_mask = Geo.WORLD | Geo.BODIES
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	for spec in [["head", Vector3(0, 1.64, 0), Vector3(0.3, 0.3, 0.32)], ["body", Vector3(0, 1.12, 0), Vector3(0.56, 0.66, 0.36)],
			["legs", Vector3(0, 0.42, 0), Vector3(0.44, 0.84, 0.3)]]:
		var area := Area3D.new()
		area.collision_layer = Geo.HITBOX
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("target", self)
		area.set_meta("zone", spec[0])
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[2]
		shape.shape = box
		area.add_child(shape)
		area.position = spec[1]
		add_child(area)
		_hitboxes.append(area)


## Spawns (or respawns) with a fresh random gun and name.
func spawn(at: Vector3, seed_value: int) -> void:
	rng.seed = seed_value
	display_name = "%s-%02d" % [NAMES[rng.randi() % NAMES.size()], rng.randi_range(1, 99)]
	var build := GunNames.random_build(rng)
	weapon = Weapon.new(build)
	if _model != null:
		_model.queue_free()
	_model = CompetitorModel.build(Faultprint.INFO_ENEMY, true, rng)
	add_child(_model)
	_gun = GunModels.build(weapon.build)
	_model.get_node("GunHand").add_child(_gun)
	global_position = at
	rotation = Vector3(0, rng.randf() * TAU, 0)
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	alive = true
	visible = true
	_see = false
	_last_seen = Vector3.INF
	for a in _hitboxes:
		a.set_deferred("collision_layer", Geo.HITBOX)
	_pick_goal()


func exclusions() -> Array:
	var out := [get_rid()]
	for a in _hitboxes:
		out.append(a.get_rid())
	return out


func _pick_goal() -> void:
	if waypoints.is_empty():
		_goal = global_position
		return
	_goal = waypoints[rng.randi() % waypoints.size()]


func _physics_process(delta: float) -> void:
	if not alive:
		return
	weapon.tick(delta)
	_slow = maxf(_slow - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	marked = maxf(marked - delta, 0.0)
	if _burn > 0.0:
		_burn -= delta
		_damage(6.0 * delta, _burn_info)
		if not alive:
			return
	_think -= delta
	if _think <= 0.0:
		_think = 0.12
		_look_for_target()
	var speed := SPEED * (0.55 if _slow > 0.0 else 1.0)
	var flat := Vector3.ZERO
	if _see and target != null:
		_reaction -= delta
		_face(target.global_position, delta, 9.0)
		# Strafe left and right while fighting, sometimes hop.
		_strafe_left -= delta
		if _strafe_left <= 0.0:
			_strafe = -_strafe if rng.randf() < 0.7 else _strafe
			_strafe_left = rng.randf_range(0.4, 1.1)
			if is_on_floor() and rng.randf() < 0.15:
				velocity.y = 6.5
		flat = global_basis.x * _strafe * speed * 0.7
		var d := global_position.distance_to(target.global_position)
		if d > float(weapon.stats.range) * 0.8:
			flat += -global_basis.z * speed * 0.6
		if _reaction <= 0.0 and not passive:
			_try_shoot()
	else:
		var to_goal := _goal - global_position
		to_goal.y = 0
		if _last_seen != Vector3.INF:
			to_goal = _last_seen - global_position
			to_goal.y = 0
			if to_goal.length() < 1.5:
				_last_seen = Vector3.INF
		if to_goal.length() < 1.2:
			_pick_goal()
		elif to_goal.length() > 0.01:
			_face(global_position + to_goal, delta, 5.0)
			flat = to_goal.normalized() * speed * 0.8
	velocity.x = lerpf(velocity.x, flat.x, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, flat.z, 1.0 - exp(-8.0 * delta))
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if is_on_wall() and is_on_floor() and not _see:
		velocity.y = 6.8
		if rng.randf() < 0.3:
			_pick_goal()
	if _model != null:
		var marker := _model.get_node_or_null("Marker")
		if marker:
			marker.rotate_y(delta * 2.0)


func _face(point: Vector3, delta: float, rate: float) -> void:
	var to := point - global_position
	to.y = 0
	if to.length() < 0.01:
		return
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-rate * delta))


func _eye() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)


func _look_for_target() -> void:
	if target == null or not target.alive:
		_see = false
		return
	var eye := _eye()
	var aim_at := target.global_position + Vector3(0, 1.3, 0)
	var d := eye.distance_to(aim_at)
	var was := _see
	_see = false
	if d > SIGHT:
		return
	var to := (aim_at - eye).normalized()
	var facing := (-global_basis.z).dot(to)
	if facing < -0.1 and d > 6.0 and not was:
		return
	var q := PhysicsRayQueryParameters3D.create(eye, aim_at, Geo.WORLD, exclusions())
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		_see = true
		_last_seen = target.global_position
		if not was:
			_reaction = rng.randf_range(REACTION.x, REACTION.y)


func _try_shoot() -> void:
	var held := true
	var just := weapon.cooldown <= 0.0
	if weapon.stats.kind == "charge":
		just = false
		held = weapon.charge < 0.7
	if not weapon.wants_fire(held, just, weapon.stats.kind == "charge" and weapon.charge >= 0.7):
		if weapon.ammo == 0:
			weapon.start_reload()
		return
	var eye := _eye()
	var aim_at := target.global_position + Vector3(0, rng.randf_range(0.9, 1.6), 0)
	var aim := Basis.looking_at((aim_at - eye).normalized(), Vector3.UP)
	# Fast targets are hard to hit: the error grows with the target's speed.
	var error := 2.2 + target.flat_speed() * 0.55 + (2.5 if target.move == Player.Move.AIR else 0.0)
	var spread := maxf(float(weapon.stats.spread), error)
	var context := {"attacker": self, "name": display_name, "team": team, "exclude": exclusions(), "moves": []}
	var saved: float = weapon.stats.damage
	weapon.stats.damage = float(saved) * DAMAGE_MULT
	var results := weapon.fire(self, eye, aim, spread, context)
	weapon.stats.damage = saved
	var world := get_tree().current_scene
	var muzzle := _gun.to_global(_gun.get_meta("muzzle")) if _gun else eye
	PrintFx.muzzle(_gun, _gun.get_meta("muzzle"), weapon.klass, 1.6)
	for r in results:
		PrintFx.tracer(world, muzzle, r.to, weapon.klass)
		if not r.hit_body:
			PrintFx.impact(world, r.to, r.normal, weapon.klass, false)
	Sfx.shot(self, weapon.klass, weapon.stats.get("suppressed", false))


func take_hit(info: Dictionary) -> bool:
	if not alive:
		return false
	if info.get("team", -1) == team and info.get("attacker") != self:
		return false
	if SafeZone.blocks(info, team, global_position):
		return false
	var e: Dictionary = info.get("effects", {})
	if e.has("knock"):
		velocity += (info.dir as Vector3) * float(e.knock) * 2.5 + Vector3(0, 2.5, 0)
	if e.has("slow") or e.has("stun"):
		_slow = maxf(_slow, float(e.get("slow", e.get("stun", 0.0))))
	if e.has("burn") or e.has("bleed"):
		_burn = maxf(_burn, float(e.get("burn", e.get("bleed", 0.0))))
		_burn_info = info
	# Being shot turns it around.
	if target != null and info.get("attacker") == target:
		_last_seen = target.global_position
	return _damage(float(info.damage), info)


func _damage(amount: float, info: Dictionary) -> bool:
	health -= amount
	_flash = 0.08
	if health <= 0.0:
		_die(info)
		return true
	return false


func _die(info: Dictionary) -> void:
	alive = false
	health = 0.0
	for a in _hitboxes:
		a.set_deferred("collision_layer", 0)
	PrintFx.takedown(get_tree().current_scene, global_position, Faultprint.INFO_ENEMY)
	visible = false
	died.emit(self, info)
