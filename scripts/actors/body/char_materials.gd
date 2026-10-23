class_name CharMaterials
## The athlete's material set (character overhaul, Phase 2). Every surface class has its
## own roughness, metalness and surface grain, so cloth never reads as plastic and plates
## never read as cloth (Counterform §7: stylised realism, low saturation):
##
##   fabric     the suit: soft twill weave, matte (0.88), a faint colour drift
##   cordura    the plate carrier, pouches, belt: a coarse basket weave, matte (0.9)
##   webbing    straps and binding: a ribbed weave, a touch of sheen (0.78)
##   leather    boot uppers, glove palms: a fine pebble grain (0.62)
##   rubber     soles, knuckle guards, gaskets: very matte (0.94)
##   skin       the face: soft (0.55), desaturated, no shine
##   shell      helmet and hard plates: painted composite, semi-matte (0.58), scuffed
##   metal      buckles, rivets, rails: bare steel (0.32, metallic 0.9)
##   lens       goggles: a dark coated mirror
##
## The body is skinned, so its textures follow its UVs (metres: u round the limb, v along
## it); the rigid gear uses the same textures in object-space triplanar, which is safe on
## a piece that never bends. The athlete's gear is skinned too (bound to its bones), so it
## uses UVs as well: triplanar would swim as the bones move.

const SKIN_TONES := [Color("#A88A78"), Color("#8A6E5E"), Color("#C2A592"), Color("#6A5448"), Color("#9C8070")]

static var _cache := {}
static var _tex := {}


static func fabric(color: Color) -> StandardMaterial3D:
	return _make("fabric", color, func(m: StandardMaterial3D) -> void:
		m.albedo_texture = _drift()
		m.normal_enabled = true
		m.normal_texture = _weave("twill")
		m.normal_scale = 0.55
		m.roughness = 0.88
		m.uv1_scale = Vector3(14, 14, 1))


static func cordura(color: Color, rigid := true) -> StandardMaterial3D:
	return _make("cordura%s" % rigid, color, func(m: StandardMaterial3D) -> void:
		m.albedo_texture = _drift()
		m.normal_enabled = true
		m.normal_texture = _weave("basket")
		m.normal_scale = 0.8
		m.roughness = 0.9
		_planar(m, rigid, 22.0))


static func webbing(color: Color, rigid := false) -> StandardMaterial3D:
	return _make("webbing%s" % rigid, color, func(m: StandardMaterial3D) -> void:
		m.normal_enabled = true
		m.normal_texture = _weave("rib")
		m.normal_scale = 0.7
		m.roughness = 0.78
		_planar(m, rigid, 40.0))


static func leather(color: Color, rigid := false) -> StandardMaterial3D:
	return _make("leather%s" % rigid, color, func(m: StandardMaterial3D) -> void:
		m.albedo_texture = _drift()
		m.normal_enabled = true
		m.normal_texture = _pebble()
		m.normal_scale = 0.45
		m.roughness = 0.62
		if rigid:
			_planar(m, true, 18.0)
		else:
			m.uv1_scale = Vector3(18, 18, 1))


static func rubber(color: Color, rigid := true) -> StandardMaterial3D:
	return _make("rubber%s" % rigid, color, func(m: StandardMaterial3D) -> void:
		m.normal_enabled = true
		m.normal_texture = _pebble()
		m.normal_scale = 0.3
		m.roughness = 0.94
		_planar(m, rigid, 30.0))


static func skin(color: Color) -> StandardMaterial3D:
	return _make("skin", color, func(m: StandardMaterial3D) -> void:
		m.albedo_texture = _drift()
		m.roughness = 0.55
		m.normal_enabled = true
		m.normal_texture = _pebble()
		m.normal_scale = 0.12
		m.uv1_scale = Vector3(30, 30, 1))


