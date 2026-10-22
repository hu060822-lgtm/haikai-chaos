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
	return 1.0 / maxf(float(stats.rate), 0.1)


## Fires one shot (or one double) from `origin` along -basis.z with a random cone of
## `spread_deg`. Returns a list of shot results for effects:
##   [{"from", "to", "normal", "hit_body", "target", "kill"}...]
func fire(shooter: Node3D, origin: Vector3, aim: Basis, spread_deg: float, context: Dictionary) -> Array:
	var rounds := 2 if mode() == "double" and ammo >= 2 else 1
	ammo -= rounds
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
	return results


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


func _ray(shooter: Node3D, origin: Vector3, dir: Vector3, reach: float, power: float, context: Dictionary) -> Dictionary:
	var exclude: Array = context.get("exclude", [])
	var result := {"from": origin, "to": origin + dir * reach, "normal": -dir, "hit_body": false}
	var from := origin
	var through_wall := false
	var bounced := false
	var hit_targets := []
	var travelled := 0.0
	for step in 6:
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
			result.hit_body = true
			result.target = target
			result.zone = info.zone
			result.damage = info.damage
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
		if stats.kind == "bounce" and not bounced:
			bounced = true
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
	if dist > falloff:
		dmg *= lerpf(1.0, FALLOFF_MIN, clampf((dist - falloff) / maxf(reach - falloff, 1.0), 0.0, 1.0))
	match zone:
		"head":
			dmg *= HEAD_MULT
		"legs":
			dmg *= LEG_MULT
	return {
		"damage": dmg, "zone": zone, "distance": dist, "point": point, "dir": dir,
		"attacker": context.get("attacker"), "attacker_name": context.get("name", "?"),
		"team": context.get("team", -1), "gun_name": name, "build": build.duplicate(true),
		"effects": stats.effects, "moves": context.get("moves", []), "through_wall": false,
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
		best.take_hit(chained)
	if points.size() > 1:
		PrintFx.zigzag(shooter.get_tree().current_scene, points)


func _explode(shooter: Node3D, at: Vector3, radius: float, context: Dictionary) -> void:
	PrintFx.explosion(shooter.get_tree().current_scene, at, radius)
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
			weapon._explode(shooter, at, float(weapon.stats.effects.get("explode", 3.0)), context)
			queue_free()
			return
		global_position = next
		if velocity.length() > 0.1 and absf(velocity.normalized().y) < 0.98:
			look_at(next + velocity, Vector3.UP)
