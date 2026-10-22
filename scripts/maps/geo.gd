class_name Geo
## Building blocks for FAULTPRINT levels: chamfered concrete blocks, wedges, runnable walls
## with their orange route band, stairs and ramps. Every piece is a StaticBody3D with a
## printed surface and a collision shape that matches what you see.
##
## Collision layers (Layers.* in code):
##   1 WORLD      everything solid
##   2 RUNNABLE   walls you can wall-run on (also WORLD)
##   3 BODIES     players and bots
##   4 HITBOX     bot and player hit areas (heads / bodies)

const WORLD := 1
const RUNNABLE := 2
const BODIES := 4
const HITBOX := 8

## Width of the orange band that marks a runnable wall (metres). Narrow on purpose: the
## brief asks for a hint, not a painted wall.
const BAND := 0.22


## A solid chamfered block, centred at `pos`.
static func block(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg := Vector3.ZERO,
		options := {}) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.chamfer_box(size, options.get("bevel", minf(0.12, size[size.min_axis_index()] * 0.2)))
	mesh.material_override = Faultprint.surface(color, options.get("print", {}))
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


## A floor slab whose top is at `top`: x/z span from `a` to `b` (corners).
static func slab(parent: Node3D, a: Vector2, b: Vector2, top: float, thick: float, color: Color,
		options := {}) -> StaticBody3D:
	var size := Vector3(absf(b.x - a.x), thick, absf(b.y - a.y))
	var centre := Vector3((a.x + b.x) / 2.0, top - thick / 2.0, (a.y + b.y) / 2.0)
	return block(parent, size, centre, color, Vector3.ZERO, options)


## A wall you can wall-run on. Runs from `a` to `b` on the ground plane, bottom at `bottom`,
## `height` tall. Both long faces get a narrow orange band at shoulder height of the run
## line (`band_y` above the bottom) and a chamfered cap in the darker ink.
static func run_wall(parent: Node3D, a: Vector2, b: Vector2, bottom: float, height: float, thick: float,
		color: Color, band_y := -1.0) -> StaticBody3D:
	var d := b - a
	var length := d.length()
	var mid := (a + b) / 2.0
	var yaw := rad_to_deg(atan2(-d.y, d.x))
	var body := block(parent, Vector3(length, height, thick), Vector3(mid.x, bottom + height / 2.0, mid.y),
		color, Vector3(0, yaw, 0))
	body.collision_layer = WORLD | RUNNABLE
	body.add_to_group("runnable")
	if band_y < 0.0:
		band_y = minf(height * 0.5, 2.6)
	var band_m := Faultprint.surface(Faultprint.ORANGE, {"slip": null, "pattern": 2})
	var cut_m := Faultprint.surface(Faultprint.CARBON, {"slip": null, "pattern": 2})
	for side in [-1.0, 1.0]:
		var stripe := MeshInstance3D.new()
		stripe.mesh = LowPoly.chamfer_box(Vector3(length - 0.6, BAND, 0.04), 0.01)
		stripe.position = Vector3(0, band_y - height / 2.0, side * (thick / 2.0 + 0.012))
		stripe.material_override = band_m
		body.add_child(stripe)
		# Directional notches above the band: chevrons pointing along the run line.
		var count := int(length / 2.4)
		for i in count:
			var notch := MeshInstance3D.new()
			notch.mesh = LowPoly.extrude(PackedVector2Array([Vector2(-0.18, -0.12), Vector2(0.0, 0.0),
				Vector2(-0.18, 0.12), Vector2(-0.1, 0.0)]), 0.03)
			notch.position = Vector3(-length / 2.0 + 1.2 + i * 2.4, band_y - height / 2.0 + 0.42, side * (thick / 2.0 + 0.012))
			notch.material_override = cut_m
			body.add_child(notch)
	return body


## A wedge (right-angle triangle prism): `size` x along the slope, y height, z width.
## The tall side is at +x. Good for cover and for the brief's slanted cuts.
static func wedge(parent: Node3D, size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees.y = yaw
	var hx := size.x / 2.0
	var outline := PackedVector2Array([Vector2(-hx, 0), Vector2(hx, 0), Vector2(hx, size.y)])
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.extrude(outline, size.z)
	mesh.material_override = Faultprint.surface(color)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p in outline:
		pts.append(Vector3(p.x, p.y, -size.z / 2.0))
		pts.append(Vector3(p.x, p.y, size.z / 2.0))
	convex.points = pts
	shape.shape = convex
	body.add_child(shape)
	parent.add_child(body)
	return body


## A tilted slab from `from` (low end, top surface point) to `to` (high end), `width` wide.
## A ramp you can walk up and slide down.
static func ramp(parent: Node3D, from: Vector3, to: Vector3, width: float, color: Color, thick := 0.6) -> StaticBody3D:
	var d := to - from
	var flat := Vector2(d.x, d.z)
	var length := d.length()
	var body := block(parent, Vector3(width, thick, length), (from + to) / 2.0, color)
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	body.basis = basis
	body.position = (from + to) / 2.0 - basis.y * thick / 2.0
	var stripes := Faultprint.surface(Faultprint.YELLOW, {"slip": null, "pattern": 2})
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		edge.mesh = LowPoly.chamfer_box(Vector3(0.16, 0.04, length - 0.4), 0.01)
		edge.position = Vector3(side * (width / 2.0 - 0.25), thick / 2.0 + 0.01, 0)
		edge.material_override = stripes
		body.add_child(edge)
	return body


## Straight stairs climbing from `from` (bottom of the first step, front edge centre) toward
## `dir` (a unit vector on the ground plane), up to `rise` metres.
static func stairs(parent: Node3D, from: Vector3, dir: Vector3, rise: float, width: float, color: Color) -> void:
	var steps := int(ceil(rise / 0.3))
	var step_h := rise / steps
	var step_d := 0.42
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	for i in steps:
		var h := step_h * (i + 1)
		var centre := from + dir * (step_d * i + step_d / 2.0) + Vector3(0, h / 2.0, 0)
		block(parent, Vector3(width, h, step_d), centre, color, Vector3(0, yaw, 0),
			{"bevel": 0.03, "print": {"slip": null}})


## A big piece of scenery with no collision (far-off fractured towers, the hanging ring).
static func scenery(parent: Node3D, mesh: Mesh, xform: Transform3D, color: Color, options := {}) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.transform = xform
	node.material_override = Faultprint.surface(color, options)
	parent.add_child(node)
	return node
