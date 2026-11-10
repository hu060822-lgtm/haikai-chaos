class_name ThrowArc
extends MeshInstance3D
## The arc a throw would fly (C12), drawn while the throw key is held: dots along the
## path up to the first thing it touches, and a ring where that is. Local player only.

var _im := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat
	visible = false
	global_transform = Transform3D.IDENTITY


## `eye`: where it's seen from (the dashes are turned to face it).
func show_arc(space: PhysicsDirectSpaceState3D, from: Vector3, v: Vector3, exclude: Array, color: Color, eye := Vector3.INF) -> void:
	var res := Grenade.predict(space, from, v, exclude)
	var pts: PackedVector3Array = res[0]
	var end: Vector3 = res[1]
	var n: Vector3 = res[2]
	_im.clear_surfaces()
	if pts.size() < 2:
		visible = false
		return
	global_transform = Transform3D.IDENTITY
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dashes along the path (flat ribbons, so they read from behind), fading in from the hand.
	for i in range(1, pts.size() - 1, 2):
		var a := float(i) / pts.size()
		var d := pts[i + 1] - pts[i]
		var look := (pts[i] - eye) if eye != Vector3.INF else Vector3.UP
		var side := d.cross(look).normalized() * 0.05
		if side.length() < 0.001:
			side = Vector3(0.05, 0, 0)
		_quad(pts[i] - side, pts[i] + side, pts[i + 1] + side, pts[i + 1] - side, Color(color, 0.6 + 0.35 * a))
	# A ring on the surface it reaches.
	var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := n.cross(t1).normalized()
	var r := 0.5
	var w := 0.06
	for k in 20:
		var a0 := TAU * k / 20.0
		var a1 := TAU * (k + 1) / 20.0
		var u0 := t1 * cos(a0) + t2 * sin(a0)
		var u1 := t1 * cos(a1) + t2 * sin(a1)
		var c := end + n * 0.04
		_quad(c + u0 * (r - w), c + u0 * (r + w), c + u1 * (r + w), c + u1 * (r - w), Color(color, 0.95))
	_im.surface_end()
	visible = true


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for v in [a, b, c, a, c, d]:
		_im.surface_set_color(col)
		_im.surface_add_vertex(v)


func hide_arc() -> void:
	if visible:
		visible = false
		_im.clear_surfaces()
