extends SceneTree
## Counterform Industrial screenshots: the backdrop from above the course, first person on
## each route, the held gun close up, the settings menu, and FOLDED WORKS.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/cf_shots.gd -- <out_dir>

var out := "user://"
var main: Main


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.load_all()
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	Main.map_id = OS.get_environment("MAP") if OS.get_environment("MAP") != "" else "lab"
	Main.skip_title = true
	change_scene_to_file("res://scenes/main.tscn")
	await frames(8)
	main = current_scene as Main
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.hud.show_hint("", 0.0)
	var p := main.player
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 900
	main.add_child(cam)
	var tag := Main.map_id
	for spec in [["overview", Vector3(10, 45, 110), Vector3(-14, 0, 0)], ["vista", Vector3(-40, 8, 40), Vector3(8, -150, 0)]]:
		cam.global_position = spec[1]
		cam.rotation_degrees = spec[2]
		cam.current = true
		await frames(6)
		await shot("%s_%s" % [tag, spec[0]])
	p.camera.current = true
	if tag == "lab":
		main.lab.restart("C")
		await frames(10)
		await shot("lab_fp_start")
		p.rotation.y = deg_to_rad(150)
		await frames(6)
		await shot("lab_fp_back")
		p.rotation.y = 0.0
		p._pitch = deg_to_rad(-25)
		Input.action_press("aim")
		await frames(40)
		await shot("lab_fp_aim")
		Input.action_release("aim")
		p._pitch = 0.0
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
		await shot("lab_fp_wallrun")
		for a in ["move_forward", "sprint"]:
			Input.action_release(a)
		main.settings_menu.open()
		await frames(4)
		await shot("lab_settings")
		main.settings_menu.close()
		main.bench.open(main.player.weapon.build, main.player.weapon.name)
		await frames(20)
		await shot("lab_bench")
	else:
		await frames(10)
		await shot("%s_fp" % tag)
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	var only := OS.get_environment("ONLY")
	if only != "" and not name in only.split(","):
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/cf_%s.png" % [out, name])
	print("PRINT shot ", name)
