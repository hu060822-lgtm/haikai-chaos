extends SceneTree
## 超規卡 (C11): the cards on their own (every card on every frame, cleaning, the
## resonances, the trade resonance halving prices, the card-only effects), then a real
## match: a host alone with bots in card mode. The pick at the build, a reroll, bots
## picking, cards kept through a purchase, a kill stealing a card (and the feed line),
## the random pick when time runs out, and the cards surviving a death.
##   godot --headless --path . --script res://tests/cards_test.gd -- [port]

var failures := 0
var port := NetSession.PORT + 14


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		port = int(args[0])
	_cards()
	change_scene_to_file("res://scenes/main.tscn")
	await _until(func() -> bool: return main() != null and main().is_node_ready(), 5.0)
	await _match()
	print("CARDS TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _map_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			return a.substr(6)
	return ""


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


func _cards() -> void:
	var kinds := Augments.counts(Augments.CARDS.keys())
	check(Augments.CARDS.size() >= 45, "%d cards (槍 %d／身法 %d／交易 %d)" % [Augments.CARDS.size(), kinds.gun, kinds.move, kinds.trade])
	var trades_priced := true
	for id in Augments.CARDS:
		var c: Dictionary = Augments.CARDS[id]
		if c.kind == "trade" and not c.has("cost"):
			trades_priced = false
	check(trades_priced, "every trade card says its price")
	# Every card on every frame: sane numbers.
	var bad := []
	for f in Arsenal.FRAMES:
		for id in Augments.CARDS:
			var s := Arsenal.stats({"frame": f, "parts": {}, "tune": {}, "cards": [id]})
			if int(s.mag) < 1 or float(s.rate) <= 0.0 or float(s.damage) <= 0.0 or float(s.reload) <= 0.0 \
					or not (s.cards as Array) == [id]:
				bad.append("%s+%s" % [f, id])
	check(bad.is_empty(), "every card fits every frame with sane stats %s" % str(bad.slice(0, 4)))
	var base := Arsenal.stats(Arsenal.STARTER)
	var b := Augments.stamp(Arsenal.STARTER, ["deep_pockets", "nope", "deep_pockets", "bounce_rounds"])
	check(b.cards == ["deep_pockets", "bounce_rounds"], "stamping drops unknown and repeated cards")
	check(Arsenal.clean(b).get("cards", []) == b.cards, "cards survive Arsenal.clean")
	check(Weapon.version_of(b) == Weapon.version_of(Arsenal.STARTER), "cards don't make a new gun version")
	var s := Arsenal.stats(b)
	check(int(s.mag) == int(base.mag) * 2 and int(s.effects.get("ricochet", 0)) == 2, "deep pockets doubles the magazine, bounce adds two ricochets")
	check(Augments.stamp(b, []).has("cards") == false, "an empty hand takes the cards off")
	# Resonances.
	var guns := ["bounce_rounds", "needle", "arc_link"]
	check(Augments.resonances(guns) == ["gun"], "three gun cards light the gun resonance")
	var g := Arsenal.stats(Augments.stamp(Arsenal.STARTER, guns))
	check(int(g.effects.ricochet) == 3 and g.effects.get("pierce", false) and float(g.damage) > float(base.damage),
		"異形化: one more bounce, pierce, more damage")
	var moves := ["featherweight", "third_dash", "spring_legs"]
	var mv := Arsenal.stats(Augments.stamp(Arsenal.STARTER, moves))
	check(is_equal_approx(Player.mobility_of(mv), 1.15 * 1.1) and int(mv.effects.extra_dash) == 2, "無重力: faster and two extra dashes")
	var brute := Arsenal.stats(Augments.stamp(Arsenal.STARTER, ["brute"]))
	check(brute.effects.get("no_aim", false), "莽夫 can't aim")
	var soft := Arsenal.stats(Augments.stamp(Arsenal.STARTER, ["brute", "last_word", "tank"]))
	check(not soft.effects.has("no_aim"), "債務重組 lifts 莽夫's no-aim")
	var hard := Arsenal.stats(Augments.stamp(Arsenal.STARTER, ["last_word"]))
	check(int(soft.mag) > int(hard.mag), "債務重組 halves 遺言's smaller magazine (%d > %d)" % [soft.mag, hard.mag])
	check(Player.mobility_of(soft) > 0.82 and Player.mobility_of(soft) < 1.0, "債務重組 halves 鐵皮's slow (%.2f)" % Player.mobility_of(soft))
	# The card-only defence and the referee's count agree.
	var tank := Arsenal.stats(Augments.stamp(Arsenal.STARTER, ["tank"]))
	check(is_equal_approx(Augments.taken(100.0, tank.effects), 65.0), "鐵皮 takes 65 of 100")
	var j := HitJudge.new()
	j.spawned("p9")
	j.took("p9", 100.0, tank.effects, {}, 0.0)
	check(is_equal_approx(float(j.ledger.p9), 35.0), "the host's ledger counts 鐵皮 too")
	var one := Arsenal.stats(Augments.stamp(Arsenal.STARTER, ["one_and_done"]))
	check(int(one.mag) == 1, "一發入魂 leaves one round")
	# Offers never repeat a held card.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var held := Augments.CARDS.keys().slice(0, 40)
	var ok := true
	for i in 50:
		for id in Augments.offer(rng, held, 3):
			ok = ok and not id in held
	check(ok, "a hand never holds a card you already have")


func _kill(tm: TeamMatch, id: String) -> void:
	var me := main().player
	tm.send_hit(id, {"attacker": me, "attacker_name": me.display_name, "team": me.team, "damage": 500.0, "zone": "body",
		"dir": Vector3(0, 0, -1), "distance": 10.0, "gun_name": me.weapon.name, "build": me.weapon.build.duplicate(true),
		"effects": {}, "moves": [], "version": me.weapon.version, "zone_hit": true})


func _match() -> void:
	var m := main()
	check(m.net.host(port) == OK, "opened a room")
	if _map_arg() != "":
		m.net.set_config("map", _map_arg())
	m.net.set_config("team_size", 2)
	m.net.set_config("mode", "cards")
	m.net.set_config("rounds", 3)
	m.net.start_match()
	var started := await _until(func() -> bool: return main() != m and main().team_match != null and main().team_match.running, 15.0)
	check(started, "the match started")
	if not started:
		return
	m = main()
	var tm := m.team_match
	var rules := tm.rules as CardRules
	check(rules != null, "card mode runs CardRules")
	tm.bots_passive = true
	for b in tm.bots():
		b.passive = true
	var me := m.player
	me.health = 1.0e9
	var up := await _until(func() -> bool: return rules.phase == "build" and rules.picking(), 3.0)
	check(up, "round 1 opens with the card pick")
	check(rules.my_offer.size() == Augments.OFFER, "a hand of %d" % Augments.OFFER)
	check(m.mouse_free() and not me.input_enabled, "the cursor is out and the player waits while picking")
	var bots_ok := true
	for b in tm.bots():
		bots_ok = bots_ok and rules.cards_of(b.id).size() == 1 and (b.weapon.build.get("cards", []) as Array).size() == 1
	check(bots_ok, "every bot picked a card and carries it")
	# Reroll.
	var first := rules.my_offer.duplicate()
	rules._ask_reroll()
	await _until(func() -> bool: return rules.my_offer != first, 1.0)
	check(rules.my_offer != first and rules.my_rerolls == CardRules.REROLLS - 1, "a reroll deals a new hand (%d left)" % rules.my_rerolls)
	var pick := str(rules.my_offer[0])
	rules._ask_pick(pick)
	await _until(func() -> bool: return pick in rules.my_cards(), 1.0)
	check(rules.my_cards() == [pick], "the pick is ours: %s" % Augments.card(pick).name)
	check((me.weapon.build.get("cards", []) as Array) == [pick], "and on the gun")
	check(not rules.picking() and me.input_enabled, "the picker closes and play resumes")
	check(rules.strip.get_child_count() >= 1, "the card shows on the HUD strip")
	# Buying keeps the cards.
	var cheap := ""
	for id in Arsenal.FRAMES:
		if id != "revolver" and Arsenal.price_of(id) >= 200 and Arsenal.price_of(id) <= 700:
			cheap = id
			break
	rules.request_buy({"frame": cheap, "parts": {}, "tune": {}}, "便宜")
	check(me.weapon.build.frame == cheap and (me.weapon.build.get("cards", []) as Array) == [pick], "a new gun from the bench keeps the cards")
	# Fight: kill an enemy, take its card.
	rules.phase_left = 0.05
	await _until(func() -> bool: return rules.phase == "fight", 2.0)
	var enemies := []
	for b in tm.bots():
		if b.team != me.team:
			enemies.append(b)
	var victim: Bot = enemies[0]
	var their := rules.cards_of(victim.id).duplicate()
	var feed_before := m.hud.feed.get_child_count()
	_kill(tm, victim.id)
	await _until(func() -> bool: return not victim.alive, 1.0)
	await _wait(0.2)
	var stole: bool = str(their[0]) != pick
	if stole:
		check(their[0] in rules.my_cards() and rules.cards_of(victim.id).is_empty(), "the kill took %s from %s" % [Augments.card(their[0]).name, victim.display_name])
		check(m.hud.feed.get_child_count() >= feed_before + 2, "the kill feed shows the kill and the steal")
		check(their[0] in (me.weapon.build.get("cards", []) as Array), "the stolen card is on our gun at once")
	else:
		check(rules.cards_of(victim.id) == their, "nothing to take when we hold the same card")
	for b in enemies.slice(1):
		_kill(tm, b.id)
	var next := await _until(func() -> bool: return rules.round_no == 2 and rules.phase == "build", RoundRules.END_PAUSE + 4.0)
	check(next, "round 2 begins")
	check(rules.offers.has(enemies[0].id) == false, "bots picked straight away")
	var behind_hand := true
	for b in enemies:
		behind_hand = behind_hand and rules.cards_of(b.id).size() >= 1
	check(behind_hand, "the losers still pick (they had a hand of %d)" % Augments.OFFER_BEHIND)
	await _until(func() -> bool: return rules.picking(), 2.0)
	var n := rules.my_cards().size()
	# Let the clock run out: a card is dealt at random.
	rules.phase_left = 0.05
	var dealt := await _until(func() -> bool: return rules.my_cards().size() == n + 1, 2.0)
	check(dealt and not rules.picking(), "no pick in time: one is dealt at random")
	# Cards stay through a death.
	var keep := rules.my_cards().duplicate()
	me.health = 1.0
	me._apply_damage(50.0, {"attacker": enemies[0], "attacker_id": enemies[0].id, "attacker_name": "x", "team": enemies[0].team, "damage": 50.0}, false)
	await _wait(0.3)
	var lost := keep.size() - rules.my_cards().size()
	check(lost <= 1, "a death loses at most the one card taken (%d)" % lost)
	m.net.leave()
