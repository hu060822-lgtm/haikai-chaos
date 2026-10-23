class_name TestamentArt
## 最後的遺訓's architecture and main art (C10, Phase 4), over the Phase 2 graybox: the
## graybox keeps every collision box (the tests drive the real player and bots over it);
## this adds what you see. Low-poly stone, dark wood, low-saturation metal, and opaque
## glowing stained glass (no transparency: cheap in GL Compatibility). Repeated pieces of
## one material are merged into one mesh (Batch), so the whole church is a few hundred
## draw calls.
##
## Everything hangs under nodes named after the book's scene tree: CentralHall,
## ChoirGallery, Confessionals, Altar, Crypt, OrganRoom, StainedGlass.

# --- Palette (design book 7.1) ---------------------------------------------------------
const STONE := Color("#9A9892")         # cool grey stone: walls, pillars
const STONE_LIGHT := Color("#B9B5AC")   # dressed stone: trim, capitals, the dais
const STONE_DARK := Color("#6A6966")    # floor slabs, the crypt
const STONE_DEEP := Color("#46464A")    # leading, shadowed recesses
const WOOD := Color("#4A3424")          # pews, confessionals, gallery
const WOOD_LIGHT := Color("#6E4E34")
const IRON := Color("#3A3C3E")
const BRASS := Color("#A88B55")
const CARPET := Color("#5A1F22")
const GLASS_BLUE := Color("#1E3A86")
const GLASS_RED := Color("#8E1F26")
const GLASS_PURPLE := Color("#56307A")
const GLASS_AMBER := Color("#D4932F")
const GLASS_TEAL := Color("#1F6B6A")
const LEAD := Color("#1C1D20")
const WARN_RED := Color("#C2352B")
const AMBER := Color("#E3A23C")

## The choir stalls: thirteen seats a side from x -30 to -14 (in their graybox block).
const STALL_X0 := -30.0
const STALL_W := 16.0 / 13.0


## A world material: Counterform's real materials, or the print look's ink.
static func mat(kind: String, color: Color, glow := Color.BLACK) -> Material:
	if Settings.look == Faultprint.COUNTERFORM:
		return Counterform.material(kind, color, true, glow)
	return Faultprint.surface(color, {"glow": glow} if glow != Color.BLACK else {})


## Gives a graybox body (Geo.block / slab / ramp) a real material: its main mesh only, so
## a ramp keeps its yellow edge stripes.
static func dress(body: Node, kind: String, color: Color) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = mat(kind, color)
			return


## Hides a graybox body's mesh (its collision stays) where a finer model replaces it.
static func hide_mesh(body: Node) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false


## Meshes of one material, merged into one MeshInstance3D each when flushed.
class Batch:
	var parts := {}   # key -> [material, [[mesh, xform], ...], shadow]

	func add(mesh: Mesh, xform: Transform3D, kind: String, color: Color, glow := Color.BLACK, shadow := true) -> void:
		var key := "%s|%s|%s|%s" % [kind, color.to_html(), glow.to_html(), shadow]
		if not parts.has(key):
			parts[key] = [TestamentArt.mat(kind, color, glow), [], shadow]
		parts[key][1].append([mesh, xform])

	func box(size: Vector3, pos: Vector3, kind: String, color: Color, rot := Vector3.ZERO, bevel := 0.04, glow := Color.BLACK, shadow := true) -> void:
		add(LowPoly.chamfer_box(size, bevel), LowPoly.at(pos, rot), kind, color, glow, shadow)

	func flush(parent: Node3D) -> void:
		for key in parts:
			var p: Array = parts[key]
			var list: Array = p[1]
			# Big lists in chunks: one mesh shouldn't span the whole map (culling).
			for i in range(0, list.size(), 400):
				var mi := MeshInstance3D.new()
				mi.mesh = LowPoly.merge(list.slice(i, i + 400))
				mi.material_override = p[0]
				if not p[2]:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(mi)
		parts.clear()


static func group(map: Node3D, name: String) -> Node3D:
	var n := map.get_node_or_null(name) as Node3D
	if n == null:
		n = Node3D.new()
		n.name = name
		map.add_child(n)
	return n


## Points along a pointed (two-centred) arch in a vertical plane: across `span` on the
## local x axis, springing at y 0, `sharp` 0 (round) .. 0.5 (lancet).
static func arch_points(span: float, sharp := 0.15, steps := 8) -> PackedVector2Array:
	var a := span / 2.0
	var c := a * sharp
	var r := a + c
	var top := sqrt(r * r - c * c)
	var out := PackedVector2Array()
	for i in steps + 1:
		# Left half: centred at (+c, 0), from angle PI to the apex.
		var end := atan2(top, -c)
		var t := lerpf(PI, end, float(i) / steps)
		out.append(Vector2(c + cos(t) * r, sin(t) * r))
	for i in range(steps - 1, -1, -1):
		var p := out[i]
		out.append(Vector2(-p.x, p.y))
	return out


