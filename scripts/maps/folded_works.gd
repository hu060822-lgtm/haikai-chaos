class_name FoldedWorks
extends Node3D
## FOLDED WORKS (折疊工廠): the first test map. A test facility of giant concrete modules,
## exposed steel and hanging platforms, in three levels:
##   ground (y 0)   main fights, cover, the slide duct, the firing range by the south spawn
##   middle (y 4.5) a ring of galleries; its gaps are crossed by wall-running the orange-
##                  banded walls
##   top (y 9)      narrow beams off the central tower: fast, exposed, the best sight lines
## Routes link the levels without stairs: the central fold (a long ramp to slide down),
## mantle crates, the climb face of the tower and wall-jump shafts.
## Palette: concrete + bone carry the map, teal is the map's own colour, orange marks
## routes, yellow marks edges and warnings.
##
## C5: the hall is now the middle of a much bigger map (about 150 × 105 m, the size of a
## CS / VALORANT map). Doors in its walls lead out to the wings, built from a floor plan
## (Layout) that is the same turned half round, so neither side is favoured:
##   spawns         blue south of the hall, red north, each a room with three exits
##   site A (west)  a big yard of concrete modules: entries from the south lane, the
##                  north lane, and the hall's west door (the short way through mid)
##   site B (east)  the same turned round
##   lanes          a long outer lane from each spawn to each site, and side doors into
##                  the hall from both lanes: every fight has a way round it

const MID := 4.5
const TOP := 9.0
const HALF := Vector2(36, 28)
const AREA := Rect2(-84, -56, 168, 112)
const OUTER_H := 8.0
## Doors through the hall's walls: north and south at these x, west and east at these z.
const DOOR_X := [-22.0, 0.0, 22.0]
const DOOR_W := 6.0
const DOOR_H := 3.6
const SIDE_DOOR_Z := 12.0

## Where the player starts (and respawns), facing north (-Z).
var player_spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 22.5))
## Where bots spawn, and the ground points they wander between.
var bot_spawns: Array[Vector3] = []
var waypoints: Array[Vector3] = []
## The firing range's distance boards (range targets are placed by Main).
var range_targets: Array[Transform3D] = []
## Team match: each team's spawn zone centre and spawn points (blue south, red north).
var team_zones: Array[Vector3] = [Vector3(0, 0, 46), Vector3(0, 0, -46)]
## 預算戰's overclock zone (open floor in the middle of the hall).
var mid_zone := Vector3(0, 0, 0)
## 爆破's bomb sites A and B: the west and east yards.
var bomb_sites: Array = [Vector3(-60, 0, 0), Vector3(60, 0, 0)]
var team_spawns: Array = [
	[Vector3(0, 0.1, 46), Vector3(-3, 0.1, 46), Vector3(3, 0.1, 46), Vector3(-1.5, 0.1, 48.5), Vector3(1.5, 0.1, 48.5)],
	[Vector3(0, 0.1, -46), Vector3(-3, 0.1, -46), Vector3(3, 0.1, -46), Vector3(-1.5, 0.1, -48.5), Vector3(1.5, 0.1, -48.5)],
]
## The floor plan (bots walk it), the play area and the lowest floor (MapGuard).
var layout: Layout
var play_area := AREA
var lowest_floor := 0.0


func _ready() -> void:
	name = "FoldedWorks"
	Faultprint.environment(self, Vector3(-48.0, -32.0, 0.0))
	_plan()
	_ground()
	_perimeter()
	_wings()
	_galleries()
	_centre()
	_ground_cover()
	_range()
	_scenery()
	if Settings.look == Faultprint.COUNTERFORM:
		Counterform.vista(self, Vector3.ZERO, 190.0)
	# Areas told apart by the colour of their light (dark look only).
	Faultprint.zone_light(self, Vector3(0, 6.0, 0), Color("#3FC6C0"), 16.0)
	Faultprint.zone_light(self, Vector3(-18, 5.0, 0), Color("#F07A3A"), 15.0)
	Faultprint.zone_light(self, Vector3(18, 5.0, 0), Color("#E6C25A"), 15.0)


