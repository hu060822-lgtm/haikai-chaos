extends SceneTree
## Headless checks for this round: the reload animation's moving pieces, the out-of-combat
## bench rule and safe zones, the death screen keeping its buttons on screen, and the
## CHAOS 2 part effects.
##   godot --headless --path . --script res://tests/chaos2_test.gd

var map: FoldedWorks
var player: Player
var failures := 0


func _init() -> void:
	InputSetup.register()
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	map = FoldedWorks.new()
	scene.add_child(map)
	player = Player.new()
	scene.add_child(player)
	await physics_frame
	await _test_reload()
	await _test_safe_zones()
	await _test_death_screen()
	_test_damage_parts()
	await _test_feed_parts()
	await _test_hit_parts()
	_test_scoring()
	print("CHAOS2 TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _spawn(at := Vector3(0, 0.1, 18)) -> void:
	player.spawn_at(Transform3D(Basis.IDENTITY, at))
	await frames(3)


func _bot(at: Vector3, team := 1) -> Bot:
	var bot := Bot.new()
	bot.passive = true
	current_scene.add_child(bot)
	bot.spawn(at, 5)
	bot.team = team
	bot.passive = true
	bot.waypoints = [at]
	await frames(4)
	return bot


func _aim_at(target: Node3D) -> void:
	player._pitch = 0.0
	player.rotation.y = 0.0
	player._place_head(player.global_position)
	player.camera.look_at(target.global_position + Vector3(0, 1.0, 0), Vector3.UP)


func _test_reload() -> void:
	print("reload animation")
	await _spawn()
	player.equip({"frame": "carbine", "parts": {}, "tune": {}})
	var gun := player.view.gun_node()
	check(gun.has_node("Magazine") and gun.get_node("Magazine").get_child_count() > 0, "the carbine's magazine is its own node")
	player.weapon.ammo = 0
	player.weapon.start_reload()
	player._on_reload(true)
	var total := player.weapon.reload_time()
	var mag_low := 0.0
	var hand_far := 0.0
	var steps := int(total / (1.0 / 120.0))
	for i in steps:
		await physics_frame
		mag_low = minf(mag_low, player.view.mag_offset().y)
		hand_far = maxf(hand_far, player.view.support_offset().length())
	check(mag_low < -0.15, "the old magazine drops out of the gun (%.2f m)" % mag_low)
	check(hand_far > 0.1, "the support hand leaves the front of the gun (%.2f m)" % hand_far)
	await frames(30)
	check(player.view.mag_offset().length() < 0.001 and player.view.support_offset().length() < 0.001, "everything is back in place after the reload")
	check(player.weapon.ammo == int(player.weapon.stats.mag), "and the gun is full")
	player.equip({"frame": "shotgun", "parts": {}, "tune": {}})
	player.weapon.ammo = 0
	player.weapon.start_reload()
	player._on_reload(true)
	var shown := false
	for i in int(player.weapon.reload_time() * 120.0):
		await physics_frame
		shown = shown or player.view._round_prop.visible
	check(player.view._reload_style == "rounds" and shown, "a tube shotgun is loaded a shell at a time, shell in hand")


func _test_safe_zones() -> void:
	print("safe zones and the bench")
	SafeZone.clear()
	SafeZone.add(Vector3(0, 0, 18), 5.0, 0)
	await _spawn(Vector3(0, 0.1, 18))
	player.equip({"frame": "carbine", "parts": {}, "tune": {}})
	var bot := await _bot(Vector3(0, 0.1, 6))
	check(player.can_mod(), "the bench opens at home")
	var hp := player.health
	player.take_hit({"damage": 30.0, "team": 1, "attacker": bot, "attacker_name": "x", "dir": Vector3.FORWARD})
	check(player.health == hp, "enemies can't hurt you in your own safe zone")
	check(player.can_mod(), "a blocked hit doesn't count as combat")
	# Shots from inside your zone don't land on enemies outside.
	_aim_at(bot)
	var bot_hp := bot.health
	player.weapon.cooldown = 0.0
	player._shoot()
	check(bot.health == bot_hp, "you can't shoot out of your safe zone")
	# Out in the field.
	await _spawn(Vector3(0, 0.1, 4))
	check(player.can_mod(), "the bench opens out in the field when nothing has happened")
	player.take_hit({"damage": 10.0, "team": 1, "attacker": bot, "attacker_name": "x", "dir": Vector3.FORWARD})
	check(not player.can_mod() and player.combat_left > 3.5, "a hit puts you in combat (%.1f s)" % player.combat_left)
	await frames(int(Player.COMBAT_LOCK * 120.0) + 10)
	check(player.can_mod(), "after %.0f quiet seconds the bench opens again" % Player.COMBAT_LOCK)
	SafeZone.repel = true
	SafeZone.add(Vector3(0, 0, -20), 4.0, 1)
	await _spawn(Vector3(0, 0.1, -20))
	hp = player.health
	await frames(60)
	check(player.health < hp - 10.0, "standing in the enemy's zone hurts (%.0f -> %.0f)" % [hp, player.health])
	SafeZone.clear()
	bot.queue_free()


func _test_death_screen() -> void:
	print("death screen")
	var ui := CanvasLayer.new()
	current_scene.add_child(ui)
	var death := DeathScreen.new()
	ui.add_child(death)
	var long := {"frame": "carbine", "parts": {}, "tune": {}}
	for i in 6:
		for s in Arsenal.open_slots(long):
			if not long.parts.has(s):
				var fits := Arsenal.parts_for(long, s)
				if not fits.is_empty():
					long.parts[s] = fits[0]
		long = Arsenal.clean(long)
	var info := {"attacker_name": "鉚釘-42", "gun_name": "測試", "build": long, "distance": 23.4, "zone": "head",
		"moves": ["牆跑", "空中", "滑鏟"], "through_wall": true}
	var all_ok := true
	for size in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(2560, 1080)]:
		root.size = size
		death.show_death(info, 64.0, 100.0)
		await process_frame
		await process_frame
		var r := death._copy.get_global_rect().merge(death._copy.get_parent().get_child(1).get_global_rect())
		var view := death.get_viewport_rect().size
		var inside: bool = r.position.y >= 0.0 and r.end.y <= view.y + 0.5 and r.end.x <= view.x + 0.5
		if not inside:
			all_ok = false
			print("    buttons at %s on %s" % [r, size])
	check(all_ok, "the copy and respawn buttons stay on screen with %d parts listed" % long.parts.size())
	death.hide_death()
	ui.queue_free()


