class_name Counterform
## COUNTERFORM INDUSTRIAL: the game's official art style (art direction v1.0).
## "Believable industrial materials in an unbelievable world": concrete, painted and
## oxidised metal and polymer that look heavy and real, in spaces that break the rules.
## The surrealism comes from space, scale and composition, never from glow or filters.
##
## Everything visual goes through here (Faultprint forwards to it in this look):
##   Counterform.material("concrete", Counterform.BONE_CONCRETE)   # a world surface
##   Counterform.world(color)        # the old ink colours, mapped to a material class
##   Counterform.gun(color, kind)    # held guns: tighter, more metallic, object-space
##   Counterform.environment(parent) # sky, sun, fill light, fog, tone mapping
##   Counterform.vista(parent, ...)  # the surreal backdrop: floating mass, endless frames
## Material classes: concrete, concrete_dark, paint, oxide, bare, polymer, rubber, glass.

# --- Palette (art direction §4; starting values, maps may shift them) --------------------
const BONE_CONCRETE := Color("#D0C7B8")   # 骨灰混凝土: the main surface
const GRAPHITE := Color("#34383B")        # 機械石墨: machinery, frames, UI panels
const OXIDE_ORANGE := Color("#A65339")    # 氧化赭橙: identity colour, used sparingly
const GREEN_GREY := Color("#777D77")      # 灰綠工業漆: industrial paint
const DUST_WHITE := Color("#E9E4D9")      # 粉塵白: light paint, UI text
const SULFUR := Color("#D9C75B")          # 警示硫黃: information only
# Derived (same logic, other values)
const CONCRETE_MID := Color("#B4AB9C")
const CONCRETE_DARK := Color("#8C857A")
const GRAPHITE_DEEP := Color("#24272A")
const OXIDE_RUST := Color("#6E3A28")
const STEEL := Color("#5D6163")
const BARE_STEEL := Color("#A3A5A3")
const BRASS := Color("#A88B55")
const POLYMER_TAN := Color("#7E6A52")

static var _cache := {}
static var _tex := {}


# --- Materials -------------------------------------------------------------------------

