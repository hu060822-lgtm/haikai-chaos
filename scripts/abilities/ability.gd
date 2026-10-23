class_name Ability
extends RefCounted
## One class ability (C6), carried by a Player or a Bot (`user`). Charges refill one at a
## time over the class's cooldown, like the dash. The user calls:
##
##   press() / release()   the ability key went down / up (bots call press() only)
##   tick(delta)           every physics tick, alive or not
##   move_frame(...)       only while the Player is in a move state this ability owns
##                         (Anchor: GRAPPLE, Ram: CHARGE)
##   cancel()              on death and respawn
##
## What an ability puts into the world goes through Deploy, so every machine in a match
## builds the same thing.

var kit := Kit.DEFAULT
var user: Node3D
var charges := 1.0
## Something is going on (a line out, a charge): the HUD shows it lit.
var busy := false


func max_charges() -> float:
	return float(Kit.info(kit).charges)


func cooldown() -> float:
	return float(Kit.info(kit).cooldown)


func can_use() -> bool:
	return charges >= 1.0 and not busy


func spend() -> void:
	charges = maxf(charges - 1.0, 0.0)


func refill() -> void:
	charges = max_charges()


func press() -> void:
	pass


func release() -> void:
	pass


func tick(delta: float) -> void:
	if charges < max_charges():
		charges = minf(charges + delta / cooldown(), max_charges())


func move_frame(_p: Player, _delta: float, _wish: Vector3) -> void:
	pass


func cancel() -> void:
	busy = false


## 0..1 of the charge being refilled (for the HUD ring).
func refill_progress() -> float:
	return 1.0 if charges >= max_charges() else fmod(charges, 1.0)


# --- Helpers for the users -------------------------------------------------------------

func alive() -> bool:
	return user != null and is_instance_valid(user) and bool(user.get("alive"))


## Where the user is looking from, and which way: the camera for a player, the eye for a bot.
func aim() -> Transform3D:
	if user.has_method("ability_aim"):
		return user.ability_aim()
	return Transform3D(user.global_basis, user.global_position + Vector3(0, 1.5, 0))


func team() -> int:
	return int(user.get("team"))


## The floor under `p` within `down` metres (or INF).
func floor_below(p: Vector3, down := 6.0) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, down, 0), Geo.WORLD)
	var hit := user.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3.INF


func say(text: String) -> void:
	if user is Player and user.is_inside_tree():
		var main := user.get_tree().current_scene
		if main != null and main.get("hud") != null:
			main.hud.show_hint(text, 1.6)
