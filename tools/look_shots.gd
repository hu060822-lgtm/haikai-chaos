extends SceneTree
## The original and the soft look side by side: the same three views with each.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/look_shots.gd -- <out_dir>

var out := "user://"
var main: Main


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Main.map_id = "lab"
	Main.skip_title = true
	change_scene_to_file("res://scenes/main.tscn")
	await frames(6)
	main = current_scene as Main
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.hud.show_hint("", 0.0)
	var p := main.player
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 600
	main.add_child(cam)
	for look in [0, 1, 2]:
		Faultprint.set_look(look)
		var tag: String = ["orig", "soft", "dark"][look]
		cam.global_position = Vector3(-48, 14, 52)
		cam.rotation_degrees = Vector3(-22, 20, 0)
		cam.current = true
		await frames(4)
		await shot("%s_lane" % tag)
		p.camera.current = true
		main.lab.restart("B")
		await frames(3)
		Input.action_press("move_forward")
		Input.action_press("sprint")
		var jumped := false
		for i in 600:
			await physics_frame
			if not jumped and p.global_position.z < 25.6:
				Input.action_press("jump")
				await physics_frame
				await physics_frame
				Input.action_release("jump")
				jumped = true
			if p.move == Player.Move.WALLRUN and p.global_position.z < 12.0:
				break
		await frames(2)
		await shot("%s_wallrun" % tag)
		for a in ["move_forward", "sprint", "jump"]:
			Input.action_release(a)
		main.lab.restart("C")
		await frames(10)
		await shot("%s_start" % tag)
	# The dark look with chunky pixels (3×).
	Settings.pixels = 2
	Faultprint.apply_post()
	cam.global_position = Vector3(-48, 14, 52)
	cam.rotation_degrees = Vector3(-22, 20, 0)
	p.camera.current = true
	main.lab.restart("C")
	await frames(10)
	await shot("dark_pixels")
	Settings.pixels = 0
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/look_%s.png" % [out, name])
	print("PRINT shot ", name)
