class_name Weapon
extends RefCounted
## One gun in someone's hands: the Arsenal build, its finished stats, and the state that
## changes while it's used (rounds, reload, heat, fire mode, charge). Players and bots use
## the same class, so a bot's custom gun behaves exactly like yours.
##
##   var w := Weapon.new(build)
##   w.tick(delta)
##   if w.wants_fire(held, just_pressed, just_released): var shots := w.fire(shooter, origin, basis, spread)
##
## Damage goes to anything with take_hit(info) via its hitboxes (Area3D on Geo.HITBOX with
## meta "target" and "zone"). PvP damage is rescaled per frame (STK, damage_scale).

## HAIKAI tuned damage for monsters; players have 100 health. Each frame gets a PvP role:
## how many body hits its bare form needs to kill (a full shotgun blast counts as one).
## Parts still multiply damage as they did in HAIKAI, so every build keeps its character;
## only the baseline is set here. Heads take HEAD_MULT, so a 2-hit rifle kills with one.
const STK := {
	"revolver": 3, "service_pistol": 5, "heavy_pistol": 4, "machine_pistol": 7, "smg": 6, "pdw": 6,
	"carbine": 5, "ak": 4, "bullpup": 5, "battle_rifle": 3, "dmr": 3, "rifle": 2, "lever_action": 2,
	"lmg": 5, "anti_materiel": 1, "shotgun": 1, "double_barrel": 1, "auto_shotgun": 2, "sawed_off": 1,
	"nail_gun": 6, "crossbow": 2, "flamethrower": 14, "tesla": 4, "harpoon": 1, "railgun": 1,
	"duck_launcher": 1, "saw_launcher": 2, "bubble_gun": 18,
	"jump_shotgun": 2, "gyrojet": 4, "minigun": 9, "quad_barrel": 1, "punt_gun": 1, "pneumatic_lance": 1,
	"ricochet_smg": 7, "glass_revolver": 2, "tuning_fork": 5, "anchor_gun": 2,
	"vector_smg": 7, "scout_rifle": 2, "silent_rifle": 5,
}
## Rays a cone weapon (flamethrower) sends per shot.
const CONE_RAYS := 7
const HEAD_MULT := 2.0
const LEG_MULT := 0.8
const FALLOFF_MIN := 0.55
## Damage lost going through a thin wall (only guns with pen >= WALLBANG_PEN).
const WALLBANG_PEN := 40.0
const WALLBANG_MULT := 0.55
const WALL_MAX := 0.6
const CHARGE_TIME := 0.8
## Speed (m/s) at which "speed_bonus" pays out in full, and where it starts.
const SPEED_BONUS_FROM := 7.0
const SPEED_BONUS_FULL := 20.0

## Shooter-side effects (CHAOS parts, shared by players and bots; values from Arsenal):
##   recoil_push  m/s added to the shooter, straight back from the aim (shotgun jumps)
##   grapple      m/s pulling the shooter toward whatever the shot hit (world or body)
##   kill_refill  a kill fills the magazine;  kill_dash: a kill recharges the dash
##   leech        fraction of damage dealt that comes back as health
##   ghost        every Nth shot costs no round
##   ricochet     how many times a shot bounces off walls
##   air_bonus    damage multiplier while the shooter is off the ground
##   speed_bonus  extra damage fraction at full speed (scales from SPEED_BONUS_FROM)
##   long_bonus   damage multiplier at full range (grows with distance instead of falling)
##   headhunter   heads take 3x, everything else 0.75x
##   last_round   the magazine's last round deals this many times the damage
##   gamble       each shot deals 0.4x to 2.2x, at random
## CHAOS 2 (see Arsenal's "CHAOS 2" parts; the player side is in Player):
##   mark         a hit tags the target for this many seconds (seen through walls)
##   spool        the rate climbs from SPOOL_FROM to 1 + spool over SPOOL_TIME of firing
##   first_shot   the first shot after FIRST_SHOT_WAIT seconds of quiet deals this many times
##   low_hp       damage multiplier while the shooter is under LOW_HP health
##   streak       +this per hit in a row (up to STREAK_MAX); a miss resets it
##   kill_heal    health back on a kill;  kill_explode: the victim blows up (radius)
##   hit_dash     dash charge back per hit;  kick_refill: an air hit gives a wall kick back
##   rush         seconds of extra speed per hit (Player.RUSH)
##   homing       a shot bends to an enemy in sight within this many degrees of the aim
##   echo         each shot repeats ECHO_DELAY later at this much damage, free
##   heat_bonus   damage +this at full heat
##   glass        damage multiplier, and the same multiplier on damage you take
##   anonymous    kills by this gun show no name or model, and can't be copied
const SPOOL_FROM := 0.6
const SPOOL_TIME := 1.2
const FIRST_SHOT_WAIT := 2.0
const LOW_HP := 40.0
const STREAK_MAX := 5
const ECHO_DELAY := 0.2
const KILL_BLAST := 45.0
const MAG_BLAST := 40.0
var shots_fired := 0
## Time this gun has existed (ticks), and when it last fired, for spool and first_shot.
var clock := 0.0
var last_shot := -100.0
var spool_t := 0.0
var streak := 0