## The height of that arch's apex.
static func arch_rise(span: float, sharp := 0.15) -> float:
	var a := span / 2.0
	var c := a * sharp
	return sqrt((a + c) * (a + c) - c * c)


## A pointed-arch outline (closed, for extrude): `w` wide, straight sides `leg` high.
static func lancet(w: float, leg: float, sharp := 0.3) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(w / 2.0, 0)])
	for p in arch_points(w, sharp, 6):
		pts.insert(1, Vector2(p.x, p.y + leg))   # reversed order: right side first
	pts.append(Vector2(-w / 2.0, 0))
	# Wind it the way LowPoly's own outlines go, or extrude turns its faces inward.
	if Geometry2D.is_polygon_clockwise(pts) != Geometry2D.is_polygon_clockwise(LowPoly.arch_outline(1.0, 1.0, 4)):
		pts.reverse()
	return pts


## A rib (a swept square tube) through points of a vertical arch in the plane x = `x`
## (the arch runs across z), springing at `base` y between z0 and z1.
static func rib_z(b: Batch, x: float, z0: float, z1: float, base: float, sharp: float, thick: float, kind: String, color: Color) -> void:
	var span := z1 - z0
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for p in arch_points(span, sharp, 9):
		path.append(Vector3(x, base + p.y, (z0 + z1) / 2.0 + p.x))
		radii.append(thick)
	b.add(LowPoly.tube(path, radii, 4), Transform3D.IDENTITY, kind, color)


# --- The whole church --------------------------------------------------------------------

static func build(map: LastTestament) -> void:
	_nave(map)
	_glass(map)
	_galleries(map)
	_confessionals(map)
	_altar(map)
	_crypt(map)
	_organ(map)