func _ground() -> void:
	# Under everything, a little below the hall's floor: the wings' floor and a net.
	Geo.slab(self, AREA.position, AREA.end, -0.04, 1.0, Faultprint.CONCRETE, {"print": {"slip": null, "wear": 0.5}})
	Geo.slab(self, Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, HALF.y), 0.0, 1.0, Faultprint.CONCRETE,
		{"print": {"slip": null, "wear": 0.4, "shadow_ink": 0.3, "shadow_tone": 0.7, "dot_px": 7.0}})
	# Floor plates in printed blocks: bone lanes and a teal court, slightly raised.
	for x in [-18.0, 18.0]:
		Geo.slab(self, Vector2(x - 3.0, -20), Vector2(x + 3.0, 20), 0.02, 0.1, Faultprint.DUST,
			{"print": {"slip": null}, "bevel": 0.02})
	Geo.slab(self, Vector2(-9, -9), Vector2(9, 9), 0.03, 0.1, Faultprint.DEEP_TEAL,
		{"print": {"slip": null, "wear": 0.5}, "bevel": 0.02})


func _perimeter() -> void:
	var h := 14.0
	# North and south walls: plain, the facade split like a print layout, three doors each.
	for z in [-HALF.y - 0.5, HALF.y + 0.5]:
		var x := -HALF.x - 1.0
		for door in DOOR_X:
			_wall_piece(Vector2(x, z), Vector2(door - DOOR_W / 2.0, z), h, false)
			x = door + DOOR_W / 2.0
		_wall_piece(Vector2(x, z), Vector2(HALF.x + 1.0, z), h, false)
		for door in DOOR_X:
			_lintel(Vector3(door, 0, z), Vector3(DOOR_W, 0, 1.0), h)
		for i in 8:
			var w := 3.0 + (i % 3) * 1.4
			var px := -HALF.x + 4.5 + i * 9.0
			var y := 6.0 + (i % 2) * 2.5
			if Settings.look == Faultprint.COUNTERFORM and i % 3 == 0:
				# Control-room windows looking down on the floor.
				Counterform.glazing(self, w, 2.2 + (i % 3), Vector3(px, y, z - signf(z) * 0.55), 0.0 if z < 0.0 else 180.0)
				continue
			Geo.block(self, Vector3(w, 2.2 + (i % 3), 0.3), Vector3(px, y, z - signf(z) * 0.6),
				Faultprint.CARBON if i % 3 == 0 else Faultprint.CONCRETE, Vector3.ZERO, {"print": {"slip": null}})
	# East and west walls are runnable along the gallery gaps (see _galleries); one door each
	# (west at -SIDE_DOOR_Z, east at +SIDE_DOOR_Z: the map is the same turned round).
	for side in [-1.0, 1.0]:
		var x: float = side * (HALF.x + 0.5)
		var dz: float = side * SIDE_DOOR_Z
		_wall_piece(Vector2(x, -HALF.y), Vector2(x, dz - DOOR_W / 2.0), h, true)
		_wall_piece(Vector2(x, dz + DOOR_W / 2.0), Vector2(x, HALF.y), h, true)
		_lintel(Vector3(x, 0, dz), Vector3(1.0, 0, DOOR_W), h)
	# Nothing gets over the hall's walls either.
	for z in [-HALF.y - 0.5, HALF.y + 0.5]:
		Layout.barrier(self, Vector3(HALF.x * 2 + 2, Layout.CEILING - h, 1.0), Vector3(0, (Layout.CEILING + h) / 2.0, z))
	for x in [-HALF.x - 0.5, HALF.x + 0.5]:
		Layout.barrier(self, Vector3(1.0, Layout.CEILING - h, HALF.y * 2 + 2), Vector3(x, (Layout.CEILING + h) / 2.0, 0))


func _wall_piece(a: Vector2, b: Vector2, h: float, runnable: bool) -> void:
	if a.distance_to(b) < 0.1:
		return
	if runnable:
		Geo.run_wall(self, a, b, 0.0, h, 1.0, Faultprint.CONCRETE, MID + 1.3)
	else:
		var d := b - a
		Geo.block(self, Vector3(maxf(absf(d.x), 1.0), h, maxf(absf(d.y), 1.0)), Vector3((a.x + b.x) / 2.0, h / 2.0, (a.y + b.y) / 2.0), Faultprint.BONE)


