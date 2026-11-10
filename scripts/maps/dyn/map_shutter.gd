class_name MapShutter
extends Node3D
## A blast gate across a lane (C12, MapDynamics). It lives in the floor: open, only its
## striped top shows; shut, a slab of armour as tall as the walls stands across the lane
## (with an invisible column above it like every wall, so it can't be climbed over). Its
## group is shut or open by the map's phase; WARN seconds before a change the lamps on the
## lane's walls flash amber and a siren goes. Shut, its cells are rock for the bots.

const THICK := 0.6
const MOVE := 2.2

var uid := ""
var group := 0
var layout: Layout
var cells: Array[Vector2i] = []
var width := 2.0
var tall := 9.0
var closed := false
var k := 0.0           # 0 down .. 1 up
var _warn := false
var _t := 0.0
var _saved: Array[String] = []
var _panel: AnimatableBody3D
var _lid: StaticBody3D
var _lamps: Array[StandardMaterial3D] = []
var _alarm_t := 0.0


func setup_cells(set: Array, through: Vector2i, wall_h: float) -> void:
	for c in set:
		cells.append(c)
		_saved.append(layout.at(c.x, c.y))
	width = cells.size() * layout.cell
	tall = minf(wall_h, 12.0)
	var a := layout.centre(cells[0].x, cells[0].y)
	var b := layout.centre(cells[-1].x, cells[-1].y)
	position = (a + b) / 2.0
	rotation.y = 0.0 if through.y != 0 else PI / 2.0


func _ready() -> void:
	add_to_group("map_shutters")
	_panel = AnimatableBody3D.new()
	_panel.collision_layer = Geo.WORLD
	_panel.collision_mask = 0
	_panel.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, tall, THICK)
	cs.shape = box
	_panel.add_child(cs)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Counterform.GRAPHITE
	mat.metallic = 0.5
	mat.roughness = 0.55
	var m := MeshInstance3D.new()
	m.mesh = LowPoly.chamfer_box(box.size, 0.06)
	m.material_override = mat
	_panel.add_child(m)
	# Ribs up its faces and a hazard band along its top edge (what shows in the floor).
	var rib_mat := StandardMaterial3D.new()
	rib_mat.albedo_color = Counterform.STEEL
	var ribs := int(width / 0.9)
	for i in ribs:
		var rib := MeshInstance3D.new()
		rib.mesh = LowPoly.chamfer_box(Vector3(0.12, tall - 0.4, THICK + 0.1), 0.02)
		rib.material_override = rib_mat
		rib.position = Vector3(-width / 2.0 + (i + 0.5) * width / ribs, 0, 0)
		_panel.add_child(rib)
	var band := StandardMaterial3D.new()
	band.albedo_color = Counterform.SULFUR
	for j in int(width / 0.5):
		if j % 2 == 0:
			var s := MeshInstance3D.new()
			s.mesh = LowPoly.chamfer_box(Vector3(0.5, 0.08, THICK + 0.12), 0.01)
			s.material_override = band
			s.position = Vector3(-width / 2.0 + j * 0.5 + 0.25, tall / 2.0 - 0.02, 0)
			_panel.add_child(s)
	add_child(_panel)
	_lid = Layout.barrier(self, Vector3(width, Layout.CEILING - tall, THICK), Vector3(0, tall + (Layout.CEILING - tall) / 2.0, 0))
	# Lamps on the lane's walls, both ends, both faces.
	for x in [-width / 2.0 - 0.03, width / 2.0 + 0.03]:
		for z in [-0.7, 0.7]:
			_lamps.append(MapDynamics.lamp(self, Vector3(x, 2.6, z), Vector3(0.08, 0.5, 0.3)))
	_place()


func _physics_process(delta: float) -> void:
	_t += delta
	var want := 1.0 if closed else 0.0
	if k != want:
		k = move_toward(k, want, delta / MOVE)
		_place()
	if k > 0.02:
		_clear()
	if _warn:
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			_alarm_t = 1.2
			Sfx.play(self, "shutter_alarm", -6.0, 70.0)
	var c := Color("#e0533d") if closed else Color("#4caf6a")
	if _warn:
		c = Color("#f0b429") if fmod(_t * 3.0, 1.0) < 0.5 else Color(0.2, 0.15, 0.05)
	for l in _lamps:
		l.albedo_color = c


func _place() -> void:
	_panel.position = Vector3(0, -tall / 2.0 + 0.02 + tall * k, 0)
	_panel.collision_layer = Geo.WORLD if k > 0.04 else 0
	_lid.collision_layer = Geo.BOUNDS if k > 0.95 else 0


## Anyone in its footprint while it stands is pushed out to the side they're on.
func _clear() -> void:
	var top := 0.02 + tall * k
	for b in MapDynamics.local_bodies(get_tree()):
		var l: Vector3 = to_local((b as Node3D).global_position)
		if absf(l.x) < width / 2.0 + 0.1 and absf(l.z) < THICK / 2.0 + 0.4 and l.y < top + 0.3 and l.y > -1.0:
			l.z = (THICK / 2.0 + 0.45) * (1.0 if l.z >= 0.0 else -1.0)
			(b as Node3D).global_position = to_global(l)


func set_closed(c: bool, instant := false) -> void:
	if c != closed and not instant:
		Sfx.play(self, "shutter_move", -2.0, 90.0)
	closed = c
	for i in cells.size():
		layout.set_cell(cells[i].x, cells[i].y, "#" if closed else _saved[i])
	if instant:
		k = 1.0 if closed else 0.0
		_place()


func warn(on: bool) -> void:
	_warn = on
	_alarm_t = 0.0


func take_hit(info: Dictionary) -> bool:
	info.blocked = true
	return false


## A new round (Deploy.reset_round): MapDynamics sets the phase back.
func restore() -> void:
	warn(false)
