extends SceneTree
## The kill replay on the death screen: a practice bot shoots you on FOLDED WORKS, then
## the replay (over the bot's shoulder), its slowed end, and the gun view after it.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/killcam_shots.gd -- <out_dir>

var out := "user://"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.load_all()
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	Main.map_id = "folded"
	Main.skip_title = true
	change_scene_to_file("res://scenes/main.tscn")
	await frames(8)
	var main := current_scene as Main
	var p := main.player
	p.input_enabled = false
	p.global_position = Vector3(-6, 0.1, 6)
	var bot: Bot = main.bots[0]
	for b in main.bots:
		if b != bot:
			b.passive = true
			b.global_position = Vector3(20, 0.1, -20)
	bot.global_position = Vector3(2, 0.1, 0)
	bot.target = p
	p.health = 1.0e9
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		p.global_position.x = -6.0 + sin(Time.get_ticks_msec() / 400.0) * 2.0
		await process_frame
	# The last shot: the bot's gun, for real.
	p.health = 10.0
	p.take_hit({"attacker": bot, "attacker_name": bot.display_name, "team": bot.team, "damage": 30.0, "zone": "head",
		"dir": (p.global_position - bot.global_position).normalized(), "distance": p.global_position.distance_to(bot.global_position),
		"gun_name": bot.weapon.name, "build": bot.weapon.build.duplicate(true), "effects": {}, "moves": [], "version": bot.weapon.version})
	print("PRINT died: ", not p.alive)
	await create_timer(1.6).timeout
	await shot("killcam_replay")
	await create_timer(1.9).timeout
	await shot("killcam_slow")
	for i in 12:
		await create_timer(0.5).timeout
		var r = main.death._replay
		print("PRINT replay ", r != null, " clock ", r.get_child(1)._clock if r != null else -1.0, " span ", float(main.death._clip.t1) - float(main.death._clip.t0))
	await shot("killcam_gun")
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("PRINT shot ", name)