var build: Dictionary
var stats: Dictionary
var name := ""
var ammo := 0
var reserve := 0
var reload_left := 0.0
var cooldown := 0.0
var burst_left := 0
var heat := 0.0
var overheated := false
var mode_i := 0
var charge := 0.0
var charging := false
var klass := "rapid"
## A short id of this exact build (team matches score kills by how fresh a version is).
var version := 0


func _init(new_build: Dictionary, gun_name := "") -> void:
	set_build(new_build, gun_name)


func set_build(new_build: Dictionary, gun_name := "") -> void:
	build = Arsenal.clean(new_build)
	stats = Arsenal.stats(build)
	name = gun_name if gun_name != "" else GunNames.auto_name(build, stats)
	ammo = int(stats.mag)
	reserve = int(stats.reserve) * 2
	reload_left = 0.0
	cooldown = 0.0
	burst_left = 0
	heat = 0.0
	overheated = false
	mode_i = 0
	charge = 0.0
	charging = false
	klass = PrintFx.weapon_class(stats)
	version = version_of(build)


static func version_of(b: Dictionary) -> int:
	var c := Arsenal.clean(b)
	return absi(hash(var_to_str([c.frame, c.parts, c.tune])))


## Multiplier from HAIKAI's damage to PvP damage for a frame (from STK and the bare frame).
static func damage_scale(frame_id: String) -> float:
	var f := Arsenal.frame(frame_id)
	if f.is_empty():
		return 1.0
	var bare := float(f.damage) * int(f.get("pellets", 1))
	var stk := int(STK.get(frame_id, 4))
	# A touch over the exact amount so rounding never adds a shot.
	return (100.0 / stk) * 1.01 / maxf(bare, 0.1)


## Damage per projectile (per pellet) in PvP terms, after parts.
static func pvp_damage(s: Dictionary) -> float:
	return float(s.damage) * damage_scale(str(s.frame))


## Damage of one full shot (all pellets, or a whole cone, landing).
static func shot_damage(s: Dictionary) -> float:
	return pvp_damage(s) * int(s.pellets)


func mode() -> String:
	return stats.modes[mode_i % stats.modes.size()]


func cycle_mode() -> void:
	mode_i = (mode_i + 1) % stats.modes.size()


func is_reloading() -> bool:
	return reload_left > 0.0


func reload_time() -> float:
	return float(stats.reload) * (Arsenal.EMPTY_RELOAD if ammo == 0 else 1.0)


func start_reload() -> bool:
	if is_reloading() or ammo >= int(stats.mag) or reserve <= 0:
		return false
	reload_left = reload_time()
	burst_left = 0
	charging = false
	charge = 0.0
	return true


func tick(delta: float) -> void:
	clock += delta
	cooldown = maxf(cooldown - delta, 0.0)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			var take := mini(int(stats.mag) - ammo, reserve)
			ammo += take
			reserve -= take
	var cooling := float(stats.cooling)
	heat = maxf(heat - cooling * delta, 0.0)
	if overheated and heat <= 0.3:
		overheated = false
	if charging:
		charge = minf(charge + delta / CHARGE_TIME, 1.0)


