class_name FaultYard
extends Node3D
## 斷層貨場 FAULT YARD (C5): the third team map and the biggest (about 175 × 115 m). A
## container yard and two warehouses on a sheared concrete shelf, in COUNTERFORM's
## industrial look: bone concrete, graphite steel, green-grey paint, oxide orange for
## identity, sulfur only for information. Built entirely from a floor plan (Layout),
## the same turned half round, like a CS / VALORANT map:
##
##   spawns        blue at the south gate, red at the north gate
##   mid           the open yard: container stacks, the crane's raised base in the
##                 middle, two ways in from each spawn
##   site A (west) the west warehouse: roofed at the back, open at the front, crates
##                 and a gantry to hold from
##   site B (east) the same turned round
##   routes        a long lane round the outside to each site, a covered tunnel to the
##                 other site, the foreman's office linking the lane, mid and spawn,
##                 and a short catwalk door from mid straight into each warehouse
##   movement      every rock wall is runnable; stacked containers and the crane base
##                 are mantle steps; the gantries are wall-kick shafts

const AREA := Rect2(-92, -62, 184, 124)
const WALL_H := 9.0
const ROOF := 7.0

var player_spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 50))
var bot_spawns: Array[Vector3] = []
var waypoints: Array[Vector3] = []
var range_targets: Array[Transform3D] = []
var team_zones: Array[Vector3] = [Vector3(0, 0, 51), Vector3(0, 0, -51)]
var mid_zone := Vector3(0, 0, 0)
var bomb_sites: Array = [Vector3(-64, 0, 0), Vector3(64, 0, 0)]
var team_spawns: Array = [
	[Vector3(0, 0.1, 51), Vector3(-3, 0.1, 51), Vector3(3, 0.1, 51), Vector3(-1.5, 0.1, 53.5), Vector3(1.5, 0.1, 53.5)],
	[Vector3(0, 0.1, -51), Vector3(-3, 0.1, -51), Vector3(3, 0.1, -51), Vector3(-1.5, 0.1, -53.5), Vector3(1.5, 0.1, -53.5)],
]
var layout: Layout
var play_area := AREA
var lowest_floor := 0.0

## Containers: [centre x/z, yaw (0 or 90), stacked] in the south/west half; the rest is
## the same turned round. 6 × 2.6 × 2.4 m each.
const CONTAINERS := [
	[Vector2(-14, 12), 0, false], [Vector2(-20, 4), 90, true], [Vector2(-6, 18), 90, false],
	[Vector2(16, 14), 0, false], [Vector2(22, 18), 90, false],
	[Vector2(-70, 12), 0, true], [Vector2(-58, 8), 90, false], [Vector2(-76, -4), 90, false],
	[Vector2(-56, 40), 90, false], [Vector2(36, 49), 0, false], [Vector2(-40, 52), 0, false],
]
const CONTAINER_COLORS := [Counterform.GREEN_GREY, Counterform.OXIDE_RUST, Counterform.STEEL, Counterform.CONCRETE_DARK]


func _ready() -> void:
	name = "FaultYard"
	Faultprint.environment(self, Vector3(-44.0, -58.0, 0.0))
	_plan()
	_build()
	_containers()
	_crane()
	_warehouses()
	_office()
	_lights()
	if Settings.look == Faultprint.COUNTERFORM:
		Counterform.vista(self, Vector3.ZERO, 200.0)
	waypoints = layout.wander_points(5)
	bot_spawns = [Vector3(-10, 0.1, 0), Vector3(10, 0.1, 0), Vector3(-64, 0.1, 6), Vector3(64, 0.1, -6), Vector3(0, 0.1, -30)]