## The nave: a ribbed pointed vault on the arcade (part fallen in, so the light still
## comes down), the clerestory wall over the arches, octagonal piers, wooden pews, the
## font, the pulpit, and a stone floor with a darker processional way.
static func _nave(map: LastTestament) -> void:
	var root := group(map, "CentralHall")
	var b := Batch.new()
	var top := LastTestament.WALL_H
	var bays := range(-36, 41, 8)
	for i in bays.size():
		var x: float = bays[i]
		rib_z(b, x, -13.0, 13.0, top, 0.15, 0.32, "concrete", STONE_LIGHT)
		# Vault webs on most bays; every third one has fallen in (book 4.5's broken vault,
		# and the daylight that keeps the nave readable).
		if i < bays.size() - 1 and i % 3 != 1:
			var pts := arch_points(26.0, 0.15, 9)
			for k in pts.size() - 1:
				var p0 := Vector3(x + 4.0, top + pts[k].y, pts[k].x)
				var p1 := Vector3(x + 4.0, top + pts[k + 1].y, pts[k + 1].x)
				var mid := (p0 + p1) / 2.0
				var d := p1 - p0
				var ang := rad_to_deg(atan2(d.y, d.z))
				b.box(Vector3(8.0, 0.35, d.length() + 0.05), mid, "concrete", STONE, Vector3(-ang, 0, 0), 0.02, Color.BLACK, false)
	# The ridge rib down the whole length.
	b.box(Vector3(76.0, 0.5, 0.5), Vector3(2.0, top + arch_rise(26.0, 0.15) - 0.1, 0), "concrete", STONE_LIGHT)
	# The arcade: pointed arches from pier to pier over the galleries.
	for s in [1.0, -1.0]:
		for x in LastTestament.ARCADE + [30.0, -40.0]:
			var x0: float = x + 1.8
			var x1: float = x0 + 6.4
			if x1 > 40.5:
				continue
			var path := PackedVector3Array()
			var radii := PackedFloat32Array()
			for p in arch_points(x1 - x0, 0.3, 7):
				path.append(Vector3((x0 + x1) / 2.0 + p.x, 8.4 + p.y, 13.0 * s))
				radii.append(0.3)
			b.add(LowPoly.tube(path, radii, 4), Transform3D.IDENTITY, "concrete", STONE_LIGHT)
	# The piers: octagonal shafts with a plinth and a capital, over the graybox boxes.
	for x in LastTestament.ARCADE:
		for s in [1.0, -1.0]:
			var at := Vector3(x + 1.0, 0, 13.0 * s)
			_pier(b, at, 0.88, top)
	for s in [1.0, -1.0]:
		var gp := Vector3(LastTestament.GREAT_PILLAR.get_center().x, 0, 4.0 * s)
		# A clustered pier: a fat core and four shafts.
		_pier(b, gp, 1.55, top)
		for c in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			b.add(LowPoly.prism(8, 0.42, 0.42, top - 1.2), LowPoly.at(gp + Vector3(c.x * 1.35, (top - 1.2) / 2.0 + 0.6, c.y * 1.35)), "concrete", STONE)
	# Pews: a seat, a back and two carved ends, inside the graybox box (0.8 × 0.9 × 5.6).
	for x in LastTestament.PEWS:
		for z in [7.0, -7.0]:
			var c := Vector3(x + 1.0, 0, z)
			b.box(Vector3(0.62, 0.08, 5.4), c + Vector3(0.06, 0.46, 0), "polymer", WOOD, Vector3.ZERO, 0.02)
			b.box(Vector3(0.08, 0.5, 5.4), c + Vector3(0.36, 0.66, 0), "polymer", WOOD, Vector3.ZERO, 0.02)
			for e in [-2.72, 2.72]:
				b.add(LowPoly.extrude(PackedVector2Array([Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0.4, 0.9), Vector2(0.2, 0.9), Vector2(0.2, 0.55), Vector2(-0.4, 0.5)]), 0.1),
					LowPoly.at(c + Vector3(0, 0, e)), "polymer", WOOD_LIGHT)
			b.box(Vector3(0.5, 0.06, 5.4), c + Vector3(-0.3, 0.12, 0), "polymer", WOOD, Vector3.ZERO, 0.02)
	# The font: an octagonal basin on a stem (in its 3.4 m graybox block).
	var font := Vector3(18, 0, 0)
	b.add(LowPoly.prism(8, 1.7, 1.7, 0.5), LowPoly.at(font + Vector3(0, 0.25, 0)), "concrete", STONE_DARK)
	b.add(LowPoly.prism(8, 0.7, 0.9, 1.4), LowPoly.at(font + Vector3(0, 1.2, 0)), "concrete", STONE)
	b.add(LowPoly.prism(8, 1.0, 1.7, 0.7), LowPoly.at(font + Vector3(0, 2.25, 0)), "concrete", STONE_LIGHT)
	b.add(LowPoly.prism(8, 1.3, 1.3, 0.08), LowPoly.at(font + Vector3(0, 2.6, 0)), "lens", Color("#2A3540"))
	# The floor: dark stone flags down the centre aisle, a border each side.
	for x in range(-36, 40, 2):
		for z in [-3.0, -1.0, 1.0, 3.0]:
			var dark := (int(x / 2) + int(z + 3) / 2) % 2 == 0
			b.box(Vector3(1.96, 0.04, 1.96), Vector3(x + 1.0, 0.02, z), "concrete", STONE_DARK if dark else STONE, Vector3.ZERO, 0.01, Color.BLACK, false)
	b.flush(root)
	# The graybox pieces this replaces keep their collision, not their look.
	for n in map.get_children():
		if n is StaticBody3D and n.has_meta("art"):
			match str(n.get_meta("art")):
				"pier", "pew", "font":
					hide_mesh(n)
				"pulpit":
					dress(n, "polymer", WOOD)
				"wall":
					dress(n, "concrete", STONE)
				"column":
					dress(n, "concrete", STONE)
				"floor":
					dress(n, "concrete", STONE_DARK)
				"crypt_floor":
					dress(n, "concrete", STONE_DEEP)
				"crypt_roof":
					dress(n, "concrete", STONE_DARK)
				"ramp":
					dress(n, "concrete", STONE_LIGHT)


## An octagonal pier with a square plinth and a capital, standing at `at`.
static func _pier(b: Batch, at: Vector3, r: float, height: float) -> void:
	b.box(Vector3(r * 2.0, 0.6, r * 2.0), at + Vector3(0, 0.3, 0), "concrete", STONE_LIGHT, Vector3.ZERO, 0.06)
	b.add(LowPoly.prism(8, r, r, height - 1.4), LowPoly.at(at + Vector3(0, 0.6 + (height - 1.4) / 2.0, 0), Vector3(0, 22.5, 0)), "concrete", STONE)
	b.add(LowPoly.prism(8, r, r * 1.35, 0.8), LowPoly.at(at + Vector3(0, height - 0.4, 0), Vector3(0, 22.5, 0)), "concrete", STONE_LIGHT)


# --- Stained glass -----------------------------------------------------------------------

