class_name LastTestament
extends Node3D
## 最後的遺訓 THE LAST TESTAMENT (C10, map 04): a cathedral the army took over. Phase 2
## graybox: plain blocks, the full floor plan, both sites, three floors for the bots.
## Mirrored north–south down the nave's centre line (Layout.mirror_ns):
##
##   spawns        blue at the south end, red at the north end
##   mid           the nave, running west–east: pews either side of the centre aisle,
##                 a pair of great pillars and the font breaking the long sightline
##   aisles        a ground aisle each side behind the arcade, the choir gallery 5 m
##                 over it: a ramp up at the east end, the organ loft joining the two
##                 galleries at the west end, gaps in the railing to drop back down,
##                 a pulpit to climb up by
##   confessionals between the aisle and the spawn: a row of 2 m booths, each with
##                 two ways out; the shortest way from spawn to the nave
##   site A (east) the altar: a 1.2 m dais up a ramp, in from the nave, both aisles
##                 and both east lanes
##   site B (west) the crypt, 4.5 m under the organ room: down a ramp from each west
##                 lane, or the trench stair at the west end of the nave
##   lanes         round the outside from each spawn to each site

const AREA := Rect2(-78, -48, 156, 96)
const WALL_H := 16.0
const GALLERY_Y := 5.0
const CRYPT_Y := -4.5
const DAIS_Y := 1.2
const SUBTITLE := "願你的槍械得到赦免。"

var player_spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 40))
var bot_spawns: Array[Vector3] = []
var waypoints: Array[Vector3] = []
var range_targets: Array[Transform3D] = []
var team_zones: Array[Vector3] = [Vector3(0, 0, 41), Vector3(0, 0, -41)]
var mid_zone := Vector3(0, 0, 0)
var bomb_sites: Array = [Vector3(54, 0, 0), Vector3(-64, CRYPT_Y, 0)]
var team_spawns: Array = [
	[Vector3(0, 0.1, 41), Vector3(-3, 0.1, 41), Vector3(3, 0.1, 41), Vector3(-1.5, 0.1, 43.5), Vector3(1.5, 0.1, 43.5)],
	[Vector3(0, 0.1, -41), Vector3(-3, 0.1, -41), Vector3(3, 0.1, -41), Vector3(-1.5, 0.1, -43.5), Vector3(1.5, 0.1, -43.5)],
]
var layout: Layout
var play_area := AREA
var lowest_floor := CRYPT_Y
var subtitle := SUBTITLE
## The floors (Layout levels): 0 the ground, then these.
var gallery := 0
var crypt := 0

## Where the ground is cut away down to the crypt's level (south half and the centre line;
## build mirrors them): the crypt, its tunnels, the two lane ramps, the trench.
const CRYPT := Rect2(-74, -16, 22, 32)
const LANE_RAMP := Rect2(-64, 20, 6, 10)       # 0 at its south end, -4.5 at its north end
const LANE_TUNNEL := Rect2(-64, 16, 6, 4)      # under the organ room's south wall
const TRENCH := Rect2(-48, -2, 10, 4)          # 0 at its east end, -4.5 at its west end
const TRENCH_TUNNEL := Rect2(-52, -2, 4, 4)    # under the organ room's east wall
## The choir gallery (south; north is its twin) and the organ loft joining the two.
const GALLERY := Rect2(-48, 14, 76, 6)
const LOFT := Rect2(-48, -14, 10, 28)
const GALLERY_RAMP := Rect2(28, 16, 10, 4)     # up westward: 0 at x 38, 5 at x 28
const RAIL_GAPS := [Vector2(-26, -24), Vector2(4, 6), Vector2(14, 16)]   # x spans on the gallery edge
const LOFT_GAPS := [Vector2(6, 8)]                                       # z spans (and twins) on the loft edge
## The organ's maintenance platform in the organ room, up a ramp from each side, joined to
## the loft through an opening high in the organ room's east wall.
const PLATFORM := Rect2(-60, -6, 8, 12)
const PLATFORM_RAMP := Rect2(-60, 6, 4, 10)    # 0 at its south end, 5 at its north end
const BRIDGE := Rect2(-52, -2, 4, 4)
## The altar.
const DAIS := Rect2(62, -8, 10, 16)
const DAIS_RAMP := Rect2(56, -4, 6, 8)
## Pews (x of each 2 m row, both sides of the centre aisle, z 4..10).
const PEWS := [-32, -28, -24, -20, 12, 16, 20, 24, 28, 32, 36]
const ARCADE := [-30, -20, -10, 0, 10, 20]


