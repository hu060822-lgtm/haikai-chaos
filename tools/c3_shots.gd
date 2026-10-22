extends SceneTree
## C3 screenshots: the front end's pages, the room lobby, a 改版死鬥 on 夢核之家 with the
## new HUD (damage numbers, callouts), the held scoreboard and the results.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c3_shots.gd -- <out_dir>

var out := "user://"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.load_all()
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	NetSession.my_name = "luz"
	change_scene_to_file("res://scenes/main.tscn")
	await frames(30)
	var main := current_scene as Main
	await shot("c3_home")
	main.front_end.show_page("practice")
	await frames(6)
	await shot("c3_practice")
	main.front_end.show_page("custom")
	await frames(6)
	await shot("c3_custom")
	main.front_end._quick_match()
	await frames(40)
	await shot("c3_search")
	main.front_end._cancel_search()
	await frames(4)
	main.front_end.visible = false
	main.net.host(24696)
	main.lobby.open()
	main.net.set_config("map", "dream")
	await frames(10)
	await shot("c3_lobby")
	main.net.start_match()
	var ok := await until(func() -> bool: return current_scene is Main and (current_scene as Main).team_match != null and (current_scene as Main).team_match.running, 20.0)
	main = current_scene as Main
	if not ok:
		print("match did not start")
		quit(1)
		return
	var tm := main.team_match
	var p := main.player
	p.input_enabled = false
	p.health = 1.0e9
	await create_timer(14.0).timeout
	p.global_position = Vector3(0, 0.1, 12)
	p.rotation.y = 0.0
	p._pitch = -0.08
	await frames(10)
	p.health = 64.0
	var target := Vector3(0, 1.4, -4)
	main.hud.hit_marker(false, false, {"damage": 28.0, "at": target})
	await frames(3)
	main.hud.hit_marker(true, false, {"damage": 54.0, "at": target})
	await frames(3)
	main.hud.hit_marker(true, true, {"damage": 54.0, "at": target})
	main.hud.callout("雙殺", "＋6", Counterform.SULFUR)
	await frames(4)
	await shot("c3_hud")
	main.scoreboard.visible = true
	main.scoreboard.modulate.a = 1.0
	await frames(6)
	await shot("c3_scoreboard")
	main.scoreboard.visible = false
	p.global_position = Vector3(30, 0.1, 10)
	p.rotation.y = PI * 0.5
	await frames(20)
	await shot("c3_dream_hall")
	tm.scores = [50, 38]
	tm._end.rpc(p.team, tm.scores)
	await frames(12)
	await shot("c3_results")
	main.net.leave()
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("PRINT shot ", name)