## Opaque, glowing panes in lead cames: the Saint of Recoil over the altar, and lancets in
## the aisle walls under the vault. A panel faces +z in its own space; `xf` places it.
static func _glass(map: LastTestament) -> void:
	var root := group(map, "StainedGlass")
	var b := Batch.new()
	# The east window over the altar: an anonymous warrior raising a huge gun in a halo.
	# Scaled to sit between the tablet's top (6 m) and the wall's (16 m).
	var east := Transform3D(Basis(Vector3.UP, -PI / 2.0).scaled(Vector3.ONE * 0.77), Vector3(73.95, 7.0, 0))
	_saint(b, east)
	# Lancets in the aisle walls, facing the nave across the gallery.
	var motifs := ["halo", "gun", "gear", "shards"]
	var k := 0
	for x in [-42.0, -30.0, -14.0, -6.0, 2.0, 10.0, 26.0, 34.0]:
		for s in [1.0, -1.0]:
			# Only in solid wall: not over a door, a window or a breach.
			var solid := true
			for dx in [-1.8, 0.0, 1.8]:
				if map.layout.kind_at(Vector3(x + dx, 0, 21.0 * s)) != "#":
					solid = false
			if not solid:
				continue
			var xf := Transform3D(Basis(Vector3.UP, PI if s > 0 else 0.0), Vector3(x, 8.0, 20.1 * s))
			_lancet(b, xf, 3.2, 5.0, motifs[k % motifs.size()])
			k += 1
	b.flush(root)


## The Saint of Recoil (4.1): 9 m wide, 11 m tall, in the east wall.
static func _saint(b: Batch, xf: Transform3D) -> void:
	var w := 9.0
	var leg := 6.0
	var outline := lancet(w, leg, 0.25)
	var glow := 0.55
	# The stone frame and the dark lead backing.
	b.add(LowPoly.extrude(lancet(w + 1.2, leg, 0.25), 0.3), xf * LowPoly.at(Vector3(0, -0.6, -0.12)), "concrete", STONE_LIGHT)
	b.add(LowPoly.extrude(outline, 0.1), xf * LowPoly.at(Vector3(0, 0, 0.06)), "paint", LEAD)
	# Background: blue diamonds and red/purple borders in bands.
	var rows := 9
	for r in rows:
		for c in 7:
			var cx := -3.6 + c * 1.2
			var cy := 0.6 + r * 1.2
			if not Geometry2D.is_point_in_polygon(Vector2(cx, cy), outline) or not Geometry2D.is_point_in_polygon(Vector2(cx + 0.5, cy + 0.5), outline):
				continue
			var col := GLASS_BLUE if (r + c) % 3 != 0 else GLASS_PURPLE
			if c == 0 or c == 6:
				col = GLASS_RED
			b.add(LowPoly.extrude(PackedVector2Array([Vector2(0, -0.52), Vector2(0.52, 0), Vector2(0, 0.52), Vector2(-0.52, 0)]), 0.06),
				xf * LowPoly.at(Vector3(cx, cy, 0.14)), "paint", col, col * glow)
	# The halo: amber ring behind the head, rays.
	var head := Vector2(0, 8.2)
	var ring := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 17:
		var t := TAU * i / 16.0
		ring.append(head + Vector2(cos(t), sin(t)) * 1.7)
	for i in 16:
		var t := TAU * (16 - i) / 16.0
		inner.append(head + Vector2(cos(t), sin(t)) * 1.25)
	for i in 16:
		var t0 := TAU * i / 16.0
		var t1 := TAU * (i + 1) / 16.0
		var seg := PackedVector2Array([head + Vector2(cos(t0), sin(t0)) * 1.25, head + Vector2(cos(t0), sin(t0)) * 1.7,
			head + Vector2(cos(t1), sin(t1)) * 1.7, head + Vector2(cos(t1), sin(t1)) * 1.25])
		b.add(LowPoly.extrude(seg, 0.08), xf * LowPoly.at(Vector3(0, 0, 0.2)), "paint", GLASS_AMBER, GLASS_AMBER * glow)
	# The figure: a robed silhouette, arms raised, holding the gun overhead.
	var robe := PackedVector2Array([Vector2(-1.6, 0.7), Vector2(1.6, 0.7), Vector2(1.0, 5.2), Vector2(0.7, 6.8), Vector2(1.9, 8.6),
		Vector2(1.5, 8.9), Vector2(0.3, 7.5), Vector2(0.45, 7.6), Vector2(-0.45, 7.6), Vector2(-0.3, 7.5), Vector2(-1.5, 8.9),
		Vector2(-1.9, 8.6), Vector2(-0.7, 6.8), Vector2(-1.0, 5.2)])
	b.add(LowPoly.extrude(robe, 0.08), xf * LowPoly.at(Vector3(0, 0, 0.22)), "paint", GLASS_RED, GLASS_RED * glow)
	b.add(LowPoly.extrude(PackedVector2Array([Vector2(-0.45, 7.55), Vector2(0.45, 7.55), Vector2(0.4, 8.6), Vector2(0, 8.85), Vector2(-0.4, 8.6)]), 0.08),
		xf * LowPoly.at(Vector3(0, 0, 0.24)), "paint", LEAD)
	# The gun across the top of the window: long barrel, a box magazine, a stock.
	var gun := PackedVector2Array([Vector2(-3.6, 9.0), Vector2(2.2, 9.0), Vector2(2.2, 9.15), Vector2(3.7, 9.15), Vector2(3.7, 9.45),
		Vector2(2.2, 9.45), Vector2(1.6, 9.75), Vector2(-1.8, 9.75), Vector2(-2.4, 9.55), Vector2(-3.6, 9.65)])
	b.add(LowPoly.extrude(gun, 0.08), xf * LowPoly.at(Vector3(0, 0, 0.26)), "paint", Color("#8A8F94"), Color("#8A8F94") * 0.35)
	b.add(LowPoly.extrude(PackedVector2Array([Vector2(-0.4, 8.2), Vector2(0.2, 8.2), Vector2(0.3, 9.0), Vector2(-0.3, 9.0)]), 0.08),
		xf * LowPoly.at(Vector3(0, 0, 0.27)), "paint", Color("#6E7378"), Color("#6E7378") * 0.3)
	# Lead cames: the window's verticals and bands.
	for x in [-3.0, -1.5, 1.5, 3.0]:
		b.add(LowPoly.chamfer_box(Vector3(0.08, leg + 1.6, 0.06), 0.01), xf * LowPoly.at(Vector3(x, (leg + 1.6) / 2.0, 0.3)), "paint", LEAD)
	for y in [2.4, 4.8]:
		b.add(LowPoly.chamfer_box(Vector3(w - 0.1, 0.1, 0.06), 0.01), xf * LowPoly.at(Vector3(0, y, 0.3)), "paint", LEAD)