## The wall over a door, with a yellow-banded frame so doors read from across the hall.
func _lintel(at: Vector3, span: Vector3, h: float) -> void:
	var size := Vector3(maxf(span.x, 1.0), h - DOOR_H, maxf(span.z, 1.0))
	Geo.block(self, size, Vector3(at.x, DOOR_H + size.y / 2.0, at.z), Faultprint.CONCRETE)
	for s in [-1.0, 1.0]:
		var post := Vector3(s * DOOR_W / 2.0, 0, 0) if span.x > 1.0 else Vector3(0, 0, s * DOOR_W / 2.0)
		var m := MeshInstance3D.new()
		m.mesh = LowPoly.chamfer_box(Vector3(0.25, DOOR_H, 1.15) if span.x > 1.0 else Vector3(1.15, DOOR_H, 0.25), 0.03)
		m.position = at + post + Vector3(0, DOOR_H / 2.0, 0)
		m.material_override = Faultprint.surface(Faultprint.YELLOW, {"slip": null, "pattern": 2})
		add_child(m)


func _galleries() -> void:
	var t := 0.8
	# West and east galleries along the outer walls, each with a wall-run gap in the middle.
	for side in [-1.0, 1.0]:
		var x0: float = side * HALF.x
		var x1: float = side * (HALF.x - 9.0)
		for seg in [[-HALF.y + 7.0, -5.0], [5.0, HALF.y - 7.0]]:
			Geo.slab(self, Vector2(minf(x0, x1), seg[0]), Vector2(maxf(x0, x1), seg[1]), MID, t, Faultprint.BONE)
			_edge(Vector2(x1, seg[0]), Vector2(x1, seg[1]), MID)
			for z in range(int(seg[0]) + 3, int(seg[1]), 7):
				Geo.block(self, Vector3(0.9, MID - t, 0.9), Vector3(x1 + side * 1.0, (MID - t) / 2.0, z), Faultprint.SLATE)
	# North and south bridges join the galleries into a ring. The south one is cut by a gap
	# you cross on the free-standing run wall beside it.
	Geo.slab(self, Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y + 7.0), MID, t, Faultprint.BONE)
	_edge(Vector2(-HALF.x + 9, -HALF.y + 7.0), Vector2(HALF.x - 9, -HALF.y + 7.0), MID)
	for x in [-HALF.x, 6.0]:
		Geo.slab(self, Vector2(x, HALF.y - 7.0), Vector2(x + HALF.x - 6.0, HALF.y), MID, t, Faultprint.BONE)
	Geo.run_wall(self, Vector2(-10.0, HALF.y - 8.2), Vector2(10.0, HALF.y - 8.2), MID - 2.5, 6.0, 0.6, Faultprint.TEAL, 3.8)
	for x in [-6.0, 6.0]:
		Geo.block(self, Vector3(0.7, MID - 2.5, 0.7), Vector3(x, (MID - 2.5) / 2.0, HALF.y - 8.2), Faultprint.SLATE)
	_edge(Vector2(-HALF.x + 9, HALF.y - 7.0), Vector2(-6, HALF.y - 7.0), MID)
	_edge(Vector2(6, HALF.y - 7.0), Vector2(HALF.x - 9, HALF.y - 7.0), MID)
	# Getting up: stairs in two corners, mantle crates in the other two.
	Geo.stairs(self, Vector3(-HALF.x + 11.5, 0, -6.5), Vector3(0, 0, -1), MID, 2.4, Faultprint.CONCRETE)
	Geo.stairs(self, Vector3(HALF.x - 11.5, 0, 6.5), Vector3(0, 0, 1), MID, 2.4, Faultprint.CONCRETE)
	for c in [Vector3(-HALF.x + 10.6, 0, 14.0), Vector3(HALF.x - 10.6, 0, -14.0)]:
		Geo.block(self, Vector3(1.8, 1.5, 1.8), c + Vector3(0, 0.75, 0), Faultprint.YELLOW)
		Geo.block(self, Vector3(1.8, 3.0, 1.8), c + Vector3(signf(c.x) * -0.0, 1.5, signf(c.z) * 1.8), Faultprint.CONCRETE)


