class_name Bot
extends CharacterBody3D
## A sparring bot for the prototype: it wanders the ground floor, fights when it sees
## you, and carries a random custom gun (so the kill feed and death screen have
## something to show). It is deliberately beatable by moving: its aim error grows with
## how fast you go, so the movement tech pays off.
##
## Difficulty (C9, BotLevel): 簡單 / 中等 / 困難 change how it behaves, never how well it
## aims: what it notices and hears, where it stands, when it reloads, backs off or takes
## cover, and (困難) calling out, hunting and flanking with its team.

signal died(bot: Bot, info: Dictionary)
## A shot left the gun (for netplay: the other screens draw the tracers).
signal shot_traced(from: Vector3, tos: PackedVector3Array)

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
## Who it is fighting. In practice that's you; in a team match it picks the nearest enemy
## it can see among the "combatants" (players, other bots, remote players).
var target: Node3D
var passive := false
## Holds still and doesn't shoot (預算戰's build phase).
var frozen := false
## Where it wants to be when it has no one to fight (爆破: a bomb site, the bomb), or INF.
var objective := Vector3.INF
var _stuck := 0.0
var _hurt_at := -100.0
var _detour := 0.0
## The map's floor plan (big maps, Layout): bots then walk real paths round corners.
var nav: Layout
var _path: Array[Vector3] = []
var _path_to := Vector3.INF
var _path_t := 0.0
var marked := 0.0
## Netplay id ("b3") and how hard it hits (sparring bots hit softer than team-match ones).
var id := ""
var damage_mult := DAMAGE_MULT
## Drawn in the ally colour (a team match, on a teammate's screen).
var tint_ally := false
var move := 0
var shot_count := 0
var _look_pitch := 0.0

var _model: CompetitorRig
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
## The class (C6). Bots don't swing on lines: they get one of BOT_KITS and use it simply
## (_use_ability): a decoy on the way somewhere, smoke and cover in a fight at range, a
## charge up close.
const BOT_KITS := ["decoy", "bulwark", "veil", "ram"]
var kit_id := ""
var ability: Ability
var _stagger := 0.0
var _lunge := Vector3.ZERO
var _lunge_left := 0.0
var _ability_think := 0.0
## Difficulty (BotLevel.EASY / MEDIUM / HARD) and its numbers.
var level := BotLevel.MEDIUM
var _p: Dictionary = BotLevel.profile(BotLevel.MEDIUM)
## When it last saw (or heard of) someone at _last_seen: it gives up after _p.memory.
var _seen_at := -100.0
## 困難: the cover it is heading for (or sitting in), how long it has sat there, and when
## it may look for cover again.
var _cover_at := Vector3.INF
var _cover_wait := 0.0
var _cover_cd := 0.0
var _cover_left := 0.0
## 困難: a flanking spot to reach before going for a teammate's callout.
var _flank_at := Vector3.INF
var _flank_left := 0.0


func _ready() -> void:
	add_to_group("hittable")
	add_to_group("bots")
	add_to_group("combatants")
	collision_layer = Geo.BODIES
	collision_mask = Geo.WORLD | Geo.BODIES | Geo.BOUNDS
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
	_model = CompetitorModel.build(FpUi.ally_color() if tint_ally else Faultprint.INFO_ENEMY, not tint_ally, rng)
	add_child(_model)
	_gun = GunModels.build(weapon.build)
	_model.find_child("GunHand", true, false).add_child(_gun)
	global_position = at
	rotation = Vector3(0, rng.randf() * TAU, 0)
	velocity = Vector3.ZERO
	if ability == null:
		set_kit(BOT_KITS[rng.randi() % BOT_KITS.size()] if kit_id == "" else kit_id)
	ability.cancel()
	ability.refill()
	_stagger = 0.0
	_lunge_left = 0.0
	health = MAX_HEALTH
	alive = true
	visible = true
	_see = false
	_last_seen = Vector3.INF
	_cover_at = Vector3.INF
	_cover_wait = 0.0
	_cover_cd = 0.0
	_flank_at = Vector3.INF
	for a in _hitboxes:
		a.set_deferred("collision_layer", Geo.HITBOX)
	_pick_goal()


