class_name RangeTarget
extends StaticBody3D
## A firing-range board: a printed silhouette on a stand that never dies. Hits show as
## floating numbers (bigger and yellow for the head) and add to a running total that
## resets after a quiet second, so you can read your gun's burst damage.

var display_name := "標靶"
var _total := 0.0
var _quiet := 0.0
var _label: Label3D
var _sum: Label3D
var _board: Node3D


func _ready() -> void:
	add_to_group("hittable")
	collision_layer = Geo.WORLD
	var stand := MeshInstance3D.new()
	stand.mesh = LowPoly.chamfer_box(Vector3(0.12, 0.9, 0.12), 0.02)
	stand.position.y = 0.45
	stand.material_override = Faultprint.surface(Faultprint.GRAPHITE, {"slip": null})
	add_child(stand)
	_board = Node3D.new()
	add_child(_board)
	var shapes := [["legs", Vector3(0.44, 0.8, 0.06), Vector3(0, 0.4 + 0.5, 0), Faultprint.CONCRETE],
		["body", Vector3(0.56, 0.66, 0.06), Vector3(0, 1.12 + 0.5, 0), Faultprint.BONE],
		["head", Vector3(0.28, 0.28, 0.06), Vector3(0, 1.62 + 0.52, 0), Faultprint.ORANGE]]
	for s in shapes:
		var m := MeshInstance3D.new()
		m.mesh = LowPoly.chamfer_box(s[1], 0.02)
		m.position = s[2]
		m.material_override = Faultprint.surface(s[3], {"dot_density": 30.0})
		_board.add_child(m)
		var area := Area3D.new()
		area.collision_layer = Geo.HITBOX
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("target", self)
		area.set_meta("zone", s[0])
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s[1] + Vector3(0, 0, 0.1)
		cs.shape = box
		area.add_child(cs)
		area.position = s[2]
		add_child(area)
	var col := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.6, 2.5, 0.1)
	col.shape = b
	col.position.y = 1.25
	add_child(col)
	_sum = Label3D.new()
	_sum.position = Vector3(0, 2.7, 0)
	_sum.font_size = 64
	_sum.outline_size = 14
	_sum.modulate = Faultprint.ui_ink
	_sum.outline_modulate = Faultprint.ui_paper
	_sum.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sum.no_depth_test = true
	add_child(_sum)


func take_hit(info: Dictionary) -> bool:
	var dmg: float = info.damage
	_total += dmg
	_quiet = 1.2
	_sum.text = "%d" % roundi(_total)
	var pop := Label3D.new()
	pop.text = "%d" % roundi(dmg)
	pop.font_size = 56 if info.zone == "head" else 40
	pop.outline_size = 12
	pop.modulate = Faultprint.YELLOW if info.zone == "head" else Faultprint.BONE
	pop.outline_modulate = Faultprint.CARBON
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	add_child(pop)
	pop.global_position = info.point + Vector3(randf_range(-0.2, 0.2), 0.2, 0)
	var t := pop.create_tween()
	t.tween_property(pop, "global_position", pop.global_position + Vector3(0, 0.6, 0), 0.6)
	t.parallel().tween_property(pop, "modulate:a", 0.0, 0.6)
	t.tween_callback(pop.queue_free)
	var k := _board.create_tween()
	_board.rotation.x = -0.12
	k.tween_property(_board, "rotation:x", 0.0, 0.25)
	return false


func _process(delta: float) -> void:
	if _quiet > 0.0:
		_quiet -= delta
		if _quiet <= 0.0:
			_total = 0.0
			_sum.text = ""
