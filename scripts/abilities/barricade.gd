class_name Barricade
extends StaticBody3D
## BULWARK's panel (C6): a WIDTH × TALL plate of armour that rises out of the floor in
## RISE seconds, stops shots and bodies, and holds for LIFE seconds or HP of damage.
##
## Limits on purpose: it faces one way (walk round it and it is nothing), it can't move
## (no pushing a wall up a lane), it shows its damage, and a RAM charge goes through it.
## Shots on it travel as Deploy events ("hit"), so it breaks on every machine together.

const WIDTH := 2.2
const TALL := 1.9
const THICK := 0.16
const RISE := 0.5
const LIFE := 7.0
const HP := 350.0

var uid := ""
var owner_id := ""
var team := 0
var hp := HP
var t := 0.0
var _plate: MeshInstance3D
var _mat: StandardMaterial3D
var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _base := Vector3.ZERO
var _gone := false


func setup(data: Dictionary) -> void:
	_base = data.get("at", Vector3.ZERO)
	position = _base - Vector3(0, TALL, 0)
	rotation.y = float(data.get("yaw", 0.0))


func _ready() -> void:
	add_to_group("deployables")
	add_to_group("barricades")
	collision_layer = Geo.WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, TALL, THICK)
	cs.shape = box
	cs.position = Vector3(0, TALL / 2.0, 0)
	add_child(cs)
	# A hit area just proud of both faces: shots meet it first and the plate takes them.
	var area := Area3D.new()
	area.collision_layer = Geo.HITBOX
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("target", self)
	area.set_meta("zone", "body")
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(WIDTH, TALL, THICK + 0.12)
	acs.shape = abox
	acs.position = Vector3(0, TALL / 2.0, 0)
	area.add_child(acs)
	add_child(area)
	var color: Color = Kit.info("bulwark").color
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("#3b3f45")
	_mat.metallic = 0.6
	_mat.roughness = 0.45
	_plate = MeshInstance3D.new()
	_plate.mesh = LowPoly.chamfer_box(Vector3(WIDTH, TALL, THICK), 0.04)
	_plate.material_override = _mat
	_plate.position = Vector3(0, TALL / 2.0, 0)
	add_child(_plate)
	# Hazard edge and feet in the class colour, a viewing slit across the top.
	var trim := StandardMaterial3D.new()
	trim.albedo_color = color
	trim.emission_enabled = true
	trim.emission = color * 0.35
	for x in [-WIDTH / 2.0 + 0.06, WIDTH / 2.0 - 0.06]:
		var post := MeshInstance3D.new()
		post.mesh = LowPoly.chamfer_box(Vector3(0.12, TALL + 0.06, THICK + 0.08), 0.02)
		post.material_override = trim
		post.position = Vector3(x, TALL / 2.0, 0)
		add_child(post)
		var foot := MeshInstance3D.new()
		foot.mesh = LowPoly.chamfer_box(Vector3(0.16, 0.08, 0.7), 0.02)
		foot.material_override = trim
		foot.position = Vector3(x, 0.04, -0.3)
		add_child(foot)
	var slit := MeshInstance3D.new()
	slit.mesh = LowPoly.chamfer_box(Vector3(WIDTH * 0.6, 0.05, THICK + 0.02), 0.01)
	var slit_mat := StandardMaterial3D.new()
	slit_mat.albedo_color = Color(0.05, 0.05, 0.06)
	slit.material_override = slit_mat
	slit.position = Vector3(0, TALL - 0.28, 0)
	add_child(slit)
	# What's left of it: a bar along the top, both sides.
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.albedo_color = color
	_bar = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(WIDTH - 0.3, 0.06, THICK + 0.04)
	_bar.mesh = bm
	_bar.material_override = _bar_mat
	_bar.position = Vector3(0, TALL + 0.08, 0)
	add_child(_bar)
	Sfx.play(self, "shield_up", -4.0)
	PrintFx.landing(get_tree().current_scene, _base, 0.6)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	t += delta
	var rise := clampf(t / RISE, 0.0, 1.0)
	global_position = _base - Vector3(0, TALL * (1.0 - (1.0 - pow(1.0 - rise, 3.0))), 0)
	var left := hp / HP
	_bar.scale.x = maxf(left, 0.02)
	_bar.position.x = -(WIDTH - 0.3) * (1.0 - left) / 2.0
	_mat.albedo_color = Color("#3b3f45").lerp(Color("#7a4a3a"), 1.0 - left)
	if t >= LIFE:
		_break(false)


func take_hit(info: Dictionary) -> bool:
	info.blocked = true
	if _gone:
		return false
	var dmg := float(info.get("damage", 0.0))
	if dmg > 0.0:
		Deploy.event(uid, "hit", dmg)
	return false


func on_event(what: String, amount: float) -> void:
	if _gone:
		return
	match what:
		"hit":
			hp -= amount
			Sfx.play(self, "shield_hit", -10.0)
			if hp <= 0.0:
				_break(true)
		"break":
			_break(true)


func _break(smashed: bool) -> void:
	_gone = true
	collision_layer = 0
	for c in get_children():
		if c is Area3D:
			(c as Area3D).collision_layer = 0
	if smashed:
		Sfx.play(self, "shield_break", -2.0)
		PrintFx.explosion(get_tree().current_scene, global_position + Vector3(0, TALL / 2.0, 0), 1.2)
		# C7: the plate comes apart in real pieces, thrown back from its face.
		PhysicsFx.shards(get_tree().current_scene, global_position + Vector3(0, TALL / 2.0, 0), Vector3(0.55, 0.45, THICK),
			_plate.material_override if _plate != null else null, 9, -global_basis.z * 3.0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 0.02, 1.0), 0.18 if smashed else 0.4)
	tw.tween_callback(queue_free)
