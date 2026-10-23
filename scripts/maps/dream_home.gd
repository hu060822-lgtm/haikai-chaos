class_name DreamHome
extends Node3D
## 夢核之家 DREAM HOME: the second team map. A house you half remember from childhood,
## too big and too quiet: pastel rooms, carpet, a tiled pool with no water, doors in the
## sky, a hallway that doesn't end. A low, endless late-afternoon sun and pastel haze.
##
##   south (blue spawn)   the nursery: sky-blue walls, cloud wallpaper, giant crib bars
##   north (red spawn)    the pink living room: a giant TV full of static, sofa walls
##   centre               the empty pool: tiled, 1.6 m deep, ramps at both ends to slide
##                        in and out, steps on the long sides, a giant rubber duck
##   west                 the endless hallway: low ceiling, fluorescent panels, repeating
##                        doors; its inner wall is runnable, its roof is a walkway
##   east                 the dining hall: a giant table to jump on and slide under, giant
##                        chairs as steps, bookshelves to climb to the mezzanine
##   up (y 4.5–5)         west roof walkway, east mezzanine, and the north and south
##                        beams that cross the house between them
##   movement (C4)        wallpaper panels floating over the pool to wall-run across it,
##                        floating toy blocks that step up to each beam, two giant
##                        playground slides from the walkways down to the deck
##
## Everything here builds its own materials (clean pastel paint, carpet, tile, checker),
## not the concrete kit.
##
## C5: the house is now the middle of a map about 145 × 100 m. Doors in its walls lead
## out into the dream around it, built from a floor plan (Layout) turned half round:
##   spawns         blue in the sunroom south of the house, red in the one north of it
##   site A (west)  the poolrooms: white tile, shallow water-blue floor, tiled pillars
##   site B (east)  the same turned round
##   corridors      the yellow backrooms between: long, humming, more than one way

const HALF := Vector2(34, 26)
const POOL := Rect2(-10, -7, 20, 14)
const POOL_DEPTH := 1.6
const UP := 4.5
const WALL_H := 9.0
const AREA := Rect2(-80, -52, 160, 104)
const OUTER_H := 7.0
const DOOR_W := 6.0
const DOOR_H := 3.4
## Doors through the house's walls: south at these x (north at the same turned round),
## east at SIDE_DOOR_Z, west at -SIDE_DOOR_Z.
const DOOR_X := [-8.0, 18.0]
const SIDE_DOOR_Z := 21.0

## Palette: pastel, slightly sun-bleached.
const SKY_BLUE := Color("#8EC5F0")
const BABY_PINK := Color("#F3AFC6")
const MINT := Color("#A6E3C4")
const LILAC := Color("#BBA6EE")
const BUTTER := Color("#F7DE86")
const CREAM := Color("#DDD0BF")
const PEACH := Color("#F7C7A8")
const TILE_AQUA := Color("#7FD0D8")
const CARPET := Color("#CBB2CF")
const DOOR_WHITE := Color("#E9E3D8")
const TOY_RED := Color("#F08A8A")

var player_spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 21.5))
var bot_spawns: Array[Vector3] = []
var waypoints: Array[Vector3] = []
var range_targets: Array[Transform3D] = []
## Team match: each team's spawn zone centre and spawn points (blue south, red north).
var team_zones: Array[Vector3] = [Vector3(0, 0, 44), Vector3(0, 0, -44)]
## 預算戰's overclock zone: the bottom of the empty pool.
var mid_zone := Vector3(0, -POOL_DEPTH, 0)
## 爆破's bomb sites: A in the west poolrooms, B in the east ones.
var bomb_sites: Array = [Vector3(-60, 0, -2), Vector3(60, 0, 2)]
var team_spawns: Array = [
	[Vector3(0, 0.1, 44), Vector3(-3, 0.1, 44), Vector3(3, 0.1, 44), Vector3(-1.5, 0.1, 46.5), Vector3(1.5, 0.1, 46.5)],
	[Vector3(0, 0.1, -44), Vector3(-3, 0.1, -44), Vector3(3, 0.1, -44), Vector3(-1.5, 0.1, -46.5), Vector3(1.5, 0.1, -46.5)],
]
var layout: Layout
var play_area := AREA
var lowest_floor := -POOL_DEPTH

static var _tex := {}
static var _mats := {}


func _ready() -> void:
	name = "DreamHome"
	_environment()
	_plan()
	_floors()
	_pool()
	_outer_walls()
	_wings()
	_nursery()
	_living_room()
	_hallway()
	_dining_hall()
	_upper()
	_middle_cover()
	_dream_sky()
	_movement()
	bot_spawns = [Vector3(-14, 0.1, 12), Vector3(14, 0.1, -12), Vector3(0, -1.5, 0), Vector3(-28, 0.1, 0), Vector3(22, 0.1, 10)]
	waypoints = layout.wander_points(5)


# --- Materials -------------------------------------------------------------------------