## A lancet window `w` wide with straight sides `leg` high and a motif: an abstract halo,
## a gun silhouette, an industrial gear, or broken shards.
static func _lancet(b: Batch, xf: Transform3D, w: float, leg: float, motif: String) -> void:
	var outline := lancet(w, leg, 0.35)
	var glow := 0.5
	b.add(LowPoly.extrude(lancet(w + 0.6, leg, 0.35), 0.2), xf * LowPoly.at(Vector3(0, -0.3, -0.06)), "concrete", STONE_LIGHT)
	b.add(LowPoly.extrude(outline, 0.08), xf * LowPoly.at(Vector3(0, 0, 0.06)), "paint", LEAD)
	var cols := [GLASS_BLUE, GLASS_PURPLE, GLASS_RED, GLASS_TEAL]
	var n := 0
	var y := 0.2
	while y < leg + w * 0.6:
		var x := -w / 2.0 + 0.2
		while x < w / 2.0 - 0.2:
			var cell := PackedVector2Array([Vector2(x, y), Vector2(x + 0.66, y), Vector2(x + 0.66, y + 0.66), Vector2(x, y + 0.66)])
			var inside := true
			for p in cell:
				if not Geometry2D.is_point_in_polygon(p, outline):
					inside = false
			if inside:
				var col: Color = cols[(n * 7 + int(y * 3)) % cols.size()]
				b.add(LowPoly.extrude(cell, 0.05), xf * LowPoly.at(Vector3(0, 0, 0.12)), "paint", col, col * glow)
			n += 1
			x += 0.72
		y += 0.72
	var c := Vector2(0, leg * 0.62)
	var shape := PackedVector2Array()
	match motif:
		"halo":
			for i in 12:
				var t := TAU * i / 12.0
				shape.append(c + Vector2(cos(t), sin(t)) * (0.9 if i % 2 == 0 else 1.15))
		"gun":
			shape = PackedVector2Array([c + Vector2(-1.2, -0.15), c + Vector2(1.1, -0.15), c + Vector2(1.1, 0.12), c + Vector2(-0.3, 0.12),
				c + Vector2(-0.3, 0.3), c + Vector2(-0.8, 0.3), c + Vector2(-0.9, -0.7), c + Vector2(-0.6, -0.7), c + Vector2(-0.6, -0.15)])
		"gear":
			for i in 16:
				var t := TAU * i / 16.0
				shape.append(c + Vector2(cos(t), sin(t)) * (1.1 if i % 4 < 2 else 0.8))
		_:
			shape = PackedVector2Array([c + Vector2(-0.9, -0.8), c + Vector2(0.2, -0.3), c + Vector2(1.0, -0.9), c + Vector2(0.6, 0.4),
				c + Vector2(0.9, 1.0), c + Vector2(-0.2, 0.5), c + Vector2(-1.0, 0.9)])
	b.add(LowPoly.extrude(shape, 0.06), xf * LowPoly.at(Vector3(0, 0, 0.16)), "paint", GLASS_AMBER, GLASS_AMBER * glow)