## A world material of `kind` in `color`. World surfaces are mapped in world space
## (triplanar), so big blocks never stretch a texture and pieces line up.
static func material(kind: String, color: Color, world_space := true, glow := Color.BLACK) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [kind, color.to_html(), world_space, glow.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world_space
	m.uv1_triplanar_sharpness = 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match kind:
		"concrete", "concrete_dark":
			# Board-formed concrete: soft colour drift, formwork seams and tie holes every
			# 3 m, fine pores in the normal map. Rough, never shiny.
			m.albedo_texture = _concrete_albedo()
			m.normal_enabled = true
			m.normal_texture = _concrete_normal()
			m.normal_scale = 0.55
			m.roughness = 0.92
			m.roughness_texture = _grain()
			m.uv1_scale = Vector3.ONE / 3.0 if world_space else Vector3.ONE
		"paint":
			# Painted steel: semi-matte paint, faint orange-peel and grime (world only: guns
			# are kept clean and precise, §6.3).
			m.albedo_texture = _grime() if world_space else null
			m.normal_enabled = true
			m.normal_texture = _fine_normal()
			m.normal_scale = 0.18
			m.roughness = 0.58
			m.metallic = 0.08
			m.uv1_scale = Vector3.ONE / 2.0 if world_space else Vector3.ONE * 2.0
		"oxide":
			m.albedo_texture = _rust() if world_space else _grime()
			m.normal_enabled = true
			m.normal_texture = _concrete_normal()
			m.normal_scale = 0.7
			m.roughness = 0.86
			m.metallic = 0.35
			m.uv1_scale = Vector3.ONE / 2.0 if world_space else Vector3.ONE * 3.0
		"bare":
			m.albedo_texture = _brushed()
			m.metallic = 0.9
			m.roughness = 0.34
			m.metallic_specular = 0.6
			m.uv1_scale = Vector3.ONE if world_space else Vector3.ONE * 4.0
		"polymer":
			m.albedo_texture = _grime() if world_space else null
			m.normal_enabled = true
			m.normal_texture = _fine_normal()
			m.normal_scale = 0.35
			m.roughness = 0.74
			m.metallic = 0.0
			m.uv1_scale = Vector3.ONE * 6.0
		"rubber":
			m.normal_enabled = true
			m.normal_texture = _fine_normal()
			m.normal_scale = 0.6
			m.roughness = 0.93
			m.metallic = 0.0
			m.uv1_scale = Vector3.ONE * 10.0
		"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(color, 0.28)
			m.roughness = 0.08
			m.metallic = 0.3
			m.metallic_specular = 0.8
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow != Color.BLACK:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = 1.4
	_cache[key] = m
	return m


## The world's old ink colours, mapped to Counterform material classes. Anything else
## (info colours on bots, one-off colours) becomes painted metal in that colour.
static func world(color: Color, glow := Color.BLACK) -> StandardMaterial3D:
	var pair := _world_map(color)
	return material(pair[0], pair[1], true, glow)


static func _world_map(c: Color) -> Array:
	match c.to_html(false):
		"aaa69c": return ["concrete", CONCRETE_MID]          # CONCRETE
		"e7e0d2": return ["concrete", BONE_CONCRETE]         # BONE
		"c9c3b6": return ["concrete", Color("#C3BAAA")]      # DUST
		"6e6c66": return ["concrete_dark", CONCRETE_DARK]    # SLATE
		"202124": return ["paint", GRAPHITE_DEEP]            # CARBON
		"3b3d41": return ["paint", GRAPHITE]                 # GRAPHITE
		"f05a35": return ["paint", OXIDE_ORANGE]             # ORANGE: routes, danger
		"b5523a": return ["oxide", OXIDE_RUST]               # OXIDE
		"37a6a0": return ["paint", GREEN_GREY]               # TEAL: wayfinding
		"24706c": return ["paint", Color("#565C57")]         # DEEP_TEAL
		"d6b64a": return ["paint", SULFUR]                   # YELLOW: information
		"a88a35": return ["paint", Color("#A99A4B")]         # OCHRE
		"c08a5c": return ["polymer", POLYMER_TAN]            # KRAFT
	return ["paint", c]


## Held guns: tighter machining. Kind is the part's old texture name; colour picks the
## finish (parkerised steel, black anodising, polymer, cerakote, brass, bare steel).
static func gun(color: Color, kind := "panel", glow := Color.BLACK) -> StandardMaterial3D:
	var pair := _gun_map(color, kind)
	var m := material(pair[0], pair[1], false, glow)
	return m


static func _gun_map(c: Color, kind: String) -> Array:
	match kind:
		"wood":
			return ["polymer", POLYMER_TAN if c.to_html(false) == "c08a5c" else c]
		"brass":
			return ["bare", BRASS]
		"pipe":
			return ["bare", BARE_STEEL]
		"grate":
			return ["bare", STEEL.darkened(0.3)]
		"rust_metal":
			return ["oxide", OXIDE_RUST]
	match c.to_html(false):
		"aaa69c": return ["paint", STEEL]                    # steel parts: parkerised
		"3b3d41": return ["paint", Color("#2C2F31")]         # black anodised
		"202124": return ["polymer", Color("#1E2022")]       # grips, stocks
		"c08a5c": return ["polymer", POLYMER_TAN]
		"b5523a", "f05a35": return ["paint", OXIDE_ORANGE]   # cerakote accents
		"c9c3b6": return ["bare", BARE_STEEL]
		"37a6a0", "24706c": return ["paint", GREEN_GREY]
		"e7e0d2": return ["paint", DUST_WHITE]
		"d6b64a": return ["paint", SULFUR]
		"6e6c66": return ["paint", Color("#4A4E50")]
	return ["paint", c]


# --- Procedural textures (made once, shared) ----------------------------------------------

static func _noise(seed_v: int, freq: float, octaves := 4, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Height field for 3 m of board-formed concrete: pores, soft drift, seams, tie holes.
static func _concrete_height() -> Image:
	if _tex.has("ch"):
		return _tex["ch"]
	var size := 512
	var pores := _noise(11, 0.09, 3, FastNoiseLite.TYPE_CELLULAR).get_seamless_image(size, size)
	var drift := _noise(12, 0.006, 3).get_seamless_image(size, size)
	var img := Image.create(size, size, false, Image.FORMAT_L8)
	for y in size:
		for x in size:
			var h := 0.6 + (drift.get_pixel(x, y).r - 0.5) * 0.25
			var p := pores.get_pixel(x, y).r
			h -= smoothstep(0.08, 0.0, p) * 0.18
			# Formwork boards every 0.75 m (a quarter tile) and a deeper seam at the tile edge.
			var by := y % (size / 4)
			if by < 2:
				h -= 0.12
			if y < 3 or x < 3:
				h -= 0.3
			# Tie holes: a 2 × 4 grid of small round pits.
			var cx := float(x % (size / 2)) - size / 4.0
			var cy := float(y % (size / 4)) - size / 8.0
			if cx * cx + cy * cy < 36.0:
				h -= 0.35
			img.set_pixel(x, y, Color(clampf(h, 0.0, 1.0), 0, 0))
	_tex["ch"] = img
	return img


static func _concrete_albedo() -> ImageTexture:
	if _tex.has("ca"):
		return _tex["ca"]
	var size := 512
	var h := _concrete_height()
	var stain := _noise(13, 0.01, 4).get_seamless_image(size, size)
	var grain := _noise(14, 0.35, 2).get_seamless_image(size, size)
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := 0.9 + (h.get_pixel(x, y).r - 0.6) * 0.35
			v += (grain.get_pixel(x, y).r - 0.5) * 0.06
			# Water stains run down from the board lines, warm and faint.
			var s := smoothstep(0.5, 0.9, stain.get_pixel(x, y).r) * (0.5 + 0.5 * float(y % 128) / 128.0)
			var c := Color(v, v * 0.985, v * 0.96).lerp(Color(v * 0.86, v * 0.81, v * 0.74), s * 0.3)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["ca"] = t
	return t


static func _concrete_normal() -> ImageTexture:
	if _tex.has("cn"):
		return _tex["cn"]
	var img := _concrete_height().duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(6.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["cn"] = t
	return t


static func _grain() -> ImageTexture:
	if _tex.has("gr"):
		return _tex["gr"]
	var img := _noise(21, 0.05, 3).get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGB8)
	img.adjust_bcs(1.0, 0.4, 1.0)
	# Roughness multiplies: keep it between 0.85 and 1 so concrete never looks wet.
	for y in img.get_height():
		for x in img.get_width():
			var g := 0.85 + img.get_pixel(x, y).r * 0.15
			img.set_pixel(x, y, Color(g, g, g))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["gr"] = t
	return t


## Faint grime for paint and polymer: mostly white (it multiplies the colour).
static func _grime() -> ImageTexture:
	if _tex.has("gm"):
		return _tex["gm"]
	var size := 256
	var n := _noise(31, 0.02, 4).get_seamless_image(size, size)
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := 1.0 - smoothstep(0.5, 0.85, n.get_pixel(x, y).r) * 0.22
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.97))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["gm"] = t
	return t


