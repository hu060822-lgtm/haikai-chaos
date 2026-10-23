extends SceneTree
## Bot difficulty (C9): 簡單 / 中等 / 困難 aim exactly alike and differ in behaviour: what
## they notice and hear, team callouts, where they stand in a fight, and 困難 taking cover.
##   godot --headless --path . --script res://tests/bot_level_test.gd

const Y := 300.0

var scene: Node3D
var player: Player
var failures := 0


func _init() -> void:
	InputSetup.register()
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var c := Faultprint.CONCRETE
	Geo.block(scene, Vector3(200, 1, 200), Vector3(0, Y - 0.5, 0), c)
	player = Player.new()
	scene.add_child(player)
	player.input_enabled = false
	await physics_frame
	await _test_same_aim()
	await _test_awareness()
	await _test_hearing()
	await _test_callouts()
	await _test_range()
	await _test_cover(c)
	_test_settings()
	print("BOT LEVEL TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _place_player(at: Vector3) -> void:
	player.spawn_at(Transform3D(Basis.IDENTITY, at))
	player.velocity = Vector3.ZERO
	await frames(2)


## A bot of `level` at `at`, facing -Z (yaw 0), quiet until told otherwise.
func _bot(level: int, at: Vector3, team := 1) -> Bot:
	var b := Bot.new()
	b.set_level(level)
	scene.add_child(b)
	b.spawn(at, 77)
	b.team = team
	b.rotation.y = 0.0
	b.passive = true
	b.waypoints = [at]
	await frames(2)
	return b


func _gone(bots: Array) -> void:
	for b in bots:
		b.queue_free()
	BotLevel.reset()
	await frames(2)


func _test_same_aim() -> void:
	await _place_player(Vector3(0, Y + 0.1, -15))
	var traces := []
	for level in 3:
		var b := await _bot(level, Vector3(0, Y + 0.1, 0))
		b.arm(Arsenal.STARTER)
		b.frozen = true
		b.target = player
		b.rng.seed = 4242
		seed(4242)   # the gun's own spread
		var ends := []
		# Compare where each shot was aimed (where a miss lands far off can differ by a hair).
		b.shot_traced.connect(func(from: Vector3, tos: PackedVector3Array) -> void:
			for t in tos:
				ends.append((t - from).normalized()))
		for i in 8:
			b.weapon.cooldown = 0.0
			b.weapon.ammo = int(b.weapon.stats.mag)
			b._try_shoot()
			player.health = 100.0
		traces.append(ends)
		await _gone([b])
	check(not traces[0].is_empty() and _same(traces[0], traces[1]) and _same(traces[1], traces[2]),
		"all three levels aim exactly alike (same seed, same %d shots)" % traces[0].size())
	var p0 := BotLevel.profile(0)
	for k in ["aim", "reaction", "spread", "damage"]:
		if p0.has(k):
			check(false, "profiles don't touch aim (%s)" % k)


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if (a[i] as Vector3).angle_to(b[i]) > 0.002:
			return false
	return true


func _sees(level: int, at: Vector3) -> bool:
	await _place_player(at)
	var b := await _bot(level, Vector3(0, Y + 0.1, 0))
	b.target = player
	await frames(10)
	var seen := b.fighting()
	await _gone([b])
	return seen


func _test_awareness() -> void:
	# Right behind it at 9 m, and off to the side at 20 m.
	var behind := Vector3(0, Y + 0.1, 9)
	var side := Vector3(20, Y + 0.1, 0)
	var r := []
	for level in 3:
		r.append([await _sees(level, behind), await _sees(level, side)])
	check(not r[0][0] and not r[1][0] and r[2][0], "behind at 9 m: only 困難 notices (%s)" % str(r.map(func(x): return x[0])))
	check(not r[0][1] and r[1][1] and r[2][1], "to the side at 20 m: 簡單 doesn't notice (%s)" % str(r.map(func(x): return x[1])))


func _test_hearing() -> void:
	# A shot 20 m behind a wall: who comes to look?
	await _place_player(Vector3(60, Y + 0.1, 60))
	var got := []
	for level in 3:
		var b := await _bot(level, Vector3(0, Y + 0.1, 0))
		BotLevel._noises.append([Vector3(0, Y, 20), 0, BotLevel.now()])
		b.target = null
		b._look_for_target()
		got.append(b._last_seen != Vector3.INF)
		await _gone([b])
	check(not got[0] and got[1] and got[2], "a gunshot 20 m away: 中等 and 困難 come to look, 簡單 doesn't hear (%s)" % str(got))


func _test_callouts() -> void:
	await _place_player(Vector3(0, Y + 0.1, -20))
	var got := []
	for level in [BotLevel.MEDIUM, BotLevel.HARD]:
		var spotter := await _bot(level, Vector3(0, Y + 0.1, 0))
		spotter.target = player
		var far := await _bot(level, Vector3(80, Y + 0.1, 80))
		far.rotation.y = 0.0
		far.target = null
		await frames(10)
		far._look_for_target()
		got.append(spotter.fighting() and far._last_seen.distance_to(player.global_position) < 3.0)
		await _gone([spotter, far])
	check(not got[0] and got[1], "困難 hunts where a teammate saw you, 中等 doesn't (%s)" % str(got))


## A long gun 4 m from the target: 困難 opens the distance, 簡單 and 中等 don't.
func _test_range() -> void:
	await _place_player(Vector3(0, Y + 0.1, -4))
	var moved := []
	for level in 3:
		var b := await _bot(level, Vector3(0, Y + 0.1, 0))
		b.weapon.stats.range = 60.0
		b.target = player
		await frames(90)
		moved.append(b.global_position.distance_to(player.global_position))
		await _gone([b])
	check(moved[2] > 6.0 and moved[2] > moved[0] + 1.5, "困難 backs off to its gun's range (%s m)" % str(moved.map(func(d): return snappedf(d, 0.1))))


## Hurt and low on ammo in the open next to a wall: 困難 gets behind it and reloads.
func _test_cover(c: Color) -> void:
	var wall := Geo.block(scene, Vector3(1, 4, 10), Vector3(4, Y + 2, 0), c)
	await _place_player(Vector3(-14, Y + 0.1, 0))
	var hidden := []
	for level in [BotLevel.MEDIUM, BotLevel.HARD]:
		# Out past the end of the wall, in the open.
		var b := await _bot(level, Vector3(3.0, Y + 0.1, 6.8))
		b.target = player
		b.health = 35.0
		b._hurt_at = BotLevel.now()
		b.weapon.ammo = 1
		await frames(150)
		var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 1.5, 0), b.global_position + Vector3(0, 1.3, 0), Geo.WORLD)
		var blocked := not scene.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		hidden.append([blocked, b.weapon.ammo > 1 or b.weapon.is_reloading()])
		await _gone([b])
	wall.queue_free()
	check(not hidden[0][0] and hidden[1][0], "hurt in the open: 困難 gets behind the wall, 中等 doesn't (%s)" % str(hidden))
	check(hidden[1][1], "困難 reloads in cover")


func _test_settings() -> void:
	check(int(NetSession.config.get("bot_level", -1)) == BotLevel.MEDIUM, "rooms default to 中等 bots")
	check(BotLevel.label(0) == "簡單" and BotLevel.label(2) == "困難" and BotLevel.label(9) == "困難", "level names")
