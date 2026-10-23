class_name Loft
## Skinned lofts (character overhaul): a tube through a run of rings, each ring a
## superellipse with its own side, front and back radii and its own bone weights, so a
## shoulder or a knee bends as one smooth surface instead of two blocks meeting at a ball.
##
##   var st := Loft.begin()
##   Loft.tube(st, rings, 18)                # rings: Array of ring dictionaries (below)
##   var mesh := Loft.commit(st, mesh, material)
##
## A ring: {c: centre, x: side axis, z: front axis (unit, model space), rx, rf, rb: radii
## to the side, front and back, n: superellipse exponent (2 = ellipse, higher = boxier),
## w: {bone index: weight}, or {} for a rigid piece built with begin(false)}. Optional: dx (centre shift along x), lean (shifts the
## front radius sideways, for asymmetric shapes).

static func begin(skinned := true) -> SurfaceTool:
	var st := SurfaceTool.new()
	if skinned:
		st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## A ring dictionary (helper for the common case).
static func ring(c: Vector3, x: Vector3, z: Vector3, rx: float, rf: float, rb: float, w: Dictionary, n := 2.0) -> Dictionary:
	return {"c": c, "x": x, "z": z, "rx": rx, "rf": rf, "rb": rb, "w": w, "n": n}


## Where a ring's point at angle `a` is (a = 0 the +x side, PI/2 the front).
static func point(r: Dictionary, a: float) -> Vector3:
	var ca := cos(a)
	var sa := sin(a)
	var e := 2.0 / float(r.get("n", 2.0))
	var px := signf(ca) * pow(absf(ca), e) * float(r.rx)
	var pz := signf(sa) * pow(absf(sa), e) * (float(r.rf) if sa > 0.0 else float(r.rb))
	return (r.c as Vector3) + (r.x as Vector3) * (px + float(r.get("dx", 0.0))) + (r.z as Vector3) * pz


## A tube through `rings` with `sides` points round each. Caps close the ends unless
## told not to (a sleeve tucked inside another part).
static func tube(st: SurfaceTool, rings: Array, sides := 16, cap_start := true, cap_end := true) -> void:
	var count := rings.size()
	if count < 2:
		return
	var pts: Array[PackedVector3Array] = []
	for r: Dictionary in rings:
		var row := PackedVector3Array()
		for k in sides:
			row.append(point(r, TAU * k / sides))
		pts.append(row)
	# UVs in metres: u round the ring, v along the centres.
	var v_at: Array[float] = [0.0]
	for i in range(1, count):
		v_at.append(v_at[i - 1] + (rings[i].c as Vector3).distance_to(rings[i - 1].c))
	var circ: Array[float] = []
	for i in count:
		var c := 0.0
		for k in sides:
			c += pts[i][k].distance_to(pts[i][(k + 1) % sides])
		circ.append(c)
	var normals: Array[PackedVector3Array] = []
	for i in count:
		var row := PackedVector3Array()
		for k in sides:
			var du := pts[i][(k + 1) % sides] - pts[i][(k - 1 + sides) % sides]
			var dv := pts[mini(i + 1, count - 1)][k] - pts[maxi(i - 1, 0)][k]
			var n := du.cross(dv).normalized()
			if n.dot(pts[i][k] - (rings[i].c as Vector3)) < 0.0:
				n = -n
			row.append(n)
		normals.append(row)
	for i in range(count - 1):
		for k in sides:
			var k2 := (k + 1) % sides
			var u0 := float(k) / sides
			var u1 := float(k + 1) / sides
			var a := [pts[i][k], normals[i][k], Vector2(u0 * circ[i], v_at[i]), rings[i].w]
			var b := [pts[i][k2], normals[i][k2], Vector2(u1 * circ[i], v_at[i]), rings[i].w]
			var c := [pts[i + 1][k2], normals[i + 1][k2], Vector2(u1 * circ[i + 1], v_at[i + 1]), rings[i + 1].w]
			var d := [pts[i + 1][k], normals[i + 1][k], Vector2(u0 * circ[i + 1], v_at[i + 1]), rings[i + 1].w]
			var out: Vector3 = (normals[i][k] + normals[i + 1][k2])
			_tri(st, a, b, c, out)
			_tri(st, a, c, d, out)
	if cap_start:
		_cap(st, rings[0], pts[0], -_along(rings, 0))
	if cap_end:
		_cap(st, rings[count - 1], pts[count - 1], _along(rings, count - 1))