## Hands it a given gun (預算戰: what it bought) in place of the random one spawn() gave it.
func arm(build: Dictionary) -> void:
	weapon = Weapon.new(build)
	if _model == null:
		return
	if _gun != null:
		_gun.queue_free()
	_gun = GunModels.build(weapon.build)
	_model.find_child("GunHand", true, false).add_child(_gun)


func set_level(l: int) -> void:
	level = clampi(l, BotLevel.EASY, BotLevel.HARD)
	_p = BotLevel.profile(level)


func set_kit(id: String) -> void:
	kit_id = Kit.valid(id)
	ability = Kit.make(kit_id, self)


## Where its abilities aim: from the eye, at its target if it has one in sight.
func ability_aim() -> Transform3D:
	var eye := _eye()
	if _see and target != null and is_instance_valid(target):
		var to := target.global_position + Vector3(0, 1.0, 0) - eye
		if to.length() > 0.5:
			return Transform3D(Basis.looking_at(to.normalized(), Vector3.UP), eye)
	return Transform3D(global_basis, eye)


## A shove it can't steer out of (a RAM charge), for `seconds`.
func lunge(v: Vector3, seconds: float) -> void:
	_lunge = v
	_lunge_left = seconds


## When to use the class ability (checked a few times a second).
func _use_ability() -> void:
	if ability == null or not ability.can_use() or passive:
		return
	if float(_p.ability) < 1.0 and rng.randf() > float(_p.ability):
		return
	var sees := _see and target != null and is_instance_valid(target)
	var d := global_position.distance_to(target.global_position) if sees else INF
	match kit_id:
		"decoy":
			if not sees and flat_speed() > 2.0 and rng.randf() < 0.04:
				ability.press()
			elif sees and hurt_within(1.0) and rng.randf() < 0.3:
				ability.press()
		"veil":
			if sees and d > 14.0 and (hurt_within(1.5) or rng.randf() < 0.05):
				ability.press()
		"bulwark":
			if sees and d > 8.0 and (health < 60.0 or weapon.is_reloading()) and rng.randf() < 0.5:
				ability.press()
		"ram":
			if sees and d < 14.0 and rng.randf() < 0.5:
				ability.press()
			elif sees and _p.punish and d < 22.0 and _target_reloading():
				ability.press()


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
	if frozen:
		velocity = Vector3(0, velocity.y - GRAVITY * delta, 0)
		move_and_slide()
		if _model != null:
			_model.pose(delta, velocity, is_on_floor())
		return
	if target != null and not is_instance_valid(target):
		target = null
		_see = false
	weapon.tick(delta)
	if ability != null:
		ability.tick(delta)
		_ability_think -= delta
		if _ability_think <= 0.0:
			_ability_think = 0.3
			_use_ability()
	_stagger = maxf(_stagger - delta, 0.0)
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
	# Reload early when nobody's in sight (簡單 waits until the magazine is empty).
	if not _see and float(_p.reload) > 0.0 and not weapon.is_reloading() \
			and weapon.ammo < int(weapon.stats.mag) * float(_p.reload):
		weapon.start_reload()
	if _p.cover:
		_think_cover(delta)
	var speed := SPEED * (0.55 if _slow > 0.0 else 1.0)
	var flat := Vector3.ZERO
	if _lunge_left > 0.0:
		_lunge_left -= delta
		velocity.x = _lunge.x
		velocity.z = _lunge.z
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if _model != null:
			_model.pose(delta, velocity, is_on_floor())
		return
	if _see and target != null:
		_reaction -= delta
		_face(target.global_position, delta, 9.0)
		if _cover_at != Vector3.INF:
			# Falling back to cover, still shooting.
			flat = _nav_move(delta, speed) if nav != null else _straight_to(_cover_at, speed)
			_face(target.global_position, delta, 9.0)
		else:
			flat = _fight_move(delta, speed)
		if _reaction <= 0.0 and not passive:
			_try_shoot()
	elif _cover_at != Vector3.INF and nav == null:
		flat = _straight_to(_cover_at, speed)
	elif nav != null:
		flat = _nav_move(delta, speed)
	else:
		var to_goal := _goal - global_position
		to_goal.y = 0
		_detour = maxf(_detour - delta, 0.0)
		if objective != Vector3.INF and _detour <= 0.0:
			to_goal = objective - global_position
			to_goal.y = 0
			if to_goal.length() < 0.8:
				to_goal = Vector3.ZERO
			# Walking into a wall on the way: go round by a random waypoint for a bit.
			_stuck = _stuck + delta if to_goal.length() > 1.5 and flat_speed() < 0.6 else 0.0
			if _stuck > 1.2:
				_stuck = 0.0
				_detour = 2.5
				_pick_goal()
		elif _last_seen != Vector3.INF:
			to_goal = _last_seen - global_position
			to_goal.y = 0
			if to_goal.length() < 1.5:
				_last_seen = Vector3.INF
		if objective != Vector3.INF and _detour <= 0.0:
			if to_goal.length() > 0.01:
				_face(global_position + to_goal, delta, 5.0)
				flat = to_goal.normalized() * speed * float(_p.roam)
		elif to_goal.length() < 1.2:
			_pick_goal()
		elif to_goal.length() > 0.01:
			_face(global_position + to_goal, delta, 5.0)
			flat = to_goal.normalized() * speed * float(_p.roam)
	velocity.x = lerpf(velocity.x, flat.x, 1.0 - exp(-8.0 * delta))
	velocity.z = lerpf(velocity.z, flat.z, 1.0 - exp(-8.0 * delta))
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if is_on_wall() and is_on_floor() and not _see and nav == null:
		velocity.y = 6.8
		if rng.randf() < 0.3:
			_pick_goal()
	if _model != null:
		var pitch := 0.0
		if _see and target != null and is_instance_valid(target):
			var to := target.global_position - global_position
			pitch = atan2(to.y, Vector2(to.x, to.z).length())
		_look_pitch = pitch
		_model.play_state(delta, velocity, anim_state())
		var marker := _model.get_node_or_null("Marker")
		if marker:
			marker.rotate_y(delta * 2.0)