# --- Galleries ---------------------------------------------------------------------------

## The choir galleries and the loft: oak floors on beams, a balustrade with posts and a
## stone cap on the graybox railing, choir stalls on the back wall.
static func _galleries(map: LastTestament) -> void:
	var root := group(map, "ChoirGallery")
	var b := Batch.new()
	var y := LastTestament.GALLERY_Y
	for s in [1.0, -1.0]:
		# Floor boards and the beams under them.
		for x in range(-48, 28, 2):
			b.box(Vector3(1.94, 0.05, 5.9), Vector3(x + 1.0, y + 0.025, 17.0 * s), "polymer", WOOD_LIGHT if (x / 2) % 2 == 0 else WOOD, Vector3.ZERO, 0.01, Color.BLACK, false)
		for x in range(-46, 28, 4):
			b.box(Vector3(0.35, 0.5, 6.0), Vector3(x, y - 0.6, 17.0 * s), "polymer", WOOD)
		# The choir stalls on the back wall (in their graybox block).
		# Thirteen seats a side; the south row's thirteenth is TestamentDetail's.
		for i in 13:
			if i == 12 and s > 0:
				continue
			_stall(b, Vector3(STALL_X0 + (i + 0.5) * STALL_W, y, 19.35 * s), s, STALL_W)
	for x in range(-48, -38, 2):
		b.box(Vector3(1.94, 0.05, 27.9), Vector3(x + 1.0, y + 0.025, 0), "polymer", WOOD if (x / 2) % 2 == 0 else WOOD_LIGHT, Vector3.ZERO, 0.01, Color.BLACK, false)
	b.flush(root)
	for n in map.get_children():
		if n is StaticBody3D and n.has_meta("art"):
			match str(n.get_meta("art")):
				"rail":
					dress(n, "polymer", WOOD)
				"deck":
					dress(n, "polymer", WOOD)
				"stall":
					hide_mesh(n)


## One choir stall (seat, high back, arm rests) against the back wall, facing the nave:
## a front panel over the collision block's face, the seat and back above it.
static func _stall(b: Batch, at: Vector3, s: float, w: float) -> void:
	b.box(Vector3(w - 0.04, 0.5, 0.1), at + Vector3(0, 0.25, -0.3 * s), "polymer", WOOD)
	b.box(Vector3(w - 0.1, 0.06, 0.9), at + Vector3(0, 0.53, 0.1 * s), "polymer", WOOD_LIGHT)
	b.box(Vector3(w - 0.04, 1.1, 0.12), at + Vector3(0, 1.05, 0.55 * s), "polymer", WOOD_LIGHT)
	for e in [-0.5, 0.5]:
		b.box(Vector3(0.08, 1.6, 0.96), at + Vector3(e * (w - 0.08), 0.8, 0.12 * s), "polymer", WOOD)


# --- Confessionals -----------------------------------------------------------------------

## Dark wood panelling inside the booths, lintels, the old grilles and the equipment
## terminals that replaced them.
static func _confessionals(map: LastTestament) -> void:
	var root := group(map, "Confessionals")
	var b := Batch.new()
	for s in [1.0, -1.0]:
		for k in 11:
			var x0 := -22.0 + 4.0 * k
			# Panelling on both sides of the booth, up to the ceiling.
			for side in [x0 + 0.03, x0 + 1.97]:
				b.box(Vector3(0.06, 3.0, 5.9), Vector3(side, 1.5, 27.0 * s), "polymer", WOOD, Vector3.ZERO, 0.01)
			# Every other booth: the grille's gone, an equipment terminal's bolted where it was.
			if k % 2 == 0:
				b.box(Vector3(0.08, 0.7, 1.0), Vector3(x0 + 0.1, 1.5, 26.0 * s), "paint", IRON)
				b.box(Vector3(0.02, 0.4, 0.7), Vector3(x0 + 0.15, 1.55, 26.0 * s), "paint", Color("#2F4A44"), Vector3.ZERO, 0.0, Color("#5FA894") * 0.6)
			else:
				for g in 5:
					b.box(Vector3(0.05, 0.6, 0.04), Vector3(x0 + 0.08, 1.6, 26.0 * s + (g - 2) * 0.16), "paint", IRON, Vector3.ZERO, 0.0)
	b.flush(root)


# --- The altar ---------------------------------------------------------------------------

