class_name MapLift
extends Node3D
## A platform column (C12, MapDynamics): a 4 × 4 m block that rises out of the floor to
## HIGH metres, holds there, sinks back and waits, on a fixed CYCLE that every machine
## follows from the host's clock. Up, it's a high angle over the lane for a few seconds;
## the lamps on its corners blink while it moves. Its cells are blocked for the bots.

const SIZE := 3.8
const HIGH := 4.5
const CYCLE := 18.0
## [start, end] of each part of the cycle: down, rising, up, sinking.
const DOWN := 7.0
const RISE := 2.5
const UP := 6.0

var uid := ""
var dyn: MapDynamics
var _body: AnimatableBody3D
var _lamps: Array[StandardMaterial3D] = []
var _cells: Array[Vector2i] = []
var _layout: Layout
var _was_moving := false


## The 2 × 2 cells from `g`.
func setup_cells(layout: Layout, g: Vector2i) -> void:
	_layout = layout
	for dy in 2:
		for dx in 2:
			var c := g + Vector2i(dx, dy)
			_cells.append(c)
			layout.set_cell(c.x, c.y, "o")
	position = (layout.centre(g.x, g.y) + layout.centre(g.x + 1, g.y + 1)) / 2.0


func _ready() -> void:
	add_to_group("map_lifts")
	_body = AnimatableBody3D.new()
	_body.collision_layer = Geo.WORLD
	_body.collision_mask = 0
	_body.sync_to_physics = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE, HIGH, SIZE)
	cs.shape = box
	cs.position = Vector3(0, -HIGH / 2.0, 0)
	_body.add_child(cs)
	var col := StandardMaterial3D.new()
	col.albedo_color = Counterform.CONCRETE_DARK
	col.roughness = 0.9
	var m := MeshInstance3D.new()
	m.mesh = LowPoly.chamfer_box(Vector3(SIZE - 0.1, HIGH - 0.1, SIZE - 0.1), 0.08)
	m.material_override = col
	m.position = Vector3(0, -HIGH / 2.0 - 0.05, 0)
	_body.add_child(m)
	var plate := MeshInstance3D.new()
	plate.mesh = LowPoly.chamfer_box(Vector3(SIZE, 0.12, SIZE), 0.03)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Counterform.STEEL
	steel.metallic = 0.5
	plate.material_override = steel
	plate.position = Vector3(0, -0.06, 0)
	_body.add_child(plate)
	var band := StandardMaterial3D.new()
	band.albedo_color = Counterform.SULFUR
	for e in [[Vector3(0, 0.005, SIZE / 2.0 - 0.12), Vector3(SIZE - 0.1, 0.02, 0.18)], [Vector3(0, 0.005, -SIZE / 2.0 + 0.12), Vector3(SIZE - 0.1, 0.02, 0.18)],
			[Vector3(SIZE / 2.0 - 0.12, 0.005, 0), Vector3(0.18, 0.02, SIZE - 0.1)], [Vector3(-SIZE / 2.0 + 0.12, 0.005, 0), Vector3(0.18, 0.02, SIZE - 0.1)]]:
		var s := MeshInstance3D.new()
		s.mesh = LowPoly.chamfer_box(e[1], 0.005)
		s.material_override = band
		s.position = e[0]
		_body.add_child(s)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_lamps.append(MapDynamics.lamp(_body, Vector3(x * (SIZE / 2.0 - 0.15), 0.06, z * (SIZE / 2.0 - 0.15)), Vector3(0.14, 0.06, 0.14)))
	add_child(_body)
	_body.position = Vector3(0, height_at(0.0), 0)


## The top's height at time `t` of the cycle.
static func height_at(t: float) -> float:
	var c := fposmod(t, CYCLE)
	if c < DOWN:
		return 0.04
	c -= DOWN
	if c < RISE:
		return lerpf(0.04, HIGH, _ease(c / RISE))
	c -= RISE
	if c < UP:
		return HIGH
	c -= UP
	return lerpf(HIGH, 0.04, _ease(clampf(c / (CYCLE - DOWN - RISE - UP), 0.0, 1.0)))


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _physics_process(_delta: float) -> void:
	var t := dyn.lift_clock if dyn != null else 0.0
	var y := height_at(t)
	var moving := absf(y - _body.position.y) > 0.0005
	_body.position = Vector3(0, y, 0)
	if moving and not _was_moving:
		Sfx.play(_body, "lift_move", -8.0, 50.0)
	_was_moving = moving
	var c := Counterform.SULFUR if (moving and fmod(t * 4.0, 1.0) < 0.5) else (Color("#4caf6a") if y > HIGH - 0.05 else Color(0.25, 0.25, 0.22))
	for l in _lamps:
		l.albedo_color = c


func top() -> float:
	return _body.position.y


## A new round (Deploy.reset_round): nothing to put back, the clock drives it.
func restore() -> void:
	pass
