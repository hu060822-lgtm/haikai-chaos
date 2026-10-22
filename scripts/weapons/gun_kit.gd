class_name GunKit
## Machined shapes for gun models (Counterform §6: credible proportions, clean split lines,
## parts you can tell apart). Two workhorses and their finishes:
##
##   GunKit.slab(outline, thick, bevel)   # a side silhouette (z, y) extruded across X with
##                                          # chamfered edges: receivers, slides, grips, stocks
##   GunKit.turned(profile, sides)         # a lathe part along Z from (z, radius) pairs listed
##                                          # front to back: barrels, cans, scopes, tubes
##
## Curved outlines are smooth-shaded (neighbouring edges under SMOOTH_DEG apart share a
## normal) and sharp corners stay sharp, so a grip reads as one moulded piece and a slide
## as machined steel. Meshes are cached by their parameters like LowPoly's.

const SMOOTH_DEG := 38.0

static var _cache := {}


## `outline`: points (z, y) round a simple polygon, either winding. `thick` across X,
## centred on x = 0. `bevel` chamfers every edge of both faces (0 for none).
static func slab(outline: PackedVector2Array, thick: float, bevel := 0.0015) -> ArrayMesh:
	var key := "slab:%s:%s:%s" % [outline, thick, bevel]
	if _cache.has(key):
		return _cache[key]
	var pts := _clean(outline)
	var b := minf(bevel, thick * 0.4)
	var inner := pts
	if b > 0.0:
		inner = _inset(pts, b)
		if inner.is_empty():
			b = 0.0
			inner = pts
	var face_tris := Geometry2D.triangulate_polygon(inner)
	if face_tris.is_empty():
		face_tris = Geometry2D.triangulate_polygon(pts)
		inner = pts
		b = 0.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := thick / 2.0
	# Faces.
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx, 0, 0)
		for i in range(0, face_tris.size(), 3):
			var a := _v(inner[face_tris[i]], sx * hx)
			var c := _v(inner[face_tris[i + 1]], sx * hx)
			var d := _v(inner[face_tris[i + 2]], sx * hx)
			_tri(st, a, c, d, n, n, n, n)
	# Side walls and chamfers, with outline normals smoothed across gentle corners.
	var count := pts.size()
	var ccw := not Geometry2D.is_polygon_clockwise(pts)
	var edge_n: Array[Vector2] = []
	for i in count:
		var e := pts[(i + 1) % count] - pts[i]
		var out := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
		edge_n.append(out.normalized())
	var cos_lim := cos(deg_to_rad(SMOOTH_DEG))
	for i in count:
		var j := (i + 1) % count
		var n_e := edge_n[i]
		# Normal at each end of this edge: shared with the neighbour when the turn is gentle.
		var n_a := n_e
		var n_prev := edge_n[(i - 1 + count) % count]
		if n_prev.dot(n_e) > cos_lim:
			n_a = (n_prev + n_e).normalized()
		var n_b := n_e
		var n_next := edge_n[j]
		if n_next.dot(n_e) > cos_lim:
			n_b = (n_next + n_e).normalized()
		var na3 := Vector3(0, n_a.y, n_a.x)
		var nb3 := Vector3(0, n_b.y, n_b.x)
		var wall := hx - b
		var a0 := _v(pts[i], -wall)
		var a1 := _v(pts[i], wall)
		var b0 := _v(pts[j], -wall)
		var b1 := _v(pts[j], wall)
		var facing := Vector3(0, n_e.y, n_e.x)
		_tri(st, a0, b0, b1, na3, nb3, nb3, facing)
		_tri(st, a0, b1, a1, na3, nb3, na3, facing)
		if b > 0.0:
			for sx: float in [-1.0, 1.0]:
				var ca := (na3 + Vector3(sx, 0, 0)).normalized()
				var cb := (nb3 + Vector3(sx, 0, 0)).normalized()
				var o_a := _v(pts[i], sx * wall)
				var o_b := _v(pts[j], sx * wall)
				var i_a := _v(inner[i], sx * hx)
				var i_b := _v(inner[j], sx * hx)
				var cf := (facing + Vector3(sx, 0, 0)).normalized()
				_tri(st, o_a, o_b, i_b, ca, cb, cb, cf)
				_tri(st, o_a, i_b, i_a, ca, cb, ca, cf)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## A turned part along Z. `profile`: (z, radius) listed front (-z) to back. A radius of 0
