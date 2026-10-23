class_name VeilThrow
extends Ability
## VEIL's ability (C6): lobs a smoke canister where you aim. The arc is worked out here once
## (THROW_SPEED, LOFT, its own gravity; it stops on what it hits and drops to the floor),
## and every machine flies the canister to that same spot and grows the same SmokeCloud.

const THROW_SPEED := 23.0
const LOFT := 3.0
const GRAVITY := 18.0
const MAX_FLIGHT := 2.4


func press() -> void:
	if not alive():
		return
	if charges < 1.0:
		say("煙幕彈還在冷卻")
		return
	spend()
	var a := aim()
	var from := a.origin - a.basis.z * 0.5
	var land := landing(from, -a.basis.z)
	Deploy.spawn("smoke", user, {"from": from, "to": land[0], "flight": land[1]})
	Sfx.play(user, "smoke_throw", -6.0)


## [where it comes to rest, after how long].
func landing(from: Vector3, dir: Vector3) -> Array:
	var space := user.get_world_3d().direct_space_state
	var p := from
	var v := dir * THROW_SPEED + Vector3(0, LOFT, 0)
	var t := 0.0
	var dt := 1.0 / 60.0
	var exclude: Array = user.exclusions() if user.has_method("exclusions") else []
	while t < MAX_FLIGHT:
		var next := p + v * dt
		v.y -= GRAVITY * dt
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, next, Geo.WORLD | Geo.BOUNDS, exclude))
		t += dt
		if not hit.is_empty():
			var at: Vector3 = hit.position + (hit.normal as Vector3) * 0.2
			if (hit.normal as Vector3).y > 0.6:
				return [hit.position, t]
			var down := floor_below(at, 30.0)
			return [down if down != Vector3.INF else at, t + 0.25]
		p = next
	var g := floor_below(p, 40.0)
	return [g if g != Vector3.INF else p, t]
