class_name Pouch
extends RefCounted
## The belt of throwables a Player or Bot carries (C12, see Throwables). The user calls:
##
##   press() / release(short)   the throw key went down / up (a frag's pin comes out on
##                              press, so holding it cooks the fuse down)
##   next()                     the next kind on the belt that has any left
##   tick(delta)                every physics tick (cooking, the kick coming back)
##   refill()                   a new life or a new round: a full belt
##   cancel(dropped)            death: a cooked frag drops live at your feet
##   throw_kind(kind, vel)      bots: throw this now at this velocity

var user: Node3D
var counts := {}
var selected := Throwables.DEFAULT
var holding := false
var cook := 0.0
var _kick_t := 0.0


func _init(who: Node3D = null) -> void:
	user = who
	refill()


func refill() -> void:
	counts = Throwables.full()
	holding = false
	cook = 0.0
	_kick_t = 0.0


func count(id: String) -> int:
	return int(counts.get(id, 0))


func total() -> int:
	var n := 0
	for id in counts:
		n += int(counts[id])
	return n


func next() -> void:
	if holding:
		return
	var i := Throwables.IDS.find(selected)
	for k in range(1, Throwables.IDS.size() + 1):
		var id: String = Throwables.IDS[(i + k) % Throwables.IDS.size()]
		if count(id) > 0:
			selected = id
			return
	selected = Throwables.IDS[(i + 1) % Throwables.IDS.size()]


func tick(delta: float) -> void:
	if count("kick") < int(Throwables.info("kick").count):
		_kick_t += delta
		if _kick_t >= Throwables.KICK_REFILL:
			_kick_t = 0.0
			counts.kick = count("kick") + 1
	else:
		_kick_t = 0.0
	if holding and selected == "frag":
		cook += delta
		if cook >= float(Throwables.info("frag").fuse):
			# Held too long: it goes off in your hand.
			holding = false
			_spend("frag")
			var at := user.global_position + Vector3(0, 1.2, 0)
			_spawn("frag", at, Vector3.ZERO, 0.0)


## 0..1 of the kick coming back (for the HUD).
func kick_progress() -> float:
	return _kick_t / Throwables.KICK_REFILL


func press() -> bool:
	if holding or not _alive():
		return false
	if count(selected) <= 0:
		next()
		if count(selected) <= 0:
			_say("投擲物用完了")
			return false
	holding = true
	cook = 0.0
	if selected == "frag":
		Sfx.play(user, "nade_pin", -10.0, 16.0)
	return true


func release(short := false) -> void:
	if not holding:
		return
	holding = false
	if not _alive() or count(selected) <= 0:
		return
	var aim := _aim()
	var v := velocity_for(aim, short)
	var kind := selected
	var fuse := float(Throwables.info(kind).fuse)
	if kind == "frag":
		fuse = maxf(fuse - cook, 0.05)
	_spend(kind)
	_spawn(kind, origin_for(aim), v, fuse)
	Sfx.play(user, "smoke_throw", -8.0, 30.0)
	if count(selected) <= 0:
		next()


## Bots: throw `kind` now with velocity `v`, from `from` (default: ahead of the eye).
func throw_kind(kind: String, v: Vector3, from := Vector3.INF) -> bool:
	if count(kind) <= 0 or not _alive():
		return false
	_spend(kind)
	_spawn(kind, from if from != Vector3.INF else origin_for(_aim()), v, float(Throwables.info(kind).fuse))
	Sfx.play(user, "smoke_throw", -8.0, 30.0)
	return true


func cancel(dropped := false) -> void:
	if holding and dropped and selected == "frag" and count("frag") > 0:
		_spend("frag")
		_spawn("frag", user.global_position + Vector3(0, 0.6, 0), Vector3(0, 1.0, 0), maxf(float(Throwables.info("frag").fuse) - cook, 0.1))
	holding = false
	cook = 0.0


## The velocity a throw along `aim` leaves the hand with (your own speed goes with it).
func velocity_for(aim: Transform3D, short := false) -> Vector3:
	var dir := -aim.basis.z
	var v := dir * Throwables.SPEED * (Throwables.SHORT if short else 1.0) + Vector3(0, Throwables.LOFT, 0)
	var own = user.get("velocity")
	if own is Vector3:
		v += (own as Vector3) * Throwables.CARRY
	return v


## Where it leaves the hand: a little ahead and to the right of the eye, never through a wall.
func origin_for(aim: Transform3D) -> Vector3:
	var want := aim.origin - aim.basis.z * 0.5 + aim.basis.x * 0.12 - aim.basis.y * 0.1
	var q := PhysicsRayQueryParameters3D.create(aim.origin, want, Geo.WORLD)
	var hit := user.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return aim.origin.lerp(hit.position, 0.6)
	return want


func _spend(kind: String) -> void:
	counts[kind] = maxi(count(kind) - 1, 0)


func _spawn(kind: String, from: Vector3, v: Vector3, fuse: float) -> void:
	Deploy.spawn("throw", user, {"kind": kind, "from": from, "vel": v, "fuse": fuse})


func _aim() -> Transform3D:
	if user.has_method("ability_aim"):
		return user.ability_aim()
	return Transform3D(user.global_basis, user.global_position + Vector3(0, 1.5, 0))


func _alive() -> bool:
	return user != null and is_instance_valid(user) and bool(user.get("alive"))


func _say(text: String) -> void:
	if user is Player and user.is_inside_tree():
		var main := user.get_tree().current_scene
		if main != null and main.get("hud") != null:
			main.hud.show_hint(text, 1.4)
