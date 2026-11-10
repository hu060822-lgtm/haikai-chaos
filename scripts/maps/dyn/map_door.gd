class_name MapDoor
extends Node3D
## A sliding door across a narrow corridor (C12, MapDynamics). Two steel leaves slide
## into the rock on E (anyone, either side; bots open them as they walk up). Shut, it
## stops shots and bodies; HP of damage (shots, blasts) and it's torn off for the rest
## of the round. A lamp over it: green open, red shut. Changes travel as Deploy events
## ("toggle", "hit"), so the door is the same on every machine.

const TALL := 3.0
const THICK := 0.14
const SLIDE := 0.35
const HP := 300.0

var uid := ""
var open := false
var broken := false
var hp := HP
## A toggle was sent and hasn't come back yet (so bots don't spam it).
var pending := false
var width := 2.0
var _k := 0.0          # 0 shut .. 1 open
var _leaves: Array[AnimatableBody3D] = []
var _area: Area3D
var _lamp: StandardMaterial3D
var _leaf_mat: StandardMaterial3D


## Across cell `g` of `layout`, for walking along `through`.
func setup_cell(layout: Layout, g: Vector2i, through: Vector2i, wall_h: float) -> void:
	width = layout.cell
	position = layout.centre(g.x, g.y)
	# Local z is the way through, local x across.
	rotation.y = 0.0 if through.y != 0 else PI / 2.0
	set_meta("wall_h", wall_h)


func _ready() -> void:
	add_to_group("map_doors")
	var wall_h := float(get_meta("wall_h", 9.0))
	_leaf_mat = StandardMaterial3D.new()
	_leaf_mat.albedo_color = Counterform.STEEL
	_leaf_mat.metallic = 0.55
	_leaf_mat.roughness = 0.5
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Counterform.SULFUR
	for side in [-1.0, 1.0]:
		var leaf := AnimatableBody3D.new()
		leaf.collision_layer = Geo.WORLD
		leaf.collision_mask = 0
		leaf.sync_to_physics = false
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width / 2.0, TALL, THICK)
		cs.shape = box
		cs.position = Vector3(0, TALL / 2.0, 0)
		leaf.add_child(cs)
		var m := MeshInstance3D.new()
		m.mesh = LowPoly.chamfer_box(box.size, 0.02)
		m.material_override = _leaf_mat
		m.position = cs.position
		leaf.add_child(m)
		# A hazard edge where the leaves meet, and a window slit.
		var edge := MeshInstance3D.new()
		edge.mesh = LowPoly.chamfer_box(Vector3(0.08, TALL - 0.1, THICK + 0.04), 0.01)
		edge.material_override = stripe
		edge.position = Vector3(-side * (width / 4.0 - 0.04), TALL / 2.0, 0)
		leaf.add_child(edge)
		var slit := MeshInstance3D.new()
		slit.mesh = LowPoly.chamfer_box(Vector3(width / 2.0 * 0.5, 0.08, THICK + 0.02), 0.01)
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.06, 0.07, 0.08)
		slit.material_override = dark
		slit.position = Vector3(0, 1.65, 0)
		leaf.add_child(slit)
		leaf.set_meta("side", side)
		add_child(leaf)
		_leaves.append(leaf)
	# The header over it, up to the top of the walls: no jumping over a shut door.
	if wall_h > TALL + 0.2:
		var head := StaticBody3D.new()
		head.collision_layer = Geo.WORLD
		head.collision_mask = 0
		var hcs := CollisionShape3D.new()
		var hb := BoxShape3D.new()
		hb.size = Vector3(width + 0.02, wall_h - TALL, 0.6)
		hcs.shape = hb
		hcs.position = Vector3(0, TALL + hb.size.y / 2.0, 0)
		head.add_child(hcs)
		var hm := MeshInstance3D.new()
		hm.mesh = LowPoly.chamfer_box(hb.size, 0.05)
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Counterform.GRAPHITE
		hm.material_override = hmat
		hm.position = hcs.position
		head.add_child(hm)
		add_child(head)
	_lamp = MapDynamics.lamp(self, Vector3(0, TALL + 0.2, 0.32), Vector3(0.5, 0.1, 0.06))
	var back := MapDynamics.lamp(self, Vector3(0, TALL + 0.2, -0.32), Vector3(0.5, 0.1, 0.06))
	back.albedo_color = Color.WHITE
	set_meta("back_lamp", back)
	_area = MapDynamics.hit_area(self, Vector3(width, TALL, THICK + 0.12), Vector3(0, TALL / 2.0, 0))
	_place()


func _physics_process(delta: float) -> void:
	var want := 1.0 if open or broken else 0.0
	if _k != want:
		_k = move_toward(_k, want, delta / SLIDE)
		_place()
		if want == 0.0:
			_clear_doorway()


func _place() -> void:
	for leaf in _leaves:
		var side := float(leaf.get_meta("side"))
		leaf.position = Vector3(side * (width / 4.0 + _k * width / 2.0), 0, 0)
		leaf.visible = not broken
		leaf.collision_layer = 0 if broken else Geo.WORLD
	var shut := _k < 0.5 and not broken
	_area.collision_layer = Geo.HITBOX if shut else 0
	var c := Color("#4caf6a") if (open or broken) else Color("#e0533d")
	_lamp.albedo_color = c
	(get_meta("back_lamp") as StandardMaterial3D).albedo_color = c


## Shutting on someone: they're nudged out to the side they were on.
func _clear_doorway() -> void:
	for b in MapDynamics.local_bodies(get_tree()):
		var l: Vector3 = to_local((b as Node3D).global_position)
		if absf(l.x) < width / 2.0 + 0.1 and absf(l.z) < 0.5 and l.y < TALL:
			l.z = 0.55 if l.z >= 0.0 else -0.55
			(b as Node3D).global_position = to_global(l)


## E (or a bot): open it if shut, shut it if open, for everyone.
func toggle() -> void:
	if broken:
		return
	pending = true
	Deploy.event(uid, "toggle", 0.0 if open else 1.0)


func set_open(o: bool, instant := false) -> void:
	if o != open:
		Sfx.play(self, "door_slide", -8.0, 40.0)
	open = o
	if instant:
		_k = 1.0 if open else 0.0
		_place()


func take_hit(info: Dictionary) -> bool:
	if broken or _k > 0.5:
		return false
	info.blocked = true
	var dmg := float(info.get("damage", 0.0))
	if dmg > 0.0:
		Deploy.event(uid, "hit", dmg)
	return false


func on_event(what: String, amount: float) -> void:
	match what:
		"toggle":
			pending = false
			if not broken:
				set_open(amount > 0.5)
		"hit":
			if broken:
				return
			hp -= amount
			_leaf_mat.albedo_color = Counterform.STEEL.lerp(Counterform.OXIDE_RUST, 1.0 - clampf(hp / HP, 0.0, 1.0))
			Sfx.play(self, "shield_hit", -12.0, 40.0)
			if hp <= 0.0:
				_smash()


func _smash() -> void:
	broken = true
	_place()
	if is_inside_tree():
		Sfx.play(self, "panel_break", -2.0)
		PhysicsFx.shards(get_tree().current_scene, global_position + Vector3(0, 1.5, 0), Vector3(0.5, 0.7, THICK), _leaf_mat, 10,
			Vector3.ZERO, 5.0)


## A new round: whole again, and shut.
func restore() -> void:
	broken = false
	hp = HP
	pending = false
	_leaf_mat.albedo_color = Counterform.STEEL
	open = false
	_k = 0.0
	_place()
