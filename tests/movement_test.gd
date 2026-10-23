extends SceneTree
## Headless checks of the movement tech and shooting on FOLDED WORKS, driven by fake input.
##   godot --headless --path . --script res://tests/movement_test.gd

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
	await _test_slide()
	await _test_wallrun()
	await _test_mantle()
	await _test_wall_kick()
	await _test_climb()
	await _test_dash()
	await _test_mobility()
	await _test_shoot_bot()
	await _test_ttk()
	print("MOVEMENT TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "dash", "fire", "aim"]:
		Input.action_release(a)


func place(pos: Vector3, yaw_deg: float, vel := Vector3.ZERO) -> void:
	release_all()
	player.spawn_at(Transform3D(Basis.IDENTITY, pos))
	player.rotation.y = deg_to_rad(yaw_deg)
	player.velocity = vel
	for i in 3:
		await physics_frame


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _test_slide() -> void:
	print("slide")
	await place(Vector3(8, 0.1, 18), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(60)
	var before := player.flat_speed()
	Input.action_press("crouch")
	await frames(4)
	check(player.move == Player.Move.SLIDE, "crouch while sprinting starts a slide (move=%s)" % Player.MOVE_NAMES[player.move])
	check(player.flat_speed() > before + 1.0, "slide boosts speed (%.1f -> %.1f)" % [before, player.flat_speed()])
	await frames(150)
	check(player.move != Player.Move.SLIDE or player.flat_speed() < before, "slide ends or slows")
	release_all()


func _test_wallrun() -> void:
	print("wall run across the west gallery gap")
	# On the south half of the west gallery, beside the outer wall, running north to the gap.
	await place(Vector3(-35.0, FoldedWorks.MID + 0.1, 14.0), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var ran := false
	var jumped := false
	for i in 360:
		await physics_frame
		if not jumped and player.global_position.z < 6.0:
			await tap("jump")
			jumped = true
		if player.move == Player.Move.WALLRUN:
			ran = true
		if player.global_position.z < -7.0 and player.is_on_floor():
			break
	check(ran, "wall run starts beside the banded wall")
	check(player.global_position.z < -5.0 and player.global_position.y > FoldedWorks.MID - 0.5,
		"crossed the gap on the wall (at %s)" % player.global_position)
	release_all()


func _test_mantle() -> void:
	print("mantle onto a crate")
	# The yellow 1.5 m crate by the west stairs: c = (-25.4, 0, 14).
	await place(Vector3(-25.4, 0.1, 17.0), 0.0)
	Input.action_press("move_forward")
	await frames(20)
	await tap("jump")
	var mantled := false
	for i in 90:
		await physics_frame
		if player.move == Player.Move.MANTLE:
			mantled = true
	check(mantled, "jumping at a ledge pulls you up")
	check(player.global_position.y > 1.3, "standing on the crate (y=%.2f)" % player.global_position.y)
	release_all()


func _test_wall_kick() -> void:
	print("wall kick in the shaft")
	# The two shaft walls at z 6.4 and 9.8 near x -25: start between them.
	await place(Vector3(-25.0, 0.1, 7.25), 0.0)
	await tap("jump")
	await frames(14)
	var y0 := player.global_position.y
	await tap("jump")
	await frames(10)
	check(player.global_position.y > y0, "kicking off the wall gains height (%.2f -> %.2f)" % [y0, player.global_position.y])
	check(player.kicks_left() < player.max_kicks(), "a kick was used")
	release_all()


func _test_climb() -> void:
	print("wall climb on the tower face")
	# The climb face on the tower's south side at z = -1.25, x 6.7..9.3.
	await place(Vector3(8.0, 0.1, 1.2), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(30)
	Input.action_press("jump")
	var climbed := false
	var top := 0.0
	for i in 120:
		await physics_frame
		if player.move == Player.Move.CLIMB:
			climbed = true
		top = maxf(top, player.global_position.y)
	check(climbed, "running at a wall holding jump climbs it")
	check(top > 3.0, "climbed high (%.2f m)" % top)
	release_all()


func _test_dash() -> void:
	print("dash")
	await place(Vector3(8, 0.1, 18), 0.0)
	Input.action_press("move_forward")
	await frames(10)
	var z0 := player.global_position.z
	await tap("dash")
	await frames(24)
	check(z0 - player.global_position.z > 2.0, "dash moves you fast (%.2f m)" % (z0 - player.global_position.z))
	await frames(10)
	await tap("dash")
	await frames(2)
	check(player.move == Player.Move.DASH, "a second dash right away (two charges)")
	await frames(20)
	await tap("dash")
	await frames(2)
	check(player.move != Player.Move.DASH, "no third dash before a charge refills")
	release_all()


func _test_mobility() -> void:
	print("gun weight vs movement (C7: none)")
	player.equip({"frame": "service_pistol", "parts": {}, "tune": {}})
	var light := player.mobility
	player.equip({"frame": "anti_materiel", "parts": {}, "tune": {}})
	var heavy := player.mobility
	check(light == 1.0 and heavy == 1.0, "a 13 kg rifle moves like a pistol (%.2f vs %.2f)" % [light, heavy])
	check(player.max_kicks() == Player.WALL_KICKS, "and gets every wall kick")
	check(float(player.weapon.stats.aim_time) > 0.3, "weight still slows aiming (%.2f s)" % player.weapon.stats.aim_time)
	player.equip({"frame": "carbine", "parts": {}, "tune": {}})


func _test_shoot_bot() -> void:
	print("shooting a bot")
	await place(Vector3(0, 0.1, 18), 0.0)
	var bot := Bot.new()
	bot.passive = true
	current_scene.add_child(bot)
	bot.spawn(Vector3(0, 0.1, 10), 5)
	bot.passive = true
	bot.waypoints = [Vector3(0, 0, 10)]
	await frames(5)
	player._pitch = deg_to_rad(-3.0)
	var hp := bot.health
	for i in 40:
		Input.action_press("fire")
		await physics_frame
		Input.action_release("fire")
		await frames(6)
		if not bot.alive:
			break
	check(bot.health < hp or not bot.alive, "shots hurt the bot (%.0f -> %.0f, alive=%s)" % [hp, bot.health, bot.alive])
	bot.queue_free()
	release_all()


func _test_ttk() -> void:
	print("time to kill, every bare frame (body shots, no falloff)")
	var ttks := []
	for id in Arsenal.FRAMES:
		var s := Arsenal.stats({"frame": id, "parts": {}, "tune": {}})
		var per_shot := Weapon.shot_damage(s) * (2 if s.modes[0] == "double" else 1)
		var shots := ceili(100.0 / maxf(per_shot, 0.1))
		var ttk := (shots - 1) / maxf(float(s.rate), 0.1)
		ttks.append(ttk)
		print("    %-16s %5.1f dmg  %2d shots  %.2f s" % [id, per_shot, shots, ttk])
	ttks.sort()
	var median: float = ttks[ttks.size() / 2]
	check(median > 0.2 and median < 1.0, "median bare-frame TTK %.2f s is in the competitive range" % median)
	for id in Weapon.STK:
		var s := Arsenal.stats({"frame": id, "parts": {}, "tune": {}})
		if ceili(100.0 / Weapon.shot_damage(s)) != int(Weapon.STK[id]):
			check(false, "%s takes %d hits, wanted %d" % [id, ceili(100.0 / Weapon.shot_damage(s)), Weapon.STK[id]])
