extends SceneTree
## Character overhaul, Phase 5: one animation state (CompetitorRig.anim) from the player,
## bots, remote players and the kill replay; a remote player's body plays its move, its
## wall, its wall kicks, its reload (on the owner's clock) and its shots; the replay
## records and replays it; the same states give the same pose wherever they're played;
## the body mesh is built before the first competitor shows up.
##   godot --headless --path . --script res://tests/net_anim_test.gd

var failures := 0


func _init() -> void:
	Settings.look = Faultprint.COUNTERFORM
	InputSetup.register()
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var floor_body := Geo.block(scene, Vector3(40, 1, 40), Vector3(0, -0.5, 0), Faultprint.CONCRETE)
	floor_body.collision_layer = Geo.WORLD
	await process_frame
	_test_prewarm()
	await _test_player_state(scene)
	await _test_avatar(scene)
	_test_same_pose(scene)
	await _test_replay(scene)
	print("NET ANIM TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _test_prewarm() -> void:
	var t0 := Time.get_ticks_usec()
	AthleteRig.prewarm()
	var warm := (Time.get_ticks_usec() - t0) / 1000.0
	var rng := RandomNumberGenerator.new()
	var t1 := Time.get_ticks_usec()
	var a := CompetitorModel.build(Color.RED, true, rng)
	var first := (Time.get_ticks_usec() - t1) / 1000.0
	a.free()
	check(AthleteRig._mesh != null and first < 60.0, "the body mesh is built on load (%.0f ms), so the first competitor takes %.1f ms" % [warm, first])


func _test_player_state(scene: Node3D) -> void:
	var p := Player.new()
	scene.add_child(p)
	await process_frame
	p.equip({"frame": "carbine", "parts": {}, "tune": {}})
	var st := p.anim_state()
	check(st.size() == 11 and int(st[0]) == Player.Move.GROUND and (st[3] as Vector3) == Vector3.ZERO, "the player's state: 11 fields, on the ground, no wall")
	p.weapon.ammo = 0
	p.weapon.start_reload()
	st = p.anim_state()
	check(float(st[4]) > 0.0 and is_equal_approx(float(st[5]), p.weapon.reload_time()) and bool(st[6]), "a dry reload is in it, on the weapon's clock")
	p.queue_free()


func _avatar(scene: Node3D, frame: String) -> Avatar:
	var a := Avatar.new()
	a.setup("p9", 1, "x", false)
	scene.add_child(a)
	a.set_build({"frame": frame, "parts": {}, "tune": {}}, "gun")
	return a


func _rig(a: Avatar) -> AthleteRig:
	return a._model as AthleteRig


func _test_avatar(scene: Node3D) -> void:
	var a := _avatar(scene, "rifle")
	var wall := Vector3(1, 0, 0)
	var st := CompetitorRig.anim(Player.Move.WALLRUN, 0.1, 0.0, wall, null, 0, 0, false)
	for i in 3:
		a.push_state(Vector3(0, 2, -i * 0.5), 0.0, 0.1, Player.Move.WALLRUN, Vector3(0, 0, -10), 100.0, 0.0, st)
	for i in 30:
		a._process(1.0 / 60.0)
	check(_rig(a).motion.move == AthleteMotion.WALLRUN and _rig(a).motion._wall.x > 0.5, "a remote wall run plays as a wall run, on the right wall")
	st = st.duplicate()
	st[0] = Player.Move.AIR
	st[7] = 1
	a.push_state(Vector3(0.5, 2.2, -1.5), 0.0, 0.1, Player.Move.AIR, Vector3(6, 4, -10), 100.0, 0.0, st)
	a._states = [a._states[-1]]
	a._process(1.0 / 60.0)
	check(_rig(a).motion.push_left > 0.0, "its wall kick pushes off with the wall-side foot")
	st = CompetitorRig.anim(Player.Move.GROUND, 0.0, 0.0, Vector3.ZERO, null, 1, 0, true)
	st[4] = 2.0
	st[5] = 3.2
	st[6] = true
	a._states = []
	a.push_state(Vector3.ZERO, 0.0, 0.0, Player.Move.GROUND, Vector3.ZERO, 100.0, 0.0, st)
	a._states[0][0] = float(a._states[0][0]) - 1.1
	a._process(1.0 / 60.0)
	var p := _rig(a).reload_progress()
	check(absf(p - (1.0 - 1.0 / 3.2)) < 0.03, "its reload runs on the owner's clock, caught up to now (%.2f through)" % p)
	st = st.duplicate()
	st[4] = 0.0
	a.push_state(Vector3.ZERO, 0.0, 0.0, Player.Move.GROUND, Vector3.ZERO, 100.0, 0.0, st)
	a._states = [a._states[-1]]
	a._process(1.0 / 60.0)
	check(_rig(a).reload_progress() == 1.0, "and stops when the owner's stops")
	a.shot_seen()
	a._process(1.0 / 60.0)
	check(_rig(a)._cycle > 0.0, "a shot seen from a bolt gun: its bolt is worked")
	a.queue_free()


## Two bodies fed the same states end in the same pose (a remote player looks the same on
## every screen, and in the replay).
func _test_same_pose(scene: Node3D) -> void:
	var rigs: Array[AthleteRig] = []
	for i in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var r := CompetitorModel.build(Color.RED, true, rng) as AthleteRig
		scene.add_child(r)
		r.steps = false
		r.hold(GunModels.build({"frame": "shotgun", "parts": {}, "tune": {}}))
		rigs.append(r)
	var seq := []
	for f in 90:
		var m := Player.Move.GROUND if f < 30 else (Player.Move.SLIDE if f < 60 else Player.Move.AIR)
		var st := CompetitorRig.anim(m, sin(f * 0.1) * 0.3, 1.0 if m == Player.Move.SLIDE else 0.0, Vector3.ZERO, null, 0, f / 20, m != Player.Move.AIR)
		st[4] = maxf(1.5 - f / 60.0, 0.0)
		st[5] = 1.5
		seq.append([Vector3(0, 0, -7), st])
	for s in seq:
		for r in rigs:
			r.play_state(1.0 / 60.0, s[0], s[1])
	var worst := 0.0
	for i in AthleteBones.count():
		worst = maxf(worst, rigs[0]._glob[i].origin.distance_to(rigs[1]._glob[i].origin))
	check(worst < 0.001, "the same states give the same pose (%.4f m apart)" % worst)
	for r in rigs:
		r.queue_free()


func _test_replay(scene: Node3D) -> void:
	var cam := KillCam.new()
	scene.add_child(cam)
	var a := _avatar(scene, "carbine")
	a.add_to_group("combatants")
	var st := CompetitorRig.anim(Player.Move.SLIDE, 0.0, 1.0, Vector3.ZERO, null, 0, 0, true)
	a.push_state(Vector3(1, 0, 1), 0.0, 0.0, Player.Move.SLIDE, Vector3(0, 0, -9), 100.0, 0.0, st)
	for i in 4:
		await physics_frame
	var found := false
	for f in cam.frames:
		var e = f[1].get(a.get_instance_id())
		if e != null and e.size() > 3 and (e[3] as Array).size() == 11 and int(e[3][0]) == Player.Move.SLIDE:
			found = true
	check(found, "the replay records each body's animation state (a slide is recorded as a slide)")
	a.queue_free()
	cam.queue_free()