func _plan() -> void:
	var g := Layout.new(AREA, 2.0)
	layout = g
	g.carve2(Rect2(-16, 44, 32, 14), "s")                  # spawn gate
	g.carve(Rect2(-30, -24, 60, 48), "m")                   # the yard (mid)
	g.carve2(Rect2(-12, 24, 6, 20))                         # spawn -> mid, two doors
	g.carve2(Rect2(6, 24, 6, 20))
	g.carve2(Rect2(-60, 48, 44, 8))                         # spawn -> the west lane
	g.carve2(Rect2(-60, 18, 8, 38))                         # ... north: A long
	g.carve2(Rect2(16, 46, 40, 6))                          # spawn -> the east tunnel
	g.carve2(Rect2(50, 18, 6, 34))                          # ... north into B: B tunnel
	g.carve2(Rect2(-48, -6, 18, 6))                         # mid -> A: the catwalk door (short)
	g.carve2(Rect2(-42, 28, 14, 12))                        # the foreman's office
	g.carve2(Rect2(-52, 32, 10, 4))                         # office <-> A long
	g.carve2(Rect2(-32, 22, 4, 6))                          # office <-> mid
	g.carve2(Rect2(-36, 40, 4, 8))                          # office <-> spawn lane
	var site := Rect2(-84, -20, 36, 40)
	g.carve(site, "a")
	g.carve(g.turned(site), "b")
	for c in CONTAINERS:
		for r in _container_rects(c):
			g.carve(r.grow(-0.2), "c")
	g.carve2(Rect2(-4, -4, 8, 8), "c")                      # the crane's base


func _container_rects(c: Array) -> Array:
	var p: Vector2 = c[0]
	var size := Vector2(6, 2.4) if int(c[1]) == 0 else Vector2(2.4, 6)
	var r := Rect2(p - size / 2.0, size)
	return [r, layout.turned(r)]


func _build() -> void:
	var walls := [Counterform.BONE_CONCRETE, Counterform.CONCRETE_MID, Counterform.BONE_CONCRETE, Counterform.CONCRETE_DARK]
	var n := [0]
	layout.mark_breaches(2)  # C6: rammable shortcuts
	layout.cut_passages(4)  # C7: small passages, vault windows, ledges
	layout.cut_windows(2)
	layout.add_ledges(6)
	PhysProp.scatter(self, layout, 36, [Faultprint.ORANGE, Faultprint.SLATE, Color("#6F7656"), Color("#3D6FB0")])  # C7: loose things
	layout.build_walls(self, WALL_H, func(size: Vector3, at: Vector3) -> void:
		var b := Geo.block(self, size, at, walls[n[0] % walls.size()], Vector3.ZERO, {"bevel": 0.12, "print": {"wear": 0.5}})
		b.collision_layer = Geo.WORLD | Geo.RUNNABLE
		b.add_to_group("runnable")
		n[0] += 1)
	Geo.slab(self, AREA.position, AREA.end, 0.0, 1.0, Counterform.CONCRETE_MID, {"print": {"slip": null, "wear": 0.6}})
	for r in layout.rects("m"):
		Geo.slab(self, r.position, r.end, 0.03, 0.1, Counterform.CONCRETE_DARK, {"print": {"slip": null, "wear": 0.7}, "bevel": 0.02})
	for r in layout.rects("ab"):
		Geo.slab(self, r.position, r.end, 0.03, 0.1, Counterform.BONE_CONCRETE, {"print": {"slip": null}, "bevel": 0.02})
	for r in layout.rects("s"):
		Geo.slab(self, r.position, r.end, 0.03, 0.1, Counterform.GREEN_GREY, {"print": {"slip": null}, "bevel": 0.02})
	# Painted lane lines down the long routes: sulfur, information only.
	for r in [Rect2(-56.2, 20, 0.4, 34), Rect2(52.8, 20, 0.4, 30), Rect2(-58, 51.8, 40, 0.4)]:
		for q in [r, layout.turned(r)]:
			Geo.slab(self, q.position, q.end, 0.06, 0.05, Counterform.SULFUR, {"print": {"slip": null, "pattern": 2}, "bevel": 0.01})


