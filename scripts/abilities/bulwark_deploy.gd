class_name BulwarkDeploy
extends Ability
## BULWARK's ability (C6): stands a Barricade up DISTANCE ahead, square to where you look.
## It needs floor there (not in the air, not on a wall).

const DISTANCE := 2.0


func press() -> void:
	if not alive():
		return
	if charges < 1.0:
		say("護盾板還在冷卻")
		return
	var fwd := -aim().basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	var chest := user.global_position + Vector3(0, 1.0, 0)
	var reach := DISTANCE
	var q := PhysicsRayQueryParameters3D.create(chest, chest + fwd * (DISTANCE + 0.4), Geo.WORLD)
	var hit := user.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		reach = maxf(chest.distance_to(hit.position) - 0.4, 0.8)
	var ground := floor_below(user.global_position + fwd * reach + Vector3(0, 1.0, 0), 3.0)
	if ground == Vector3.INF:
		say("那裡沒有地板，護盾板立不起來")
		return
	spend()
	Deploy.spawn("barricade", user, {"at": ground, "yaw": atan2(fwd.x, fwd.z)})