## at an end closes it to a point; otherwise the ends get flat caps.
static func turned(profile: PackedVector2Array, sides := 16) -> ArrayMesh:
	var key := "turn:%s:%d" % [profile, sides]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := profile.size()
	# Profile normal of each segment in (z, r): outward, i.e. away from the axis side.
	var seg_n: Array[Vector2] = []
	for i in count - 1:
		var d := profile[i + 1] - profile[i]
		seg_n.append(Vector2(-d.y, d.x).normalized())
	var cos_lim := cos(deg_to_rad(SMOOTH_DEG))
	for i in count - 1:
		var p := profile[i]
		var q := profile[i + 1]
		if p.distance_to(q) < 1e-6:
			continue
		var n0 := seg_n[i]
		var n1 := seg_n[i]
		if i > 0 and seg_n[i - 1].dot(seg_n[i]) > cos_lim:
			n0 = (seg_n[i - 1] + seg_n[i]).normalized()
		if i < count - 2 and seg_n[i + 1].dot(seg_n[i]) > cos_lim:
			n1 = (seg_n[i + 1] + seg_n[i]).normalized()
		for s in sides:
			var t0 := TAU * s / sides
			var t1 := TAU * (s + 1) / sides
			var a := _ring(p, t0)
			var b2 := _ring(p, t1)
			var c := _ring(q, t1)
			var d2 := _ring(q, t0)
			var na0 := _rn(n0, t0)
			var na1 := _rn(n0, t1)
			var nb1 := _rn(n1, t1)
			var nb0 := _rn(n1, t0)
			var facing := _rn(seg_n[i], (t0 + t1) / 2.0)
			if p.y > 1e-6:
				_tri(st, a, b2, c, na0, na1, nb1, facing)
			if q.y > 1e-6:
				_tri(st, a, c, d2, na0, nb1, nb0, facing)
	for end in [0, count - 1]:
		var e := profile[end]
		if e.y <= 1e-6:
			continue
		var n := Vector3(0, 0, -1 if end == 0 else 1)
		var centre := Vector3(0, 0, e.x)
		for s in sides:
			var a := _ring(e, TAU * s / sides)
			var b2 := _ring(e, TAU * (s + 1) / sides)
			_tri(st, centre, a, b2, n, n, n, n)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## A simple turned rod: radius `r`, `length` along Z, centred, with small edge chamfers.
static func rod(r: float, length: float, sides := 12, chamfer := -1.0) -> ArrayMesh:
	var c := chamfer if chamfer >= 0.0 else minf(r * 0.15, 0.0015)
	var h := length / 2.0
	return turned(PackedVector2Array([Vector2(-h, r - c), Vector2(-h + c, r), Vector2(h - c, r), Vector2(h, r - c)]), sides)


# --- Building blocks ---------------------------------------------------------------

static func _v(p: Vector2, x: float) -> Vector3:
	return Vector3(x, p.y, p.x)


static func _ring(p: Vector2, t: float) -> Vector3:
	return Vector3(cos(t) * p.y, sin(t) * p.y, p.x)


static func _rn(n: Vector2, t: float) -> Vector3:
	return Vector3(cos(t) * n.y, sin(t) * n.y, n.x).normalized()


## Drops repeated points (and a closing duplicate) that would break triangulation.
static func _clean(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 1e-5:
			out.append(p)
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) < 1e-5:
		out.remove_at(out.size() - 1)
	return out


## The outline moved inward by `d` (mitred corners, clamped so spikes don't form).
## Empty when the result folds over (the part is too thin to chamfer).
static func _inset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var count := pts.size()
	var ccw := not Geometry2D.is_polygon_clockwise(pts)
	var out := PackedVector2Array()
	for i in count:
		var prev := pts[(i - 1 + count) % count]
		var cur := pts[i]
		var next := pts[(i + 1) % count]
		var e1 := (cur - prev).normalized()
		var e2 := (next - cur).normalized()
		var in1 := Vector2(-e1.y, e1.x) if ccw else Vector2(e1.y, -e1.x)
		var in2 := Vector2(-e2.y, e2.x) if ccw else Vector2(e2.y, -e2.x)
		var bis := in1 + in2
		if bis.length() < 1e-4:
			bis = in1
		bis = bis.normalized()
		var k := clampf(1.0 / maxf(bis.dot(in1), 0.35), 1.0, 2.8)
		out.append(cur + bis * d * k)
	if Geometry2D.is_polygon_clockwise(out) != (not ccw):
		return PackedVector2Array()
	# A self-crossing inset: give up on the chamfer.
	for i in count:
		var a := out[i]
		var b := out[(i + 1) % count]
		for j in range(i + 2, count):
			if (j + 1) % count == i:
				continue
			if Geometry2D.segment_intersects_segment(a, b, out[j], out[(j + 1) % count]) != null:
				return PackedVector2Array()
	return out


## One triangle with per-vertex normals, wound to face along `facing`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, facing: Vector3) -> void:
	var g := (b - a).cross(c - a)
	if g.length_squared() < 1e-14:
		return
	if g.dot(facing) < 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	# Godot's front faces are clockwise: add a, c, b.
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nc)
	st.add_vertex(c)
	st.set_normal(nb)
	st.add_vertex(b)
