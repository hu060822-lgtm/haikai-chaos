extends SceneTree
## 超規卡 (C11) over a real connection: a host and a client process (tools/net_test.sh
## style). The client gets its own hand, picks, and the host sees the card on the client's
## gun; the host kills the client and takes a card; the client sees it gone and the steal
## line in its kill feed.
##   godot --headless --path . --script res://tests/cards_net_test.gd -- host|client [port]
## (tools/cards_net_test.sh runs both.)

var role := "host"
var port := NetSession.PORT + 16
var failures := 0
var _finished := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		role = args[0]
	if args.size() > 1:
		port = int(args[1])
	NetSession.my_name = "主機" if role == "host" else "訪客"
	change_scene_to_file("res://scenes/main.tscn")
	await _until(func() -> bool: return root.get_node_or_null("Main") != null and root.get_node("Main").is_node_ready(), 5.0)
	if role == "host":
		await _host()
	else:
		await _client()
	check(_finished, "ran to the end")
	print("CARDS NET %s TESTS: %s" % [role.to_upper(), "PASS" if failures == 0 else "%d FAILED" % failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print("  %s %s: %s" % ["ok  " if ok else "FAIL", role, what])
	if not ok:
		failures += 1


func main() -> Main:
	return root.get_node_or_null("Main") as Main


func team_match() -> TeamMatch:
	var m := main()
	return m.team_match if m != null else null


func _until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _host() -> void:
	var m := main()
	check(m.net.host(port) == OK, "opened a room")
	var joined := await _until(func() -> bool: return NetSession.roster.size() == 2, 15.0)
	check(joined, "the client joined")
	if not joined:
		return
	var cid := ""
	for p in NetSession.roster:
		if int(p) != 1:
			cid = "p%d" % int(p)
	m.net.set_config("mode", "cards")
	m.net.set_config("team_size", 1)
	m.net.set_config("bots", false)
	m.net.set_config("rounds", 3)
	await _wait(0.5)
	m.net.start_match()
	var started := await _until(func() -> bool: return team_match() != null and team_match().running, 15.0)
	check(started, "the match started")
	if not started:
		return
	m = main()
	var tm := team_match()
	var rules := tm.rules as CardRules
	var me := m.player
	me.health = 1.0e9
	await _until(func() -> bool: return rules.picking(), 4.0)
	# Our pick: one the client wasn't offered, so there is something to steal.
	var theirs: Array = rules.offers.get(cid, [])
	var pick := ""
	for c in rules.my_offer:
		if not c in theirs:
			pick = str(c)
			break
	if pick == "":
		pick = str(rules.my_offer[0])
	rules._ask_pick(pick)
	var got := await _until(func() -> bool: return rules.cards_of(cid).size() == 1, 10.0)
	check(got, "the client's pick reached the host (%s)" % str(rules.cards_of(cid)))
	var avatar: Avatar = tm.entities.get(cid)
	var shown := await _until(func() -> bool: return (avatar.build.get("cards", []) as Array) == rules.cards_of(cid), 5.0)
	check(shown, "the client's gun carries its card on the host")
	rules.phase_left = 0.05
	await _until(func() -> bool: return rules.phase == "fight", 3.0)
	await _wait(0.5)
	var their_card := str(rules.cards_of(cid)[0]) if not rules.cards_of(cid).is_empty() else ""
	tm.send_hit(cid, {"attacker": me, "attacker_name": me.display_name, "team": me.team, "damage": 500.0, "zone": "body",
		"dir": Vector3(0, 0, -1), "distance": 2.0, "point": avatar.global_position + Vector3(0, 1, 0),
		"gun_name": me.weapon.name, "build": me.weapon.build.duplicate(true),
		"effects": {}, "moves": [], "version": me.weapon.version, "zone_hit": true})
	var stole := await _until(func() -> bool: return their_card in rules.my_cards(), 6.0)
	check(stole or their_card == pick, "killing the client took its card (%s)" % their_card)
	check(rules.cards_of(cid).is_empty() or their_card == pick, "and the client no longer has it")
	# Hold the room open while the client checks its side.
	await _wait(4.0)
	_finished = true
	m.net.leave()


func _client() -> void:
	var m := main()
	var ok := await _until(func() -> bool: return m.net.join("127.0.0.1", port) == OK and true, 1.0)
	var joined := await _until(func() -> bool: return NetSession.roster.size() == 2, 15.0)
	check(ok and joined, "joined the host")
	var started := await _until(func() -> bool: return team_match() != null and team_match().running, 20.0)
	check(started, "the match started")
	if not started:
		return
	m = main()
	var tm := team_match()
	var rules := tm.rules as CardRules
	var up := await _until(func() -> bool: return rules.picking(), 8.0)
	check(up and rules.my_offer.size() == Augments.OFFER, "our hand arrived (%s)" % str(rules.my_offer))
	if not up:
		return
	var pick := str(rules.my_offer[0])
	rules._ask_pick(pick)
	var mine := await _until(func() -> bool: return rules.my_cards() == [pick], 5.0)
	check(mine, "the host confirmed our pick")
	check((m.player.weapon.build.get("cards", []) as Array) == [pick], "the card is on our gun")
	var host_has := await _until(func() -> bool: return rules.cards_of("p1").size() == 1, 5.0)
	check(host_has, "we see the host's card too")
	var feed_before := m.hud.feed.get_child_count()
	var dead := await _until(func() -> bool: return not m.player.alive, 10.0)
	check(dead, "the host's shot killed us")
	if rules.cards_of("p1")[0] != pick:
		var gone := await _until(func() -> bool: return is_instance_valid(rules) and rules.my_cards().is_empty(), 5.0)
		check(gone, "our card was taken")
		check(m.hud.feed.get_child_count() >= feed_before + 2, "the feed shows the kill and the steal")
	_finished = true