func _ready() -> void:
	name = "LastTestament"
	Faultprint.environment(self, Vector3(-58.0, 32.0, 0.0))
	_plan()
	_build()
	_nave()
	_galleries()
	_altar()
	_crypt()
	_lights()
	waypoints = layout.wander_points(5)
	bot_spawns = [Vector3(-6, 0.1, 6), Vector3(6, 0.1, -6), Vector3(50, 0.1, 10), Vector3(-62, CRYPT_Y + 0.1, 8), Vector3(0, GALLERY_Y + 0.1, 17)]


func _plan() -> void:
	var g := Layout.new(AREA, 2.0)
	g.mirror_ns = true
	layout = g
	g.carve2(Rect2(-14, 36, 28, 10), "s")                 # spawn
	g.carve2(Rect2(14, 38, 46, 8))                        # spawn -> the east lane
	g.carve2(Rect2(52, 18, 8, 20))                        # ... north into the altar
	g.carve2(Rect2(-64, 38, 50, 8))                       # spawn -> the west lane
	g.carve2(Rect2(-64, 30, 6, 8))                        # ... north to the crypt ramp
	g.carve2(LANE_RAMP, "r")
	g.carve(CRYPT, "y")                                   # the organ room (the crypt below)
	g.carve2(Rect2(-52, 6, 4, 4))                         # organ room <-> narthex doors
	g.carve(Rect2(-48, -20, 12, 40))                      # the narthex
	g.carve(Rect2(-36, -12, 76, 24), "m")                 # the nave
	g.carve2(Rect2(-48, 12, 88, 8))                       # the aisle
	g.carve(TRENCH, "r")
	g.carve2(PLATFORM_RAMP, "r")
	g.carve(BRIDGE, "o")                                  # the wall's built by hand round the opening
	g.carve2(Rect2(-48, 2, 10, 2), "o")                   # the trench's railings
	g.carve2(GALLERY_RAMP, "r")
	for x in ARCADE:
		g.carve2(Rect2(x, 12, 2, 2), "o")
	g.carve2(Rect2(4, 12, 2, 2), "o")                     # the pulpit
	g.carve2(Rect2(-14, 2, 4, 4), "o")                    # the great pillars
	g.carve(Rect2(16, -2, 4, 4), "o")                     # the font
	for x in PEWS:
		g.carve2(Rect2(x, 4, 2, 6), "c")
	# The confessionals: a front corridor off the aisle, a row of booths, a back corridor
	# to the spawn.
	g.carve2(Rect2(-26, 22, 52, 2))
	g.carve2(Rect2(-20, 20, 4, 2))
	g.carve2(Rect2(16, 20, 4, 2))
	for k in 11:
		g.carve2(Rect2(-22 + 4 * k, 24, 2, 6))
	g.carve2(Rect2(-26, 30, 52, 2))
	g.carve2(Rect2(-10, 32, 4, 4))
	g.carve2(Rect2(6, 32, 4, 4))
	# The altar: the chancel arch, side doors from the aisles, the room.
	g.carve(Rect2(40, -8, 4, 16))
	g.carve2(Rect2(40, 12, 4, 4))
	g.carve(Rect2(44, -18, 30, 36), "a")
	g.carve2(Rect2(58, 4, 4, 2), "o")                     # candle stands beside the dais ramp
	g.carve(Rect2(72, -4, 2, 8), "o")                     # the tablet
	g.carve2(Rect2(48, 10, 2, 2), "o")                    # crates
	g.carve2(Rect2(54, 8, 4, 2), "c")
	# Heights on the ground floor.
	g.set_slope(LANE_RAMP, Vector2i(0, 1), CRYPT_Y, 0.0)
	g.set_slope(g.turned(LANE_RAMP), Vector2i(0, -1), CRYPT_Y, 0.0)
	g.set_slope(TRENCH, Vector2i(1, 0), CRYPT_Y, 0.0)
	for r in [GALLERY_RAMP, g.turned(GALLERY_RAMP)]:
		g.set_slope(r, Vector2i(-1, 0), 0.0, GALLERY_Y)
	g.set_slope(PLATFORM_RAMP, Vector2i(0, -1), 0.0, GALLERY_Y)
	g.set_slope(g.turned(PLATFORM_RAMP), Vector2i(0, 1), 0.0, GALLERY_Y)
	g.set_height(DAIS, DAIS_Y)
	g.set_slope(DAIS_RAMP, Vector2i(1, 0), 0.0, DAIS_Y)
	# The floors above and below.
	gallery = g.add_deck(GALLERY_Y)
	g.open_deck2(gallery, GALLERY)
	g.open_deck(gallery, LOFT)
	g.open_deck(gallery, PLATFORM)
	g.open_deck(gallery, BRIDGE)
	crypt = g.add_deck(CRYPT_Y)
	g.open_deck(crypt, CRYPT)
	g.open_deck2(crypt, LANE_TUNNEL)
	g.open_deck(crypt, TRENCH_TUNNEL)
	for r in _crypt_blocks():
		g.open_deck(crypt, r[0], false)
	# Stairs and drops between them.
	g.link2(0, Vector3(29, 4.5, 17), gallery, Vector3(27, GALLERY_Y, 17))
	g.link2(0, Vector3(-59, 4.5, 7), gallery, Vector3(-59, GALLERY_Y, 5))
	g.link2(0, Vector3(-61, CRYPT_Y, 21), crypt, Vector3(-61, CRYPT_Y, 19))
	g.link2(0, Vector3(-47, CRYPT_Y, 1), crypt, Vector3(-49, CRYPT_Y, 1))
	for gap in [RAIL_GAPS[0], RAIL_GAPS[2]]:
		var x: float = (gap.x + gap.y) / 2.0
		g.link2(gallery, Vector3(x, GALLERY_Y, 15), 0, Vector3(x, 0, 10), false)
	for gap in LOFT_GAPS:
		var z: float = (gap.x + gap.y) / 2.0
		g.link2(gallery, Vector3(-39, GALLERY_Y, z), 0, Vector3(-35, 0, z), false)


