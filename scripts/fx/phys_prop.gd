class_name PhysProp
extends RigidBody3D
## A loose thing on a map (C7, PhysicsFx): a crate, a drum, a paint can, a cone, a chair.
## Shots knock it, blasts throw it, anyone running through kicks it out of the way. It
## never blocks a person or a shot, and each machine simulates its own.

const KINDS := ["crate", "drum", "can", "cone", "bucket", "box"]
## How close (m) someone has to pass to kick it.
const REACH := 0.75

var kind := "crate"
var _sleep_check := 0.0


static func make(kind_id: String, tint: Color, rng: RandomNumberGenerator) -> PhysProp:
	var p := PhysProp.new()
	p.kind = kind_id
	p._build(tint, rng)
	return p


func _build(tint: Color, rng: RandomNumberGenerator) -> void:
	collision_layer = PhysicsFx.LAYER
	collision_mask = PhysicsFx.MASK
	add_to_group("loose")
	add_to_group("props")
	can_sleep = true
	linear_damp = 0.2
	angular_damp = 0.6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.2
	physics_material_override = pm
	var body := StandardMaterial3D.new()
	body.albedo_color = tint.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.15)
	body.roughness = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = body.albedo_color.darkened(0.45)
	dark.roughness = 0.9
	var shape: Shape3D
	match kind:
		"drum":
			mass = 18.0
			var c := CylinderShape3D.new()
			c.radius = 0.3
			c.height = 0.88
			shape = c
			_mesh(LowPoly.prism(14, 0.3, 0.3, 0.88), Vector3.ZERO, body)
			for y in [-0.3, 0.0, 0.3]:
				_mesh(LowPoly.prism(14, 0.315, 0.315, 0.04), Vector3(0, y, 0), dark)
		"can":
			mass = 3.0
			var c := CylinderShape3D.new()
			c.radius = 0.14
			c.height = 0.34
			shape = c
			_mesh(LowPoly.prism(10, 0.14, 0.14, 0.34), Vector3.ZERO, body)
			_mesh(LowPoly.prism(10, 0.145, 0.145, 0.03), Vector3(0, 0.16, 0), dark)
		"cone":
			mass = 2.0
			var c := CylinderShape3D.new()
			c.radius = 0.2
			c.height = 0.6
			shape = c
			_mesh(LowPoly.prism(10, 0.04, 0.17, 0.56), Vector3(0, 0.02, 0), body)
			_mesh(LowPoly.chamfer_box(Vector3(0.42, 0.04, 0.42), 0.01), Vector3(0, -0.28, 0), dark)
			var band := StandardMaterial3D.new()
			band.albedo_color = Color("#e8e4da")
			_mesh(LowPoly.prism(10, 0.1, 0.12, 0.08), Vector3(0, 0.05, 0), band)
		"bucket":
			mass = 4.0
			var c := CylinderShape3D.new()
			c.radius = 0.2
			c.height = 0.4
			shape = c
			_mesh(LowPoly.prism(12, 0.2, 0.16, 0.4), Vector3.ZERO, body)
			_mesh(LowPoly.prism(12, 0.205, 0.205, 0.03), Vector3(0, 0.19, 0), dark)
		"box":
			mass = 5.0
			var b := BoxShape3D.new()
			b.size = Vector3(0.5, 0.36, 0.4)
			shape = b
			var card := StandardMaterial3D.new()
			card.albedo_color = Color("#a8875c").lerp(body.albedo_color, 0.2)
			_mesh(LowPoly.chamfer_box(b.size, 0.01), Vector3.ZERO, card)
			_mesh(LowPoly.chamfer_box(Vector3(0.08, 0.37, 0.41), 0.004), Vector3.ZERO, dark)
		_:
			mass = 14.0
			var b := BoxShape3D.new()
			b.size = Vector3(0.8, 0.8, 0.8)
			shape = b
			_mesh(LowPoly.chamfer_box(b.size, 0.03), Vector3.ZERO, body)
			for sx in [-1.0, 1.0]:
				_mesh(LowPoly.chamfer_box(Vector3(0.06, 0.82, 0.82), 0.01), Vector3(sx * 0.37, 0, 0), dark)
			_mesh(LowPoly.chamfer_box(Vector3(0.82, 0.06, 0.82), 0.01), Vector3(0, 0.37, 0), dark)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)


