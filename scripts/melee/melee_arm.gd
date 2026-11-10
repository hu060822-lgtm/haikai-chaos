class_name MeleeArm
extends RefCounted
## The melee weapon a Player or Bot carries (C13, see Melee). The user calls press() when
## the melee key goes down (bots when someone is close) and tick(delta) every physics tick.
## A swing winds up for the weapon's `windup`, then lands: the nearest enemy in front of
## you within reach (a short cone around where you look, so a hit on someone right next to
## you or a bit below the crosshair still counts; walls stop it), or else the wall, door,
## cover or shield wall the swing meets. Then `recover` seconds before the next one.
##
## Like a shot, only this machine (the swinger's) works out the hit: take_hit on the target,
## which in a match goes to the host's judge (HitJudge: `melee` in the wire caps it at
## Melee.max_damage, and the victim has to be within reach of the swinger).

enum State { IDLE, WINDUP, RECOVER }

var user: Node3D
var id := Melee.DEFAULT
var state := State.IDLE
var t := 0.0
## The last swing's result, for the HUD and tests: the node it hit (or null), and whether
## it was a backstab.
var last_target: Node = null
var last_backstab := false
var swings := 0


func _init(who: Node3D = null, weapon_id := Melee.DEFAULT) -> void:
	user = who
	id = Melee.valid(weapon_id)


func info() -> Dictionary:
	return Melee.info(id)


func ready() -> bool:
	return state == State.IDLE


func busy() -> bool:
	return state != State.IDLE


func _alive() -> bool:
	return user != null and is_instance_valid(user) and bool(user.get("alive"))


func press() -> bool:
	if state != State.IDLE or not _alive():
		return false
	var i := info()
	state = State.WINDUP
	t = float(i.windup)
	swings += 1
	Sfx.play(user, "melee_swing", -8.0, 30.0)
	if float(i.lunge) > 0.0 and user.has_method("launch"):
		var fwd := -_aim().basis.z
		var flat := Vector3(fwd.x, 0, fwd.z).normalized()
		user.launch(flat * float(i.lunge) + Vector3(0, 1.5, 0))
	if user is Player:
		(user as Player).view.swing(id, float(i.windup) + float(i.recover))
	Deploy.fx(user, "melee", {"id": id})
	if t <= 0.0:
		_land()
	return true


func tick(delta: float) -> void:
	if state == State.IDLE:
		return
	t -= delta
	if t > 0.0:
		return
	if state == State.WINDUP:
		_land()
	else:
		state = State.IDLE
		t = 0.0


func cancel() -> void:
	state = State.IDLE
	t = 0.0


func _aim() -> Transform3D:
	if user.has_method("ability_aim"):
		return user.ability_aim()
	return Transform3D(user.global_basis, user.global_position + Vector3(0, 1.5, 0))


func _land() -> void:
	state = State.RECOVER
	t = float(info().recover)
	last_target = null
	last_backstab = false
	if not _alive():
		return
	var aim := _aim()
	var eye := aim.origin
	var fwd := -aim.basis.z
	var space := user.get_world_3d().direct_space_state
	var exclude: Array = user.exclusions() if user.has_method("exclusions") else []
	var hit := find_target(space, eye, fwd, exclude)
	var reach := Melee.reach(id)
	# What the swing meets along the line, if it's nearer than the person.
	var q := PhysicsRayQueryParameters3D.create(eye, eye + fwd * reach, Geo.WORLD | Geo.HITBOX, exclude)
	q.collide_with_areas = true
	var wall := space.intersect_ray(q)
	var wall_d := eye.distance_to(wall.position) if not wall.is_empty() else INF
	if not hit.is_empty() and float(hit.d) <= wall_d + 0.3:
		_strike(hit.node, hit.at, fwd)
		return
	if wall.is_empty():
		return
	var col: Object = wall.get("collider")
	var thing: Object = col.get_meta("target") if col is Area3D and (col as Area3D).has_meta("target") else col
	if thing is Node and (thing as Node).is_in_group("combatants"):
		_strike(thing as Node3D, wall.position, fwd)
		return
	_structure(thing, wall.position, wall.normal)