static func _image(key: String, size: int, fill: Callable) -> ImageTexture:
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, fill.call(x, y))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Tiny value noise for speckle (deterministic).
static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## A clean material: `kind` paint, carpet, tile, checker, stripes, glow.
static func mat(kind: String, color: Color, color_b := Color.WHITE, scale := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [kind, color.to_html(), color_b.to_html(), scale]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 6.0
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match kind:
		"paint":
			# Flat paint with a faint sun-bleached mottle.
			m.albedo_texture = _image("paint" + color.to_html(), 64, func(x: int, y: int) -> Color:
				var n := _hash(x / 8, y / 8) * 0.5 + _hash(x, y) * 0.5
				return color.lightened(0.04 * n).darkened(0.03 * (1.0 - n)))
			m.uv1_scale = Vector3.ONE / 4.0
			m.roughness = 0.9
		"carpet":
			m.albedo_texture = _image("carpet" + color.to_html(), 128, func(x: int, y: int) -> Color:
				return color.darkened(0.12 * _hash(x, y) + 0.05 * _hash(x / 4, y / 4)))
			m.uv1_scale = Vector3.ONE / 1.5
			m.roughness = 1.0
		"tile":
			# Square tiles with grout lines; glossy.
			m.albedo_texture = _image("tile" + color.to_html(), 128, func(x: int, y: int) -> Color:
				var grout := x % 64 < 3 or y % 64 < 3
				return CREAM.darkened(0.15) if grout else color.lightened(0.05 * _hash(x / 64, y / 64)))
			m.uv1_scale = Vector3.ONE / 1.0
			m.roughness = 0.22
			m.metallic_specular = 0.7
		"checker":
			m.albedo_texture = _image("checker" + color.to_html() + color_b.to_html(), 128, func(x: int, y: int) -> Color:
				return color if ((x / 64) + (y / 64)) % 2 == 0 else color_b)
			m.uv1_scale = Vector3.ONE / (1.6 * scale)
			m.roughness = 0.35
		"stripes":
			# Wallpaper: soft vertical stripes with a thin line between.
			m.albedo_texture = _image("stripes" + color.to_html() + color_b.to_html(), 128, func(x: int, y: int) -> Color:
				var band := (x / 32) % 2 == 0
				return (color if band else color_b) if x % 32 > 1 else color.darkened(0.08))
			m.uv1_scale = Vector3.ONE / 1.2
		"clouds":
			# Cloud wallpaper: white puffs on blue.
			m.albedo_texture = _image("clouds" + color.to_html(), 128, func(x: int, y: int) -> Color:
				var c := 0.0
				for k in 3:
					var cx := float((k * 47 + 20) % 128)
					var cy := float((k * 71 + 30) % 128)
					var dx := minf(absf(x - cx), 128 - absf(x - cx))
					var dy := minf(absf(y - cy), 128 - absf(y - cy)) * 1.8
					c = maxf(c, clampf(1.0 - sqrt(dx * dx + dy * dy) / 14.0, 0.0, 1.0))
				return color.lerp(Color.WHITE, smoothstep(0.0, 0.25, c)))
			m.uv1_scale = Vector3.ONE / 3.0
		"glow":
			m.albedo_color = color
			m.uv1_triplanar = false
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 1.6 * scale
			m.roughness = 1.0
		"static":
			m.uv1_triplanar = false
			m.albedo_texture = _image("static", 128, func(x: int, y: int) -> Color:
				var v := _hash(x * 3, y * 7)
				return Color(v, v, v * 1.05))
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission = Color(0.8, 0.85, 1.0)
			m.emission_energy_multiplier = 1.2
		"water":
			m.albedo_color = Color(color, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic_specular = 1.0
			m.uv1_triplanar = false
		"cloud":
			m.albedo_color = color
			m.uv1_triplanar = false
			m.roughness = 1.0
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 0.15
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_mats[key] = m
	return m


# --- Building ----------------------------------------------------------------------------

## A solid box (collision matches the mesh), centred at `pos`.
func box(size: Vector3, pos: Vector3, material: Material, yaw := 0.0, runnable := false, visible_mesh := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Geo.WORLD | (Geo.RUNNABLE if runnable else 0)
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees.y = yaw
	if runnable:
		body.add_to_group("runnable")
	var mi := MeshInstance3D.new()
	mi.mesh = LowPoly.chamfer_box(size, minf(0.05, size[size.min_axis_index()] * 0.2))
	mi.material_override = material
	mi.visible = visible_mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body


## Decoration only (no collision).
func deco(mesh: Mesh, xform: Transform3D, material: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	mi.material_override = material
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A floor slab with its top at `top` covering the rectangle a..b.
func floor_at(a: Vector2, b: Vector2, top: float, material: Material, thick := 1.0) -> StaticBody3D:
	return box(Vector3(absf(b.x - a.x), thick, absf(b.y - a.y)), Vector3((a.x + b.x) / 2.0, top - thick / 2.0, (a.y + b.y) / 2.0),
		material)


## A wall from a to b (ground plan), bottom at `bottom`.
func wall(a: Vector2, b: Vector2, height: float, material: Material, thick := 0.5, bottom := 0.0, runnable := false) -> StaticBody3D:
	var d := b - a
	var body := box(Vector3(d.length(), height, thick), Vector3((a.x + b.x) / 2.0, bottom + height / 2.0, (a.y + b.y) / 2.0),
		material, rad_to_deg(atan2(-d.y, d.x)), runnable)
	if runnable:
		# The runnable band, in peach: the same language as the orange bands elsewhere.
		for side in [-1.0, 1.0]:
			var band := MeshInstance3D.new()
			band.mesh = LowPoly.chamfer_box(Vector3(d.length() - 0.6, 0.2, 0.03), 0.01)
			band.position = Vector3(0, minf(height * 0.5, 2.6) - height / 2.0, side * (thick / 2.0 + 0.01))
			band.material_override = mat("glow", Color("#FFB08A"), Color.WHITE, 0.25)
			body.add_child(band)
	return body


## Straight stairs: from `from` (front edge of the first step) along `dir`, rising `rise`.
func stairs(from: Vector3, dir: Vector3, rise: float, width: float, material: Material) -> void:
	var steps := int(ceil(rise / 0.3))
	var step_h := rise / steps
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	for i in steps:
		var h := step_h * (i + 1)
		box(Vector3(width, h, 0.42), from + dir * (0.42 * i + 0.21) + Vector3(0, h / 2.0, 0), material, yaw)


## A ramp surface from `low` to `high` (top surface points), `width` wide.
func ramp(low: Vector3, high: Vector3, width: float, material: Material, thick := 0.6) -> StaticBody3D:
	var d := high - low
	var body := box(Vector3(width, thick, d.length()), (low + high) / 2.0, material)
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	body.basis = basis
	body.position = (low + high) / 2.0 - basis.y * thick / 2.0
	return body


# --- The house -------------------------------------------------------------------------

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#6A9BD3")
	sky_mat.sky_horizon_color = Color("#F2C6CF")
	sky_mat.sky_curve = 0.18
	sky_mat.ground_horizon_color = Color("#F2C6CF")
	sky_mat.ground_bottom_color = Color("#D9B8C8")
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.38
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.58
	env.tonemap_white = 4.0
	env.fog_enabled = true
	env.fog_light_color = Color("#E9C9D6")
	env.fog_light_energy = 0.8
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# Low and warm: the afternoon that never ends, with long shadows across the carpet.
	sun.rotation_degrees = Vector3(-34, -30, 0)
	sun.light_color = Color("#FFD8B0")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_blur = 3.0
	sun.directional_shadow_max_distance = 110.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.add_to_group("fp_sun")
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.light_color = Color("#D8E4FF")
	fill.light_energy = 0.25
	fill.light_specular = 0.0
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)


func _floors() -> void:
	var carpet := mat("carpet", CARPET)
	var checker := mat("checker", CREAM, Color("#C9A7B8"), 1.0)
	# Ground around the pool hole, then special floors laid on top (2 cm).
	floor_at(Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, POOL.position.y), 0.0, carpet)
	floor_at(Vector2(-HALF.x, POOL.end.y), Vector2(HALF.x, HALF.y), 0.0, carpet)
	floor_at(Vector2(-HALF.x, POOL.position.y), Vector2(POOL.position.x, POOL.end.y), 0.0, checker)
	floor_at(Vector2(POOL.end.x, POOL.position.y), Vector2(HALF.x, POOL.end.y), 0.0, checker)
	# The pool deck: a checker ring around the pool.
	for r in [[Vector2(-14, -11), Vector2(14, POOL.position.y)], [Vector2(-14, POOL.end.y), Vector2(14, 11)]]:
		floor_at(r[0], r[1], 0.02, checker, 0.1)
	# Room carpets.
	floor_at(Vector2(-20, 15), Vector2(20, HALF.y), 0.02, mat("carpet", Color("#BFD9F0")), 0.1)
	floor_at(Vector2(-20, -HALF.y), Vector2(20, -15), 0.02, mat("carpet", Color("#F2C4D3")), 0.1)


func _pool() -> void:
	var tile := mat("tile", TILE_AQUA)
	var deep := -POOL_DEPTH
	var inner := Rect2(POOL.position.x + 4.0, POOL.position.y, POOL.size.x - 8.0, POOL.size.y)
	# The bottom.
	floor_at(Vector2(inner.position.x, inner.position.y), Vector2(inner.end.x, inner.end.y), deep, tile)
	# Ramps at both ends (slide in, slide-jump out).
	ramp(Vector3(inner.position.x, deep, 0), Vector3(POOL.position.x, 0.0, 0), POOL.size.y, tile)
	ramp(Vector3(inner.end.x, deep, 0), Vector3(POOL.end.x, 0.0, 0), POOL.size.y, tile)
	# Tile walls on the long sides (with a lip), and steps in the middle of each.
	for z in [POOL.position.y - 0.25, POOL.end.y + 0.25]:
		box(Vector3(POOL.size.x, POOL_DEPTH, 0.5), Vector3(0, deep / 2.0, z), tile)
		deco(LowPoly.chamfer_box(Vector3(POOL.size.x + 0.6, 0.03, 0.7), 0.01), LowPoly.at(Vector3(0, 0.035, z)), mat("paint", DOOR_WHITE))
	for side in [-1.0, 1.0]:
		var edge := POOL.end.y if side > 0 else POOL.position.y
		for i in 5:
			var h := POOL_DEPTH * (5 - i) / 5.0
			box(Vector3(3.0, h, 0.45), Vector3(0, deep + h / 2.0, edge - side * (0.22 + i * 0.45)), tile)
	# A thin sheet of water that isn't there: only a reflection on the deep end's floor.
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(inner.size.x - 0.4, inner.size.y - 0.4)
	deco(sheet, Transform3D(Basis.IDENTITY, Vector3(inner.get_center().x, deep + 0.03, inner.get_center().y)),
		mat("water", Color("#C9F1F4")), false)
	# Lane lines on the bottom.
	for x in [-3.0, 0.0, 3.0]:
		deco(LowPoly.chamfer_box(Vector3(0.25, 0.02, inner.size.y - 2.0), 0.005),
			Transform3D(Basis.IDENTITY, Vector3(x, deep + 0.02, 0)), mat("paint", Color("#5AA9C6")), false)
	# Pool ladders (decor) and the giant rubber duck (cover).
	for x in [-5.0, 5.0]:
		for z in [POOL.position.y + 0.15, POOL.end.y - 0.15]:
			for k in 2:
				deco(LowPoly.prism(8, 0.05, 0.05, 2.2), LowPoly.at(Vector3(x + k * 0.6, deep + 0.6, z)),
					mat("paint", Color("#D8DDE2")))
	_duck(Vector3(-1.5, deep, -1.0))


func _duck(at: Vector3) -> void:
	var yellow := mat("paint", Color("#FFD94D"))
	box(Vector3(2.4, 1.6, 1.8), at + Vector3(0, 0.8, 0), yellow, 20.0, false, false)
	deco(LowPoly.blob(1.3, Vector3(1.25, 0.8, 0.95), 2), LowPoly.at(at + Vector3(0, 0.95, 0), Vector3(0, 20, 0)), yellow)
	deco(LowPoly.blob(0.75, Vector3.ONE, 2), LowPoly.at(at + Vector3(0.75, 2.05, 0.25)), yellow)
	deco(LowPoly.blob(0.35, Vector3(1.3, 0.5, 0.9), 1), LowPoly.at(at + Vector3(1.35, 1.95, 0.45), Vector3(0, 20, 0)),
		mat("paint", Color("#F59A3B")))
	for side in [-0.32, 0.32]:
		deco(LowPoly.blob(0.09, Vector3.ONE, 1), LowPoly.at(at + Vector3(1.2, 2.3, 0.25 + side)), mat("paint", Color("#2A2A33")))


func _outer_walls() -> void:
	var paper := mat("stripes", CREAM, Color("#F7E3EA"))
	# North and south walls carry their rooms' colours; east and west are long and runnable
	# above the walkway level. Doors (C5) lead out to the rest of the dream.
	for z in [-HALF.y - 0.5, HALF.y + 0.5]:
		var m := mat("stripes", BABY_PINK, Color("#F9D7E2")) if z < 0.0 else mat("clouds", SKY_BLUE)
		var doors: Array = DOOR_X.map(func(x: float) -> float: return x if z > 0.0 else -x)
		doors.sort()
		var x0 := -HALF.x - 1.0
		for d in doors:
			box(Vector3(d - DOOR_W / 2.0 - x0, WALL_H, 1.0), Vector3((x0 + d - DOOR_W / 2.0) / 2.0, WALL_H / 2.0, z), m)
			box(Vector3(DOOR_W, WALL_H - DOOR_H, 1.0), Vector3(d, (WALL_H + DOOR_H) / 2.0, z), m)
			_door_frame(Vector3(d, 0, z), true)
			x0 = d + DOOR_W / 2.0
		box(Vector3(HALF.x + 1.0 - x0, WALL_H, 1.0), Vector3((x0 + HALF.x + 1.0) / 2.0, WALL_H / 2.0, z), m)
	for x in [-HALF.x - 0.5, HALF.x + 0.5]:
		var dz := SIDE_DOOR_Z * signf(x)
		wall(Vector2(x, -HALF.y), Vector2(x, dz - DOOR_W / 2.0), WALL_H, paper, 1.0, 0.0, true)
		wall(Vector2(x, dz + DOOR_W / 2.0), Vector2(x, HALF.y), WALL_H, paper, 1.0, 0.0, true)
		box(Vector3(1.0, WALL_H - DOOR_H, DOOR_W), Vector3(x, (WALL_H + DOOR_H) / 2.0, dz), paper)
		_door_frame(Vector3(x, 0, dz), false)
	# Nothing gets over the house's walls.
	for z in [-HALF.y - 0.5, HALF.y + 0.5]:
		Layout.barrier(self, Vector3(HALF.x * 2 + 2, Layout.CEILING - WALL_H, 1.0), Vector3(0, (Layout.CEILING + WALL_H) / 2.0, z))
	for x in [-HALF.x - 0.5, HALF.x + 0.5]:
		Layout.barrier(self, Vector3(1.0, Layout.CEILING - WALL_H, HALF.y * 2 + 2), Vector3(x, (Layout.CEILING + WALL_H) / 2.0, 0))
	# Baseboards.
	for z in [-HALF.y + 0.05, HALF.y - 0.05]:
		deco(LowPoly.chamfer_box(Vector3(HALF.x * 2, 0.25, 0.1), 0.01), LowPoly.at(Vector3(0, 0.125, z)), mat("paint", DOOR_WHITE))
	# Windows full of sky (glowing, a little too bright), high on the long walls.
	for i in 6:
		var z := -20.0 + i * 8.0
		for x in [-HALF.x + 0.02, HALF.x - 0.02]:
			var w := deco(QuadMesh.new(), Transform3D(Basis(Vector3.UP, PI / 2.0 if x < 0 else -PI / 2.0).scaled(Vector3(2.4, 3.0, 1)),
				Vector3(x, 6.6, z)), mat("glow", Color("#CFEAFF"), Color.WHITE, 0.35), false)
			w.name = "SkyWindow"


## A white door frame round a doorway in an outer wall.
func _door_frame(at: Vector3, across_x: bool) -> void:
	var white := mat("paint", DOOR_WHITE)
	for side in [-1.0, 1.0]:
		var off := Vector3(side * (DOOR_W / 2.0 + 0.1), 0, 0) if across_x else Vector3(0, 0, side * (DOOR_W / 2.0 + 0.1))
		deco(LowPoly.chamfer_box(Vector3(0.2, DOOR_H, 1.3) if across_x else Vector3(1.3, DOOR_H, 0.2), 0.02),
			LowPoly.at(at + off + Vector3(0, DOOR_H / 2.0, 0)), white)
	deco(LowPoly.chamfer_box(Vector3(DOOR_W + 0.4, 0.25, 1.3) if across_x else Vector3(1.3, 0.25, DOOR_W + 0.4), 0.02),
		LowPoly.at(at + Vector3(0, DOOR_H + 0.12, 0)), white)


## The floor plan (see FoldedWorks._plan): the house in the middle ('x'), its walls ('o')
## with doors, the dream around it carved out of solid wall, turned half round.
func _plan() -> void:
	var g := Layout.new(AREA, 2.0)
	layout = g
	g.carve(Rect2(-HALF.x - 2, -HALF.y - 2, HALF.x * 2 + 4, HALF.y * 2 + 4), "x")
	for r in [Rect2(-HALF.x - 2, -HALF.y - 2, HALF.x * 2 + 4, 2), Rect2(-HALF.x - 2, HALF.y, HALF.x * 2 + 4, 2),
			Rect2(-HALF.x - 2, -HALF.y - 2, 2, HALF.y * 2 + 4), Rect2(HALF.x, -HALF.y - 2, 2, HALF.y * 2 + 4)]:
		g.carve(r, "o")
	for x in DOOR_X:
		g.carve2(Rect2(x - DOOR_W / 2.0, HALF.y, DOOR_W, 2))
	g.carve2(Rect2(HALF.x, SIDE_DOOR_Z - DOOR_W / 2.0, 2, DOOR_W))
	# Inside the house, what bots must walk round: the pool's long sides are steps (fine),
	# the hallway's inner wall, the crib, the TV, the table's legs, the bookshelves.
	g.carve(Rect2(-25.4, -18, 0.8, 8.4), "o")
	g.carve(Rect2(-25.4, 9.6, 0.8, 8.4), "o")
	g.carve(Rect2(-17.6, 19, 6.2, 4), "o")
	g.carve(Rect2(-7, -HALF.y, 14, 2.2), "o")
	for z in [-12.0, 0.0, 12.0]:
		g.carve(Rect2(24.2, z - 1.6, 2.0, 3.2), "o")
	# The dream outside.
	g.carve2(Rect2(-14, 38, 28, 12), "s")
	g.carve2(Rect2(-11, 28, 6, 10))                    # sunroom -> house (south door, x -8)
	g.carve2(Rect2(15, 28, 6, 14))                     # house's other south door -> east corridor
	g.carve2(Rect2(14, 42, 44, 6))                     # sunroom -> east, toward B
	g.carve2(Rect2(52, 18, 6, 30))                     # ... north into B
	g.carve2(Rect2(-48, 42, 34, 6))                    # sunroom -> west, toward A
	g.carve2(Rect2(-48, 16, 6, 32))                    # ... north into A
	g.carve2(Rect2(-44, -SIDE_DOOR_Z - DOOR_W / 2.0, 8, DOOR_W))   # house's west door -> A
	# A side room on each corridor: a short cut between the two lanes behind the spawn.
	g.carve2(Rect2(-34, 30, 12, 12))
	g.carve2(Rect2(-30, 28, 4, 2))
	var site := Rect2(-72, -24, 28, 40)
	g.carve(site, "a")
	g.carve(g.turned(site), "b")
	for c in POOLROOM_PILLARS:
		g.carve2(Rect2(c.x - 1.0, c.y - 1.0, 2.0, 2.0), "c")


## Tiled pillars in poolroom A (B has them turned round).
const POOLROOM_PILLARS := [Vector2(-66, -16), Vector2(-66, -2), Vector2(-66, 10), Vector2(-54, -12), Vector2(-52, 6),
	Vector2(-60, 12)]


## The dream around the house: yellow corridors, two poolrooms, the sunrooms.
func _wings() -> void:
	var backrooms := mat("stripes", Color("#E8D9A0"), Color("#DCCB8A"))
	var tile_wall := mat("tile", Color("#EEF4F2"))
	var n := [0]
	# C7: back-room crawlways through the thick blocks by the top lanes, one with a window.
	layout.carve_cells2(Rect2i(14, 8, 15, 1))
	layout.carve_cells2(Rect2i(21, 5, 1, 3))
	layout.carve_cells2(Rect2i(33, 8, 9, 1))
	layout.window2(Vector2i(25, 8), Vector2i(1, 0))
	layout.mark_breaches(2)  # C6: rammable shortcuts
	layout.cut_passages(4)  # C7: small passages, vault windows, ledges
	layout.cut_windows(2)
	layout.add_ledges(6)
	PhysProp.scatter(self, layout, 36, [BABY_PINK, MINT, LILAC, BUTTER, SKY_BLUE, TOY_RED])  # C7: loose things
	layout.build_walls(self, OUTER_H, func(size: Vector3, at: Vector3) -> void:
		var near_site := absf(at.x) > 40.0 and absf(at.z) < 28.0
		box(size, at, tile_wall if near_site else backrooms, 0.0, true)
		n[0] += 1)
	# Floors: a base under everything (and the pool's hole cut out of it by the house's own
	# floors sitting on top), then each area's own.
	floor_at(AREA.position, Vector2(AREA.end.x, -HALF.y - 1.0), -0.02, mat("carpet", Color("#CDBB86")))
	floor_at(Vector2(AREA.position.x, HALF.y + 1.0), AREA.end, -0.02, mat("carpet", Color("#CDBB86")))
	floor_at(Vector2(AREA.position.x, -HALF.y - 1.0), Vector2(-HALF.x - 1.0, HALF.y + 1.0), -0.02, mat("carpet", Color("#CDBB86")))
	floor_at(Vector2(HALF.x + 1.0, -HALF.y - 1.0), Vector2(AREA.end.x, HALF.y + 1.0), -0.02, mat("carpet", Color("#CDBB86")))
	for r in layout.rects("ab"):
		floor_at(r.position, r.end, 0.02, mat("tile", TILE_AQUA), 0.1)
	for r in layout.rects("s"):
		floor_at(r.position, r.end, 0.02, mat("checker", CREAM, Color("#BFD9F0"), 1.0), 0.1)
	# The ring under the house's walls (C8): the house's floor stops at HALF and the dream's
	# starts a metre further out, so anything cut through the walls (doors, panels,
	# passages) used to open onto a metre-wide hole.
	var ring := mat("carpet", CARPET)
	floor_at(Vector2(-HALF.x - 1.0, -HALF.y - 1.0), Vector2(HALF.x + 1.0, -HALF.y), 0.0, ring)
	floor_at(Vector2(-HALF.x - 1.0, HALF.y), Vector2(HALF.x + 1.0, HALF.y + 1.0), 0.0, ring)
	floor_at(Vector2(-HALF.x - 1.0, -HALF.y), Vector2(-HALF.x, HALF.y), 0.0, ring)
	floor_at(Vector2(HALF.x, -HALF.y), Vector2(HALF.x + 1.0, HALF.y), 0.0, ring)
	# The door strips through the house's walls (the house's floor stops at its walls).
	for r in layout.rects("."):
		var inside_wall := Rect2(-HALF.x - 2, -HALF.y - 2, HALF.x * 2 + 4, HALF.y * 2 + 4).encloses(r)
		if inside_wall:
			floor_at(r.position, r.end, 0.0, mat("carpet", CARPET))
	for c in POOLROOM_PILLARS:
		for p in [Vector3(c.x, 0, c.y), Layout.turn(Vector3(c.x, 0, c.y))]:
			box(Vector3(2.0, OUTER_H, 2.0), p + Vector3(0, OUTER_H / 2.0, 0), tile_wall)
	# Poolrooms: a shallow step down, a lifeguard chair to hold from, a ladder of light.
	for flip in [false, true]:
		var chair := Vector3(-70, 0, 4) if not flip else Layout.turn(Vector3(-70, 0, 4))
		box(Vector3(3.0, 2.6, 3.0), chair + Vector3(0, 1.3, 0), mat("paint", Color.WHITE))
		var way := Vector3(-1, 0, 0) if not flip else Vector3(1, 0, 0)
		stairs(chair - way * 5.3, way, 2.6, 1.6, mat("paint", DOOR_WHITE))
		for k in 6:
			var z := -20.0 + k * 7.0
			var p := Vector3(-58, OUTER_H - 0.05, z) if not flip else Layout.turn(Vector3(-58, OUTER_H - 0.05, z))
			deco(LowPoly.chamfer_box(Vector3(2.4, 0.06, 1.0), 0.01), LowPoly.at(p), mat("glow", Color("#E8FFFF"), Color.WHITE, 1.0), false)
	# Corridor cover: laundry baskets, a vending machine that hums, a lost armchair.
	for p in [Vector3(-45, 0, 30), Vector3(-30, 0, 45), Vector3(36, 0, 45), Vector3(55, 0, 30), Vector3(-28, 0, 36)]:
		for q in [p, Layout.turn(p)]:
			box(Vector3(1.8, 1.3, 1.8), q + Vector3(0, 0.65, 0), mat("paint", PEACH if int(absf(q.x)) % 2 == 0 else LILAC), 25.0)
	var hum := Color("#FFF6C8")
	for p in [Vector3(-45, 5.5, 44), Vector3(36, 5.5, 45), Vector3(0, 5.5, 44), Vector3(-60, 6.0, 0)]:
		for q in [p, Layout.turn(p)]:
			var l := OmniLight3D.new()
			l.position = q
			l.light_color = hum if absf(q.x) < 40.0 else Color("#DFFFFF")
			l.light_energy = 0.8
			l.omni_range = 20.0
			add_child(l)
	for i in 2:
		var l := Label3D.new()
		l.text = "AB"[i]
		l.font_size = 900
		l.pixel_size = 0.009
		l.modulate = Color("#F08A8A") if i == 0 else Color("#8EC5F0")
		l.position = Vector3(-71.9, 4.2, -4) if i == 0 else Vector3(71.9, 4.2, 4)
		l.rotation_degrees = Vector3(0, 90 if i == 0 else -90, 0)
		l.shaded = false
		add_child(l)


func _nursery() -> void:
	var blue := mat("clouds", SKY_BLUE)
	var white := mat("paint", DOOR_WHITE)
	# Divider with three openings: the room reads as a room, the spawn is shielded.
	for seg in [[-20.0, -8.0], [-3.0, 3.0], [8.0, 20.0]]:
		wall(Vector2(seg[0], 15.0), Vector2(seg[1], 15.0), 3.4, blue, 0.5)
		box(Vector3(seg[1] - seg[0] + 0.2, 0.2, 0.7), Vector3((seg[0] + seg[1]) / 2.0, 3.5, 15.0), white)
	# The giant crib: bars you can see (and shoot) through, a mattress to stand on.
	var crib := Vector3(-14.5, 0, 21.0)
	box(Vector3(6.0, 1.0, 3.6), crib + Vector3(0, 0.5, 0), white)
	box(Vector3(5.8, 0.4, 3.4), crib + Vector3(0, 1.2, 0), mat("paint", Color("#FDF6FA")))
	for i in 13:
		var x := -2.9 + i * (5.8 / 12.0)
		for z in [-1.75, 1.75]:
			box(Vector3(0.14, 2.2, 0.14), crib + Vector3(x, 2.1, z), white)
	for z in [-1.75, 1.75]:
		box(Vector3(6.0, 0.18, 0.22), crib + Vector3(0, 3.2, z), white)
	# Toy blocks with letters (cover), a mobile of stars over the spawn.
	_toy_block(Vector3(13.0, 0, 21.5), 1.6, TOY_RED, 15.0)
	_toy_block(Vector3(15.2, 0, 20.4), 1.6, MINT, -10.0)
	_toy_block(Vector3(14.1, 1.6, 21.0), 1.6, BUTTER, 40.0)
	for i in 6:
		var a := TAU * i / 6.0
		deco(LowPoly.blob(0.35, Vector3(1, 1, 0.3), 1), LowPoly.at(Vector3(cos(a) * 2.0, 6.5, 21.5 + sin(a) * 2.0)),
			mat("glow", BUTTER, Color.WHITE, 0.4), false)
		deco(LowPoly.prism(4, 0.01, 0.01, 1.5), LowPoly.at(Vector3(cos(a) * 2.0, 7.3, 21.5 + sin(a) * 2.0)), white, false)


func _toy_block(at: Vector3, s: float, color: Color, yaw: float) -> void:
	var b := box(Vector3(s, s, s), at + Vector3(0, s / 2.0, 0), mat("paint", color), yaw)
	for face in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
		var inset := MeshInstance3D.new()
		inset.mesh = LowPoly.chamfer_box(Vector3(s * 0.7, s * 0.7, 0.04), 0.01)
		inset.position = face * (s / 2.0 + 0.01)
		inset.rotation.y = atan2(face.x, face.z)
		inset.material_override = mat("paint", color.lightened(0.45))
		b.add_child(inset)


func _living_room() -> void:
	var pink := mat("stripes", BABY_PINK, Color("#F9D7E2"))
	var sofa := mat("carpet", Color("#E9A3BC"))
	# Sofa walls: low, deep, things to jump over or hide behind.
	for seg in [[-20.0, -8.0], [8.0, 20.0]]:
		box(Vector3(seg[1] - seg[0], 1.1, 2.2), Vector3((seg[0] + seg[1]) / 2.0, 0.55, -15.0), sofa)
		box(Vector3(seg[1] - seg[0], 1.2, 0.7), Vector3((seg[0] + seg[1]) / 2.0, 1.7, -15.8), sofa)
		for x in [seg[0], seg[1]]:
			box(Vector3(0.8, 1.6, 2.2), Vector3(x, 0.8, -15.0), sofa)
	wall(Vector2(-3.0, -15.6), Vector2(3.0, -15.6), 3.0, pink, 0.5)
	# The giant TV on the north wall, full of static, on a low cabinet.
	box(Vector3(14.0, 1.4, 2.0), Vector3(0, 0.7, -HALF.y + 1.0), mat("paint", Color("#C8A88E")))
	box(Vector3(11.0, 6.6, 1.2), Vector3(0, 4.8, -HALF.y + 0.8), mat("paint", Color("#3B3943")))
	var screen := QuadMesh.new()
	screen.size = Vector2(9.6, 5.4)
	deco(screen, Transform3D(Basis.IDENTITY, Vector3(0, 4.8, -HALF.y + 1.42)), mat("static", Color.WHITE), false)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 4.5, -HALF.y + 4.0)
	glow.light_color = Color("#DDE6FF")
	glow.light_energy = 1.2
	glow.omni_range = 14.0
	add_child(glow)
	# A floor lamp and a rug-sized coffee table (cover).
	box(Vector3(5.0, 1.0, 2.6), Vector3(-13.0, 0.5, -21.0), mat("paint", Color("#E7CFB4")))
	box(Vector3(5.0, 1.0, 2.6), Vector3(13.0, 0.5, -21.0), mat("paint", Color("#E7CFB4")))
	for x in [-24.0, 24.0]:
		box(Vector3(0.3, 4.6, 0.3), Vector3(x, 2.3, -22.0), mat("paint", Color("#D9C3A5")))
		deco(LowPoly.prism(8, 1.1, 0.6, 1.0), LowPoly.at(Vector3(x, 4.5, -22.0)), mat("glow", Color("#FFE8C4"), Color.WHITE, 0.6), false)


func _hallway() -> void:
	# The endless hallway: x -34..-25, low ceiling at UP, an inner runnable wall at x -25
	# with three doorways. Doors line the outer wall and go nowhere.
	var inner_x := -25.0
	var paper := mat("stripes", MINT, Color("#D5F2E2"))
	var segs := [[-18.0, -9.5], [-6.5, -1.5], [1.5, 6.5], [9.5, 18.0]]
	for s in segs:
		wall(Vector2(inner_x, s[0]), Vector2(inner_x, s[1]), UP, paper, 0.6, 0.0, true)
	for s in [[-9.5, -6.5], [-1.5, 1.5], [6.5, 9.5]]:
		# Lintels over the doorways.
		box(Vector3(0.6, 1.2, s[1] - s[0]), Vector3(inner_x, UP - 0.6, (s[0] + s[1]) / 2.0), paper)
	# The ceiling (its top is the west walkway).
	floor_at(Vector2(-HALF.x, -18.0), Vector2(inner_x + 0.3, 18.0), UP + 0.5, mat("paint", CREAM), 0.5)
	# Fluorescent panels, a little too many.
	for z in range(-16, 17, 4):
		deco(LowPoly.chamfer_box(Vector3(1.0, 0.06, 2.4), 0.01), LowPoly.at(Vector3(-29.5, UP - 0.04, z)),
			mat("glow", Color("#F2FFF8"), Color.WHITE, 1.2), false)
	var tube := OmniLight3D.new()
	tube.position = Vector3(-29.5, UP - 0.8, 0)
	tube.light_color = Color("#EFFFF6")
	tube.light_energy = 0.9
	tube.omni_range = 18.0
	add_child(tube)
	# Doors on the outer wall: white, with brass knobs, evenly spaced, all shut.
	for z in range(-15, 16, 5):
		box(Vector3(0.2, 2.6, 1.3), Vector3(-HALF.x + 0.1, 1.3, z), mat("paint", DOOR_WHITE))
		deco(LowPoly.blob(0.07, Vector3.ONE, 1), LowPoly.at(Vector3(-HALF.x + 0.25, 1.2, z + 0.45)), mat("paint", Color("#D8B45A")))
	# Pillars inside as cover.
	for z in [-12.0, -4.0, 4.0, 12.0]:
		box(Vector3(1.0, UP, 1.0), Vector3(-30.0, UP / 2.0, z), mat("paint", Color("#E6F4EC")))
	# Stairs at the south end up to the walkway, along the inside of the room.
	stairs(Vector3(-23.0, 0.0, 23.0), Vector3(0, 0, -1), UP + 0.5, 2.4, mat("carpet", Color("#C9E3D6")))


func _dining_hall() -> void:
	var wood := mat("paint", Color("#E2C9A6"))
	var chair := mat("paint", Color("#C9B4E8"))
	# The giant table: top at 2.2, legs at the corners; you can walk (crouch) under it.
	var t := Vector3(19.0, 0, 0)
	box(Vector3(10.0, 0.3, 7.0), t + Vector3(0, 2.05, 0), wood)
	for x in [-4.6, 4.6]:
		for z in [-3.1, 3.1]:
			box(Vector3(0.6, 1.9, 0.6), t + Vector3(x, 0.95, z), wood)
	deco(LowPoly.chamfer_box(Vector3(9.8, 0.02, 2.2), 0.005), LowPoly.at(t + Vector3(0, 2.21, 0)), mat("checker", Color("#F7D4DE"), CREAM, 0.4))
	# A teacup the size of a car (cover on the table).
	deco(LowPoly.prism(12, 1.0, 1.25, 1.2), LowPoly.at(t + Vector3(2.0, 2.2, -1.0)), mat("paint", DOOR_WHITE))
	box(Vector3(2.0, 1.2, 2.0), t + Vector3(2.0, 2.8, -1.0), mat("paint", DOOR_WHITE))
	# Chairs: seat 1.2, back 3.4 — steps up to the table.
	for z in [-5.2, 5.2]:
		for x in [-2.5, 2.5]:
			var c := t + Vector3(x, 0, z)
			box(Vector3(2.4, 1.2, 2.4), c + Vector3(0, 0.6, 0), chair)
			box(Vector3(2.4, 2.2, 0.4), c + Vector3(0, 2.3, signf(z) * 1.0), chair)
	# The east mezzanine (top at UP), with a rail and bookshelves to climb.
	floor_at(Vector2(26.0, -20.0), Vector2(HALF.x, 16.5), UP, mat("carpet", Color("#E4D6F2")), 0.5)
	for z in [-19.8, 16.3]:
		box(Vector3(0.4, UP - 0.5, 0.4), Vector3(26.2, (UP - 0.5) / 2.0, z), wood)
	# A rail with gaps where the bookshelves come up (and where the slide leaves, z -8).
	for seg in [[-20.0, -13.8], [-10.2, -9.4], [-6.6, -1.8], [1.8, 10.2], [13.8, 16.5]]:
		box(Vector3(0.12, 1.0, seg[1] - seg[0]), Vector3(26.1, UP + 0.5, (seg[0] + seg[1]) / 2.0), mat("paint", DOOR_WHITE))
	for z in [-12.0, 0.0, 12.0]:
		_bookshelf(Vector3(25.0, 0, z))
	stairs(Vector3(30.0, 0.0, 23.2), Vector3(0, 0, -1), UP, 2.6, mat("carpet", Color("#E4D6F2")))


func _bookshelf(at: Vector3) -> void:
	var wood := mat("paint", Color("#D6B48F"))
	# Three shelves 1.5 m apart: mantle up one at a time to the mezzanine.
	box(Vector3(1.6, UP, 3.2), at + Vector3(0.6, UP / 2.0, 0), wood)
	for k in 2:
		var y := 1.5 * (k + 1)
		box(Vector3(1.0, 0.15, 3.2), at + Vector3(-0.7, y, 0), wood)
	var colors := [BABY_PINK, SKY_BLUE, MINT, BUTTER, LILAC, PEACH]
	for k in 3:
		for i in 7:
			var h := 0.9 + _hash(i, k) * 0.4
			deco(LowPoly.chamfer_box(Vector3(0.7, h, 0.32), 0.02),
				LowPoly.at(at + Vector3(-0.15, 1.5 * k + 0.08 + h / 2.0 + (0.15 if k > 0 else 0.0), -1.3 + i * 0.42)), mat("paint", colors[(i + k) % 6]))


func _upper() -> void:
	# The north beam: a narrow walk at y 5 from the west walkway to the mezzanine, over the
	# living room's edge. Exposed; the best view of the pool.
	var beam := mat("paint", Color("#F3E9F8"))
	box(Vector3(51.0, 0.5, 1.6), Vector3(0.5, UP + 0.25, -12.0), beam)
	for x in [-12.0, 0.0, 12.0]:
		box(Vector3(0.6, UP, 0.6), Vector3(x, UP / 2.0, -12.0), mat("paint", DOOR_WHITE))
	# Rails of light along its edges (also tells you where the edge is at speed).
	for side in [-0.75, 0.75]:
		deco(LowPoly.chamfer_box(Vector3(51.0, 0.05, 0.06), 0.01), LowPoly.at(Vector3(0.5, UP + 0.53, -12.0 + side)),
			mat("glow", Color("#FFD3E2"), Color.WHITE, 0.5), false)


func _middle_cover() -> void:
	# Around the pool deck: giant blocks, a beach ball, potted plants.
	_toy_block(Vector3(-12.5, 0, 9.0), 1.8, LILAC, 12.0)
	_toy_block(Vector3(12.5, 0, -9.0), 1.8, PEACH, -22.0)
	_toy_block(Vector3(-16.0, 0, -6.0), 1.4, SKY_BLUE, 30.0)
	_toy_block(Vector3(16.0, 0, 6.0), 1.4, BUTTER, -5.0)
	var ball := Vector3(9.0, 0, 9.5)
	box(Vector3(1.6, 1.6, 1.6), ball + Vector3(0, 0.8, 0), mat("paint", Color.WHITE), 0.0, false, false)
	deco(LowPoly.blob(1.05, Vector3.ONE, 2), LowPoly.at(ball + Vector3(0, 1.05, 0)), mat("checker", BABY_PINK, SKY_BLUE, 0.35))
	for p in [Vector3(-9.0, 0, -10.0), Vector3(9.0, 0, 10.5) - Vector3(18, 0, 0), Vector3(20.0, 0, -12.0), Vector3(-20.0, 0, 12.0)]:
		box(Vector3(1.2, 1.0, 1.2), p + Vector3(0, 0.5, 0), mat("paint", Color("#E6B8A2")))
		deco(LowPoly.blob(0.9, Vector3(1, 1.4, 1), 1, 0.25, 3), LowPoly.at(p + Vector3(0, 2.0, 0)), mat("paint", Color("#9ED6A9")))


func _dream_sky() -> void:
	# Clouds in and around the house; some come in through the open roof.
	var cloud := mat("cloud", Color("#FFFFFF"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(100.0, 170.0)
		var c := Vector3(cos(a) * r, rng.randf_range(14.0, 42.0), sin(a) * r)
		for k in 5:
			deco(LowPoly.blob(rng.randf_range(4.0, 8.0), Vector3(1.6, 0.8, 1.2), 1, 0.2, i * 7 + k),
				LowPoly.at(c + Vector3(rng.randf_range(-9, 9), rng.randf_range(-2, 2), rng.randf_range(-6, 6))), cloud, false)
	for k in 4:
		deco(LowPoly.blob(2.2, Vector3(1.8, 0.7, 1.3), 1, 0.2, 90 + k), LowPoly.at(Vector3(-6.0 + k * 4.0, 13.0 + k * 0.6, -3.0 + k * 1.5)),
			cloud, false)
	# Doors floating in the sky, a staircase up into the clouds, a door frame on the pool deck.
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var p := Vector3(cos(a) * 60.0, 22.0 + i * 3.0, sin(a) * 60.0)
		deco(LowPoly.chamfer_box(Vector3(2.4, 4.8, 0.25), 0.03), LowPoly.at(p, Vector3(rng.randf_range(-15, 15), rad_to_deg(-a) + 90.0, rng.randf_range(-10, 10))),
			mat("paint", [DOOR_WHITE, BABY_PINK, SKY_BLUE, MINT][i % 4]), false)
	for k in 30:
		deco(LowPoly.chamfer_box(Vector3(5.0, 0.4, 1.4), 0.04), LowPoly.at(Vector3(48.0, 6.0 + k * 1.2, -30.0 - k * 1.6)),
			mat("paint", CREAM), false)
	var frame := mat("paint", DOOR_WHITE)
	for x in [-1.1, 1.1]:
		box(Vector3(0.2, 3.0, 0.3), Vector3(x, 1.5, -10.0), frame)
	box(Vector3(2.4, 0.25, 0.3), Vector3(0, 3.1, -10.0), frame)
	var light := QuadMesh.new()
	light.size = Vector2(2.0, 2.9)
	deco(light, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -10.0)), mat("glow", Color("#FFF6E8"), Color.WHITE, 1.4), false)


# --- Movement (C4) ----------------------------------------------------------------------

func _movement() -> void:
	# Wallpaper panels floating over the pool: wall-run across it instead of going down
	# and up. 2.4 m of room under them on the pool floor.
	var panel_paper := [mat("stripes", LILAC, Color("#DCD0F7")), mat("stripes", PEACH, Color("#FBE0CF"))]
	for i in 2:
		var z := -4.0 if i == 0 else 4.0
		wall(Vector2(-6.0, z), Vector2(6.0, z), 3.0, panel_paper[i], 0.4, 0.8, true)
	# The south beam, the north one's twin over the nursery side, so both teams have a
	# high lane.
	var beam := mat("paint", Color("#E6F1FA"))
	box(Vector3(51.0, 0.5, 1.6), Vector3(0.5, UP + 0.25, 12.0), beam)
	for x in [-12.0, 0.0, 12.0]:
		box(Vector3(0.6, UP, 0.6), Vector3(x, UP / 2.0, 12.0), mat("paint", DOOR_WHITE))
	for side in [-0.75, 0.75]:
		deco(LowPoly.chamfer_box(Vector3(51.0, 0.05, 0.06), 0.01), LowPoly.at(Vector3(0.5, UP + 0.53, 12.0 + side)),
			mat("glow", Color("#CFE6FF"), Color.WHITE, 0.5), false)
	# Floating toy blocks: three hops from the pool deck up to each beam.
	var colors := [BUTTER, MINT, BABY_PINK]
	for k in 3:
		var top := 1.3 + 1.2 * k
		_float_block(Vector3(5.0 + 2.5 * k, top, -8.3 - 1.0 * k), colors[k], 15.0 * k)
		_float_block(Vector3(-5.0 - 2.5 * k, top, 8.3 + 1.0 * k), colors[2 - k], -15.0 * k)
	# Two giant playground slides: off the west walkway and the east mezzanine, down to the
	# deck at speed (slide down them for a free boost into the middle).
	_slide(Vector3(-24.6, UP + 0.5, 8.0), Vector3(-15.0, 0.0, 8.0))
	_slide(Vector3(25.9, UP, -8.0), Vector3(16.2, 0.0, -8.0))


## A toy block hanging in the air, top at `top`: a step you jump to.
func _float_block(at: Vector3, color: Color, yaw: float) -> void:
	var s := 1.6
	_toy_block(at - Vector3(0, s, 0), s, color, yaw)


func _slide(high: Vector3, low: Vector3) -> void:
	var yellow := mat("paint", BUTTER)
	var body := ramp(low, high, 2.4, yellow, 0.4)
	# Side rails (decoration; the slide itself is the collision).
	for side in [-1.25, 1.25]:
		var rail := MeshInstance3D.new()
		rail.mesh = LowPoly.chamfer_box(Vector3(0.12, 0.5, (high - low).length()), 0.02)
		rail.position = Vector3(side, 0.45, 0)
		rail.material_override = mat("paint", Color("#F59A8B"))
		body.add_child(rail)