## The crypt's solid pieces: [rect, height] (south half and centre line; twins built too).
func _crypt_blocks() -> Array:
	var out := []
	for r in [[Rect2(-68, 6, 2, 2), 4.0], [Rect2(-58, 6, 2, 2), 4.0], [Rect2(-72, 2, 4, 2), 1.0],
			[Rect2(-74, 10, 2, 4), 2.2], [Rect2(-66, 12, 6, 2), 1.0]]:
		out.append(r)
		out.append([layout.turned(r[0]), r[1]])
	out.append([Rect2(-58, -2, 2, 4), 1.0])   # the low wall facing the trench
	return out


func _build() -> void:
	var walls := [Counterform.BONE_CONCRETE, Counterform.CONCRETE_MID, Counterform.BONE_CONCRETE, Counterform.CONCRETE_DARK]
	var n := [0]
	layout.mark_breaches(2)
	layout.cut_passages(4)
	layout.cut_windows(2)
	layout.add_ledges(6)
	# Vault windows between confessional booths (the walls are too thin for cut_windows to
	# count the way round as a detour).
	for x in [-19.0, -3.0, 9.0]:
		layout.window2(layout.cell_of(Vector3(x, 0, 27)), Vector2i(1, 0))
	PhysProp.scatter(self, layout, 36, [Faultprint.ORANGE, Faultprint.SLATE, Color("#6F7656"), Counterform.BRASS])
	layout.build_walls(self, WALL_H, func(size: Vector3, at: Vector3) -> void:
		var b := Geo.block(self, size, at, walls[n[0] % walls.size()], Vector3.ZERO, {"bevel": 0.12, "print": {"wear": 0.4}})
		b.collision_layer = Geo.WORLD | Geo.RUNNABLE
		b.add_to_group("runnable")
		n[0] += 1)
	# The ground: solid down to under the crypt, except where it is cut away.
	var cut := Layout.new(AREA, 2.0)
	for r in _voids():
		cut.carve(r, ".")
	for r in cut.rects("#"):
		Geo.slab(self, r.position, r.end, 0.0, 6.0, Counterform.CONCRETE_MID, {"print": {"slip": null, "wear": 0.6}})
	for r in cut.rects("."):
		Geo.slab(self, r.position, r.end, CRYPT_Y, 1.0, Counterform.CONCRETE_DARK, {"print": {"slip": null, "wear": 0.8}})
	# The crypt's ceiling is the organ room's floor.
	Geo.slab(self, CRYPT.position, CRYPT.end, 0.0, 0.5, Counterform.CONCRETE_DARK, {"print": {"slip": null}})
	for r in layout.rects("m"):
		Geo.slab(self, r.position, r.end, 0.03, 0.1, Counterform.CONCRETE_DARK, {"print": {"slip": null, "wear": 0.7}, "bevel": 0.02})
	for r in layout.rects("s"):
		Geo.slab(self, r.position, r.end, 0.03, 0.1, Counterform.GREEN_GREY, {"print": {"slip": null}, "bevel": 0.02})
	# Ramps down to the crypt.
	for z in [25.0, -25.0]:
		var a := Vector3(-61, CRYPT_Y, 20.0 * signf(z))
		var b := Vector3(-61, 0.0, 30.0 * signf(z))
		Geo.ramp(self, a, b, 6.0, Counterform.CONCRETE_MID)
	Geo.ramp(self, Vector3(-48, CRYPT_Y, 0), Vector3(-38, 0, 0), 4.0, Counterform.CONCRETE_MID)
	for z in [3.0, -3.0]:
		_rail(Vector3(-43, 0, 2.25 * signf(z)), Vector3(10, 1.1, 0.4))


