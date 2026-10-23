class_name PhysicsFx
## The light physics layer (C7): loose things that react to the fight. Nothing here
## changes the match (it never blocks a person or a shot, and it isn't sent over the
## network); every machine simulates its own copy, so it can be as lively as it likes.
##
##   props     PhysProp crates, drums, cans and cones scattered on the maps: shots knock
##             them, blasts throw them, people running through kick them aside
##   shards    pieces of broken things (shield panels, rammed walls) as rigid bodies
##   ragdolls  corpses (CompetitorRig.ragdoll) share the same layer
##
## Everything loose lives on LAYER and collides with the world and with itself.

const LAYER := 32
const MASK := Geo.WORLD | LAYER
## Loose pieces in the world at once; the oldest go first.
const MAX_SHARDS := 80
static var _shards: Array = []


## A shot from `from` to `to` along `dir`: the first loose thing on the way gets a shove.
static func shot(shooter: Node3D, from: Vector3, to: Vector3, dir: Vector3, power := 1.0) -> void:
	if shooter == null or not shooter.is_inside_tree():
		return
	var q := PhysicsRayQueryParameters3D.create(from, to + dir * 0.05, LAYER)
	var hit := shooter.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit.collider is RigidBody3D):
		return
	var b := hit.collider as RigidBody3D
	b.apply_impulse(dir * clampf(2.5 * power, 1.0, 9.0) * sqrt(b.mass), hit.position - b.global_position)
	if b is PhysProp:
		(b as PhysProp).hit_fx(hit.position, hit.normal)


## An explosion (or a slam) at `at`: everything loose within `radius` flies away from it.
static func blast(tree: SceneTree, at: Vector3, radius: float, strength := 1.0) -> void:
	if tree == null:
		return
	for n in tree.get_nodes_in_group("loose"):
		if not (n is RigidBody3D) or not is_instance_valid(n) or (n as RigidBody3D).freeze:
			continue
		var b := n as RigidBody3D
		var to := b.global_position - at
		var d := to.length()
		if d > radius * 1.6:
			continue
		var k := 1.0 - d / (radius * 1.6)
		var dir := (to / maxf(d, 0.05) + Vector3.UP * 0.6).normalized()
		b.apply_central_impulse(dir * (6.0 + 10.0 * k) * strength * k * b.mass)
		b.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * b.mass * 0.4 * k)


## People moving through loose things push them (called by props on themselves).
static func shove_from(b: RigidBody3D, who: Node3D, vel: Vector3, reach: float) -> void:
	var to := b.global_position - who.global_position
	to.y = 0.0
	var d := to.length()
	if d > reach or vel.length() < 0.5:
		return
	var away := to / maxf(d, 0.05)
	var into := maxf(vel.dot(away), 0.0) + 0.6
	b.apply_central_impulse((away * into + vel * 0.35 + Vector3.UP * into * 0.25) * b.mass * 0.25)


## Breaks something into `count` rigid pieces of `size` round `at`, thrown along `push`.
static func shards(world: Node, at: Vector3, size: Vector3, mat: Material, count: int, push: Vector3, life := 4.0) -> void:
	if world == null:
		return
	for i in count:
		var b := RigidBody3D.new()
		b.collision_layer = LAYER
		b.collision_mask = MASK
		b.mass = maxf(size.x * size.y * size.z * 600.0, 0.3)
		b.add_to_group("loose")
		var piece := Vector3(size.x * randf_range(0.5, 1.0), size.y * randf_range(0.5, 1.0), size.z * randf_range(0.6, 1.0))
		var mi := MeshInstance3D.new()
		mi.mesh = LowPoly.chamfer_box(piece, minf(0.01, piece.z * 0.3))
		mi.material_override = mat
		b.add_child(mi)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = piece.max(Vector3(0.03, 0.03, 0.03))
		cs.shape = box
		b.add_child(cs)
		world.add_child(b)
		b.global_position = at + Vector3(randf_range(-0.5, 0.5), randf_range(-0.4, 0.4), randf_range(-0.5, 0.5)) * size.length()
		b.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		b.linear_velocity = push * randf_range(0.6, 1.2) + Vector3(randf_range(-2, 2), randf_range(1, 3.5), randf_range(-2, 2))
		b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_keep(b, life)


static func _keep(b: RigidBody3D, life: float) -> void:
	_shards.append(b)
	while _shards.size() > MAX_SHARDS:
		var old = _shards.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := b.create_tween()
	tw.tween_interval(life)
	for c in b.get_children():
		if c is MeshInstance3D:
			tw.tween_property(c, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(b.queue_free)
