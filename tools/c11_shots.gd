extends SceneTree
## C1.1 screenshots: a fast first-person slide (speed lines, speed FOV), a wall run, and the
## settings menu with key bindings.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c11_shots.gd -- <out_dir>

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
	# Route A: sprint, slide down the ramp, shoot at full speed.
	main.lab.restart("A")
	await frames(3)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 600:
		await physics_frame
		if p.global_position.z < 33.0:
			Input.action_press("crouch")
		if p.flat_speed() > 15.0 and p.global_position.z < 20.0:
			break
	await frames(2)
	await shot("fast_slide")
	release()
	# Route B: on the first wall.
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
	await shot("wallrun")
	release()
	main.settings_menu.open()
	await frames(4)
	await shot("settings")
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func release() -> void:
	for a in ["move_forward", "move_left", "move_right", "sprint", "crouch", "jump", "aim", "fire"]:
		Input.action_release(a)


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/c11_%s.png" % [out, name])
	print("PRINT shot ", name)