static func shell(color: Color, rigid := false) -> StandardMaterial3D:
	return _make("shell%s" % rigid, color, func(m: StandardMaterial3D) -> void:
		m.albedo_texture = _scuffs()
		m.normal_enabled = true
		m.normal_texture = _pebble()
		m.normal_scale = 0.1
		m.roughness = 0.58
		m.metallic = 0.05
		_planar(m, rigid, 3.0))


static func metal(color: Color) -> StandardMaterial3D:
	return _make("metal", color, func(m: StandardMaterial3D) -> void:
		m.roughness = 0.32
		m.metallic = 0.9
		m.metallic_specular = 0.6)


static func lens(color: Color) -> StandardMaterial3D:
	return _make("lens", color, func(m: StandardMaterial3D) -> void:
		m.roughness = 0.06
		m.metallic = 0.8
		m.metallic_specular = 0.9)


## A flat signal colour (team band, visor slit): unshaded so it reads in any light.
static func signal_color(color: Color) -> StandardMaterial3D:
	return _make("signal", color, func(m: StandardMaterial3D) -> void:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED)


static func _make(kind: String, color: Color, setup: Callable) -> StandardMaterial3D:
	var key := "%s|%s" % [kind, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	setup.call(m)
	_cache[key] = m
	return m


## Rigid pieces: object-space triplanar (`per_m` repeats per metre); skinned: UVs.
static func _planar(m: StandardMaterial3D, rigid: bool, per_m: float) -> void:
	if rigid:
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE * per_m
	else:
		m.uv1_scale = Vector3(per_m, per_m, 1)


# --- Generated textures (cached for the session) ---------------------------------------

static func _weave(kind: String) -> ImageTexture:
	var key := "weave_" + kind
	if _tex.has(key):
		return _tex[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RF)
	for y in n:
		for x in n:
			var h := 0.0
			match kind:
				"twill":
					# Diagonal ribs, threads over two and under one.
					var d := fmod(float(x + y) / 6.0, 1.0)
					h = 0.5 + 0.5 * sin(d * TAU) * (0.7 + 0.3 * sin(float(x - y) * 0.9))
				"basket":
					var cx := int(x / 8) % 2
					var cy := int(y / 8) % 2
					var f := float(x % 8) / 8.0 if cx == cy else float(y % 8) / 8.0
					h = 0.25 + 0.75 * sin(f * PI)
				"rib":
					h = 0.5 + 0.5 * sin(float(y) / 4.0 * TAU)
			img.set_pixel(x, y, Color(h, 0, 0))
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(4.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func _pebble() -> ImageTexture:
	if _tex.has("pebble"):
		return _tex["pebble"]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.09
	noise.seed = 11
	var img := noise.get_seamless_image(128, 128)
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(3.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["pebble"] = t
	return t


## A soft colour drift around 1.0 (multiplied with the albedo colour).
static func _drift() -> ImageTexture:
	if _tex.has("drift"):
		return _tex["drift"]
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	noise.seed = 5
	var src := noise.get_seamless_image(128, 128)
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var v := 0.9 + 0.1 * src.get_pixel(x, y).r
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["drift"] = t
	return t


## Scuffs and grime for painted shells: light scratches, darker grime in patches.
static func _scuffs() -> ImageTexture:
	if _tex.has("scuffs"):
		return _tex["scuffs"]
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	noise.seed = 21
	var grime := noise.get_seamless_image(256, 256)
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for y in 256:
		for x in 256:
			var g := grime.get_pixel(x, y).r
			var v := 1.0 - maxf(g - 0.55, 0.0) * 0.6
			img.set_pixel(x, y, Color(v, v, v))
	for i in 70:
		var p := Vector2(rng.randf() * 256, rng.randf() * 256)
		var d := Vector2.from_angle(rng.randf() * TAU)
		for k in rng.randi_range(6, 20):
			var q := p + d * k
			var px := posmod(int(q.x), 256)
			var py := posmod(int(q.y), 256)
			img.set_pixel(px, py, Color(1.12, 1.12, 1.1))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["scuffs"] = t
	return t