func _test_damage_parts() -> void:
	print("CHAOS 2 damage parts")
	var w := Weapon.new({"frame": "carbine", "parts": {}, "tune": {}})
	var base: float = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, {}).damage
	var hit := func(fx: Dictionary, ctx: Dictionary) -> float:
		w.stats.effects = fx
		return w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, ctx).damage
	check(is_equal_approx(hit.call({"first_shot": 2.0}, {"first": true}), base * 2.0) and is_equal_approx(hit.call({"first_shot": 2.0}, {}), base),
		"ambush trigger: only the first shot after a pause is doubled")
	check(is_equal_approx(hit.call({"low_hp": 1.5}, {"low_hp": true}), base * 1.5), "berserker grip: +50% when hurt")
	check(is_equal_approx(hit.call({"streak": 0.08}, {"streak": 5}), base * 1.4), "metronome: five hits in a row is +40%")
	w.heat = 1.0
	check(is_equal_approx(hit.call({"heat_bonus": 0.8}, {}), base * 1.8), "red-hot barrel: +80% at full heat")
	w.heat = 0.0
	check(is_equal_approx(hit.call({"glass": 1.3}, {}), base * 1.3), "glass heart: +30% damage dealt")
	w.stats.effects = {"anonymous": true}
	var anon: Dictionary = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, {})
	check(anon.gun_name == "？？？" and (anon.build as Dictionary).is_empty(), "black tape hides the gun's name and build")
	# Spool: the interval shrinks while firing continuously.
	var spool := Weapon.new({"frame": "carbine", "parts": {"trigger": "spool_trigger"}, "tune": {}})
	var slow: float = spool.interval()
	spool.spool_t = Weapon.SPOOL_TIME
	var fast: float = spool.interval()
	check(fast < slow * 0.45, "spool trigger: from %.3f s to %.3f s between shots" % [slow, fast])
	for id in ["tracker_dart", "slide_loader", "parkour_feed", "spool_trigger", "ambush_trigger", "berserker_grip", "metronome",
			"trophy_charm", "glass_heart", "black_tape", "volatile_rounds", "adrenaline_rounds", "smart_rounds", "crank_handle",
			"glider_stock", "riot_foregrip", "echo_chamber", "echo_can", "skate_bolt", "red_hot_barrel", "vent_handguard",
			"pain_feed", "bomb_mag", "bounty_scope", "juggler_sight", "dash_feed", "pogo_pad", "leech_grip", "stopwatch", "chicken_foot"]:
		if not Arsenal.PARTS.has(id):
			check(false, "part %s exists" % id)
	check(true, "all 30 new parts are in the arsenal (%d parts in total)" % Arsenal.PARTS.size())