func _containers() -> void:
	var i := 0
	for c in CONTAINERS:
		for r in _container_rects(c):
			var rr: Rect2 = r
			var yaw := 0.0 if rr.size.x > rr.size.y else 90.0
			var at := Vector3(rr.get_center().x, 0, rr.get_center().y)
			_container(at, yaw, CONTAINER_COLORS[i % CONTAINER_COLORS.size()])
			if c[2]:
				_container(at + Vector3(0, 2.6, 0), yaw + 4.0, CONTAINER_COLORS[(i + 1) % CONTAINER_COLORS.size()])
			i += 1


## One shipping container: ribbed sides, doors at one end, a stencil band.
func _container(at: Vector3, yaw: float, color: Color) -> void:
	var body := Geo.block(self, Vector3(6.0, 2.6, 2.4), at + Vector3(0, 1.3, 0), color, Vector3(0, yaw, 0), {"bevel": 0.05})
	for k in 9:
		for side in [-1.0, 1.0]:
			var rib := MeshInstance3D.new()
			rib.mesh = LowPoly.chamfer_box(Vector3(0.12, 2.3, 0.06), 0.01)
			rib.position = Vector3(-2.6 + k * 0.65, 0, side * 1.22)
			rib.material_override = Faultprint.surface(color.darkened(0.15), {"slip": null})
			body.add_child(rib)
	for side in [-1.0, 1.0]:
		var bar := MeshInstance3D.new()
		bar.mesh = LowPoly.chamfer_box(Vector3(0.06, 2.4, 0.08), 0.01)
		bar.position = Vector3(3.02, 0, side * 0.5)
		bar.material_override = Faultprint.surface(Counterform.GRAPHITE, {"slip": null})
		body.add_child(bar)


## The crane in the middle of the yard: a raised base to fight from (mantle up its sides or
## take the ramp), four legs, and a long boom overhead (scenery, no collision).
func _crane() -> void:
	Geo.block(self, Vector3(8, 2.2, 8), Vector3(0, 1.1, 0), Counterform.CONCRETE_DARK, Vector3.ZERO, {"bevel": 0.1})
	Geo.ramp(self, Vector3(0, 0, 10.5), Vector3(0, 2.2, 4.0), 3.0, Counterform.GREEN_GREY)
	Geo.ramp(self, Vector3(0, 0, -10.5), Vector3(0, 2.2, -4.0), 3.0, Counterform.GREEN_GREY)
	for x in [-3.4, 3.4]:
		for z in [-3.4, 3.4]:
			Geo.block(self, Vector3(0.7, 18.0, 0.7), Vector3(x, 2.2 + 9.0, z), Counterform.OXIDE_ORANGE, Vector3.ZERO, {"bevel": 0.04})
	Geo.block(self, Vector3(9.0, 1.4, 9.0), Vector3(0, 20.9, 0), Counterform.GRAPHITE, Vector3.ZERO, {"bevel": 0.06})
	Geo.scenery(self, LowPoly.chamfer_box(Vector3(70.0, 1.6, 2.0), 0.1), LowPoly.at(Vector3(6, 22.4, 0), Vector3(0, 24, 0)),
		Counterform.OXIDE_ORANGE)
	Geo.scenery(self, LowPoly.chamfer_box(Vector3(0.15, 12.0, 0.15), 0.02), LowPoly.at(Vector3(30, 16.0, -12)), Counterform.GRAPHITE)
	Geo.scenery(self, LowPoly.chamfer_box(Vector3(6.0, 2.6, 2.4), 0.05), LowPoly.at(Vector3(30, 8.7, -12), Vector3(0, 30, 0)),
		Counterform.OXIDE_RUST)


