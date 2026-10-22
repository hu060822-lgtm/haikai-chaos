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

const MID := 4.5
const TOP := 9.0
const HALF := Vector2(36, 28)

## Where the player starts (and respawns), facing north (-Z).
var player_spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 22.5))
## Where bots spawn, and the ground points they wander between.
var bot_spawns: Array[Vector3] = []
var waypoints: Array[Vector3] = []
## The firing range's distance boards (range targets are placed by Main).
var range_targets: Array[Transform3D] = []


func _ready() -> void:
	name = "FoldedWorks"
	Faultprint.environment(self, Vector3(-48.0, -32.0, 0.0))
	_ground()
	_perimeter()
	_galleries()
	_centre()
	_ground_cover()
	_range()
	_scenery()
	# Areas told apart by the colour of their light (dark look only).
	Faultprint.zone_light(self, Vector3(0, 6.0, 0), Color("#3FC6C0"), 16.0)
	Faultprint.zone_light(self, Vector3(-18, 5.0, 0), Color("#F07A3A"), 15.0)
	Faultprint.zone_light(self, Vector3(18, 5.0, 0), Color("#E6C25A"), 15.0)


func _ground() -> void:
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
	# North and south walls: plain, the facade split like a print layout.
	for z in [-HALF.y - 0.5, HALF.y + 0.5]:
		Geo.block(self, Vector3(HALF.x * 2 + 2, h, 1.0), Vector3(0, h / 2, z), Faultprint.BONE)
		for i in 8:
			var w := 3.0 + (i % 3) * 1.4
			var x := -HALF.x + 4.5 + i * 9.0
			var y := 6.0 + (i % 2) * 2.5
			Geo.block(self, Vector3(w, 2.2 + (i % 3), 0.3), Vector3(x, y, z - signf(z) * 0.6),
				Faultprint.CARBON if i % 3 == 0 else Faultprint.CONCRETE, Vector3.ZERO, {"print": {"slip": null}})
	# East and west walls are runnable along the gallery gaps (see _galleries).
	for x in [-HALF.x - 0.5, HALF.x + 0.5]:
		var a := Vector2(x, -HALF.y)
		var b := Vector2(x, HALF.y)
		Geo.run_wall(self, a, b, 0.0, h, 1.0, Faultprint.CONCRETE, MID + 1.3)


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
	for x in [-4.4, 4.4]:
		var lip := MeshInstance3D.new()
		lip.mesh = LowPoly.chamfer_box(Vector3(0.1, 0.14, 2.8), 0.02)
		lip.position = duct + Vector3(x, 1.05, 0)
		lip.material_override = Faultprint.surface(Faultprint.ORANGE, {"slip": null, "pattern": 2})
		add_child(lip)
	bot_spawns = [Vector3(-8, 0.1, -20), Vector3(8, 0.1, -21), Vector3(0, 0.1, -10), Vector3(-20, 0.1, -4), Vector3(22, 0.1, 6)]
	waypoints = [Vector3(-8, 0, -20), Vector3(8, 0, -21), Vector3(0, 0, -10), Vector3(-18, 0, -8),
		Vector3(-18, 0, 8), Vector3(18, 0, 8), Vector3(26, 0, -6), Vector3(0, 0, 4), Vector3(-12, 0, 18),
		Vector3(12, 0, 18), Vector3(-28, 0, -10), Vector3(14, 0, -20)]


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
		var dist := rng.randf_range(70.0, 140.0)
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