## Site A: the dais in dressed stone with a carpet up its ramp, brass candelabra on the
## stands, the stone tablet, and the giant experimental gun on its display stand.
static func _altar(map: LastTestament) -> void:
	var root := group(map, "Altar")
	var b := Batch.new()
	b.box(Vector3(6.1, 0.03, 2.4), Vector3(59, 0.62, 0), "polymer", CARPET, Vector3(0, 0, rad_to_deg(atan2(1.2, 6.0))), 0.0, Color.BLACK, false)
	b.box(Vector3(9.6, 0.02, 2.4), Vector3(67, 1.21, 0), "polymer", CARPET, Vector3.ZERO, 0.0, Color.BLACK, false)
	for z in [5.0, -5.0]:
		for x in [58.8, 61.2]:
			var at := Vector3(x, 1.6, z)
			b.add(LowPoly.prism(6, 0.05, 0.05, 1.6), LowPoly.at(at + Vector3(0, 0.8, 0)), "bare", BRASS)
			b.add(LowPoly.prism(6, 0.25, 0.05, 0.12), LowPoly.at(at + Vector3(0, 1.6, 0)), "bare", BRASS)
			for c in [-0.18, 0.0, 0.18]:
				b.add(LowPoly.prism(6, 0.035, 0.035, 0.22), LowPoly.at(at + Vector3(c, 1.77, 0)), "polymer", Color("#E8E0CC"), Color("#FFB860") * 0.4)
	# The gun's brackets on its stand (the stand is a graybox block).
	for z in [-1.2, 1.2]:
		b.box(Vector3(0.18, 2.0, 0.18), Vector3(69, 2.6, z), "bare", BRASS)
	b.flush(root)
	var gun := GunModels.build({"frame": "anti_materiel", "parts": {}, "tune": {}})
	gun.name = "AltarGun"
	gun.scale = Vector3.ONE * 4.0
	gun.position = Vector3(69, 3.7, -0.97)   # the model's centre is 0.24 m behind its origin
	gun.rotation_degrees = Vector3(0, 180, 0)
	root.add_child(gun)
	# What you see is what you hit: a box round the gun and its brackets.
	var box := _bounds(gun, Transform3D(Basis.from_euler(gun.rotation).scaled(gun.scale), gun.position))
	box = box.merge(AABB(Vector3(68.9, 1.6, -1.3), Vector3(0.2, 2.0, 2.6)))
	var body := StaticBody3D.new()
	body.name = "AltarGunBody"
	body.collision_layer = Geo.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = box.size
	shape.position = box.get_center()
	body.add_child(shape)
	root.add_child(body)
	for n in map.get_children():
		if n is StaticBody3D and n.has_meta("art"):
			match str(n.get_meta("art")):
				"dais", "tablet", "gun_stand":
					dress(n, "concrete", STONE_LIGHT)
				"stand":
					dress(n, "concrete", STONE)


## The world-space bounds of every mesh under `node`, placed by `xf`.
static func _bounds(node: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	for c in node.get_children():
		var cx := xf
		if c is Node3D:
			cx = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var a := cx * (c as MeshInstance3D).mesh.get_aabb()
			out = a if first else out.merge(a)
			first = false
		var sub := _bounds(c, cx)
		if sub.size != Vector3.ZERO:
			out = sub if first else out.merge(sub)
			first = false
	return out


# --- The crypt ---------------------------------------------------------------------------

## Site B: a low ribbed vault, burial niches in the walls, lidded sarcophagi, and old
## stone rooms turned into a power plant (cabinets, cables, amber lamps), crates of
## supplies where they don't belong.
static func _crypt(map: LastTestament) -> void:
	var root := group(map, "Crypt")
	var b := Batch.new()
	var floor_y := LastTestament.CRYPT_Y
	var c := LastTestament.CRYPT
	# Ribs across the vault, every 4 m.
	# Ribs across the vault every 4 m: shallow segmental arches under the ceiling slab.
	for x in range(int(c.position.x) + 2, int(c.end.x), 4):
		var path := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in 13:
			var t := float(i) / 12.0
			path.append(Vector3(x, -1.4 + 0.9 * sin(PI * t), lerpf(c.position.y, c.end.y, t)))
			radii.append(0.2)
		b.add(LowPoly.tube(path, radii, 4), Transform3D.IDENTITY, "concrete", STONE_DARK)
	# Niches: arched dark recesses in the long walls and the west wall, two rows.
	for s in [1.0, -1.0]:
		for x in range(-72, -54, 3):
			if x > -65 and x < -57:
				continue   # the lane tunnel comes in here
			for row in 2:
				var xf := Transform3D(Basis(Vector3.UP, PI if s > 0 else 0.0), Vector3(x, floor_y + 0.4 + row * 1.7, c.end.y * s - 0.02 * s))
				b.add(LowPoly.extrude(LowPoly.arch_outline(1.5, 1.4, 5), 0.05), xf, "paint", STONE_DEEP)
				b.add(LowPoly.extrude(LowPoly.arch_outline(1.8, 1.6, 5), 0.03), xf * LowPoly.at(Vector3(0, -0.1, -0.02)), "concrete", STONE)
	for z in range(-9, 10, 3):
		var xf := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(c.position.x + 0.02, floor_y + 0.4, z))
		b.add(LowPoly.extrude(LowPoly.arch_outline(1.5, 1.4, 5), 0.05), xf, "paint", STONE_DEEP)
	# Cables along the walls from the cabinets, amber lamps on them.
	for s in [1.0, -1.0]:
		var path := PackedVector3Array([Vector3(-73, floor_y + 2.4, 12 * s), Vector3(-73.5, floor_y + 3.6, 15.5 * s), Vector3(-60, floor_y + 3.7, 15.6 * s),
			Vector3(-54, floor_y + 3.6, 15.6 * s)])
		var radii := PackedFloat32Array([0.06, 0.06, 0.06, 0.06])
		b.add(LowPoly.tube(path, radii, 5), Transform3D.IDENTITY, "rubber", Color("#202020"))
		for x in [-70.0, -62.0, -56.0]:
			b.box(Vector3(0.3, 0.2, 0.15), Vector3(x, floor_y + 3.45, 15.85 * s), "paint", IRON)
			b.box(Vector3(0.18, 0.1, 0.06), Vector3(x, floor_y + 3.45, 15.75 * s), "polymer", AMBER, Vector3.ZERO, 0.01, AMBER)
	b.flush(root)
	for n in map.get_children():
		if n is StaticBody3D and n.has_meta("art"):
			match str(n.get_meta("art")):
				"crypt_pillar":
					dress(n, "concrete", STONE_DARK)
				"tomb":
					dress(n, "concrete", STONE)
				"cabinet":
					dress(n, "paint", IRON)