## The two warehouses: a roof over the back of each site on graphite columns, a gantry
## along the back wall (up a ladder of crates), roll-up doors framing the front.
func _warehouses() -> void:
	for flip in [false, true]:
		var t := func(p: Vector3) -> Vector3: return Layout.turn(p) if flip else p
		var roof := Rect2(-84, -20, 18, 40)
		if flip:
			roof = layout.turned(roof)
		Geo.slab(self, roof.position, roof.end, ROOF + 0.5, 0.5, Counterform.GRAPHITE, {"bevel": 0.04})
		for z in [-12.0, 0.0, 12.0]:
			Geo.block(self, Vector3(0.6, ROOF, 0.6), t.call(Vector3(-66.3, ROOF / 2.0, z)), Counterform.GRAPHITE)
		# The gantry: a walkway 3.4 m up along the back wall, crates as steps.
		var g := Rect2(-84, -18, 3, 36)
		if flip:
			g = layout.turned(g)
		Geo.slab(self, g.position, g.end, 3.4, 0.3, Counterform.STEEL, {"bevel": 0.03})
		for k in 3:
			var h := 1.15 * (k + 1)
			Geo.block(self, Vector3(1.6, h, 1.6), t.call(Vector3(-79.8 + k * 1.6, h / 2.0, 16.0)), Counterform.POLYMER_TAN, Vector3.ZERO, {"bevel": 0.05})
		# Crates on the floor and a forklift-sized block of pallets.
		for p in [Vector3(-66, 0, -10), Vector3(-72, 0, 6), Vector3(-62, 0, 14), Vector3(-52, 0, -14)]:
			Geo.block(self, Vector3(2.0, 1.6, 2.0), t.call(p) + Vector3(0, 0.8, 0), Counterform.POLYMER_TAN, Vector3(0, 12, 0), {"bevel": 0.05})
		# Roll-up door frames where the catwalk door and the lanes come in.
		var label := Label3D.new()
		label.text = "A" if not flip else "B"
		label.font_size = 900
		label.pixel_size = 0.01
		label.modulate = Counterform.OXIDE_ORANGE
		label.position = t.call(Vector3(-83.9, 4.5, 0))
		label.rotation_degrees = Vector3(0, 90 if not flip else -90, 0)
		label.shaded = false
		add_child(label)


## The foreman's office between the west lane, mid and the spawn lane: a low ceiling, a
## desk, a window band. Its twin is turned round to the north-east.
func _office() -> void:
	for flip in [false, true]:
		var t := func(p: Vector3) -> Vector3: return Layout.turn(p) if flip else p
		var r := Rect2(-42, 28, 14, 12)
		if flip:
			r = layout.turned(r)
		Geo.slab(self, r.position, r.end, 4.2, 0.4, Counterform.CONCRETE_DARK, {"bevel": 0.03})
		Geo.block(self, Vector3(4.0, 1.0, 1.6), t.call(Vector3(-36, 0.5, 34)), Counterform.GREEN_GREY, Vector3.ZERO, {"bevel": 0.04})
		Geo.block(self, Vector3(1.2, 2.2, 1.2), t.call(Vector3(-40, 1.1, 30)), Counterform.STEEL, Vector3(0, 20, 0), {"bevel": 0.04})
		var lamp := OmniLight3D.new()
		lamp.position = t.call(Vector3(-35, 3.6, 34))
		lamp.light_color = Color("#FFE9C2")
		lamp.light_energy = 0.9
		lamp.omni_range = 10.0
		add_child(lamp)


func _lights() -> void:
	Faultprint.zone_light(self, Vector3(-64, 6.0, 0), Counterform.OXIDE_ORANGE, 24.0)
	Faultprint.zone_light(self, Vector3(64, 6.0, 0), Counterform.SULFUR, 24.0)
	Faultprint.zone_light(self, Vector3(0, 8.0, 0), Color("#9FB7B3"), 30.0)
	for z in [51.0, -51.0]:
		Faultprint.zone_light(self, Vector3(0, 5.0, z), Color("#3FC6C0"), 16.0)
	# Floodlight masts at the yard's corners (scenery above the walls).
	for p in [Vector3(-28, 0, -22), Vector3(28, 0, 22)]:
		Geo.block(self, Vector3(0.5, 14.0, 0.5), p + Vector3(0, 7.0, 0), Counterform.GRAPHITE)
		Geo.scenery(self, LowPoly.chamfer_box(Vector3(2.4, 1.0, 0.6), 0.05), LowPoly.at(p + Vector3(0, 14.2, 0)), Counterform.DUST_WHITE)