## Decides whether a shot leaves the gun this frame, given the trigger.
func wants_fire(held: bool, just: bool, released: bool) -> bool:
	if is_reloading() or overheated:
		return false
	if ammo <= 0:
		if just:
			start_reload()
		return false
	if stats.kind == "charge":
		if held and not charging and cooldown <= 0.0:
			charging = true
			charge = 0.0
		if released and charging:
			charging = false
			return true
		return false
	if cooldown > 0.0:
		return false
	match mode():
		"auto":
			return held
		"burst":
			if burst_left > 0:
				return true
			if just:
				burst_left = Arsenal.BURST
				return true
			return false
		_:
			return just


## The time between shots at the current mode.
func interval() -> float:
	var rate := float(stats.rate)
	if stats.effects.has("spool"):
		rate *= lerpf(SPOOL_FROM, 1.0 + float(stats.effects.spool), clampf(spool_t / SPOOL_TIME, 0.0, 1.0))
	return 1.0 / maxf(rate, 0.1)


## Moves `count` rounds from the reserve into the magazine (feeds, refills); returns how many.
func feed(count: int) -> int:
	var take := mini(mini(count, int(stats.mag) - ammo), reserve)
	if take <= 0:
		return 0
	ammo += take
	reserve -= take
	if is_reloading() and ammo >= int(stats.mag):
		reload_left = 0.0
	return take


## Fires one shot (or one double) from `origin` along -basis.z with a random cone of
## `spread_deg`. Returns a list of shot results for effects:
##   [{"from", "to", "normal", "hit_body", "target", "kill"}...]
func fire(shooter: Node3D, origin: Vector3, aim: Basis, spread_deg: float, context: Dictionary) -> Array:
	var rounds := 2 if mode() == "double" and ammo >= 2 else 1
	var fx: Dictionary = stats.effects
	var quiet := clock - last_shot
	spool_t = spool_t + quiet if quiet < 0.35 else 0.0
	context.first = quiet >= FIRST_SHOT_WAIT
	last_shot = clock
	context.streak = streak
	if "health" in shooter:
		context.low_hp = float(shooter.health) < LOW_HP
	if fx.has("homing") and stats.kind in ["hitscan", "charge", "bounce"]:
		aim = _home(shooter, origin, aim, float(fx.homing), context)
	context.last_round = ammo <= rounds
	context.from_safe = SafeZone.is_safe(origin, int(context.get("team", -1)))
	ammo -= rounds
	shots_fired += 1
	if fx.has("ghost") and shots_fired % maxi(int(fx.ghost), 2) == 0:
		ammo += rounds
	if shooter is CharacterBody3D:
		var body := shooter as CharacterBody3D
		context.air = not body.is_on_floor()
		context.speed = Vector2(body.velocity.x, body.velocity.z).length()
	cooldown = interval()
	if mode() == "burst":
		burst_left = maxi(burst_left - 1, 0)
		if burst_left == 0:
			cooldown = interval() * 3.0
	heat += float(stats.heat) * rounds
	if heat >= 1.0:
		overheated = true
	var power := 1.0
	if stats.kind == "charge":
		power = 0.35 + 0.65 * charge
		charge = 0.0
	var results := []
	var pellets := int(stats.pellets) * rounds
	match stats.kind:
		"cone":
			for i in CONE_RAYS:
				results.append(_ray(shooter, origin, _spread_dir(aim, 10.0), minf(float(stats.range), 12.0), power / CONE_RAYS, context))
		"lob":
			_lob(shooter, origin, _spread_dir(aim, spread_deg), context)
		_:
			for i in pellets:
				var spread := spread_deg if pellets == 1 else maxf(spread_deg, float(stats.spread))
				results.append(_ray(shooter, origin, _spread_dir(aim, spread), float(stats.range) * 1.4, power, context))
	_after_shot(shooter, aim, results)
	if fx.has("echo") and not context.get("echo", false):
		_schedule_echo(shooter, origin, aim, spread_deg, context)
	return results