## The floor plan: the hall in the middle (built by hand, 'x'), its walls ('o', with
## doors), and the wings carved out of solid rock, every piece also turned half round.
func _plan() -> void:
	var g := Layout.new(AREA, 2.0)
	layout = g
	g.carve(Rect2(-HALF.x - 2, -HALF.y - 2, HALF.x * 2 + 4, HALF.y * 2 + 4), "x")
	for r in [Rect2(-HALF.x - 2, -HALF.y - 2, HALF.x * 2 + 4, 2), Rect2(-HALF.x - 2, HALF.y, HALF.x * 2 + 4, 2),
			Rect2(-HALF.x - 2, -HALF.y - 2, 2, HALF.y * 2 + 4), Rect2(HALF.x, -HALF.y - 2, 2, HALF.y * 2 + 4)]:
		g.carve(r, "o")
	for x in DOOR_X:
		g.carve2(Rect2(x - DOOR_W / 2.0, HALF.y, DOOR_W, 2), ".")
	g.carve2(Rect2(-HALF.x - 2, -SIDE_DOOR_Z - DOOR_W / 2.0, 2, DOOR_W), ".")
	# Hand-built things inside the hall that bots must walk round.
	g.carve(Rect2(5.0, -7.0, 6.0, 6.0), "o")          # the tower
	g.carve(Rect2(13.0, -14.5, 10.0, 5.0), "o")       # the slide duct
	g.carve(Rect2(-8.0, -HALF.y + 7.0, 8.0, 15.0), "o") # under the fold's high end
	g.carve(Rect2(-27.0, 6.0, 4.0, 4.0), "o")         # the wall-jump shaft
	# Spawns, the way into the hall from each, and the lanes out to the sites.
	g.carve2(Rect2(-14, 40, 28, 12), "s")
	g.carve2(Rect2(-3, 30, 6, 10))                    # spawn -> hall (mid)
	g.carve2(Rect2(-52, 44, 38, 6))                   # spawn -> west (A for blue, B for red)
	g.carve2(Rect2(-52, 16, 6, 34))                   # ... and north into the site
	g.carve2(Rect2(14, 44, 48, 6))                    # spawn -> east, the long way
	g.carve2(Rect2(56, 16, 6, 34))                    # ... and north into the other site
	g.carve2(Rect2(-25, 30, 6, 14))                   # hall side doors <-> the lanes
	g.carve2(Rect2(19, 30, 6, 14))
	g.carve2(Rect2(-46, -SIDE_DOOR_Z - DOOR_W / 2.0, 8, DOOR_W))  # hall's west door -> site A (the short way)
	var site := Rect2(-74, -16, 28, 32)
	g.carve(site, "a")
	g.carve(g.turned(site), "b")
	# Cover inside the yards (built in _wings; bots go round).
	for c in SITE_COVER:
		var r: Rect2 = c[0]
		g.carve2(r.grow(-0.01), "c")


## Cover in site A: [rect (x/z), height, colour index]. Site B gets the same turned round.
const SITE_COVER := [
	[Rect2(-66, -6, 4, 4), 2.6, 0],       # the big module by the plant spot
	[Rect2(-56, 4, 2, 4), 1.2, 1],        # low crates
	[Rect2(-70, 8, 4, 2), 1.2, 1],
	[Rect2(-54, -10, 6, 2), 1.2, 2],      # half wall facing the hall's door
	[Rect2(-72, -14, 4, 4), 2.6, 0],
	[Rect2(-60, 12, 4, 2), 2.6, 3],
]


