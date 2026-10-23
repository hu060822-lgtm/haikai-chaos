class_name RopeLine
extends MeshInstance3D
## The ANCHOR line as drawn (C6): a thin cable from `a` to `b`, with a bright hook at `b`.
## Everyone sees everyone's line (that's part of the counterplay).

var _hook: MeshInstance3D


func _init() -> void:
	top_level = true
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.022
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#1d2228")
	m.emission_enabled = true
	m.emission = Kit.info("anchor").color * 0.5
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hook = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	_hook.mesh = s
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Kit.info("anchor").color
	_hook.material_override = hm
	_hook.top_level = true
	add_child(_hook)
	visible = false


func show_line(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.05:
		visible = false
		return
	visible = true
	var y := d / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	global_transform = Transform3D(Basis(x, y * length, z), (a + b) / 2.0)
	_hook.global_position = b