static func _along(rings: Array, i: int) -> Vector3:
	var a: Vector3 = rings[maxi(i - 1, 0)].c
	var b: Vector3 = rings[mini(i + 1, rings.size() - 1)].c
	return (b - a).normalized()


static func _cap(st: SurfaceTool, r: Dictionary, row: PackedVector3Array, facing: Vector3) -> void:
	var centre := [r.c as Vector3, facing, Vector2.ZERO, r.w]
	for k in row.size():
		var p := [row[k], facing, Vector2.ZERO, r.w]
		var q := [row[(k + 1) % row.size()], facing, Vector2.ZERO, r.w]
		_tri(st, centre, p, q, facing)


## One triangle; each corner is [position, normal, uv, weights], wound to face `facing`.
static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, facing: Vector3) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var g := (pb - pa).cross(pc - pa)
	if g.length_squared() < 1e-16:
		return
	if g.dot(facing) < 0.0:
		var t := b
		b = c
		c = t
	# Godot's front faces are clockwise: a, c, b.
	_vert(st, a)
	_vert(st, c)
	_vert(st, b)


static func _vert(st: SurfaceTool, v: Array) -> void:
	var w: Dictionary = v[3]
	if w.is_empty():
		# A rigid piece (gear): no bones.
		st.set_normal(v[1])
		st.set_uv(v[2])
		st.add_vertex(v[0])
		return
	var bones := PackedInt32Array([0, 0, 0, 0])
	var weights := PackedFloat32Array([0, 0, 0, 0])
	var keys := w.keys()
	keys.sort_custom(func(p, q) -> bool: return float(w[p]) > float(w[q]))
	var total := 0.0
	for i in mini(keys.size(), 4):
		bones[i] = int(keys[i])
		weights[i] = float(w[keys[i]])
		total += weights[i]
	for i in 4:
		weights[i] = weights[i] / maxf(total, 0.0001)
	st.set_normal(v[1])
	st.set_uv(v[2])
	st.set_bones(bones)
	st.set_weights(weights)
	st.add_vertex(v[0])


## Adds the surface to `mesh` (a new one if null) with `material`.
static func commit(st: SurfaceTool, mesh: ArrayMesh, material: Material) -> ArrayMesh:
	st.index()
	st.generate_tangents()
	var m := st.commit(mesh)
	m.surface_set_material(m.get_surface_count() - 1, material)
	return m


## Bone weights that blend from bone `a` to bone `b` as `t` goes 0..1 (smoothstep).
static func blend(a: int, b: int, t: float) -> Dictionary:
	var k := clampf(t, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	if a == b or k <= 0.0:
		return {a: 1.0}
	if k >= 1.0:
		return {b: 1.0}
	return {a: 1.0 - k, b: k}


## A rounded box (plates, pouches, pads): a short tube along `ay` through four rings in
## the plane of `ax` and `az`, the end rings pulled in by `bevel` so the edges are soft.
## `taper` scales the far end (a pack narrower at the top, a fin). `n` sets how square
## the corners are (2 round, 8 nearly square).
static func box(st: SurfaceTool, c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, hx: float, hy: float, hz: float,
		w: Dictionary, n := 6.0, taper := 1.0, bevel := 0.25) -> void:
	var bv := minf(minf(hx, hz), hy) * bevel
	var rings := []
	for r in [[-hy, 1.0, bv], [-hy + bv, 1.0, 0.0], [hy - bv, taper, 0.0], [hy, taper, bv]]:
		var s: float = r[1]
		var k: float = r[2]
		rings.append({"c": c + ay * float(r[0]), "x": ax, "z": az, "rx": maxf(hx * s - k, 0.001), "rf": maxf(hz - k, 0.001),
			"rb": maxf(hz - k, 0.001), "w": w, "n": n})
	tube(st, rings, 16)


## A tube along a path of points with one radius per point (straps, wires, a boom mic).
## `side` is a direction across the path that sets which way the ring's x faces.
static func path(st: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, side: Vector3, w: Dictionary,
		thick := 1.0, sides := 8) -> void:
	var rings := []
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var x := (side - along * side.dot(along)).normalized()
		var z := along.cross(x).normalized()
		rings.append({"c": points[i], "x": x, "z": z, "rx": radii[i], "rf": radii[i] * thick, "rb": radii[i] * thick, "w": w, "n": 2.0})
	tube(st, rings, sides)