func _test_feed_parts() -> void:
	print("CHAOS 2 movement and feed parts")
	await _spawn()
	player.equip({"frame": "carbine", "parts": {"charging": "slide_loader"}, "tune": {}})
	player.weapon.ammo = 2
	player._start_slide(false)
	check(player.weapon.ammo == int(player.weapon.stats.mag), "slide loader: a slide fills the magazine")
	player.equip({"frame": "carbine", "parts": {"rail_r": "dash_feed", "handguard": "quad_rail"}, "tune": {}})
	player.weapon.ammo = 0
	player._start_dash(Vector3.FORWARD)
	check(player.weapon.ammo >= int(player.weapon.stats.mag * 0.4), "dash feeder: a dash puts 40%% back (%d)" % player.weapon.ammo)
	player.equip({"frame": "carbine", "parts": {"magazine": "pain_feed"}, "tune": {}})
	player.weapon.ammo = 0
	player.take_hit({"damage": 25.0, "team": 1, "attacker": null, "attacker_name": "x", "dir": Vector3.FORWARD})
	check(player.weapon.ammo == 3, "pain feed: 25 damage taken is 3 rounds (%d)" % player.weapon.ammo)
	await _spawn()
	player.equip({"frame": "carbine", "parts": {"stock": "glider_stock"}, "tune": {}})
	player.global_position.y = 12.0
	player._set_move(Player.Move.AIR, "test")
	player.velocity = Vector3(0, -2.0, 0)
	player._aim = 1.0
	player._gravity_half()
	var glide_drop := -2.0 - player.velocity.y
	player.velocity = Vector3(0, -2.0, 0)
	player._aim = 0.0
	player._gravity_half()
	var fall_drop := -2.0 - player.velocity.y
	check(glide_drop < fall_drop * 0.35, "glider stock: aiming in the air falls at 30%")
	await _spawn()
	player.equip({"frame": "carbine", "parts": {"foregrip": "riot_foregrip", "handguard": "quad_rail"}, "tune": {}})
	player._aim = 1.0
	var hp := player.health
	player.take_hit({"damage": 20.0, "team": 1, "attacker": null, "attacker_name": "x", "dir": Vector3.FORWARD})
	check(is_equal_approx(hp - player.health, 13.0), "riot foregrip: aiming takes 35%% less (%.1f)" % (hp - player.health))
	player._aim = 0.0


