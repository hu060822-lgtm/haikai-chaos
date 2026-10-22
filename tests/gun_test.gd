extends SceneTree
## Headless checks of the arsenal: every frame and every part builds a model (on a frame it
## fits), every frame has a PvP role, and the CHAOS effects do what their parts say.
##   godot --headless --path . --script res://tests/gun_test.gd

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
	_test_models()
	_test_damage_mods()
	await _test_push_and_grapple()
	await _test_kill_effects()
	print("GUN TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _meshes(n: Node) -> int:
	var count := 1 if n is MeshInstance3D else 0
	for c in n.get_children():
		count += _meshes(c)
	return count


func _test_models() -> void:
	print("models")
	var bad := []
	for id in Arsenal.FRAMES:
		var model := GunModels.build({"frame": id, "parts": {}, "tune": {}})
		if _meshes(model) < 8 or not model.has_node("Muzzle"):
			bad.append(id)
		model.free()
	check(bad.is_empty(), "all %d frames build a model with a muzzle %s" % [Arsenal.FRAMES.size(), bad])
	var missing := []
	for id in Arsenal.FRAMES:
		if not Weapon.STK.has(id) or not GunNames.FRAME_SHORT.has(id):
			missing.append(id)
	check(missing.is_empty(), "every frame has a PvP role and a short name %s" % [missing])
	# Every part on the first frame it fits (in a root slot or one a handguard opens).
	var placed := 0
	var unplaced := []
	var lumps := []
	for pid in Arsenal.PARTS:
		if Arsenal.is_organ(pid):
			continue
		var slot: String = Arsenal.PARTS[pid].slot
		var build := {}
		for f in Arsenal.FRAMES:
			var b := {"frame": f, "parts": {}, "tune": {}}
			# Open the slot with the first part that adds it (a handguard for rails, a flash
			# hider for a can) when the bare frame doesn't have it.
			if not slot in Arsenal.open_slots(b).map(func(x): return Arsenal.slot_type(x)):
				for s in Arsenal.open_slots(b):
					for opener in Arsenal.parts_for(b, s):
						var adds: Array = Arsenal.part(opener).get("adds", [])
						if adds.any(func(x): return Arsenal.slot_type(x) == slot):
							b.parts[s] = opener
							break
					if b.parts.size() > 0:
						break
				b = Arsenal.clean(b)
			for s in Arsenal.open_slots(b):
				if Arsenal.slot_type(s) == slot and pid in Arsenal.parts_for(b, s):
					b.parts[s] = pid
					build = Arsenal.clean(b)
					break
			if not build.is_empty():
				break
		if build.is_empty():
			unplaced.append(pid)
			continue
		var before := GunModels.lumps
		var model := GunModels.build(build)
		if GunModels.lumps > before:
			lumps.append("%s on %s" % [pid, build.frame])
		model.free()
		placed += 1
	check(unplaced.is_empty(), "every part fits some frame %s" % [unplaced])
	check(lumps.is_empty(), "%d parts each have a model of their own (no placeholder lump) %s" % [placed, lumps])


func _test_damage_mods() -> void:
	print("damage effects")
	var w := Weapon.new({"frame": "carbine", "parts": {}, "tune": {}})
	var base: float = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, {}).damage
	w.stats.effects = {"air_bonus": 1.6}
	var air: float = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, {"air": true}).damage
	var ground: float = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, {"air": false}).damage
	check(is_equal_approx(air, base * 1.6) and is_equal_approx(ground, base), "air bonus only in the air (%.1f / %.1f)" % [air, ground])
	w.stats.effects = {"speed_bonus": 0.6}
	var fast: float = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, {"speed": 25.0}).damage
	check(is_equal_approx(fast, base * 1.6), "speed bonus pays out at full speed (%.1f)" % fast)
	w.stats.effects = {"headhunter": true}
	var head: float = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "head", 1.0, {}).damage
	var body: float = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, {}).damage
	check(is_equal_approx(head, base * 3.0) and is_equal_approx(body, base * 0.75), "headhunter: heads 3x, body 0.75x")
	w.stats.effects = {"last_round": 3.0}
	var last: float = w._hit_info(Vector3.ZERO, Vector3(0, 0, -5), Vector3.FORWARD, "body", 1.0, {"last_round": true}).damage
	check(is_equal_approx(last, base * 3.0), "last round hits three times as hard")
	var gyro := Weapon.new({"frame": "gyrojet", "parts": {}, "tune": {}})
	var near: float = gyro._hit_info(Vector3.ZERO, Vector3(0, 0, -2), Vector3.FORWARD, "body", 1.0, {}).damage
	var far: float = gyro._hit_info(Vector3.ZERO, Vector3(0, 0, -60), Vector3.FORWARD, "body", 1.0, {}).damage
	check(far > near * 1.5, "rocket pistol hits harder far away (%.1f -> %.1f)" % [near, far])


func _test_push_and_grapple() -> void:
	print("shooter movement")
	player.spawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 18)))
	await frames(3)
	player.equip({"frame": "jump_shotgun", "parts": {}, "tune": {}})
	player._pitch = deg_to_rad(-89.0)
	player._place_head(player.global_position)
	var before := player.velocity.y
	player._shoot()
	check(player.velocity.y - before > 6.0, "a jump shotgun fired at the floor throws you up (+%.1f m/s)" % (player.velocity.y - before))
	await frames(40)
	player.spawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 18)))
	await frames(3)
	player.equip({"frame": "anchor_gun", "parts": {}, "tune": {}})
	player._pitch = 0.0
	player._place_head(player.global_position)
	var v0 := player.velocity
	player._shoot()
	var pull := (player.velocity - v0)
	check(pull.length() > 8.0 and pull.z < 0.0, "an anchor gun pulls you toward where it hit (%.1f m/s)" % pull.length())


func _test_kill_effects() -> void:
	print("kill effects")
	player.spawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 18)))
	await frames(3)
	var bot := Bot.new()
	bot.passive = true
	current_scene.add_child(bot)
	bot.spawn(Vector3(0, 0.1, 12), 5)
	bot.passive = true
	bot.waypoints = [Vector3(0, 0, 12)]
	await frames(5)
	player.equip({"frame": "carbine", "parts": {"magazine": "hourglass_mag", "grip": "runner_grip"}, "tune": {}})
	player._dash_charge = 0.0
	var aim_at := bot.global_position + Vector3(0, 1.0, 0)
	player._pitch = 0.0
	player.rotation.y = 0.0
	player._place_head(player.global_position)
	player.camera.look_at(aim_at, Vector3.UP)
	var shots := 0
	while bot.alive and shots < 12:
		player.weapon.cooldown = 0.0
		player.weapon.ammo = maxi(player.weapon.ammo, 1)
		var before := player.weapon.ammo
		player._shoot()
		shots += 1
		if not bot.alive:
			check(player.weapon.ammo == int(player.weapon.stats.mag), "hourglass magazine refills on a kill (%d -> %d)" % [before, player.weapon.ammo])
			check(player._dash_charge >= 1.0, "runner grip recharges the dash on a kill")
		await frames(2)
	check(not bot.alive, "the bot went down in %d shots" % shots)
	bot.queue_free()
