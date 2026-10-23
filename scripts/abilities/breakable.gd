class_name Breakable
extends StaticBody3D
## A thin sheet-metal panel in a gap of the map's rock (C6): a shortcut that is shut until
## a RAM charges through it. Built by Layout (cells marked 'w'); until it breaks, bots
## treat its cell as rock. Shots only get through with the rounds that go through thin
## walls anyway. A new round puts every panel back (Deploy.reset_round).

const THICK := 0.3

var uid := ""
var broken := false
var layout: Layout
var cell := Vector2i.ZERO
var _parts: Array[Node3D] = []
var _shape: CollisionShape3D


## `size` x/z across the gap and its height; `along_x`: the panel spans x (a gap in a
## wall that runs east-west).
func build(width: float, height: float, along_x: bool) -> void:
	add_to_group("breakables")
	collision_layer = Geo.WORLD
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, THICK) if along_x else Vector3(THICK, height, width)
	_shape.shape = box
	_shape.position = Vector3(0, height / 2.0, 0)
	add_child(_shape)
	var sheet := StandardMaterial3D.new()
	sheet.albedo_color = Color("#6d6a63")
	sheet.metallic = 0.5
	sheet.roughness = 0.6
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Kit.info("ram").color
	stripe.emission_enabled = true
	stripe.emission = Kit.info("ram").color * 0.25
	var plate := MeshInstance3D.new()
	plate.mesh = LowPoly.chamfer_box(box.size, 0.03)
	plate.material_override = sheet
	plate.position = _shape.position
	add_child(plate)
	_parts.append(plate)
	# Corrugation ribs and a hazard band at chest height: "this one gives".
	var ribs := int(width / 0.4)
	for i in ribs:
		var off := -width / 2.0 + (i + 0.5) * width / ribs
		var rib := MeshInstance3D.new()
		rib.mesh = LowPoly.chamfer_box(Vector3(0.06, height - 0.2, THICK + 0.06) if along_x else Vector3(THICK + 0.06, height - 0.2, 0.06), 0.01)
		rib.material_override = sheet
		rib.position = Vector3(off, height / 2.0, 0) if along_x else Vector3(0, height / 2.0, off)
		add_child(rib)
		_parts.append(rib)
	for y in [1.1, 1.45]:
		var band := MeshInstance3D.new()
		band.mesh = LowPoly.chamfer_box(Vector3(width - 0.1, 0.12, THICK + 0.1) if along_x else Vector3(THICK + 0.1, 0.12, width - 0.1), 0.01)
		band.material_override = stripe
		band.position = Vector3(0, y, 0)
		add_child(band)
		_parts.append(band)


func take_hit(info: Dictionary) -> bool:
	info.blocked = true
	return false


func on_event(what: String, _amount: float) -> void:
	if what == "break" and not broken:
		smash()


func smash() -> void:
	broken = true
	collision_layer = 0
	for p in _parts:
		p.visible = false
	if layout != null:
		layout.set_cell(cell.x, cell.y, ".")
	if is_inside_tree():
		Sfx.play(self, "panel_break", -1.0)
		PrintFx.landing(get_tree().current_scene, global_position, 1.0, true)
		_debris()


func restore() -> void:
	if not broken:
		return
	broken = false
	collision_layer = Geo.WORLD
	for p in _parts:
		p.visible = true
	if layout != null:
		layout.set_cell(cell.x, cell.y, "w")


## Bent sheets as real pieces (C7, PhysicsFx), thrown the way the ram was going.
func _debris() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#6d6a63")
	mat.metallic = 0.5
	var push := Vector3.ZERO
	for p in get_tree().get_nodes_in_group("combatants"):
		if p is Node3D and (p as Node3D).global_position.distance_to(global_position) < 4.0 and p.get("velocity") is Vector3:
			push = (p.get("velocity") as Vector3) * 0.8
	PhysicsFx.shards(get_tree().current_scene, global_position + Vector3(0, 1.2, 0), Vector3(0.7, 0.8, 0.05), mat, 8, push, 5.0)
