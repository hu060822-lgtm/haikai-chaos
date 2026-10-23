extends SceneTree
## 預算戰 (C4): the price rules on their own, then a real match: a host alone with bots
## in rounds mode. Buying at the bench (paid, and refused when too dear), no damage in the
## build phase, a wiped-out team losing the round and the money that follows, guns kept by
## the living and lost by the dead, the overclock zone deciding a round, and the match
## ending at the round target.
##   godot --headless --path . --script res://tests/rounds_test.gd -- [port]

var failures := 0
var port := NetSession.PORT + 12


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		port = int(args[0])
	_prices()
	change_scene_to_file("res://scenes/main.tscn")
	await _until(func() -> bool: return main() != null and main().is_node_ready(), 5.0)
	await _match()
	print("ROUNDS TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)



## The map to play on: --map=<id> among the test's arguments (else the room's default).
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


## A frame other than the starter with price in lo..hi.
func _frame_in(lo: int, hi: int) -> String:
	for id in Arsenal.FRAMES:
		var p := Arsenal.price_of(id)
		if id != "revolver" and p >= lo and p <= hi:
			return id
	return ""


func _prices() -> void:
	var starter := Arsenal.STARTER.duplicate(true)
	check(RoundRules.cost(starter, starter) == 0, "keeping the same gun costs nothing")
	check(Arsenal.price_of("revolver") == 0, "the starter revolver is free")
	var cheap := _frame_in(200, 700)
	check(cheap != "", "a frame under the starting money exists (%s $%d)" % [cheap, Arsenal.price_of(cheap)])
	var b := {"frame": cheap, "parts": {}, "tune": {}}
	check(RoundRules.cost(starter, b) == Arsenal.price_of(cheap), "a new frame costs its price")
	check(RoundRules.cost(b, starter) == -int(floor(Arsenal.price_of(cheap) * RoundRules.SELL_BACK)),
		"going back sells it for half")
	var slot := ""
	var part := ""
	for s in Arsenal.open_slots(b):
		var options := Arsenal.parts_for(b, s)
		if not options.is_empty():
			slot = s
			part = options[0]
			break
	var with_part := Arsenal.clean({"frame": cheap, "parts": {slot: part}, "tune": {}})
	check(RoundRules.cost(b, with_part) == Arsenal.price_of(part), "adding a part costs the part's price only")
	check(RoundRules.value(with_part) == Arsenal.price_of(cheap) + Arsenal.price_of(part), "a gun's value is the sum of its prices")
	check(RoundRules.loss_pay(1) == RoundRules.LOSS and RoundRules.loss_pay(2) == RoundRules.LOSS + RoundRules.LOSS_STEP
		and RoundRules.loss_pay(9) == RoundRules.LOSS + RoundRules.LOSS_STEP * RoundRules.LOSS_STEPS, "loss money grows with a streak, capped")
	var dear := {"frame": _frame_in(1200, 99999), "parts": {}, "tune": {}}
	check(RoundRules.kill_pay(starter) == RoundRules.KILL, "killing a starter pays the base kill money")
	check(RoundRules.kill_pay(dear) == RoundRules.KILL + int(RoundRules.value(dear) * RoundRules.SALVAGE), "salvage is a quarter of the victim's gun")


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
	m.net.set_config("mode", "rounds")
	m.net.set_config("rounds", 2)
	m.net.start_match()
	var started := await _until(func() -> bool: return main() != m and main().team_match != null and main().team_match.running, 15.0)
	check(started, "the match started")
	if not started:
		return
	m = main()
	var tm := m.team_match
	var rules := tm.rules
	check(rules != null, "rounds mode runs RoundRules")
	tm.bots_passive = true
	for b in tm.bots():
		b.passive = true
	var me := m.player
	m.player.health = 1.0e9
	var building := await _until(func() -> bool: return rules.phase == "build", 3.0)
	check(building and rules.round_no == 1, "round 1 opens with the build phase")
	check(rules.my_money() == RoundRules.START_MONEY, "everyone starts with $%d" % RoundRules.START_MONEY)
	check(me.weapon.build.frame == "revolver", "everyone starts on the starter revolver")
	var all_frozen := true
	for b in tm.bots():
		all_frozen = all_frozen and b.frozen
	check(all_frozen, "bots hold still while building")
	# Damage is off while building.
	var enemy: Bot = null
	for b in tm.bots():
		if b.team != me.team:
			enemy = b
			break
	_kill(tm, enemy.id)
	await _wait(0.2)
	check(enemy.alive, "no damage in the build phase")
	# Too dear: refused, the gun stays.
	var dear := {"frame": _frame_in(1200, 99999), "parts": {}, "tune": {}}
	rules.request_buy(dear, "太貴")
	check(me.weapon.build.frame == "revolver" and rules.my_money() == RoundRules.START_MONEY, "a gun over budget is refused")
	var cheap := _frame_in(200, 700)
	rules.request_buy({"frame": cheap, "parts": {}, "tune": {}}, "便宜")
	var paid := RoundRules.START_MONEY - Arsenal.price_of(cheap)
	check(me.weapon.build.frame == cheap and rules.my_money() == paid, "buying a frame pays for it ($%d left)" % rules.my_money())
	check(m.bench.budget_text.is_valid(), "the bench shows the budget")
	# Leaving the zone isn't allowed while building.
	me.global_position = Vector3(0, 0.1, 0)
	await _wait(0.1)
	check(SafeZone.is_safe(me.global_position, me.team), "the build phase keeps you in your spawn zone")
	# Fight: wipe the other team out.
	rules.phase_left = 0.05
	var fighting := await _until(func() -> bool: return rules.phase == "fight", 2.0)
	check(fighting, "the fight phase starts after the build")
	var enemies := []
	for b in tm.bots():
		check(not b.frozen, "%s moves once the fight starts" % b.display_name)
		if b.team != me.team:
			enemies.append(b)
	var enemy_money := int(rules.money.get(enemies[0].id, 0))
	var bounty := 0
	for e in enemies:
		bounty += RoundRules.kill_pay(rules.builds[e.id])
	for b in enemies:
		_kill(tm, b.id)
	var won := await _until(func() -> bool: return rules.phase == "end", 3.0)
	check(won and rules.wins[me.team] == 1, "wiping out the other team wins the round (%s)" % str(rules.wins))
	var expect := paid + bounty + RoundRules.WIN
	check(rules.my_money() == expect, "kills and the win pay out ($%d, want $%d)" % [rules.my_money(), expect])
	check(int(rules.money[enemies[0].id]) == enemy_money + RoundRules.LOSS, "the losers get the loss money")
	var next := await _until(func() -> bool: return rules.round_no == 2 and rules.phase == "build", RoundRules.END_PAUSE + 3.0)
	check(next, "round 2 begins after the pause")
	check(me.weapon.build.frame == cheap, "the survivor keeps the gun")
	for b in enemies:
		check(b.alive, "%s is back for round 2" % b.display_name)
	# Round 2: the overclock zone.
	rules.phase_left = 0.05
	await _until(func() -> bool: return rules.phase == "fight", 2.0)
	for b in tm.bots():
		b.frozen = true
	rules.phase_left = RoundRules.ZONE_OPENS - 0.5
	var opened := await _until(func() -> bool: return rules.zone_open, 2.0)
	check(opened, "the overclock zone opens near the end")
	me.global_position = rules.mid_zone() + Vector3(0, 0.1, 0)
	var held := await _until(func() -> bool: return rules.phase != "fight", RoundRules.ZONE_HOLD + 3.0)
	check(held and rules.wins[me.team] == 2, "holding the zone alone wins the round (%s)" % str(rules.wins))
	var ended := await _until(func() -> bool: return tm.over, RoundRules.END_PAUSE + 3.0)
	check(ended, "reaching the round target ends the match")
	check(m.results != null and m.results.visible, "the results screen is up")
	m.net.leave()