func _voids() -> Array:
	var out := [CRYPT, TRENCH, TRENCH_TUNNEL]
	for r in [LANE_RAMP, LANE_TUNNEL]:
		out.append(r)
		out.append(layout.turned(r))
	return out


## The nave: pews, the arcade, the great pillars, the font, the pulpit.
func _nave() -> void:
	for x in PEWS:
		for z in [7.0, -7.0]:
			Geo.block(self, Vector3(0.8, 0.9, 5.6), Vector3(x + 1.0, 0.45, z), Counterform.POLYMER_TAN, Vector3.ZERO, {"bevel": 0.04})
	for x in ARCADE:
		for z in [13.0, -13.0]:
			var p := Geo.block(self, Vector3(1.6, WALL_H, 1.6), Vector3(x + 1.0, WALL_H / 2.0, z), Counterform.BONE_CONCRETE, Vector3.ZERO, {"bevel": 0.1})
			p.collision_layer = Geo.WORLD | Geo.RUNNABLE
			p.add_to_group("runnable")
	for z in [4.0, -4.0]:
		var p := Geo.block(self, Vector3(3.6, WALL_H, 3.6), Vector3(-12, WALL_H / 2.0, z), Counterform.CONCRETE_MID, Vector3.ZERO, {"bevel": 0.15})
		p.collision_layer = Geo.WORLD | Geo.RUNNABLE
		p.add_to_group("runnable")
		Geo.block(self, Vector3(1.8, 2.2, 1.8), Vector3(5, 1.1, 13.0 * signf(z)), Counterform.OXIDE_RUST, Vector3.ZERO, {"bevel": 0.06})
		# Its sounding board, hung under the gallery's edge: a face to climb up by.
		Geo.block(self, Vector3(1.8, 2.4, 0.4), Vector3(5, 3.4, 14.2 * signf(z)), Counterform.OXIDE_RUST, Vector3.ZERO, {"bevel": 0.04})
	Geo.block(self, Vector3(3.4, 2.6, 3.4), Vector3(18, 1.3, 0), Counterform.STEEL, Vector3.ZERO, {"bevel": 0.1})


