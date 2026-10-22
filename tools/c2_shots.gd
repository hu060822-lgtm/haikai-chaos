extends SceneTree
## C2 screenshots: the title, the lobby, a live 改版死鬥 (host alone with bots), the meta's
## marks, the bench in the field, the death wait and the results.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c2_shots.gd -- <out_dir>

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
	await frames(10)
	var main := current_scene as Main
	await shot("c2_title")
	main._open_lobby()
	main.net.host(24695)
	main.net.set_config("team_size", 4)
	await frames(6)
	await shot("c2_lobby")
	main.net.start_match()
	await frames(4)
	var ok := await until(func() -> bool: return current_scene is Main and (current_scene as Main).team_match != null and (current_scene as Main).team_match.running, 15.0)
	main = current_scene as Main
	if not ok:
		print("match did not start")
		quit(1)
		return
	var tm := main.team_match
	var p := main.player
	p.input_enabled = false
	p.health = 1.0e9
	await frames(20)
	p.rotation.y = 0.0
	p._pitch = -0.05
	await frames(4)
	p.health = 100.0
	await frames(2)
	await shot("c2_spawn")
	p.health = 1.0e9
	# A minute of bots fighting, then the field from the middle.
	await create_timer(20.0).timeout
	tm.time_left = 6 * 60 + 41
	p.global_position = Vector3(0, 0.1, 6)
	p.rotation.y = 0.0
	# Make one enemy bot the meta so its diamond shows.
	for b in tm.bots():
		if b.team != p.team and b.alive:
			tm.meta_version = b.weapon.version
			tm.meta_gun = b.weapon.name
			b.marked = 3.0
	main.hud.show_hint("新的版本答案：「%s」。拿著它的人，所有人都看得到" % tm.meta_gun, 5.0)
	await frames(30)
	p.health = 100.0
	await frames(2)
	await shot("c2_field")
	p.combat_left = 0.0
	main.bench.open(p.weapon.build, p.weapon.name, true)
	await frames(8)
	await shot("c2_bench_field")
	main.bench.close()
	p.health = 100.0
	p.take_hit({"attacker": tm.bots()[0], "attacker_name": tm.bots()[0].display_name, "team": 1 - p.team, "damage": 500.0,
		"zone": "head", "dir": Vector3(0, 0, -1), "distance": 18.0, "gun_name": tm.bots()[0].weapon.name,
		"build": tm.bots()[0].weapon.build, "effects": {}, "moves": ["滑鏟"], "version": 1})
	await create_timer(1.5).timeout
	await shot("c2_death_wait")
	tm.scores = [50, 41]
	tm._end.rpc(p.team, tm.scores)
	await frames(10)
	await shot("c2_results")
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