func _mesh(m: Mesh, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	add_child(mi)


## How high its centre sits above the floor when it stands.
func rest_height() -> float:
	match kind:
		"drum": return 0.44
		"can": return 0.17
		"cone": return 0.3
		"bucket": return 0.2
		"box": return 0.18
	return 0.4


func hit_fx(at: Vector3, normal: Vector3) -> void:
	PrintFx.impact(get_tree().current_scene, at, normal, "rapid")


func _physics_process(delta: float) -> void:
	# Kicked aside by anyone moving through (people never collide with props).
	_sleep_check -= delta
	if _sleep_check > 0.0:
		return
	_sleep_check = 0.05
	for n in get_tree().get_nodes_in_group("combatants"):
		if not (n is Node3D) or n.get("alive") == false:
			continue
		var who := n as Node3D
		if who.global_position.distance_squared_to(global_position) > 4.0:
			continue
		var vel: Vector3 = who.get("velocity") if who.get("velocity") is Vector3 else Vector3.ZERO
		if who.has_method("seen_velocity"):
			vel = who.seen_velocity()
		if absf(who.global_position.y + 0.6 - global_position.y) > 1.4:
			continue
		sleeping = false
		PhysicsFx.shove_from(self, who, vel, REACH + 0.25)


## Scatters `count` props over a map's open floor (C7): small clusters against walls and
## in corners, on whatever floor is there (placed after the first physics frame, by a ray
## down), mirrored half round like the maps. `tints` picks their colours.
static func scatter(parent: Node3D, layout: Layout, count: int, tints: Array, seed := 7) -> void:
	var holder := _Scatter.new()
	holder.name = "Props"
	holder.layout = layout
	holder.count = count
	holder.tints = tints
	holder.rng.seed = seed
	parent.add_child(holder)


class _Scatter extends Node3D:
	var layout: Layout
	var count := 0
	var tints: Array = []
	var rng := RandomNumberGenerator.new()
	var _done := false

	func _physics_process(_delta: float) -> void:
		if _done:
			return
		_done = true
		var spots: Array[Vector2i] = []
		for r in range(1, layout.rows - 1):
			for c in range(1, layout.cols - 1):
				if layout.at(c, r) != "." and layout.at(c, r) != "a" and layout.at(c, r) != "b":
					continue
				var walls := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if layout.solid(c + d.x, r + d.y):
						walls += 1
				if walls >= 1:
					spots.append(Vector2i(c, r))
		if spots.is_empty():
			return
		var mid := layout.rect.get_center()
		var made := 0
		var tries := 0
		while made < count and tries < count * 6:
			tries += 1
			var g: Vector2i = spots[rng.randi() % spots.size()]
			var base := layout.centre(g.x, g.y)
			var kind: String = PhysProp.KINDS[rng.randi() % PhysProp.KINDS.size()]
			var cluster := 1 + rng.randi() % 3
			for i in cluster:
				var off := Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
				for p in [base + off, Layout.turn(base + off, mid)]:
					if _place(p, kind if i == 0 else PhysProp.KINDS[rng.randi() % PhysProp.KINDS.size()]):
						made += 1

	func _place(at: Vector3, kind: String) -> bool:
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 8.0, 0), at + Vector3(0, -2.0, 0), Geo.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or hit.normal.y < 0.8 or hit.position.y > 3.0:
			return false
		var tint: Color = tints[rng.randi() % tints.size()] if not tints.is_empty() else Color("#8a8f94")
		var p := PhysProp.make(kind, tint, rng)
		add_child(p)
		p.global_position = hit.position + Vector3(0, p.rest_height() + 0.02, 0)
		p.rotation.y = rng.randf() * TAU
		if kind == "can" and rng.randf() < 0.3:
			p.rotation.x = PI / 2.0
		p.sleeping = true
		return true