## The shot again ECHO_DELAY later from the same spot, at fx.echo damage, costing nothing.
func _schedule_echo(shooter: Node3D, origin: Vector3, aim: Basis, spread_deg: float, context: Dictionary) -> void:
	var echo := context.duplicate()
	echo.echo = true
	echo.exclude = (context.get("exclude", []) as Array).duplicate()
	shooter.get_tree().create_timer(ECHO_DELAY, false, true).timeout.connect(func() -> void:
		if not is_instance_valid(shooter) or not shooter.is_inside_tree() or not shooter.get("alive"):
			return
		var power := float(stats.effects.get("echo", 0.5))
		var world := shooter.get_tree().current_scene
		for i in maxi(int(stats.pellets), 1):
			var r := _ray(shooter, origin, _spread_dir(aim, spread_deg), float(stats.range) * 1.4, power, echo)
			PrintFx.tracer(world, origin + (r.to - origin).normalized() * 0.6, r.to, klass)
			if r.has("target") and r.target != shooter and shooter.has_signal("hit_confirmed") and float(r.get("damage", 0.0)) > 0.0:
				shooter.hit_confirmed.emit({"zone": r.get("zone", "body"), "damage": r.damage, "target": r.target, "at": r.to}, r.get("kill", false)))


## Bends `aim` toward the nearest enemy in sight within `degrees` of it.
func _home(shooter: Node3D, origin: Vector3, aim: Basis, degrees: float, context: Dictionary) -> Basis:
	var forward := -aim.z
	var best: Node3D = null
	var best_angle := deg_to_rad(degrees)
	var best_point := Vector3.ZERO
	for t in shooter.get_tree().get_nodes_in_group("hittable"):
		if t == shooter or not (t is Node3D) or not t.get("alive") or t.get("team") == null:
			continue
		if int(t.team) == int(context.get("team", -1)):
			continue
		var point := (t as Node3D).global_position + Vector3(0, 1.15, 0)
		var angle := forward.angle_to((point - origin).normalized())
		if angle >= best_angle:
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, point, Geo.WORLD, context.get("exclude", []))
		if not shooter.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		best = t
		best_angle = angle
		best_point = point
	if best == null:
		return aim
	return Basis.looking_at((best_point - origin).normalized(), Vector3.UP)


## What the shot does to the one who fired it (see the shooter-side effects above).
func _after_shot(shooter: Node3D, aim: Basis, results: Array) -> void:
	var fx: Dictionary = stats.effects
	var body := shooter as CharacterBody3D
	if body and fx.has("recoil_push"):
		body.velocity += aim.z * float(fx.recoil_push)
	if body and fx.has("grapple"):
		for r in results:
			var to: Vector3 = r.to
			if r.get("hit_body", false) or to.distance_to(r.from) < float(stats.range) * 1.39:
				body.velocity += (to - body.global_position).normalized() * float(fx.grapple) + Vector3(0, 1.5, 0)
				break
	var killed := false
	var dealt := 0.0
	var hits := 0
	for r in results:
		killed = killed or r.get("kill", false)
		if r.get("target") != shooter:
			dealt += float(r.get("damage", 0.0))
			if float(r.get("damage", 0.0)) > 0.0:
				hits += 1
	streak = mini(streak + 1, STREAK_MAX) if hits > 0 else 0
	if hits > 0:
		if fx.has("hit_dash") and shooter.has_method("add_dash"):
			shooter.add_dash(float(fx.hit_dash) * hits)
		if fx.has("rush") and shooter.has_method("rush"):
			shooter.rush(float(fx.rush))
		if fx.get("kick_refill", false) and shooter.has_method("air_refill"):
			shooter.air_refill()
	if killed and fx.has("kill_heal") and "health" in shooter and shooter.get("alive"):
		shooter.health = minf(float(shooter.health) + float(fx.kill_heal), 100.0)
	if killed and fx.get("kill_refill", false):
		ammo = maxi(ammo, int(stats.mag))
	if killed and fx.get("kill_dash", false) and shooter.has_method("refill_dash"):
		shooter.refill_dash()
	if fx.has("leech") and dealt > 0.0 and "health" in shooter and shooter.get("alive"):
		shooter.health = minf(float(shooter.health) + dealt * float(fx.leech), 100.0)


