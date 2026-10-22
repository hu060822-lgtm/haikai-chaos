class_name GunThumb
## Pictures of guns for the kill feed, death screen and bench: a build rendered side-on in
## its own little world (studio light in Counterform, transparent background). Cached by build, so
## a gun is rendered once however often it shows up.
##
##   var tex := GunThumb.texture(build, Vector2i(220, 80))   # ViewportTexture
##   var vp := GunThumb.live(build, size)                     # SubViewport that keeps turning

static var _holder: Node
static var _cache := {}


static func _key(build: Dictionary, size: Vector2i) -> String:
	return "%s|%s" % [var_to_str(Arsenal.clean(build)), size]


static func _ensure_holder(tree: SceneTree) -> void:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "GunThumbs"
		tree.root.add_child.call_deferred(_holder)


static func texture(tree: SceneTree, build: Dictionary, size := Vector2i(220, 80)) -> Texture2D:
	var key := _key(build, size)
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return (_cache[key] as SubViewport).get_texture()
	_ensure_holder(tree)
	var vp := _make(build, size, false)
	_holder.add_child.call_deferred(vp)
	_cache[key] = vp
	return vp.get_texture()


## A viewport whose gun slowly turns (death screen, bench). Caller owns and frees it.
static func live(build: Dictionary, size: Vector2i) -> SubViewport:
	return _make(build, size, true)


static func _make(build: Dictionary, size: Vector2i, spin: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if spin else SubViewport.UPDATE_ONCE
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	if Settings.look == Faultprint.COUNTERFORM:
		# A product-shot studio: soft ambient, a warm key from the camera side, a cool fill
		# and a rim from behind, so metal, polymer and glass read apart at kill-feed size.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#B9BEC2")
		env.ambient_light_energy = 0.55
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.95
		for spec in [[Vector3(-35, 40, 0), Color("#FFF0DA"), 1.6], [Vector3(-10, -130, 0), Color("#B8C4CC"), 0.45],
				[Vector3(-20, 180, 0), Color("#FFFFFF"), 0.6]]:
			var l := DirectionalLight3D.new()
			l.rotation_degrees = spec[0]
			l.light_color = spec[1]
			l.light_energy = spec[2]
			vp.add_child(l)
	else:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, 30, 0)
		vp.add_child(sun)
	var pivot := Turner.new()
	pivot.spin = spin
	vp.add_child(pivot)
	var gun := GunModels.build(build)
	pivot.add_child(gun)
	# Frame the gun: centre its bounds and fit its length.
	var aabb := _bounds(gun)
	gun.position = -aabb.get_center()
	var cam := Camera3D.new()
	var aspect := float(size.x) / float(size.y)
	if spin:
		var length := maxf(aabb.size.z, 0.3)
		cam.fov = 30.0
		cam.near = 0.05
		cam.far = 20.0
		cam.look_at_from_position(Vector3(length * 1.35, length * 0.38, 0.0), Vector3.ZERO)
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(aabb.size.z / aspect, aabb.size.y) * 1.12
		cam.position = Vector3(3.0, 0, 0)
		cam.rotation_degrees = Vector3(0, 90, 0)
		cam.near = 0.05
		cam.far = 10.0
	vp.add_child(cam)
	return vp


static func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in _meshes(node):
		var box := m.get_aabb()
		var xf := node.global_transform.affine_inverse() * m.global_transform if m.is_inside_tree() else _local_xform(node, m)
		box = xf * box
		out = box if first else out.merge(box)
		first = false
	return out


static func _local_xform(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out


class Turner:
	extends Node3D
	var spin := false
	var drag := 0.0

	func _process(delta: float) -> void:
		if spin:
			rotate_y(delta * 0.6 + drag)
			drag = lerpf(drag, 0.0, 0.2)
