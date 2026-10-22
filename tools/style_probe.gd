extends SceneTree
## Quick look at the FAULTPRINT surface: a few blocks, a sphere and a gun lineup.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/style_probe.gd -- out.png

func _init() -> void:
	var out := "user://probe.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var root3 := Node3D.new()
	root.add_child(root3)
	Faultprint.environment(root3)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor.mesh = pm
	floor.material_override = Faultprint.surface(Faultprint.CONCRETE, {"slip": null})
	root3.add_child(floor)
	var colors := [Faultprint.BONE, Faultprint.ORANGE, Faultprint.TEAL, Faultprint.CONCRETE, Faultprint.YELLOW]
	for i in colors.size():
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.6, 2.4 + i * 0.5, 1.6)
		b.mesh = bm
		b.position = Vector3(-5 + i * 2.5, bm.size.y / 2, -6)
		b.rotation_degrees.y = 20 + i * 9
		b.material_override = Faultprint.surface(colors[i])
		root3.add_child(b)
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	s.mesh = sm
	s.position = Vector3(3.5, 1, -2.5)
	s.material_override = Faultprint.surface(Faultprint.BONE)
	root3.add_child(s)
	var builds := [
		{"frame": "carbine", "parts": {}, "tune": {}},
		{"frame": "shotgun", "parts": {}, "tune": {}},
		{"frame": "heavy_pistol", "parts": {}, "tune": {}},
	]
	for i in builds.size():
		var g := GunModels.build(builds[i])
		g.position = Vector3(-1.2, 1.1 + i * 0.32, -1.0)
		g.rotation_degrees.y = 90
		g.scale = Vector3.ONE * 1.4
		root3.add_child(g)
	var cam := Camera3D.new()
	cam.fov = 70
	root3.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.7, 1.6), Vector3(-0.5, 1.3, -3))
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