## Walking the floor plan to where it wants to be: the bomb site, where it last saw
## someone, or a random spot. Re-plans every couple of seconds or when the goal moves.
func _nav_move(delta: float, speed: float) -> Vector3:
	if _last_seen != Vector3.INF and _at(_last_seen, 1.5):
		_last_seen = Vector3.INF
	if _flank_at != Vector3.INF:
		_flank_left -= delta
		if _flat_to(_flank_at) < 2.0 or _flank_left <= 0.0:
			_flank_at = Vector3.INF
	var dest := objective if objective != Vector3.INF else (_last_seen if _last_seen != Vector3.INF else _goal)
	if _flank_at != Vector3.INF and objective == Vector3.INF:
		dest = _flank_at
	if _cover_at != Vector3.INF:
		dest = _cover_at
	if objective == Vector3.INF and _last_seen == Vector3.INF and _flank_at == Vector3.INF and _cover_at == Vector3.INF \
			and _at(_goal, 1.5):
		_pick_goal()
		dest = _goal
	_path_t -= delta
	if _path_t <= 0.0 or _path_to.distance_to(dest) > 2.0:
		_path = nav.path(global_position, dest)
		_path_to = dest
		_path_t = 2.0 + rng.randf() * 0.5
		if _path.is_empty() and objective == Vector3.INF:
			_pick_goal()
	while not _path.is_empty() and _at(_path[0], 0.6 if _path.size() == 1 else 1.1):
		_path.pop_front()
	if _path.is_empty():
		return Vector3.ZERO
	var to := _path[0] - global_position
	to.y = 0.0
	_stuck = _stuck + delta if flat_speed() < 0.6 else 0.0
	if _stuck > 1.0:
		_stuck = 0.0
		_path_t = 0.0
		if is_on_floor():
			velocity.y = 6.8
	# 困難 walks with its gun on the corner it expects you round (where you were last seen);
	# the others look where they're going.
	if level == BotLevel.HARD and _last_seen != Vector3.INF and _flat_to(_last_seen) < 30.0 and not _see:
		_face(_last_seen, delta, 6.0)
	elif not _see:
		_face(global_position + to, delta, 6.0)
	return to.normalized() * speed * (0.95 if _cover_at != Vector3.INF else float(_p.roam))