static func _fine_normal() -> ImageTexture:
	if _tex.has("fn"):
		return _tex["fn"]
	var img := _noise(41, 0.12, 2).get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(2.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["fn"] = t
	return t


## Oxide: patches of darker and redder rust over the colour.
static func _rust() -> ImageTexture:
	if _tex.has("rs"):
		return _tex["rs"]
	var size := 256
	var a := _noise(51, 0.03, 5).get_seamless_image(size, size)
	var b := _noise(52, 0.15, 2).get_seamless_image(size, size)
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var p := a.get_pixel(x, y).r
			var q := b.get_pixel(x, y).r
			var c := Color(1, 1, 1).lerp(Color(1.12, 0.96, 0.85), smoothstep(0.4, 0.8, p))
			c = c.lerp(Color(0.72, 0.68, 0.66), smoothstep(0.75, 0.95, q) * 0.4)
			img.set_pixel(x, y, c.clamp())
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["rs"] = t
	return t


## Brushed metal: fine streaks along one axis.
static func _brushed() -> ImageTexture:
	if _tex.has("br"):
		return _tex["br"]
	var size := 256
	var n := _noise(61, 0.5, 2).get_seamless_image(size, 4)
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := 0.88 + n.get_pixel(x, y % 4).r * 0.12
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["br"] = t
	return t


# --- Light and air -------------------------------------------------------------------------

## Sky, sun and air for a Counterform map. `tint` shifts the sky and fog per map (each map
## may have its own environment colour, §4.1); materials and light logic stay the same.
static func environment(parent: Node, sun_angle := Vector3(-48.0, -36.0, 0.0), tint := Color("#C9C2B4")) -> DirectionalLight3D:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#7F8A8E")
	sky_mat.sky_horizon_color = tint
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = tint.darkened(0.35)
	sky_mat.ground_horizon_color = tint.darkened(0.08)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.2
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.72
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = tint
	env.fog_light_energy = 0.8
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = sun_angle
	sun.light_color = Color("#FFF0DA")
	sun.light_energy = 1.3
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 110.0
	sun.add_to_group("fp_sun")
	parent.add_child(sun)
	# A weak cool fill from the other side, so backlit faces keep their geometry (§9.1).
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-20.0, sun_angle.y + 160.0, 0.0)
	fill.light_color = Color("#B8C4CC")
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	parent.add_child(fill)
	return sun


