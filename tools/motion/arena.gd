## The motion test arena (character overhaul, Phase 3): the same fixed ground for
## recording the real player's moves (motion/record.gd) and for filming the athlete
## replaying them (motion/film.gd). Everything sits far from anything else.
##   a 120 m floor; a long wall along x = -6 (wall runs); a 3.2 m block with a top at
##   z = -32 (climb and mantle); a 6 m tower at x = 20 (high falls, stomps)

const WALL_X := -6.0
const CLIMB_Z := -30.0
const TOWER := Vector3(20, 6, 0)


static func build(parent: Node3D) -> void:
	var c := Faultprint.CONCRETE
	var floor_body := Geo.block(parent, Vector3(120, 1, 120), Vector3(0, -0.5, 0), c)
	floor_body.collision_layer = Geo.WORLD
	_paint(floor_body, Counterform.material("concrete", Color("#6E6A63")))
	var wall := Geo.block(parent, Vector3(1, 6, 60), Vector3(WALL_X - 0.5, 3, -15), Counterform.CONCRETE_DARK)
	wall.collision_layer = Geo.WORLD
	var climb := Geo.block(parent, Vector3(8, 3.2, 4), Vector3(10, 1.6, CLIMB_Z - 2.0), Counterform.CONCRETE_MID)
	climb.collision_layer = Geo.WORLD
	var tower := Geo.block(parent, Vector3(4, 6, 4), Vector3(TOWER.x, 3, TOWER.z), c)
	tower.collision_layer = Geo.WORLD
	_paint(tower, Counterform.material("concrete", Color("#7A766E")))


static func _paint(body: Node, mat: Material) -> void:
	for n in body.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = mat