## The choir galleries, the organ loft and their railings, the ramps up.
func _galleries() -> void:
	for flip in [false, true]:
		var t := func(r: Rect2) -> Rect2: return layout.turned(r) if flip else r
		var s := -1.0 if flip else 1.0
		var deck: Rect2 = t.call(GALLERY)
		Geo.slab(self, deck.position, deck.end, GALLERY_Y, 0.4, Counterform.CONCRETE_DARK, {"bevel": 0.03})
		# The railing along the nave side, with gaps to drop through.
		var x0 := -38.0
		for gap in RAIL_GAPS + [Vector2(28, 28)]:
			if gap.x > x0:
				_rail(Vector3((x0 + gap.x) / 2.0, GALLERY_Y, 14.15 * s), Vector3(gap.x - x0, 1.1, 0.3))
			x0 = gap.y
		# The ramp up at the east end, solid underneath.
		Geo.ramp(self, Vector3(38, 0, 18 * s), Vector3(28, GALLERY_Y, 18 * s), 4.0, Counterform.CONCRETE_MID)
		Geo.wedge(self, Vector3(10, GALLERY_Y - 0.05, 4), Vector3(33, 0, 18 * s), Counterform.CONCRETE_MID, 180.0)
		# A low wall along the ramp's open side.
		_rail(Vector3(33, 0, 16.15 * s), Vector3(10, 1.1, 0.3))
	Geo.slab(self, LOFT.position, LOFT.end, GALLERY_Y, 0.4, Counterform.CONCRETE_DARK, {"bevel": 0.03})
	# The organ platform, its ramps, and the wall round the opening to the loft.
	Geo.slab(self, PLATFORM.position, PLATFORM.end, GALLERY_Y, 0.4, Counterform.STEEL, {"bevel": 0.03})
	Geo.slab(self, BRIDGE.position, BRIDGE.end, GALLERY_Y, 0.4, Counterform.STEEL, {"bevel": 0.03})
	for s in [1.0, -1.0]:
		Geo.ramp(self, Vector3(-58, 0, 16 * s), Vector3(-58, GALLERY_Y, 6 * s), 4.0, Counterform.CONCRETE_MID)
		Geo.wedge(self, Vector3(10, GALLERY_Y - 0.05, 4), Vector3(-58, 0, 11 * s), Counterform.CONCRETE_MID, 90.0 * s)
		_rail(Vector3(-54, GALLERY_Y, 5.85 * s), Vector3(4, 1.1, 0.3))
	_rail(Vector3(-59.85, GALLERY_Y, 0), Vector3(0.3, 1.1, 12))
	var wall := BRIDGE.get_center()
	for part in [[0.0, GALLERY_Y - 0.4], [GALLERY_Y + 3.2, WALL_H]]:
		var b := Geo.block(self, Vector3(BRIDGE.size.x, part[1] - part[0], BRIDGE.size.y), Vector3(wall.x, (part[0] + part[1]) / 2.0, wall.y),
			Counterform.BONE_CONCRETE, Vector3.ZERO, {"bevel": 0.12})
		b.collision_layer = Geo.WORLD | Geo.RUNNABLE
		b.add_to_group("runnable")
	Layout.barrier(self, Vector3(BRIDGE.size.x, Layout.CEILING - WALL_H, BRIDGE.size.y), Vector3(wall.x, (Layout.CEILING + WALL_H) / 2.0, wall.y))
	var z0 := -14.0
	var gaps := [Vector2(-8, -6)] + LOFT_GAPS + [Vector2(14, 14)]
	for gap in gaps:
		if gap.x > z0:
			_rail(Vector3(-38.15, GALLERY_Y, (z0 + gap.x) / 2.0), Vector3(0.3, 1.1, gap.x - z0))
		z0 = gap.y
	# Columns under the loft.
	for z in [-10.0, 10.0]:
		Geo.block(self, Vector3(1.0, GALLERY_Y, 1.0), Vector3(-38.6, GALLERY_Y / 2.0, z), Counterform.CONCRETE_MID)