## The wings: rock walls round every lane, floors, cover, lights and markings.
func _wings() -> void:
	var colors := [Faultprint.CONCRETE, Faultprint.SLATE, Faultprint.BONE]
	var n := [0]
	layout.build_walls(self, OUTER_H, func(size: Vector3, at: Vector3) -> void:
		var b := Geo.block(self, size, at, colors[n[0] % colors.size()], Vector3.ZERO, {"bevel": 0.1, "print": {"wear": 0.45}})
		b.collision_layer = Geo.WORLD | Geo.RUNNABLE
		b.add_to_group("runnable")
		n[0] += 1)
	# Floors: spawn rooms and sites printed in their own colours over the base slab.
	for r in layout.rects("s"):
		Geo.slab(self, r.position, r.end, 0.02, 0.1, Faultprint.DEEP_TEAL, {"print": {"slip": null, "wear": 0.5}, "bevel": 0.02})
	for r in layout.rects("ab"):
		Geo.slab(self, r.position, r.end, 0.02, 0.1, Faultprint.DUST, {"print": {"slip": null, "wear": 0.4}, "bevel": 0.02})
	var cover_colors := [Faultprint.TEAL, Faultprint.YELLOW, Faultprint.CONCRETE, Faultprint.BONE]
	for c in SITE_COVER:
		for r in [c[0], layout.turned(c[0])]:
			var rr: Rect2 = r
			Geo.block(self, Vector3(rr.size.x, c[1], rr.size.y), Vector3(rr.get_center().x, float(c[1]) / 2.0, rr.get_center().y),
				cover_colors[int(c[2])], Vector3.ZERO, {"bevel": 0.08})
	# A raised walkway along each yard's back wall, up a flight of stairs: a place to hold from.
	for flip in [false, true]:
		var shelf := Rect2(-74, -2, 4, 14)
		var stair_at := Vector3(-70.0, 0, 12.0)
		var dir := Vector3(0, 0, -1)
		if flip:
			shelf = layout.turned(shelf)
			stair_at = Layout.turn(stair_at)
			dir = -dir
		Geo.slab(self, shelf.position, shelf.end, 3.0, 0.5, Faultprint.BONE)
		_edge(Vector2(shelf.end.x if not flip else shelf.position.x, shelf.position.y),
			Vector2(shelf.end.x if not flip else shelf.position.x, shelf.end.y), 3.0)
		Geo.stairs(self, stair_at + Vector3(-2.0 if not flip else 2.0, 0, 0), dir, 3.0, 3.6, Faultprint.CONCRETE)
	# Lane cover: a few crates so long lanes aren't shooting galleries.
	for p in [Vector3(-49, 0, 30), Vector3(-36, 0, 47), Vector3(40, 0, 46.5), Vector3(59, 0, 32), Vector3(-22, 0, 37)]:
		for q in [p, Layout.turn(p)]:
			Geo.block(self, Vector3(1.8, 1.3, 1.8), q + Vector3(0, 0.65, 0), Faultprint.YELLOW, Vector3(0, 20, 0), {"bevel": 0.06})
	# Lights: orange over A, yellow over B, teal in the spawns, plain along the lanes.
	Faultprint.zone_light(self, Vector3(-60, 6.0, 0), Color("#F07A3A"), 22.0)
	Faultprint.zone_light(self, Vector3(60, 6.0, 0), Color("#E6C25A"), 22.0)
	for z in [46.0, -46.0]:
		Faultprint.zone_light(self, Vector3(0, 5.0, z), Color("#3FC6C0"), 16.0)
	# Big site letters on the back walls.
	for i in 2:
		var l := Label3D.new()
		l.text = "AB"[i]
		l.font_size = 900
		l.pixel_size = 0.01
		l.modulate = Color("#F07A3A") if i == 0 else Color("#E6C25A")
		l.outline_size = 0
		l.position = Vector3(-73.9, 5.0, 0) if i == 0 else Vector3(73.9, 5.0, 0)
		l.rotation_degrees = Vector3(0, 90 if i == 0 else -90, 0)
		l.shaded = false
		add_child(l)


## A yellow lip on a platform edge so drops read at speed.
func _edge(a: Vector2, b: Vector2, top: float) -> void:
	var d := b - a
	var m := MeshInstance3D.new()
	m.mesh = LowPoly.chamfer_box(Vector3(maxf(absf(d.x), 0.18), 0.08, maxf(absf(d.y), 0.18)), 0.02)
	m.position = Vector3((a.x + b.x) / 2.0, top + 0.03, (a.y + b.y) / 2.0)
	m.material_override = Faultprint.surface(Faultprint.YELLOW, {"slip": null, "pattern": 2})
	add_child(m)


