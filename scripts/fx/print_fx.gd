class_name PrintFx
## Combat feedback drawn like graphic print marks, not glowing particles: a short angular
## muzzle star, a thin directional tracer, a stamped impact burst, a landing ring, a slam
## shockwave. Every mark lives a fraction of a second and never sits over the crosshair
## (the muzzle star is on the gun, impacts are on the far surface).
##
## Shape tells the weapon class apart, not only colour (art brief 8.2):
##   rapid fire   small 4-point star, short flicker
##   heavy        big 6-point star + a ring stamp on impact
##   precise      thin long tracer, a tight cross on impact
##   odd kinds    their own shapes (cone fan, arc zigzag, lob ring)

const INK := Faultprint.CARBON
const FLASH := Faultprint.YELLOW


## Which visual class a gun's stats fall in.
static func weapon_class(stats: Dictionary) -> String:
	if stats.get("kind", "hitscan") != "hitscan":
		return "odd"
	if float(stats.rate) >= 9.0:
		return "rapid"
	if float(stats.damage) * int(stats.pellets) >= 60.0:
		return "heavy"
	if float(stats.zoom) >= 2.5 or float(stats.moa) <= 2.0:
		return "precise"
	return "rapid" if float(stats.rate) >= 5.0 else "heavy"


static func _expire(node: Node, seconds: float) -> void:
	var t := node.create_tween()
	t.tween_interval(seconds)
	t.tween_callback(node.queue_free)


static func _star_mesh(points: int, outer: float, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points * 2:
		var a0 := TAU * i / (points * 2)
		var a1 := TAU * (i + 1) / (points * 2)
		var r0 := outer if i % 2 == 0 else inner
		var r1 := outer if (i + 1) % 2 == 0 else inner
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0, 0))
		st.add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1, 0))
	return st.commit()


## The muzzle star on the gun. `parent` is the gun (view model or bot), `pos` its muzzle.
static func muzzle(parent: Node3D, pos: Vector3, klass: String, scale := 1.0) -> void:
	var points := 4
	var size := 0.07
	var life := 0.035
	match klass:
		"heavy":
			points = 6
			size = 0.13
			life = 0.06
		"precise":
			points = 4
			size = 0.09
			life = 0.045
		"odd":
			points = 8
			size = 0.1
			life = 0.05
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var star := MeshInstance3D.new()
	star.mesh = _star_mesh(points, size * scale, size * 0.3 * scale)
	star.material_override = Faultprint.flat(FLASH)
	star.rotation.z = randf() * TAU
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(star)
	var core := MeshInstance3D.new()
	core.mesh = _star_mesh(points, size * 0.55 * scale, size * 0.18 * scale)
	core.material_override = Faultprint.flat(Faultprint.BONE)
	core.position.z = -0.002
	core.rotation.z = star.rotation.z + PI / points
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	# Face the camera roughly: the gun points -Z, the star is drawn in its XY plane, which
	# from behind the gun reads as the star itself.
	_expire(root, life)


## A thin tracer line from `from` to `to` in world space.
static func tracer(world: Node, from: Vector3, to: Vector3, klass: String) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var width := 0.012 if klass == "precise" else 0.02
	var life := 0.07 if klass == "precise" else 0.045
	var seg := minf(length, 6.0 if klass != "precise" else 40.0)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, seg)
	m.mesh = box
	m.material_override = Faultprint.flat(Faultprint.BONE if klass != "rapid" else FLASH)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	var dir := (to - from).normalized()
	var start := from + dir * minf(1.0, length * 0.2)
	m.look_at_from_position(start + dir * seg / 2.0, start + dir * seg, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	var t := m.create_tween()
	t.tween_property(m, "global_position", to - dir * seg / 2.0, life)
	t.tween_callback(m.queue_free)


## A stamped burst on the surface that was hit. `normal` faces out of it.
static func impact(world: Node, pos: Vector3, normal: Vector3, klass: String, on_body := false) -> void:
	var root := Node3D.new()
	world.add_child(root)
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT
	root.look_at_from_position(pos + normal * 0.02, pos + normal * 0.02 - normal, up)
	var color := Faultprint.INFO_HIT if on_body else INK
	var shards := 6 if klass != "precise" else 4
	for i in shards:
		var s := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.025, 0.11 if klass == "heavy" else 0.07, 0.005)
		s.mesh = b
		s.material_override = Faultprint.flat(color)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / shards + randf_range(-0.2, 0.2)
		s.rotation.z = a
		s.position = Vector3(cos(a + PI / 2), sin(a + PI / 2), 0) * 0.06
		root.add_child(s)
		var t := s.create_tween()
		t.tween_property(s, "position", s.position * 3.2, 0.12)
	if klass == "heavy" or klass == "odd":
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh(0.16, 0.2, 14)
		ring.material_override = Faultprint.flat(color)
		root.add_child(ring)
		var t2 := ring.create_tween()
		t2.tween_property(ring, "scale", Vector3.ONE * 2.2, 0.14)
	# A carbon dot left on walls (fades after a while), a print "mark" of the hit.
	if not on_body:
		var dot := MeshInstance3D.new()
		dot.mesh = _star_mesh(8, 0.045, 0.03)
		dot.material_override = Faultprint.flat(INK)
		dot.position.z = -0.004
		world.add_child(dot)
		dot.global_transform = root.global_transform
		_expire(dot, 6.0)
	_expire(root, 0.15)