func _rail(centre: Vector3, size: Vector3) -> void:
	Geo.block(self, size, centre + Vector3(0, size.y / 2.0, 0), Counterform.GRAPHITE, Vector3.ZERO, {"bevel": 0.04})


## Site A: the dais up its ramp, the tablet behind it, the candle stands and crates.
func _altar() -> void:
	Geo.block(self, Vector3(DAIS.size.x, DAIS_Y, DAIS.size.y), Vector3(DAIS.get_center().x, DAIS_Y / 2.0, DAIS.get_center().y),
		Counterform.BONE_CONCRETE, Vector3.ZERO, {"bevel": 0.06})
	Geo.ramp(self, Vector3(56, 0, 0), Vector3(62, DAIS_Y, 0), 8.0, Counterform.CONCRETE_MID, 0.4)
	Geo.block(self, Vector3(1.6, 6.0, 7.6), Vector3(73, 3.0, 0), Counterform.CONCRETE_DARK, Vector3.ZERO, {"bevel": 0.08})
	for z in [1.0, -1.0]:
		Geo.block(self, Vector3(3.6, 1.6, 1.6), Vector3(60, 0.8, 5.0 * z), Counterform.BRASS, Vector3.ZERO, {"bevel": 0.05})
		Geo.block(self, Vector3(1.8, 1.6, 1.8), Vector3(49, 0.8, 11.0 * z), Counterform.POLYMER_TAN, Vector3(0, 10, 0), {"bevel": 0.05})
		Geo.block(self, Vector3(3.6, 1.0, 1.6), Vector3(56, 0.5, 9.0 * z), Counterform.GREEN_GREY, Vector3.ZERO, {"bevel": 0.05})
	_site_label("A", Vector3(73.9 - 1.0, 7.5, 0), -90.0)


## Site B: the crypt's pillars, tombs, cabinets and the low wall.
func _crypt() -> void:
	for r in _crypt_blocks():
		var rect: Rect2 = r[0]
		var h: float = r[1]
		if h >= 4.0:
			h = -CRYPT_Y - 0.5
		var shrink := 0.3 if h < 4.0 else 0.2
		var q := rect.grow(-shrink)
		Geo.block(self, Vector3(q.size.x, h, q.size.y), Vector3(q.get_center().x, CRYPT_Y + h / 2.0, q.get_center().y),
			Counterform.STEEL if h > 2.0 and h < 3.0 else Counterform.CONCRETE_MID, Vector3.ZERO, {"bevel": 0.05})
	_site_label("B", Vector3(-73.9, CRYPT_Y + 2.4, 0), 90.0)
	# The organ above: pipes on the organ room's west wall (scenery for now).
	for k in 9:
		var h := 6.0 + 4.0 * absf(sin(k * 0.9))
		Geo.block(self, Vector3(0.8, h, 0.8), Vector3(-73.4, h / 2.0, -8.0 + k * 2.0), Counterform.BRASS, Vector3.ZERO, {"bevel": 0.1})


func _site_label(text: String, pos: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 700
	label.pixel_size = 0.01
	label.modulate = Counterform.OXIDE_ORANGE
	label.position = pos
	label.rotation_degrees = Vector3(0, yaw, 0)
	label.shaded = false
	add_child(label)


func _lights() -> void:
	Faultprint.zone_light(self, Vector3(60, 7.0, 0), Counterform.SULFUR, 24.0)
	Faultprint.zone_light(self, Vector3(-63, CRYPT_Y + 3.4, 0), Counterform.OXIDE_ORANGE, 20.0)
	Faultprint.zone_light(self, Vector3(0, 10.0, 0), Color("#9FB7B3"), 34.0)
	Faultprint.zone_light(self, Vector3(-62, 6.0, 0), Counterform.BRASS, 16.0)
	for z in [41.0, -41.0]:
		Faultprint.zone_light(self, Vector3(0, 5.0, z), Color("#3FC6C0"), 16.0)
	for z in [17.0, -17.0]:
		Faultprint.zone_light(self, Vector3(0, GALLERY_Y + 3.0, z), Color("#C9B79A"), 20.0, 0.6)