## Where it moves in a fight (it is already facing the target). 簡單 mostly stands and
## walks in, 中等 strafes and hops and backs off when hurt, 困難 also holds its gun's best
## distance and closes in on someone reloading.
func _fight_move(delta: float, speed: float) -> Vector3:
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe = -_strafe if rng.randf() < 0.7 else _strafe
		# 困難 breaks rhythm: shorter, less even strafes.
		_strafe_left = rng.randf_range(0.25, 0.9) if level == BotLevel.HARD else rng.randf_range(0.4, 1.1)
		if is_on_floor() and rng.randf() < float(_p.hop):
			velocity.y = 6.5
	var flat := global_basis.x * _strafe * speed * float(_p.strafe)
	var d := global_position.distance_to(target.global_position)
	var fwd := -global_basis.z
	if _p.hold_range:
		var best := clampf(float(weapon.stats.range) * 0.45, 5.0, 26.0)
		if _p.punish and _target_reloading():
			best = 3.0
		if d > best * 1.3:
			flat += fwd * speed * 0.75
		elif d < best * 0.6:
			flat -= fwd * speed * 0.6
	elif float(_p.approach) > 0.0:
		if d > float(_p.approach):
			flat += fwd * speed * 0.5
	elif d > float(weapon.stats.range) * 0.8:
		flat += fwd * speed * 0.6
	if float(_p.retreat) > 0.0 and health < float(_p.retreat) and not _p.cover:
		flat -= fwd * speed * 0.6
	return flat


func _straight_to(p: Vector3, speed: float) -> Vector3:
	var to := p - global_position
	to.y = 0.0
	return to.normalized() * speed if to.length() > 0.3 else Vector3.ZERO


func _target_reloading() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var w = target.get("weapon")
	return w is Weapon and (w as Weapon).is_reloading()


## Nobody in sight: gunshots in earshot (中等, 困難) and the team's callouts (困難) give it
## somewhere to go.
func _listen() -> void:
	if _last_seen != Vector3.INF and BotLevel.now() - _seen_at < 1.0:
		return
	if float(_p.hearing) > 0.0:
		var noise := BotLevel.nearest_noise(global_position, team, float(_p.hearing))
		if noise != Vector3.INF:
			_last_seen = noise
			_seen_at = BotLevel.now()
			return
	if not _p.team or _last_seen != Vector3.INF:
		return
	var c := BotLevel.callout(team)
	if c.is_empty() or c.by == self:
		return
	_last_seen = c.at
	_seen_at = float(c.time)
	# A teammate is already fighting there: come at it from the side.
	var by = c.by
	if nav != null and _flank_at == Vector3.INF and by is Bot and is_instance_valid(by) and (by as Bot).alive \
			and (by as Bot).fighting():
		_flank_at = _flank_point((by as Bot).global_position, c.at)
		_flank_left = 8.0


## A spot to the side of the line from `from` (a teammate) to `at` (the enemy), on the
## floor plan, from which to come at it; INF if there is none.
func _flank_point(from: Vector3, at: Vector3) -> Vector3:
	var dir := at - from
	dir.y = 0.0
	if dir.length() < 1.0:
		return Vector3.INF
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	if side.dot(global_position - at) < 0.0:
		side = -side
	for off in [10.0, 7.0, 4.5]:
		for back in [3.0, 0.0]:
			var p: Vector3 = at + side * off - dir * back
			var c := nav.cell_of(p)
			if nav.walkable(c.x, c.y):
				return nav.centre(c.x, c.y, at.y)
	return Vector3.INF


## 困難: when hurt, low on ammo or caught reloading in a fight, fall back to the nearest
## spot out of the target's sight, reload there, then go back for them.
func _think_cover(delta: float) -> void:
	_cover_cd = maxf(_cover_cd - delta, 0.0)
	if _cover_at != Vector3.INF:
		if _flat_to(_cover_at) < 1.0:
			_cover_wait += delta
			if weapon.ammo < int(weapon.stats.mag):
				weapon.start_reload()
			if (_cover_wait > 1.0 and not weapon.is_reloading()) or _cover_wait > 4.0 or (_see and _cover_wait > 0.4):
				_cover_at = Vector3.INF
				_cover_wait = 0.0
				_cover_cd = 3.0
		else:
			_cover_left -= delta
			if _cover_left <= 0.0:
				_cover_at = Vector3.INF   # can't get there: fight on
				_cover_cd = 3.0
		return
	if _cover_cd > 0.0 or target == null or not is_instance_valid(target) or not (_see or hurt_within(1.0)):
		return
	var low_ammo := weapon.ammo <= int(weapon.stats.mag) * 0.25 or weapon.is_reloading()
	if not (health < float(_p.retreat) and hurt_within(3.0)) and not (low_ammo and _see):
		return
	_cover_cd = 2.0
	var spot := _find_cover()
	if spot == Vector3.INF:
		return
	_cover_at = spot
	_cover_wait = 0.0
	_cover_left = 4.0
	if weapon.ammo < int(weapon.stats.mag):
		weapon.start_reload()
	if ability != null and ability.can_use() and (kit_id == "veil" or kit_id == "bulwark"):
		ability.press()


