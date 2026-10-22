extends SceneTree
## Screenshots of the movement lab: an overview, each route start, and first person with
## the debug panel open mid-move.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/lab_shots.gd -- <out_dir> [names...]

var out := "user://"
var only: Array = []
var main: Main


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	only = args.slice(1)
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
	for spec in [["overview", Vector3(10, 70, 95), Vector3(-38, 0, 0)], ["lane_a", Vector3(-48, 14, 52), Vector3(-22, 20, 0)],
			["lane_b", Vector3(-25, 12, 46), Vector3(-20, 0, 0)], ["lane_c", Vector3(32, 18, 50), Vector3(-22, 12, 0)],
			["practice", Vector3(60, 26, 62), Vector3(-28, 0, 0)]]:
		cam.global_position = spec[1]
		cam.rotation_degrees = spec[2]
		cam.current = true
		await frames(4)
		await shot(spec[0])
	p.camera.current = true
	main.move_debug.toggle()
	# Route B: run and jump onto the first wall, shoot mid wall run.
	main.lab.restart("B")
	await frames(3)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var jumped := false
	for i in 400:
		await physics_frame
		if not jumped and p.global_position.z < 25.6:
			Input.action_press("jump")
			await physics_frame
			Input.action_release("jump")
			jumped = true
		if p.move == Player.Move.WALLRUN and p.global_position.z < 14.0:
			break
	await shot("fp_wallrun_debug")
	release()
	# Route A: slide down the ramp.
	main.lab.restart("A")
	await frames(3)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 400:
		await physics_frame
		if p.global_position.z < 30.0:
			Input.action_press("crouch")
		if p.global_position.z < 18.0:
			break
	await shot("fp_slide_debug")
	release()
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func release() -> void:
	for a in ["move_forward", "move_left", "move_right", "sprint", "crouch", "jump", "aim", "fire"]:
		Input.action_release(a)


func shot(name: String) -> void:
	if not only.is_empty() and not name in only:
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/lab_%s.png" % [out, name])