# --- The surreal backdrop --------------------------------------------------------------------

## A representative Counterform vista around `centre` (outside the playable area, no
## collision): concrete masses hanging in the air, an inverted tower, a stair that climbs
## into nothing and turns over, steel frames that repeat into the fog, a tilted slab
## pierced by a frame. Real materials, impossible relationships (§2, §8).
static func vista(parent: Node3D, centre: Vector3, radius := 150.0) -> Node3D:
	var root := Node3D.new()
	root.name = "CounterformVista"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	var conc := material("concrete", CONCRETE_MID)
	var conc_dark := material("concrete_dark", CONCRETE_DARK)
	var steel := material("paint", GRAPHITE)
	var oxide := material("paint", OXIDE_ORANGE)
	# 1. Floating monoliths: building-sized concrete slabs, some tilted, hanging in a ring.
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		var r := radius * rng.randf_range(0.9, 1.4)
		var size := Vector3(rng.randf_range(14, 30), rng.randf_range(40, 90), rng.randf_range(12, 26))
		var pos := centre + Vector3(cos(a) * r, rng.randf_range(25, 70), sin(a) * r)
		var rot := Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 90), rng.randf_range(-18, 18))
		_box(root, size, pos, rot, conc if i % 3 else conc_dark)
		# Windows / service slots on the face toward the centre: dark strips in graphite.
		for k in 4:
			var slot_y := pos.y - size.y * 0.35 + k * size.y * 0.22
			_box(root, Vector3(size.x * 0.7, 1.2, 0.6), Vector3(pos.x, slot_y, pos.z) - Vector3(cos(a), 0, sin(a)) * (size.z * 0.5),
				rot, steel)
	# 2. An inverted tower hanging from above the course: floors stacked downward.
	var top := centre + Vector3(-radius * 0.55, 120.0, -radius * 0.7)
	for f in 10:
		var w := 22.0 - f * 0.8
		_box(root, Vector3(w, 3.6, w), top - Vector3(0, f * 4.4, 0), Vector3(0, f * 3.0, 0), conc)
		_box(root, Vector3(w + 0.6, 0.5, w + 0.6), top - Vector3(0, f * 4.4 + 2.0, 0), Vector3(0, f * 3.0, 0), steel)
	# 3. A stair that rises into the air, reaches a landing, and carries on upside down.
	var s0 := centre + Vector3(radius * 0.7, 2.0, radius * 0.1)
	for k in 26:
		_box(root, Vector3(6.0, 0.5, 1.6), s0 + Vector3(0, k * 1.1, -k * 1.5), Vector3.ZERO, conc)
	var landing := s0 + Vector3(0, 26 * 1.1, -26 * 1.5)
	_box(root, Vector3(8.0, 1.0, 8.0), landing, Vector3.ZERO, conc_dark)
	for k in 26:
		_box(root, Vector3(6.0, 0.5, 1.6), landing + Vector3(0, 6.0 + k * 1.1, -4.0 - k * 1.5), Vector3(180, 0, 0), conc)
	_box(root, Vector3(0.3, 30.0, 0.3), s0 + Vector3(3.2, 15.0, -20.0), Vector3.ZERO, steel)
	# 4. Steel portal frames repeating into the fog: no start, no end in sight.
	var f0 := centre + Vector3(-radius * 0.9, 0.0, radius * 0.4)
	for k in 40:
		var p := f0 + Vector3(-k * 9.0, 0, -k * 2.5)
		_box(root, Vector3(0.7, 22.0, 0.7), p + Vector3(0, 11.0, -7.0), Vector3.ZERO, steel)
		_box(root, Vector3(0.7, 22.0, 0.7), p + Vector3(0, 11.0, 7.0), Vector3.ZERO, steel)
		_box(root, Vector3(0.9, 0.9, 15.0), p + Vector3(0, 22.0, 0), Vector3.ZERO, oxide if k % 7 == 0 else steel)
	# 5. A huge slab standing on its corner, pierced by a frame that should not fit.
	var c0 := centre + Vector3(radius * 0.15, 0.0, -radius * 1.1)
	_box(root, Vector3(60.0, 60.0, 8.0), c0 + Vector3(0, 30.0, 0), Vector3(0, 10, 45), conc)
	_box(root, Vector3(1.2, 1.2, 40.0), c0 + Vector3(0, 30.0, 0), Vector3(0, 10, 0), oxide)
	return root


static func _box(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