# --- The organ -----------------------------------------------------------------------------

## The organ: a bank of pipes on the organ room's west wall (some swapped for industrial
## steel), and its façade high on the loft wall looking down the nave: the landmark at the
## west end.
static func _organ(map: LastTestament) -> void:
	var root := group(map, "OrganRoom")
	var b := Batch.new()
	# The bank in the organ room (inside its graybox casing).
	for k in 19:
		var z := -9.0 + k * 1.0
		var h := 5.0 + 7.0 * (1.0 - absf(k - 9) / 9.0) + (0.8 if k % 2 == 0 else 0.0)
		var steel := k % 5 == 2
		b.add(LowPoly.prism(8, 0.36, 0.36, h), LowPoly.at(Vector3(-73.2, 1.4 + h / 2.0, z)), "bare" if not steel else "paint", BRASS if not steel else Color("#7C8184"))
		b.box(Vector3(0.1, 0.2, 0.5), Vector3(-72.82, 2.2, z), "paint", LEAD, Vector3.ZERO, 0.01)
	b.box(Vector3(1.4, 1.4, 20.0), Vector3(-73.3, 0.7, 0), "polymer", WOOD, Vector3.ZERO, 0.04)
	# Behind the pipes, filling the collision block up to its top.
	b.box(Vector3(0.5, 13.1, 20.0), Vector3(-73.75, 7.95, 0), "polymer", WOOD, Vector3.ZERO, 0.04)
	# The façade over the loft, facing the nave: pipes in three towers.
	for tower in [-6.0, 0.0, 6.0]:
		for k in 7:
			var z: float = tower + (k - 3) * 0.62
			var h := 4.0 + 3.0 * (1.0 - absf(k - 3) / 3.0) + (2.0 if tower == 0.0 else 0.0)
			b.add(LowPoly.prism(8, 0.26, 0.26, h), LowPoly.at(Vector3(-47.6, 8.75 + h / 2.0, z)), "bare", BRASS if k % 3 != 1 else Color("#8D9194"))
		b.box(Vector3(0.8, 0.5, 5.0), Vector3(-47.6, 8.5, tower), "polymer", WOOD)
	# The casing behind and between the towers, the whole collision block.
	b.box(Vector3(0.3, 9.4, 17.0), Vector3(-47.85, 13.0, 0), "polymer", WOOD, Vector3.ZERO, 0.04)
	for z in [-8.6, 8.6]:
		b.box(Vector3(0.12, 0.12, 0.12), Vector3(-47.9, 7.9, z), "polymer", WARN_RED, Vector3.ZERO, 0.01, WARN_RED)
	b.flush(root)
	for n in map.get_children():
		if n is StaticBody3D and n.has_meta("art"):
			match str(n.get_meta("art")):
				"platform":
					dress(n, "paint", IRON)
				"organ":
					hide_mesh(n)
