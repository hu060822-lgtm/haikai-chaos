extends SceneTree
## Screenshots of the running prototype: title, first person, aiming, wall run, kill feed,
## bench, death screen.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/game_shots.gd -- <out_dir> [names...]

var out := "user://"
var only: Array = []
var main: Main


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	only = args.slice(1)
	change_scene_to_file("res://scenes/main.tscn")
	await frames(4)
	main = current_scene as Main
	for b in main.bots:
		b.passive = true
	await shot("title")
	main._start()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.hud.show_hint("", 0.0)
	var p := main.player
	await place(Vector3(-3, 0.1, 18.5), -12.0, -4.0)
	await frames(30)
	await shot("first_person")
	Input.action_press("aim")
	await frames(40)
	await shot("aim")
	Input.action_release("aim")
	# A bot in front, then a kill for the feed.
	var bot: Bot = main.bots[0]
	bot.global_position = Vector3(-2, 0.1, 10)
	bot.rotation.y = PI
	await frames(10)
	await shot("bot")
	for i in 2:
		var b2: Bot = main.bots[i + 1]
		b2._die({"attacker": p, "attacker_name": p.display_name, "gun_name": p.weapon.name, "build": p.weapon.build,
			"zone": "head" if i == 0 else "body", "moves": ["牆跑"] if i == 0 else ["滑鏟"], "dir": Vector3.FORWARD, "point": Vector3.ZERO})
	await frames(20)
	await shot("killfeed")
	# Wall run along the west wall.
	await place(Vector3(-35.0, FoldedWorks.MID + 0.1, 14.0), 0.0, 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var jumped := false
	for i in 300:
		await physics_frame
		if not jumped and p.global_position.z < 6.0:
			Input.action_press("jump")
			await physics_frame
			Input.action_release("jump")
			jumped = true
		if p.move == Player.Move.WALLRUN and p.global_position.z < 0.0:
			break
	await shot("wallrun")
	release()
	# Slide down the fold.
	await place(Vector3(14, 0.1, 22.0), 10.0, -4.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(40)
	Input.action_press("crouch")
	await frames(12)
	print("slide at ", main.player.global_position, " move ", main.player.move, " alive ", main.player.alive)
	await shot("slide")
	release()
	# Top beam view with a heavy gun.
	await place(Vector3(14, FoldedWorks.TOP + 0.6, -4), -90.0, -6.0)
	p.equip({"frame": "anti_materiel", "parts": {}, "tune": {}})
	await frames(20)
	await shot("top_beam")
	# Bench.
	p.equip({"frame": "carbine", "parts": {"handguard": "quad_rail", "sight": "holo", "muzzle": "brake", "stock": "crane_stock"}, "tune": {}})
	main.bench.open(p.weapon.build, p.weapon.name)
	await frames(10)
	main.bench._slot = "sight"
	main.bench._refresh()
	await frames(20)
	await shot("bench")
	main.bench.visible = false
	# Death screen.
	var killer_build := GunNames.random_build(bot.rng)
	var info := {"attacker": bot, "attacker_name": "套色-07", "gun_name": GunNames.auto_name(killer_build, Arsenal.stats(killer_build)),
		"build": killer_build, "zone": "head", "moves": ["空中"], "distance": 18.4, "dir": Vector3.FORWARD, "point": Vector3.ZERO}
	p.damage_taken["套色-07"] = 100.0
	p.damage_dealt["套色-07"] = 62.0
	p._die(info)
	await frames(90)
	await shot("death")
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func release() -> void:
	for a in ["move_forward", "sprint", "crouch", "jump", "aim", "fire"]:
		Input.action_release(a)


func place(pos: Vector3, yaw: float, pitch: float) -> void:
	var p := main.player
	p.spawn_at(Transform3D(Basis.IDENTITY, pos))
	p.rotation.y = deg_to_rad(yaw)
	p._pitch = deg_to_rad(pitch)
	await frames(3)


func shot(name: String) -> void:
	if not only.is_empty() and not name in only:
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/game_%s.png" % [out, name])