func _centre() -> void:
	# The fold: a long concrete slab from the north bridge down into the court. Slide it.
	Geo.ramp(self, Vector3(-4.0, 0.0, 6.0), Vector3(-4.0, MID, -HALF.y + 7.0), 6.0, Faultprint.CONCRETE)
	# The central tower: top level, climb face on the south side (orange chevron column).
	var tower := Vector3(8.0, 0, -4.0)
	Geo.block(self, Vector3(5.0, TOP, 5.0), tower + Vector3(0, TOP / 2.0, 0), Faultprint.TEAL)
	Geo.block(self, Vector3(5.6, 0.5, 5.6), tower + Vector3(0, TOP + 0.25, 0), Faultprint.CARBON)
	var climb := Geo.run_wall(self, Vector2(tower.x - 1.3, tower.z + 2.75), Vector2(tower.x + 1.3, tower.z + 2.75),
		0.0, TOP - 0.2, 0.3, Faultprint.BONE, 1.2)
	climb.add_to_group("climbable")
	# Top beams from the tower to the galleries' walls. Narrow on purpose.
	Geo.block(self, Vector3(HALF.x - tower.x - 2.5, 0.5, 1.3), Vector3((tower.x + 2.5 + HALF.x) / 2.0, TOP + 0.25, tower.z), Faultprint.CONCRETE)
	Geo.block(self, Vector3(1.3, 0.5, HALF.y + tower.z - 2.5), Vector3(tower.x, TOP + 0.25, (tower.z - 2.5 - HALF.y) / 2.0), Faultprint.CONCRETE)
	for p in [Vector3(HALF.x - 3.0, TOP, tower.z), Vector3(tower.x, TOP, -HALF.y + 3.0)]:
		Geo.block(self, Vector3(3.0, 0.5, 3.0), p + Vector3(0, 0.25, 0), Faultprint.CONCRETE)
		Geo.block(self, Vector3(0.6, TOP - MID, 0.6), Vector3(p.x, (TOP + MID) / 2.0, p.z), Faultprint.SLATE)
	# Wall-jump shaft: two close walls west of the court, kick up between them to the gallery.
	for z in [6.4, 9.8]:
		Geo.block(self, Vector3(4.0, MID + 2.0, 0.5), Vector3(-25.0, (MID + 2.0) / 2.0, z), Faultprint.CONCRETE)


func _ground_cover() -> void:
	var cover := [
		[Vector3(3.2, 1.2, 1.0), Vector3(-10, 0, 0), 0.0, Faultprint.CONCRETE],
		[Vector3(1.0, 1.2, 3.2), Vector3(12, 0, 5), 0.0, Faultprint.CONCRETE],
		[Vector3(2.2, 2.2, 2.2), Vector3(-14, 0, -12), 22.0, Faultprint.BONE],
		[Vector3(2.2, 2.2, 2.2), Vector3(16, 0, 12), -14.0, Faultprint.BONE],
		[Vector3(4.0, 1.2, 1.0), Vector3(0, 0, 12), 0.0, Faultprint.YELLOW],
		[Vector3(1.4, 2.6, 1.4), Vector3(-6, 0, -14), 45.0, Faultprint.SLATE],
		[Vector3(1.4, 2.6, 1.4), Vector3(22, 0, -2), 45.0, Faultprint.SLATE],
	]
	for c in cover:
		var size: Vector3 = c[0]
		Geo.block(self, size, c[1] + Vector3(0, size.y / 2.0, 0), c[3], Vector3(0, c[2], 0))
	for w in [[Vector3(4.0, 2.2, 3.0), Vector3(-26, 0, -18), 0.0], [Vector3(4.0, 2.2, 3.0), Vector3(26, 0, 18), 180.0],
			[Vector3(3.0, 1.6, 2.4), Vector3(4, 0, -16), 90.0]]:
		Geo.wedge(self, w[0], w[1], Faultprint.CONCRETE, w[2])
	# The slide duct: a heavy block with a 1.1 m tunnel through it, east-west.
	var duct := Vector3(18.0, 0, -12.0)
	for z in [-1.8, 1.8]:
		Geo.block(self, Vector3(9.0, 1.1, 0.8), duct + Vector3(0, 0.55, z), Faultprint.CONCRETE)
	Geo.block(self, Vector3(9.0, 1.6, 4.4), duct + Vector3(0, 1.9, 0), Faultprint.TEAL)
	if Settings.look == Faultprint.COUNTERFORM:
		# A glazed roof light on the duct block: glass lying flat in a steel frame.
		var roof := Counterform.glazing(self, 6.0, 2.4, duct + Vector3(0, 2.72, 0), 0.0)
		roof.rotation_degrees = Vector3(-90, 0, 0)
	for x in [-4.4, 4.4]:
		var lip := MeshInstance3D.new()
		lip.mesh = LowPoly.chamfer_box(Vector3(0.1, 0.14, 2.8), 0.02)
		lip.position = duct + Vector3(x, 1.05, 0)
		lip.material_override = Faultprint.surface(Faultprint.ORANGE, {"slip": null, "pattern": 2})
		add_child(lip)
	bot_spawns = [Vector3(-8, 0.1, -20), Vector3(8, 0.1, -21), Vector3(0, 0.1, -10), Vector3(-20, 0.1, -4), Vector3(22, 0.1, 6)]
	waypoints = layout.wander_points(5)