static func _spread_dir(aim: Basis, deg: float) -> Vector3:
	var forward := -aim.z
	if deg <= 0.0:
		return forward
	# Uniform in a cone: random angle up to deg, biased toward the centre a little.
	var a := deg_to_rad(deg) * sqrt(randf())
	var roll := randf() * TAU
	var off := aim.x * cos(roll) + aim.y * sin(roll)
	return (forward * cos(a) + off * sin(a)).normalized()


func _query(shooter: Node3D, from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, Geo.WORLD | Geo.HITBOX, exclude)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	return shooter.get_world_3d().direct_space_state.intersect_ray(q)


## One ray of a shot (C7: and whatever loose thing it passes gets knocked, PhysicsFx).
func _ray(shooter: Node3D, origin: Vector3, dir: Vector3, reach: float, power: float, context: Dictionary) -> Dictionary:
	var result := _trace(shooter, origin, dir, reach, power, context)
	PhysicsFx.shot(shooter, origin, result.to, dir, float(stats.damage) * power / 15.0)
	return result


func _trace(shooter: Node3D, origin: Vector3, dir: Vector3, reach: float, power: float, context: Dictionary) -> Dictionary:
	# A copy: what one ray passes through must not hide the target from the next pellet (or the echo).
	var exclude: Array = (context.get("exclude", []) as Array).duplicate()
	var result := {"from": origin, "to": origin + dir * reach, "normal": -dir, "hit_body": false}
	var from := origin
	var through_wall := false
	var bounces := 1 if stats.kind == "bounce" else 0
	bounces += int(stats.effects.get("ricochet", 0))
	var hit_targets := []
	var travelled := 0.0
	for step in 8:
		var hit := _query(shooter, from, from + dir * maxf(reach - travelled, 0.1), exclude)
		if hit.is_empty():
			return result
		travelled += from.distance_to(hit.position)
		result.to = hit.position
		result.normal = hit.normal
		var col: Object = hit.collider
		if col is Area3D and col.has_meta("target"):
			var target: Node = col.get_meta("target")
			exclude.append(col.get_rid())
			if target in hit_targets:
				from = hit.position + dir * 0.01
				continue
			hit_targets.append(target)
			var info := _hit_info(origin, hit.position, dir, str(col.get_meta("zone", "body")), power, context)
			info.through_wall = through_wall
			if through_wall:
				info.damage *= WALLBANG_MULT
			if target.has_method("take_hit"):
				var killed: bool = target.take_hit(info)
				result.kill = result.get("kill", false) or killed
				if not info.get("blocked", false):
					if stats.effects.has("mark") and "marked" in target:
						target.marked = maxf(float(target.marked), float(stats.effects.mark))
					if killed and stats.effects.has("kill_explode"):
						blast(shooter, hit.position, float(stats.effects.kill_explode), KILL_BLAST, context)
			result.hit_body = true
			result.target = target
			result.zone = info.zone
			result.damage = 0.0 if info.get("blocked", false) else info.damage
			if stats.effects.has("chain"):
				_chain(shooter, target, hit.position, info, int(stats.effects.chain), context)
			if stats.effects.has("explode"):
				_explode(shooter, hit.position, float(stats.effects.explode), context)
			if stats.effects.get("pierce", false):
				from = hit.position + dir * 0.01
				continue
			return result
		# World. Bouncing shots reflect once; strong rounds go through thin walls.
		if stats.effects.has("explode"):
			_explode(shooter, hit.position, float(stats.effects.explode), context)
			return result
		if bounces > 0:
			bounces -= 1
			dir = dir.bounce(hit.normal).normalized()
			from = hit.position + hit.normal * 0.02
			continue
		if not through_wall and float(stats.pen) >= WALLBANG_PEN and _thin_wall(shooter, hit, dir):
			through_wall = true
			exclude.append(hit.rid)
			from = hit.position + dir * 0.02
			continue
		return result
	return result