## The best nearby spot the target can't see and it can walk straight to, or INF.
func _find_cover() -> Vector3:
	var space := get_world_3d().direct_space_state
	var threat := target.global_position + Vector3(0, 1.5, 0)
	var best := Vector3.INF
	var best_score := INF
	for i in 16:
		var a := TAU * i / 16.0
		var dir := Vector3(sin(a), 0, cos(a))
		for r in [3.0, 5.0, 7.5, 10.0]:
			var p: Vector3 = global_position + dir * r
			var walk := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), p + Vector3(0, 0.6, 0),
				Geo.WORLD | Geo.BODIES, exclusions())
			var straight := space.intersect_ray(walk).is_empty()
			if not straight and nav == null:
				break
			var floor_q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.8, 0), p + Vector3(0, -1.5, 0), Geo.WORLD)
			if space.intersect_ray(floor_q).is_empty():
				continue
			var look := PhysicsRayQueryParameters3D.create(threat, p + Vector3(0, 1.3, 0), Geo.WORLD, exclusions())
			if space.intersect_ray(look).is_empty():
				continue
			# Round a corner on the floor plan, if it's not far.
			var walk_len: float = r
			if not straight:
				var c := nav.cell_of(p)
				if not nav.walkable(c.x, c.y):
					continue
				var path := nav.path(global_position, p)
				if path.is_empty():
					continue
				walk_len = 0.0
				var from := global_position
				for q in path:
					walk_len += Vector2(q.x - from.x, q.z - from.z).length()
					from = q
				if walk_len > 16.0:
					continue
			var score: float = walk_len - 0.3 * p.distance_to(threat)
			if score < best_score:
				best_score = score
				best = p
	return best


## Within `r` of `p` across the floor, and on a plan with more than one floor (C10) on
## the same one as it (not right under a gallery it is heading up to).
func _at(p: Vector3, r: float) -> bool:
	return _flat_to(p) < r and (nav == null or not nav.layered() or absf(p.y - global_position.y) < 2.2)


func _flat_to(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _face(point: Vector3, delta: float, rate: float) -> void:
	var to := point - global_position
	to.y = 0
	if to.length() < 0.01:
		return
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-rate * delta))


func _eye() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)


## In a fight right now (sees a target).
func fighting() -> bool:
	return _see and target != null


## Shot at in the last `seconds`.
func hurt_within(seconds: float) -> bool:
	return Time.get_ticks_msec() / 1000.0 - _hurt_at < seconds


func flat_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## The nearest enemy combatant it can see, else the one it had.
func _pick_target() -> void:
	var eye := _eye()
	var options := []
	# Decoys look like anyone else to a bot: it can be fooled.
	for c in get_tree().get_nodes_in_group("combatants") + get_tree().get_nodes_in_group("decoys"):
		if c == self or not (c is Node3D) or not c.get("alive") or c.get("team") == null or int(c.team) == team:
			continue
		options.append([eye.distance_to((c as Node3D).global_position), c])
	if options.is_empty():
		return
	options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(options.size(), 4):
		var c: Node3D = options[i][1]
		if options[i][0] > SIGHT:
			break
		var q := PhysicsRayQueryParameters3D.create(eye, c.global_position + Vector3(0, 1.3, 0), Geo.WORLD, exclusions())
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty() and not Deploy.sight_blocked(eye, c.global_position + Vector3(0, 1.3, 0)):
			if c != target:
				target = c
				_see = false
			return
	if target == null or not target.get("alive"):
		target = options[0][1]