static func _ring_mesh(inner: float, outer: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(cos(a0), sin(a0), 0)
		var p1 := Vector3(cos(a1), sin(a1), 0)
		st.add_vertex(p0 * inner)
		st.add_vertex(p0 * outer)
		st.add_vertex(p1 * outer)
		st.add_vertex(p0 * inner)
		st.add_vertex(p1 * outer)
		st.add_vertex(p1 * inner)
	return st.commit()


## A flat ring stamped on the floor where someone lands hard (or slams).
static func landing(world: Node, pos: Vector3, strength: float, slam := false) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh(0.55, 0.7 if not slam else 0.85, 20)
	ring.material_override = Faultprint.flat(Faultprint.ORANGE if slam else INK)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.04, 0)
	ring.rotation_degrees.x = -90
	ring.scale = Vector3.ONE * 0.4
	var t := ring.create_tween()
	t.tween_property(ring, "scale", Vector3.ONE * (1.2 + strength * (5.0 if slam else 1.0)), 0.16 if not slam else 0.28)
	t.tween_callback(ring.queue_free)
	if slam:
		for i in 10:
			var a := TAU * i / 10.0
			var shard := MeshInstance3D.new()
			shard.mesh = LowPoly.prism(3, 0.12, 0.0, 0.5)
			shard.material_override = Faultprint.flat(Faultprint.CONCRETE)
			world.add_child(shard)
			shard.global_position = pos + Vector3(cos(a), 0, sin(a)) * 0.8
			var t2 := shard.create_tween()
			t2.tween_property(shard, "global_position", pos + Vector3(cos(a) * 3.2, 0.6, sin(a) * 3.2), 0.25)
			t2.tween_callback(shard.queue_free)


## A shower of ink chips where someone was taken out.
static func takedown(world: Node, pos: Vector3, color: Color) -> void:
	for i in 14:
		var chip := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.12, 0.12, 0.02)
		chip.mesh = b
		chip.material_override = Faultprint.flat(color if i % 3 else INK)
		world.add_child(chip)
		chip.global_position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.6, 1.6), randf_range(-0.3, 0.3))
		chip.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var to := chip.global_position + Vector3(randf_range(-1.6, 1.6), randf_range(0.4, 1.6), randf_range(-1.6, 1.6))
		var t := chip.create_tween()
		t.tween_property(chip, "global_position", to, 0.35).set_ease(Tween.EASE_OUT)
		t.tween_property(chip, "scale", Vector3.ZERO, 0.25)
		t.tween_callback(chip.queue_free)


## Chain lightning drawn as a hard zigzag line.
static func zigzag(world: Node, points: Array) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var steps := 5
		var prev := a
		for s in range(1, steps + 1):
			var p := a.lerp(b, float(s) / steps)
			if s < steps:
				p += Vector3(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
			_line(world, prev, p, Faultprint.TEAL, 0.03, 0.09)
			prev = p


static func _line(world: Node, a: Vector3, b: Vector3, color: Color, width: float, life: float) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, length)
	m.mesh = box
	m.material_override = Faultprint.flat(color)
	world.add_child(m)
	var dir := (b - a).normalized()
	m.look_at_from_position((a + b) / 2.0, b, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	_expire(m, life)


## An explosion: a stamped star burst and a ring, no fireball.
static func explosion(world: Node, pos: Vector3, radius: float) -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = pos
	var star := MeshInstance3D.new()
	star.mesh = _star_mesh(10, radius * 0.9, radius * 0.4)
	star.material_override = Faultprint.flat(Faultprint.ORANGE)
	root.add_child(star)
	var cam := root.get_viewport().get_camera_3d()
	if cam:
		star.look_at(cam.global_position, Vector3.UP)
	var t := star.create_tween()
	t.tween_property(star, "scale", Vector3.ONE * 1.3, 0.12)
	t.tween_property(star, "scale", Vector3.ZERO, 0.1)
	landing(world, pos, radius * 0.4, true)
	_expire(root, 0.3)
