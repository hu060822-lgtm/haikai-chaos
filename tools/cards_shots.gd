extends SceneTree
## 超規卡 screenshots: the lobby on the card mode, the pick, the HUD strip after a few
## cards (with a resonance), and a steal in the kill feed.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/cards_shots.gd -- <out_dir>

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
	main.net.host(24752)
	main.net.set_config("mode", "cards")
	main.net.set_config("team_size", 3)
	main.front_end.visible = false
	main.lobby.open()
	await frames(10)
	await shot("cards_lobby")
	main.net.start_match()
	await create_timer(3.0).timeout
	main = current_scene as Main
	var tm := main.team_match
	tm.bots_passive = true
	for b in tm.bots():
		b.passive = true
	var rules := tm.rules as CardRules
	await create_timer(1.5).timeout
	await shot("cards_pick")
	# A trade-heavy hand to show the prices.
	rules.offers[tm.my_id] = ["glass_cannon", "wall_loader", "verdict", "brute"]
	rules._offer(rules.offers[tm.my_id], 2)
	await frames(10)
	await shot("cards_pick_behind")
	rules._ask_pick("glass_cannon")
	await frames(5)
	# Hand the host a few more, enough for a resonance.
	for c in ["bounce_rounds", "needle", "arc_link", "wall_loader"]:
		(rules.cards[tm.my_id] as Array).append(c)
	rules._sync.rpc(rules.cards, "", "", "")
	await frames(5)
	rules.phase_left = 0.05
	await create_timer(0.6).timeout
	var enemy: Bot = null
	for b in tm.bots():
		if b.team != main.player.team:
			enemy = b
	var me := main.player
	rules.cards[enemy.id] = ["embers"]
	rules._sync.rpc(rules.cards, "", "", "")
	await frames(3)
	tm.send_hit(enemy.id, {"attacker": me, "attacker_name": me.display_name, "team": me.team, "damage": 500.0, "zone": "head",
		"dir": Vector3(0, 0, -1), "distance": 10.0, "gun_name": me.weapon.name, "build": me.weapon.build.duplicate(true),
		"effects": {}, "moves": ["牆跑"], "version": me.weapon.version, "zone_hit": true})
	await create_timer(0.8).timeout
	await shot("cards_steal")
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("PRINT shot ", name)