func _look_for_target() -> void:
	if target != null and not is_instance_valid(target):
		target = null
	_pick_target()
	if _last_seen != Vector3.INF and BotLevel.now() - _seen_at > float(_p.memory):
		_last_seen = Vector3.INF
	if target == null or not target.get("alive"):
		_see = false
		_listen()
		return
	var eye := _eye()
	var aim_at := target.global_position + Vector3(0, 1.3, 0)
	var d := eye.distance_to(aim_at)
	var was := _see
	_see = false
	if d > SIGHT:
		_listen()
		return
	var to := (aim_at - eye).normalized()
	var facing := (-global_basis.z).dot(to)
	if facing < float(_p.view) and d > float(_p.near) and not was:
		_listen()
		return
	var q := PhysicsRayQueryParameters3D.create(eye, aim_at, Geo.WORLD, exclusions())
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty() and not Deploy.sight_blocked(eye, aim_at):
		_see = true
		_last_seen = target.global_position
		_seen_at = BotLevel.now()
		if _p.team:
			BotLevel.call_out(team, _last_seen, self)
		if not was:
			_reaction = rng.randf_range(REACTION.x, REACTION.y)
	else:
		_listen()


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
	var error := 2.2 + float(target.flat_speed()) * 0.55 + (2.5 if target.get("move") == Player.Move.AIR else 0.0)
	var spread := maxf(float(weapon.stats.spread), error)
	var context := {"attacker": self, "name": display_name, "team": team, "exclude": exclusions(), "moves": []}
	var saved: float = weapon.stats.damage
	weapon.stats.damage = float(saved) * damage_mult
	var results := weapon.fire(self, eye, aim, spread, context)
	shot_count += 1
	weapon.stats.damage = saved
	var world := get_tree().current_scene
	var muzzle := _gun.to_global(_gun.get_meta("muzzle")) if _gun else eye
	PrintFx.muzzle(_gun, _gun.get_meta("muzzle"), weapon.klass, 1.6)
	var tos := PackedVector3Array()
	for r in results:
		PrintFx.tracer(world, muzzle, r.to, weapon.klass)
		tos.append(r.to)
		if not r.hit_body:
			PrintFx.impact(world, r.to, r.normal, weapon.klass, false)
	Sfx.shot(self, weapon.klass, weapon.stats.get("suppressed", false))
	shot_traced.emit(muzzle, tos)


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
	if e.has("mark"):
		marked = maxf(marked, float(e.mark))
	if e.has("stagger"):
		# Off balance: a beat before it can shoot straight again, and slower for a moment.
		_stagger = maxf(_stagger, float(e.stagger))
		_reaction = maxf(_reaction, float(e.stagger))
		_slow = maxf(_slow, float(e.stagger) * 0.6)
	_hurt_at = Time.get_ticks_msec() / 1000.0
	if _model != null and info.get("dir") is Vector3:
		_model.flinch(info.dir, clampf(float(info.get("damage", 20.0)) / 30.0, 0.3, 1.5))
	# Being shot turns it around (toward whoever did it).
	var by = info.get("attacker")
	if by is Node3D and is_instance_valid(by) and by != self and by.get("alive") and by.get("team") != null and int(by.team) != team:
		target = by
		_last_seen = (by as Node3D).global_position
		_seen_at = BotLevel.now()
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
	if ability != null:
		ability.cancel()
	health = 0.0
	for a in _hitboxes:
		a.set_deferred("collision_layer", 0)
	PrintFx.takedown(get_tree().current_scene, global_position, Faultprint.INFO_ENEMY)
	# The body stays where it fell, gone limp (CompetitorRig); the bot itself hides until
	# it spawns again with a new one.
	CompetitorRig.leave_corpse(_model, info.get("dir", Vector3.ZERO) if info.get("dir") is Vector3 else Vector3.ZERO,
		6.0, CompetitorRig.kill_force(info), velocity)
	_model = null
	_gun = null
	visible = false
	died.emit(self, info)


## How the third-person body should look right now (CompetitorRig.anim).
func anim_state() -> Array:
	var m := Player.Move.GROUND if is_on_floor() else Player.Move.AIR
	return CompetitorRig.anim(m, _look_pitch, 0.0, Vector3.ZERO, weapon, 0, shot_count, is_on_floor())