func _range() -> void:
	# The firing range: a strip by the south spawn with boards at 10, 20 and 35 m (north).
	for i in 3:
		var d: float = [10.0, 20.0, 35.0][i]
		var x := -14.0 + i * 3.0
		range_targets.append(Transform3D(Basis.IDENTITY, Vector3(x, 0, 22.5 - d)))
		# Distance tick on the floor in front of each board.
		Geo.slab(self, Vector2(x - 0.8, 22.5 - d + 0.6), Vector2(x + 0.8, 22.5 - d + 0.9), 0.06, 0.05,
			Faultprint.YELLOW, {"print": {"slip": null, "pattern": 2}, "bevel": 0.01})


func _scenery() -> void:
	# Out past the walls: fractured towers at the wrong scale, fading into the paper.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var colors := [Faultprint.CONCRETE, Faultprint.BONE, Faultprint.TEAL, Faultprint.CONCRETE, Faultprint.DUST]
	for i in 26:
		var ang := TAU * i / 26.0 + rng.randf_range(-0.08, 0.08)
		var dist := rng.randf_range(125.0, 200.0)
		var h := rng.randf_range(30.0, 95.0)
		var w := rng.randf_range(8.0, 22.0)
		var pos := Vector3(cos(ang) * dist, h / 2.0 - rng.randf_range(0.0, 10.0), sin(ang) * dist)
		var rot := Vector3(rng.randf_range(-9, 9), rng.randf_range(0, 90), rng.randf_range(-12, 12))
		Geo.scenery(self, LowPoly.chamfer_box(Vector3(w, h, w * rng.randf_range(0.4, 1.0)), 0.8),
			LowPoly.at(pos, rot), colors[i % colors.size()], {"dot_density": 1.2, "wear": 0.5})
		if i % 3 == 0:
			# A sliced-off top block, floating a little off its tower.
			Geo.scenery(self, LowPoly.chamfer_box(Vector3(w * 1.1, h * 0.18, w), 0.6),
				LowPoly.at(pos + Vector3(rng.randf_range(-3, 3), h * 0.62, 0), rot + Vector3(0, 0, rng.randf_range(-14, 14))),
				Faultprint.BONE if i % 2 == 0 else Faultprint.ORANGE, {"dot_density": 1.2})
	# The hanging ring over the court: the map's landmark.
	var ring := Node3D.new()
	ring.position = Vector3(-2, 21, -2)
	ring.rotation_degrees = Vector3(72, 20, 0)
	add_child(ring)
	for i in 14:
		var a := TAU * i / 14.0
		var seg := MeshInstance3D.new()
		seg.mesh = LowPoly.chamfer_box(Vector3(5.2, 2.4, 3.2), 0.25)
		seg.position = Vector3(cos(a) * 11.0, sin(a) * 11.0, (i % 2) * 0.6)
		seg.rotation.z = a + PI / 2.0
		seg.material_override = Faultprint.surface(Faultprint.CONCRETE if i % 4 else Faultprint.TEAL, {"dot_density": 3.0})
		ring.add_child(seg)
	for cable in [Vector3(-12, 0, 0), Vector3(12, 0, 0)]:
		var c := MeshInstance3D.new()
		c.mesh = LowPoly.chamfer_box(Vector3(0.12, 30.0, 0.12), 0.02)
		c.position = Vector3(-2, 21, -2) + cable + Vector3(0, 15.0, 0)
		c.material_override = Faultprint.surface(Faultprint.CARBON, {"slip": null, "pattern": 2})
		add_child(c)
