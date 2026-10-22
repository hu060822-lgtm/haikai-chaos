extends SceneTree
## 預算戰 screenshots: the lobby with the mode picker, the build phase HUD, the bench as a
## shop, and the overclock zone.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/rounds_shots.gd -- <out_dir>

var out := "user://"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.load_all()
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	change_scene_to_file("res://scenes/main.tscn")
	await frames(10)
	var main := current_scene as Main
	NetSession.my_name = "luz"
	main.net.host(24750)
	main.net.set_config("mode", "rounds")
	main.net.set_config("team_size", 3)
	main.front_end.visible = false
	main.lobby.open()
	await frames(10)
	await shot("rounds_lobby")
	main.net.start_match()
	await create_timer(3.0).timeout
	main = current_scene as Main
	var tm := main.team_match
	tm.bots_passive = true
	for b in tm.bots():
		b.passive = true
	await create_timer(1.0).timeout
	await shot("rounds_build")
	main._try_bench()
	await frames(5)
	main.bench._on_frame("carbine")
	await frames(10)
	await shot("rounds_bench")
	main.bench.close()
	await frames(5)
	var rules := tm.rules
	rules.phase_left = 0.05
	await create_timer(0.5).timeout
	for b in tm.bots():
		b.frozen = true
	rules.phase_left = RoundRules.ZONE_OPENS - 0.5
	await create_timer(1.0).timeout
	var p := main.player
	p.global_position = rules.mid_zone() + Vector3(0, 0.1, 9)
	p.rotation.y = 0.0
	p._pitch = -0.25
	await create_timer(2.5).timeout
	await shot("rounds_zone")
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("PRINT shot ", name)
