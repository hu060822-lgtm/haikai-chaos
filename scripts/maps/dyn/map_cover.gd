class_name MapCover
extends StaticBody3D
## A concrete barrier (C12, MapDynamics): waist-high cover you can vault, crouch behind,
## or shoot apart. It chips and darkens as it takes damage (shots, grenades) and comes
## apart in real pieces at 0 HP; a new round builds it again. Its cell is low cover for
## the bots ('c') while it stands. Damage travels as Deploy events ("hit").

const LONG := 2.8
const TALL := 1.15
const DEEP := 0.8
const HP := 300.0

var uid := ""
var hp := HP
var broken := false
var _layout: Layout
var _cell := Vector2i.ZERO
var _saved := "."
var _parts: Array[MeshInstance3D] = []
var _chips: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _area: Area3D
var _shape: CollisionShape3D


## On cell `g`, long side across x if `across_x`.
func setup_cell(layout: Layout, g: Vector2i, across_x: bool) -> void:
	_layout = layout
	_cell = g
	_saved = layout.at(g.x, g.y)
	layout.set_cell(g.x, g.y, "c")
	position = layout.centre(g.x, g.y)
	rotation.y = PI / 2.0 if across_x else 0.0


func _ready() -> void:
	add_to_group("map_cover")
	collision_layer = Geo.WORLD
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LONG, TALL, DEEP)
	_shape.shape = box
	_shape.position = Vector3(0, TALL / 2.0, 0)
	add_child(_shape)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Counterform.BONE_CONCRETE
	_mat.roughness = 0.95
	# A jersey barrier: a wide foot, a narrower top, a sulfur reflector strip.
	for spec in [[Vector3(LONG, 0.5, DEEP), Vector3(0, 0.25, 0)], [Vector3(LONG - 0.04, 0.68, DEEP * 0.55), Vector3(0, 0.81, 0)]]:
		var m := MeshInstance3D.new()
		m.mesh = LowPoly.chamfer_box(spec[0], 0.08)
		m.material_override = _mat
		m.position = spec[1]
		add_child(m)
		_parts.append(m)
	var strip := MeshInstance3D.new()
	strip.mesh = LowPoly.chamfer_box(Vector3(LONG * 0.7, 0.08, DEEP * 0.55 + 0.02), 0.01)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Counterform.SULFUR
	strip.material_override = sm
	strip.position = Vector3(0, 0.95, 0)
	add_child(strip)
	_parts.append(strip)
	# Corner chips that fall off as it's worn down.
	for x in [-LONG / 2.0 + 0.25, LONG / 2.0 - 0.25]:
		var c := MeshInstance3D.new()
		c.mesh = LowPoly.chamfer_box(Vector3(0.5, 0.3, DEEP * 0.6), 0.05)
		c.material_override = _mat
		c.position = Vector3(x, 1.0, 0)
		add_child(c)
		_parts.append(c)
		_chips.append(c)
	_area = MapDynamics.hit_area(self, Vector3(LONG + 0.06, TALL + 0.05, DEEP + 0.1), Vector3(0, TALL / 2.0, 0))


func take_hit(info: Dictionary) -> bool:
	if broken:
		return false
	info.blocked = true
	var dmg := float(info.get("damage", 0.0))
	if dmg > 0.0:
		Deploy.event(uid, "hit", dmg)
	return false


func on_event(what: String, amount: float) -> void:
	if broken or what != "hit":
		return
	hp -= amount
	var left := clampf(hp / HP, 0.0, 1.0)
	_mat.albedo_color = Counterform.BONE_CONCRETE.lerp(Counterform.CONCRETE_DARK, 1.0 - left)
	for i in _chips.size():
		if _chips[i].visible and left < 0.66 - i * 0.3:
			_chips[i].visible = false
			if is_inside_tree():
				PhysicsFx.shards(get_tree().current_scene, _chips[i].global_position, Vector3(0.2, 0.15, 0.2), _mat, 3, Vector3.UP, 3.0)
	if is_inside_tree():
		Sfx.play(self, "cover_hit", -14.0, 40.0)
	if hp <= 0.0:
		_crumble()


func _crumble() -> void:
	broken = true
	collision_layer = 0
	_area.collision_layer = 0
	for p in _parts:
		p.visible = false
	_layout.set_cell(_cell.x, _cell.y, _saved)
	if is_inside_tree():
		Sfx.play(self, "cover_break", -2.0)
		PrintFx.landing(get_tree().current_scene, global_position, 1.0, true)
		PhysicsFx.shards(get_tree().current_scene, global_position + Vector3(0, 0.6, 0), Vector3(0.45, 0.35, 0.35), _mat, 12, Vector3.ZERO, 6.0)


func restore() -> void:
	hp = HP
	_mat.albedo_color = Counterform.BONE_CONCRETE
	if not broken:
		for c in _chips:
			c.visible = true
		return
	broken = false
	collision_layer = Geo.WORLD
	_area.collision_layer = Geo.HITBOX
	for p in _parts:
		p.visible = true
	_layout.set_cell(_cell.x, _cell.y, "c")
