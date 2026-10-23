extends SceneTree
## C7: the new map pieces (vault windows, ledges, loose props) and a ragdoll mid-throw.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c7_shots.gd -- <out_dir>

var out := "user://"
var cam: Camera3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://"
	cam = Camera3D.new()
	cam.fov = 80
	cam.far = 600
	root.add_child(cam)
	for id in ["folded", "dream", "yard"]:
		var map: Node3D
		match id:
			"dream": map = DreamHome.new()
			"yard": map = FaultYard.new()
			_: map = FoldedWorks.new()
		root.add_child(map)
		current_scene = map
		for i in 30:
			await physics_frame
		var l: Layout = map.get("layout")
		if not l.windows.is_empty():
			var g: Vector2i = l.windows[0][0]
			var axis: Vector2i = l.windows[0][1]
			var at := l.centre(g.x, g.y)
			var back := Vector3(axis.x, 0, axis.y) * 6.0
			await _shot(at + back + Vector3(0.6, 1.7, 0.4), at + Vector3(0, 1.4, 0), "%s_window" % id)
		if not l.passages.is_empty():
			var p: Array = l.passages[0]
			var axis2: Vector2i = p[1]
			var g2: Vector2i = p[0] + axis2 * (int(p[2]) / 2)
			var at2 := l.centre(g2.x, g2.y)
			await _shot(at2 - Vector3(axis2.x, 0, axis2.y) * 7.0 + Vector3(0, 1.7, 0), at2 + Vector3(0, 1.4, 0), "%s_passage" % id)
		for k in mini(2, l.ledges.size()):
			var g3: Vector2i = l.ledges[k][0]
			var at3 := l.centre(g3.x, g3.y)
			await _shot(at3 + Vector3(5, 2.6, 5), at3 + Vector3(0, 1.0, 0), "%s_ledge%d" % [id, k])
		var props := map.get_node_or_null("Props")
		if props != null and props.get_child_count() > 0:
			var pr := props.get_child(0) as Node3D
			await _shot(pr.global_position + Vector3(3, 2.0, 3), pr.global_position, "%s_props" % id)
		if id == "folded" and props != null and props.get_child_count() > 0:
			await _ragdoll(map, (props.get_child(0) as Node3D).global_position * Vector3(1, 0, 1) + Vector3(0, 0.05, 0))
		map.queue_free()
		for i in 3:
			await process_frame
	quit()


func _shot(from: Vector3, to: Vector3, name: String) -> void:
	cam.look_at_from_position(from, to, Vector3.UP)
	cam.make_current()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _ragdoll(map: Node3D, spot: Vector3) -> void:
	var rig := CompetitorModel.build(Color("#c84a3a"), true, RandomNumberGenerator.new())
	map.add_child(rig)
	rig.global_position = spot
	for i in 2:
		await physics_frame
	CompetitorRig.leave_corpse(rig, Vector3.RIGHT, 6.0, CompetitorRig.kill_force({"blast": true}), Vector3.ZERO)
	for step in [6, 14, 60]:
		for i in step:
			await physics_frame
		await _shot(spot + Vector3(1, 1.8, 6), spot + Vector3(2, 0.6, 0), "ragdoll_%d" % step)
