extends SceneTree
## 爆破 (C5): a host alone with bots, first to 2 (so the sides swap after round 1). Round
## 1: we attack, plant at A by holding E, and the bomb goes off. Round 2: sides swapped,
## money back to the start, a bot plants at a site and we defuse it.
##   godot --headless --path . --script res://tests/bomb_test.gd -- [port]

var failures := 0
var port := NetSession.PORT + 14


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		port = int(args[0])
	change_scene_to_file("res://scenes/main.tscn")
	await _until(func() -> bool: return main() != null and main().is_node_ready(), 5.0)
	await _match()
	Input.action_release("interact")
	print("BOMB TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func main() -> Main:
	return root.get_node_or_null("Main") as Main


func _until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _calm(tm: TeamMatch) -> void:
	tm.bots_passive = true
	for b in tm.bots():
		b.passive = true


func _match() -> void:
	var m := main()
	check(m.net.host(port) == OK, "opened a room")
	m.net.set_config("team_size", 2)
	m.net.set_config("mode", "bomb")
	m.net.set_config("rounds", 2)
	m.net.start_match()
	var started := await _until(func() -> bool: return main() != m and main().team_match != null and main().team_match.running, 15.0)
	check(started, "the match started")
	if not started:
		return
	m = main()
	var tm := m.team_match
	var rules := tm.rules as BombRules
	check(rules != null, "爆破 runs BombRules")
	_calm(tm)
	var me := m.player
	await _until(func() -> bool: return rules.phase == "build", 3.0)
	check(rules.attackers() == 0 and me.team == 0, "blue attacks first")
	check(rules.sites().size() == 2, "the map has two bomb sites")
	# Round 1: plant at A.
	rules.phase_left = 0.05
	await _until(func() -> bool: return rules.phase == "fight", 2.0)
	_calm(tm)
	for b in tm.bots():
		b.frozen = true
	var money_before := rules.my_money()
	me.global_position = rules.sites()[0] + Vector3(0, 0.1, 0)
	me.velocity = Vector3.ZERO
	me.input_enabled = true
	await _wait(0.3)
	check(rules.site_at(me.global_position) == 0, "standing in site A")
	Input.action_press("interact")
	await _wait(1.0)
	check(not rules.planted, "not planted after a second of holding")
	var planted := await _until(func() -> bool: return rules.planted, BombRules.PLANT_TIME + 2.0)
	Input.action_release("interact")
	check(planted and rules.bomb_site == 0, "holding E in A plants the bomb")
	check(rules.my_money() == money_before + BombRules.OBJECTIVE, "planting pays $%d" % BombRules.OBJECTIVE)
	check(absf(rules.phase_left - BombRules.FUSE) < 3.0, "the fuse runs from %d s (%.1f)" % [int(BombRules.FUSE), rules.phase_left])
	rules.phase_left = 0.05
	var boom := await _until(func() -> bool: return rules.phase == "end", 2.0)
	check(boom and rules.wins[0] == 1, "the bomb going off wins the round for the attackers (%s)" % str(rules.wins))
	# Round 2: sides swap.
	var next := await _until(func() -> bool: return rules.round_no == 2 and rules.phase == "build", RoundRules.END_PAUSE + 3.0)
	check(next, "round 2 begins")
	check(rules.attackers() == 1, "the sides swapped at half time")
	check(rules.my_money() == RoundRules.START_MONEY and me.weapon.build.frame == "revolver", "half time resets money and guns")
	rules.phase_left = 0.05
	await _until(func() -> bool: return rules.phase == "fight", 2.0)
	_calm(tm)
	var planter: Bot = null
	for b in tm.bots():
		b.frozen = true
		if b.team == 1 and planter == null:
			planter = b
	planter.global_position = rules.sites()[1] + Vector3(0, 0.1, 0)
	planter.velocity = Vector3.ZERO
	var bot_planted := await _until(func() -> bool: return rules.planted, BombRules.PLANT_TIME + 3.0)
	check(bot_planted and rules.bomb_site == 1, "an attacking bot plants at B on its own")
	# Kill both attackers: with the bomb down the round goes on.
	for b in tm.bots():
		if b.team == 1:
			tm.send_hit(b.id, {"attacker": me, "attacker_name": me.display_name, "team": me.team, "damage": 500.0, "zone": "body",
				"dir": Vector3(0, 0, -1), "distance": 10.0, "gun_name": me.weapon.name, "build": me.weapon.build.duplicate(true),
				"effects": {}, "moves": [], "version": me.weapon.version, "zone_hit": true})
	await _wait(0.5)
	check(rules.phase == "fight", "wiping out the attackers after the plant doesn't end the round")
	me.global_position = rules.bomb_at + Vector3(1.0, 0.1, 0)
	me.velocity = Vector3.ZERO
	me.input_enabled = true
	await _wait(0.2)
	Input.action_press("interact")
	var defused := await _until(func() -> bool: return rules.phase == "end", BombRules.DEFUSE_TIME + 2.0)
	Input.action_release("interact")
	check(defused and rules.wins[0] == 2, "holding E by the bomb defuses it (%s)" % str(rules.wins))
	var ended := await _until(func() -> bool: return tm.over, RoundRules.END_PAUSE + 3.0)
	check(ended, "first to 2 takes the match")
	m.net.leave()