## The enemy this swing reaches from `eye` looking `fwd`: {node, at, d}, or {}.
func find_target(space: PhysicsDirectSpaceState3D, eye: Vector3, fwd: Vector3, exclude: Array) -> Dictionary:
	var reach := Melee.reach(id)
	var best := {}
	var my_team := int(user.get("team"))
	for tg in user.get_tree().get_nodes_in_group("hittable"):
		if tg == user or not (tg is Node3D) or not tg.get("alive") or not (tg as Node3D).is_visible_in_tree():
			continue
		if tg.get("team") != null and int(tg.get("team")) == my_team and tg.is_in_group("combatants"):
			continue
		var base := (tg as Node3D).global_position
		var span := [0.0] if tg is Grenade else [0.3, 0.9, 1.35, 1.65]
		for h in span:
			var p: Vector3 = base + Vector3(0, h, 0)
			var to := p - eye
			var along := to.dot(fwd)
			if along < -0.2 or along > reach:
				continue
			var off := (to - fwd * along).length()
			# Close in, the swing covers a wide arc; further out it narrows to the line.
			if off > Melee.BODY + 0.35 + maxf(1.2 - along, 0.0) * 0.5:
				continue
			if to.length() > 0.3 and to.normalized().dot(fwd) < Melee.CONE - 0.35 and along > 1.2:
				continue
			if not best.is_empty() and along >= float(best.d):
				continue
			var los := PhysicsRayQueryParameters3D.create(eye, p, Geo.WORLD, exclude)
			if not space.intersect_ray(los).is_empty():
				continue
			best = {"node": tg, "at": p, "d": maxf(along, 0.0)}
	return best


func _strike(tg: Node3D, at: Vector3, fwd: Vector3) -> void:
	var i := info()
	var speed := (user.get("velocity") as Vector3).length() if user.get("velocity") is Vector3 else 0.0
	var dmg := Melee.damage_at(id, speed)
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	if float(i.backstab) > 0.0 and tg.is_in_group("combatants"):
		var theirs := -tg.global_basis.z
		theirs.y = 0.0
		if theirs.length() > 0.1 and theirs.normalized().dot(flat) > Melee.BEHIND:
			dmg = float(i.backstab)
			last_backstab = true
	if user is Bot:
		dmg *= float(user.get("damage_mult"))
	var hit := {
		"damage": dmg, "zone": "body", "distance": user.global_position.distance_to(tg.global_position), "point": at,
		"dir": flat if flat.length() > 0.1 else fwd, "attacker": user, "attacker_name": str(user.get("display_name")),
		"team": int(user.get("team")), "gun_name": str(i.name), "build": {}, "effects": (i.effects as Dictionary).duplicate(),
		"moves": ["近戰"] + (["背刺"] if last_backstab else []), "through_wall": false, "blast": false, "melee": id,
		"from_safe": false, "version": 0,
	}
	last_target = tg
	var killed: bool = tg.take_hit(hit)
	Sfx.play(user, "melee_hit" if not last_backstab else "melee_stab", -4.0, 40.0)
	if user.has_signal("hit_confirmed") and tg.is_in_group("combatants"):
		user.hit_confirmed.emit({"zone": "body", "damage": dmg, "target": tg, "at": at}, killed)
	if user is Player:
		(user as Player).view.kick(2.0, 0.0)
		(user as Player).combat_left = Player.COMBAT_LOCK


## A swing into the map: doors, cover and shield walls take its structure damage; the map's
## thin panels break to a heavy swing.
func _structure(thing: Object, at: Vector3, n: Vector3) -> void:
	var i := info()
	var dmg := float(i.structure)
	if thing is Node and (thing as Node).is_in_group("breakables"):
		if dmg >= 200.0 and str(thing.get("uid")) != "":
			Deploy.event(str(thing.get("uid")), "break")
		last_target = thing as Node
	elif thing is Node and thing.has_method("take_hit") and str(thing.get("uid")) != "":
		thing.take_hit({"damage": dmg, "zone": "body", "point": at, "dir": -n, "attacker": user,
			"team": int(user.get("team")), "melee": id, "effects": {}, "build": {}})
		last_target = thing as Node
	Sfx.play(user, "melee_thud", -8.0, 30.0)
	if user.get_tree() != null and user.get_tree().current_scene != null:
		PrintFx.impact(user.get_tree().current_scene, at, n, "odd", false)
	if user is Player:
		(user as Player).view.kick(1.4, 0.0)