## True when the wall hit by `hit` is at most WALL_MAX thick along `dir`.
func _thin_wall(shooter: Node3D, hit: Dictionary, dir: Vector3) -> bool:
	var back := _query(shooter, hit.position + dir * WALL_MAX, hit.position, [])
	return not back.is_empty() and back.collider == hit.collider


func _hit_info(origin: Vector3, point: Vector3, dir: Vector3, zone: String, power: float, context: Dictionary) -> Dictionary:
	var dist := origin.distance_to(point)
	var dmg := pvp_damage(stats) * power
	var falloff := float(stats.falloff)
	var reach := float(stats.range)
	if dist > falloff and not stats.effects.has("long_bonus"):
		dmg *= lerpf(1.0, FALLOFF_MIN, clampf((dist - falloff) / maxf(reach - falloff, 1.0), 0.0, 1.0))
	var fx: Dictionary = stats.effects
	if fx.has("long_bonus"):
		dmg *= lerpf(1.0, float(fx.long_bonus), clampf(dist / maxf(reach, 1.0), 0.0, 1.0))
	if fx.has("air_bonus") and context.get("air", false):
		dmg *= float(fx.air_bonus)
	if fx.has("speed_bonus"):
		var t := clampf((float(context.get("speed", 0.0)) - SPEED_BONUS_FROM) / (SPEED_BONUS_FULL - SPEED_BONUS_FROM), 0.0, 1.0)
		dmg *= 1.0 + float(fx.speed_bonus) * t
	if fx.has("last_round") and context.get("last_round", false):
		dmg *= float(fx.last_round)
	if fx.get("gamble", false):
		dmg *= randf_range(0.4, 2.2)
	if fx.has("first_shot") and context.get("first", false):
		dmg *= float(fx.first_shot)
	if fx.has("low_hp") and context.get("low_hp", false):
		dmg *= float(fx.low_hp)
	if fx.has("streak"):
		dmg *= 1.0 + float(fx.streak) * int(context.get("streak", 0))
	if fx.has("heat_bonus"):
		dmg *= 1.0 + float(fx.heat_bonus) * clampf(heat, 0.0, 1.0)
	if fx.has("glass"):
		dmg *= float(fx.glass)
	var head := HEAD_MULT
	if fx.get("headhunter", false):
		head = 3.0
		dmg *= 0.75
		if zone == "head":
			dmg /= 0.75
	match zone:
		"head":
			dmg *= head
		"legs":
			dmg *= LEG_MULT
	var anonymous: bool = fx.get("anonymous", false)
	return {
		"damage": dmg, "zone": zone, "distance": dist, "point": point, "dir": dir,
		"attacker": context.get("attacker"), "attacker_name": context.get("name", "?"),
		"team": context.get("team", -1), "gun_name": "？？？" if anonymous else name,
		"build": {} if anonymous else build.duplicate(true),
		"effects": stats.effects, "moves": context.get("moves", []), "through_wall": false,
		"from_safe": context.get("from_safe", false), "version": version,
	}


func _chain(shooter: Node3D, from_target: Node, point: Vector3, info: Dictionary, count: int, context: Dictionary) -> void:
	var points := [point]
	var done := [from_target]
	var last := point
	for i in count:
		var best: Node3D = null
		var best_d := 7.0
		for t in shooter.get_tree().get_nodes_in_group("hittable"):
			if t in done or t == context.get("attacker") or not (t is Node3D):
				continue
			var d := (t as Node3D).global_position.distance_to(last)
			if d < best_d:
				best_d = d
				best = t
		if best == null:
			break
		done.append(best)
		var p := best.global_position + Vector3(0, 1.1, 0)
		points.append(p)
		last = p
		var chained := info.duplicate()
		chained.damage = info.damage * 0.5
		chained.zone = "body"
		chained.chained = true
		best.take_hit(chained)
	if points.size() > 1:
		PrintFx.zigzag(shooter.get_tree().current_scene, points)