func _test_hit_parts() -> void:
	print("CHAOS 2 hit and kill parts")
	await _spawn()
	var bot := await _bot(Vector3(0, 0.1, 12))
	player.equip({"frame": "carbine", "parts": {"underbarrel": "tracker_dart", "charging": "crank_handle", "handguard": "quad_rail",
		"gadget": "trophy_charm"}, "tune": {}})
	_aim_at(bot)
	player._dash_charge = 0.0
	player.health = 50.0
	player.weapon.cooldown = 0.0
	player._shoot()
	check(bot.marked > 3.5, "tracker dart: a hit marks the target (%.1f s)" % bot.marked)
	check(player._dash_charge >= 0.2, "crank handle: a hit charges the dash")
	var shots := 0
	while bot.alive and shots < 12:
		player.weapon.cooldown = 0.0
		player.weapon.ammo = maxi(player.weapon.ammo, 1)
		player._shoot()
		shots += 1
		await frames(2)
	check(not bot.alive and player.health >= 84.0, "trophy charm: the kill gives health back (%.0f)" % player.health)
	bot.queue_free()
	# Volatile rounds: the victim's blast hurts the one standing next to it.
	await _spawn()
	var a := await _bot(Vector3(0, 0.1, 12))
	var b := await _bot(Vector3(1.2, 0.1, 12))
	a.health = 5.0
	player.equip({"frame": "carbine", "parts": {"ammo": "volatile_rounds"}, "tune": {}})
	_aim_at(a)
	player.weapon.cooldown = 0.0
	player._shoot()
	check(not a.alive and b.health < 100.0, "volatile rounds: the kill blows up on the bot beside it (%.0f)" % b.health)
	a.queue_free()
	b.queue_free()
	# Echo: a second hit arrives a moment later without costing a round.
	await _spawn()
	var e := await _bot(Vector3(0, 0.1, 14))
	e.set_physics_process(false)  # standing still: bots now pick a fight with you and strafe
	player.equip({"frame": "carbine", "parts": {"bolt": "echo_chamber"}, "tune": {}})
	_aim_at(e)
	player.weapon.cooldown = 0.0
	player._aim = 1.0  # aimed down sights: the echo's cone is tight enough to land
	var ammo := player.weapon.ammo
	player._shoot()
	var after_one := e.health
	await frames(40)
	player._aim = 0.0
	check(e.health < after_one and player.weapon.ammo == ammo - 1, "echo chamber: the shot rings again for free (%.0f -> %.0f)" % [after_one, e.health])
	e.queue_free()
	# Smart rounds bend a shot aimed beside the target.
	await _spawn()
	var h := await _bot(Vector3(0, 0.1, 10))
	player.equip({"frame": "carbine", "parts": {"ammo": "smart_rounds"}, "tune": {}})
	_aim_at(h)
	player.camera.rotate_y(deg_to_rad(3.5))
	player.weapon.cooldown = 0.0
	player._aim = 1.0
	player._shoot()
	check(h.health < 100.0, "smart rounds: a shot 3.5° off still finds the target")
	player._aim = 0.0
	h.queue_free()


func _test_scoring() -> void:
	print("PATCH WAR scoring")
	var tm := TeamMatch.new()
	tm.entities = {"p1": {"team": 0}, "p2": {"team": 1}, "b0": {"team": 1}}
	var pts := []
	for i in 6:
		pts.append(int(tm.score_kill("p1", 0, "p2", 111, [])[0]))
	check(pts == [3, 3, 2, 2, 1, 1], "one version's kills fade 3, 3, 2, 2, 1, 1 (%s)" % str(pts))
	check(int(tm.score_kill("p1", 0, "p2", 222, [])[0]) == 3, "a new version is fresh again: 3")
	check(int(tm.score_kill("p1", 0, "b0", 333, ["滑鏟"])[0]) == 4, "a kill with a move tag is +1")
	tm.meta_version = 999
	tm.versions = {"p2": 999}
	var meta: Array = tm.score_kill("p1", 0, "p2", 444, [])
	check(int(meta[0]) == 3 + TeamMatch.META_BONUS and "版本答案" in str(meta[1]), "killing the meta's carrier is +%d (%s)" % [TeamMatch.META_BONUS, meta[1]])
	check(int(tm.score_kill("b0", 1, "p2", 555, [])[0]) == 0, "killing a teammate scores nothing")
	check(int(tm.score_kill("p1", 0, "p1", 555, [])[0]) == 0, "killing yourself scores nothing")
	check(tm.scores[1] == 0 and tm.scores[0] == 12 + 3 + 4 + 6, "the team score adds up (%s)" % str(tm.scores))
	# Assists: 25+ damage this life (not the killer, not a teammate) shares the kill.
	tm.entities = {"p1": {"team": 0, "display_name": "甲"}, "p3": {"team": 0, "display_name": "乙"},
		"p4": {"team": 0, "display_name": "丙"}, "p2": {"team": 1, "display_name": "丁"}, "b0": {"team": 1, "display_name": "戊"}}
	tm._dmg_log = {"p2": {"p1": 60.0, "p3": 30.0, "p4": 10.0, "b0": 50.0}}
	var wire := tm._with_assists("p2", {"attacker_id": "p1"})
	check(wire.assist_ids == ["p3"], "assists: only the other enemy with 25+ damage (%s)" % str(wire.assist_ids))
	check(not tm._dmg_log.has("p2"), "the damage log clears on death")
	tm.stats = {}
	tm._stat("p1", "points", 7)
	tm._stat("p1", "kills", 2)
	tm._stat("p3", "points", 7)
	tm._stat("p3", "kills", 3)
	tm._stat("p2", "points", 2)
	check(str(tm.mvp().get("id", "")) == "p3", "MVP: most points, then most kills (%s)" % str(tm.mvp()))
	tm.free()
