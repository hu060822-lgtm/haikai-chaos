class_name Faultprint
## FAULTPRINT (斷層印刷體): the one place the art style lives. Palette, surface materials,
## outlines and the world environment all come from here, so a later restyle only touches
## this file and the shaders.
##
##   Faultprint.surface(Faultprint.CONCRETE)               # a world-space printed surface
##   Faultprint.surface(Faultprint.ORANGE, {"pattern": 1})  # hatched instead of dotted
##   Faultprint.gun(Faultprint.BONE, "panel")               # object-space, for held guns
##   Faultprint.outline(node)                               # carbon silhouette (players, bots)

# --- Base palette (the art brief's six inks) -------------------------------------------
const CARBON := Color("#202124")   # outlines, shadows, mechanical gaps
const CONCRETE := Color("#AAA69C") # buildings, concrete, base surfaces
const BONE := Color("#E7E0D2")     # lit faces, clean geometric blocks, paper
const ORANGE := Color("#F05A35")   # movement routes, danger, key interactions
const TEAL := Color("#37A6A0")     # scene wayfinding, some UI
const YELLOW := Color("#D6B64A")   # warnings, machine labels

# --- Derived shades (mixes of the base inks; still the same print run) ------------------
const GRAPHITE := Color("#3B3D41")
const SLATE := Color("#6E6C66")
const DUST := Color("#C9C3B6")
const KRAFT := Color("#C08A5C")    # wood / paper-board parts
const OXIDE := Color("#B5523A")    # rust, red parts
const DEEP_TEAL := Color("#24706C")
const OCHRE := Color("#A88A35")

# --- Game information colours: never used by the environment ----------------------------
# Kept apart from the world palette so they can be swapped for colour-blind settings.
const INFO_ENEMY := Color("#FF2E63")
const INFO_ALLY := Color("#3FA7FF")
const INFO_HIT := Color("#FFFFFF")

const SURFACE := preload("res://shaders/faultprint.gdshader")
const OUTLINE := preload("res://shaders/fp_outline.gdshader")
const MISREG := preload("res://shaders/fp_misreg.gdshader")

# Looks (Settings.look): 0 the original light print, 1 soft (darker paper, calmer ink),
# 2 dark print (dark paper, pale inks). The surfaces switch live through the fp_soft and
# fp_dark shader globals; the UI colours below are read when a screen is built.
const LOOKS := ["原版", "柔和", "暗色印刷"]
const SOFT_PAPER := Color("#C2BBAD")
const DARK_PAPER := Color("#26272B")
const PAPERS := [BONE, SOFT_PAPER, DARK_PAPER]

static var ui_ink := CARBON        # UI text, borders
static var ui_paper := BONE        # UI panels
static var ui_dust := DUST         # UI preview panels
static var _cache := {}
static var _envs: Array[Environment] = []


## A printed surface in world space (walls, floors, props). `options` overrides any shader
## uniform: pattern, dot_density, wear, plate, plate_amount, shadow_tone, glow... and "slip":
## the colour of the off-register ghost around the silhouette (null = none).
static func surface(color: Color, options := {}) -> ShaderMaterial:
	var key := "s|%s|%s" % [color.to_html(), var_to_str(options)]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("paint", linear(color))
	m.set_shader_parameter("plate", linear(_plate_for(color)))
	var slip: Variant = options.get("slip", _plate_for(color))
	if slip != null:
		var s := ShaderMaterial.new()
		s.shader = MISREG
		s.set_shader_parameter("color", linear(slip))
		m.next_pass = s
	for k in options:
		if k == "slip":
			continue
		var v = options[k]
		if v is Color:
			var c := linear(v)
			v = Vector3(c.r, c.g, c.b) if k == "glow" else c
		m.set_shader_parameter(k, v)
	_cache[key] = m
	return m


## A gun part: object-space dots (they stay put on a moving gun), finer and with less wear.
## `kind` is the old HAIKAI texture name and picks the print treatment.
static func gun(color: Color, kind := "panel", glow := Color.BLACK) -> ShaderMaterial:
	var options := {"slip": null, "object_space": true, "dot_density": 150.0, "wear": 0.0, "grain": 0.02,
		"glow": glow, "shadow_tone": 0.58, "mid_tone": 0.86}
	match kind:
		"wood":
			options.pattern = 1
			options.dot_density = 110.0
		"grate":
			options.pattern = 1
			options.dot_density = 220.0
		"brass", "pipe":
			options.mid_ink = 0.12
		"rust_metal", "concrete":
			options.dot_density = 190.0
			options.shadow_ink = 0.7
	return surface(color, options)


## The off-register second plate: teal under warm inks, orange under cool ones, carbon
## under the darkest so it reads as a misprint rather than a colour.
static func _plate_for(color: Color) -> Color:
	if color.get_luminance() < 0.2:
		return SLATE
	if color.h < 0.17 or color.h > 0.9:
		return TEAL if color.s > 0.25 else ORANGE
	return ORANGE


## Adds a carbon inverted-hull silhouette to every mesh under `node`. Only for things the
## player has to pick out at speed (players, bots): the world gets its edges from geometry.
static func outline(node: Node, width := 0.03, color := CARBON) -> void:
	if Settings.look == 2 and color == CARBON:
		color = DUST
	var m := ShaderMaterial.new()
	m.shader = OUTLINE
	m.set_shader_parameter("color", linear(color))
	m.set_shader_parameter("width", width)
	for child in _meshes(node):
		var base := child.material_override
		if base == null:
			continue
		var copy := base.duplicate() as Material
		copy.next_pass = m
		child.material_override = copy


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out


## Shader colour uniforms are linear; the palette is written as sRGB hex.
static func linear(c: Color) -> Color:
	return c.srgb_to_linear()


## Flat, untextured colour for UI-ish 3D bits (tracers, markers). Unshaded.
static func flat(color: Color, through_walls := false) -> StandardMaterial3D:
	var key := "f|%s|%s" % [color.to_html(), through_walls]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = through_walls
	_cache[key] = m
	return m


## The world environment and sun every FAULTPRINT scene uses: paper-coloured sky, no ambient
## light (the surface shader paints its own shadow tone), linear tone mapping so the inks
## come out as their hex values.
static func environment(parent: Node, sun_angle := Vector3(-52.0, -38.0, 0.0)) -> DirectionalLight3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = PAPERS[Settings.look]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	env.fog_light_color = BONE
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	_envs = _envs.filter(func(e: Environment) -> bool: return is_instance_valid(e) and e.get_reference_count() > 1)
	_envs.append(env)
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = sun_angle
	sun.light_color = Color.WHITE
	sun.light_energy = 1.0
	sun.add_to_group("fp_sun")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	parent.add_child(sun)
	return sun


## Switches every printed surface (live) and the UI palette (for screens built after this).
static func set_look(look: int) -> void:
	RenderingServer.global_shader_parameter_set("fp_soft", 1.0 if look == 1 else 0.0)
	RenderingServer.global_shader_parameter_set("fp_dark", 1.0 if look == 2 else 0.0)
	var dark := look == 2
	ui_ink = Color("#E7E0D2") if dark else CARBON
	ui_paper = Color("#2E3034") if dark else BONE
	ui_dust = Color("#3E4045") if dark else DUST
	for e in _envs:
		if is_instance_valid(e):
			e.background_color = PAPERS[look]