func _explode(shooter: Node3D, at: Vector3, radius: float, context: Dictionary) -> void:
	PrintFx.explosion(shooter.get_tree().current_scene, at, radius)
	Deploy.blow(at, radius)
	for t in shooter.get_tree().get_nodes_in_group("hittable"):
		if not (t is Node3D):
			continue
		var d := (t as Node3D).global_position.distance_to(at)
		if d > radius + 0.5:
			continue
		var info := _hit_info(at, at, ((t as Node3D).global_position - at).normalized(), "body", 1.0, context)
		info.damage = pvp_damage(stats) * clampf(1.0 - d / (radius + 0.5), 0.2, 1.0)
		if t == context.get("attacker"):
			info.damage *= 0.4  # rocket jumping should hurt, a bit
			info.self_hit = true
		t.take_hit(info)


## A blast of fixed `damage` (falling off to a fifth at the edge) at `at`, from this gun.
func blast(shooter: Node3D, at: Vector3, radius: float, damage: float, context: Dictionary) -> void:
	PrintFx.explosion(shooter.get_tree().current_scene, at, radius)
	Deploy.blow(at, radius)
	for t in shooter.get_tree().get_nodes_in_group("hittable"):
		if not (t is Node3D) or not t.get("alive"):
			continue
		var d := (t as Node3D).global_position.distance_to(at)
		if d > radius + 0.5:
			continue
		var info := _hit_info(at, at, ((t as Node3D).global_position - at).normalized(), "body", 1.0, context)
		info.damage = damage * clampf(1.0 - d / (radius + 0.5), 0.2, 1.0)
		info.blast = true
		if t == context.get("attacker"):
			info.damage *= 0.4
			info.self_hit = true
		t.take_hit(info)


## The bomb magazine: the old magazine thrown ahead, blowing up where it lands.
func throw_mag(shooter: Node3D, origin: Vector3, dir: Vector3, context: Dictionary) -> void:
	var shell := Lobbed.new()
	shell.weapon = self
	shell.shooter = shooter
	shell.context = context
	shell.blast_radius = float(stats.effects.get("mag_bomb", 3.0))
	shell.velocity = dir * 15.0 + Vector3(0, 3.0, 0)
	shooter.get_tree().current_scene.add_child(shell)
	shell.global_position = origin


func _lob(shooter: Node3D, origin: Vector3, dir: Vector3, context: Dictionary) -> void:
	var shell := Lobbed.new()
	shell.weapon = self
	shell.shooter = shooter
	shell.context = context
	shell.velocity = dir * clampf(float(stats.velocity) * 0.06, 14.0, 34.0) + Vector3(0, 2.0, 0)
	shooter.get_tree().current_scene.add_child(shell)
	shell.global_position = origin


## A lobbed round (grenade, duck): flies on a ballistic arc and blows up on contact.
class Lobbed:
	extends MeshInstance3D
	var weapon: Weapon
	var shooter: Node3D
	var context: Dictionary
	var velocity := Vector3.ZERO
	var life := 4.0
	## A thrown magazine (throw_mag) blows up with a fixed blast instead of the gun's.
	var blast_radius := 0.0

	func _ready() -> void:
		mesh = LowPoly.blob(0.09, Vector3(1, 1, 1.4), 0)
		material_override = Faultprint.surface(Faultprint.YELLOW, {"slip": null})

	func _physics_process(delta: float) -> void:
		life -= delta
		var next := global_position + velocity * delta
		velocity.y -= 18.0 * delta
		var q := PhysicsRayQueryParameters3D.create(global_position, next, Geo.WORLD | Geo.HITBOX, context.get("exclude", []))
		q.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() or life <= 0.0:
			var at: Vector3 = hit.position if not hit.is_empty() else global_position
			if blast_radius > 0.0:
				weapon.blast(shooter, at, blast_radius, Weapon.MAG_BLAST, context)
			else:
				weapon._explode(shooter, at, float(weapon.stats.effects.get("explode", 3.0)), context)
			queue_free()
			return
		global_position = next
		if velocity.length() > 0.1 and absf(velocity.normalized().y) < 0.98:
			look_at(next + velocity, Vector3.UP)
