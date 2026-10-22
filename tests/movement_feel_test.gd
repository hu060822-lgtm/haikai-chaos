extends SceneTree
## Movement feel checks on the MOVEMENT LAB, at a chosen physics tick rate, driven by fake
## input: speed carry-over through every transition, input windows, air steering limits,
## wall run stability, determinism and tick-rate independence.
##   godot --headless --fixed-fps 120 --path . --script res://tests/movement_feel_test.gd -- 120
## Prints one line per check and a summary table (machine-readable lines start with "METRIC").

var lab: MovementLab
var player: Player
var failures := 0
var ticks := 120
var metrics := {}
var only: Array = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		ticks = int(args[0])
	only = args.slice(1)
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = 64
	InputSetup.register()
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	lab = MovementLab.new()
	scene.add_child(lab)
	player = Player.new()
	scene.add_child(player)
	await physics_frame
	# No pit resets: the tests use the floor under the lanes.
	lab.set_physics_process(false)
	print("physics ticks: %d Hz" % ticks)
	for t in ["_test_ground_accel", "_test_slide", "_test_slide_jump", "_test_slide_chain", "_test_bhop", "_test_land_grace", "_test_jump_buffer", "_test_coyote", "_test_air_steer", "_test_determinism", "_test_wallrun", "_test_wall_jump", "_test_wall_coyote", "_test_slam_conflict", "_test_mantle", "_test_jump_arc"]:
		if only.is_empty() or t.trim_prefix("_test_") in only:
			await call(t)
	for k in metrics:
		print("METRIC %s %d %.4f" % [k, ticks, metrics[k]])
	print("FEEL TESTS @%d Hz: %s" % [ticks, "PASS" if failures == 0 else "%d FAILED" % failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func n(seconds: float) -> int:
	return maxi(roundi(seconds * ticks), 1)


func release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "dash", "fire", "aim"]:
		Input.action_release(a)


func place(pos: Vector3, yaw_deg: float, vel := Vector3.ZERO, pitch_deg := 0.0) -> void:
	release_all()
	player.spawn_at(Transform3D(Basis.IDENTITY, pos))
	player.rotation.y = deg_to_rad(yaw_deg)
	player._pitch = deg_to_rad(pitch_deg)
	await physics_frame
	player.velocity = vel
	await physics_frame


func secs(t: float) -> void:
	for i in n(t):
		await physics_frame


func tap(action: String) -> void:
	# Held for two ticks, like a real key press between frames: a press made here is
	# first seen on the next tick.
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	if OS.get_environment("DBG") != "":
		print("    tap %s at %d: move=%s vy=%.2f win=%s" % [action, Engine.get_physics_frames(), Player.MOVE_NAMES[player.move], player.velocity.y, player.windows()])
		for i in 3:
			await physics_frame
			print("      +%d move=%s vy=%.2f win=%s" % [i + 1, Player.MOVE_NAMES[player.move], player.velocity.y, player.windows()])


func hold(actions: Array) -> void:
	for a in actions:
		Input.action_press(a)


# A flat 100 m strip on the lab's base floor (y -6) between lanes A and B.
const STRIP_X := -43.0
const STRIP_Y := -5.9


func _test_ground_accel() -> void:
	print("ground acceleration")
	await place(Vector3(STRIP_X, STRIP_Y, 40), 0.0)
	hold(["move_forward", "sprint"])
	await secs(0.5)
	check(player.flat_speed() > 7.8, "sprint reaches %.1f m/s in 0.5 s" % player.flat_speed())
	metrics["sprint_0.5s"] = player.flat_speed()
	release_all()
	await secs(0.5)
	check(player.flat_speed() < 0.5, "and stops within 0.5 s of letting go (%.2f)" % player.flat_speed())


func _test_slide() -> void:
	print("slide: boost, smooth wind-down, no speed reset at the end")
	await place(Vector3(STRIP_X, STRIP_Y, 40), 0.0)
	hold(["move_forward", "sprint"])
	await secs(0.7)
	var before := player.flat_speed()
	Input.action_press("crouch")
	await physics_frame
	await physics_frame
	check(player.move == Player.Move.SLIDE, "crouch while sprinting starts a slide")
	check(player.flat_speed() > before + 2.0, "slide boost %.1f -> %.1f" % [before, player.flat_speed()])
	var prev := player.flat_speed()
	var worst := 0.0
	var t := 0.0
	while player.move == Player.Move.SLIDE and t < 4.0:
		await physics_frame
		t += 1.0 / ticks
		worst = maxf(worst, (prev - player.flat_speed()) * ticks)
		if OS.get_environment("DBG") != "" and (int(t * ticks) % 6 == 0 or (prev - player.flat_speed()) * ticks > 10.0):
			print("    t=%.3f v=%.2f decel=%.1f %s floor=%s y=%.3f" % [t, player.flat_speed(), (prev - player.flat_speed()) * ticks, player.limiter, player.is_on_floor(), player.global_position.y])
		prev = player.flat_speed()
	var why: String = player.transitions[0].why if not player.transitions.is_empty() else ""
	check(t > 1.0 and t < 2.8, "slide lasts %.2f s on the flat" % t)
	check(worst < 10.5, "never decelerates harder than %.1f m/s² (no sudden reset)" % worst)
	check(why == "滑鏟速度用完", "ends because the speed ran out (%s)" % why)
	check(player.flat_speed() > 3.2, "and hands over %.1f m/s to the crouch walk" % player.flat_speed())
	metrics["slide_time"] = t
	metrics["slide_worst_decel"] = worst
	release_all()


func _test_slide_jump() -> void:
	print("slide jump keeps the slide's speed")
	await place(Vector3(STRIP_X, STRIP_Y, 40), 0.0)
	hold(["move_forward", "sprint"])
	await secs(0.7)
	Input.action_press("crouch")
	await secs(0.25)
	var before := player.flat_speed()
	await tap("jump")
	check(player.move == Player.Move.AIR and player.velocity.y > 5.0, "jump from a slide")
	check(player.flat_speed() >= before * 0.98, "keeps the speed (%.2f -> %.2f)" % [before, player.flat_speed()])
	release_all()


func _test_slide_chain() -> void:
	print("slide -> jump -> land into a slide, eight times: speed carries, boosts don't stack")
	await place(Vector3(STRIP_X, STRIP_Y, 40), 0.0)
	hold(["move_forward", "sprint"])
	await secs(0.7)
	Input.action_press("crouch")
	var speeds := []
	var lowest := INF
	var highest := 0.0
	for i in 8:
		await secs(0.2)
		await tap("jump")
		var landed := false
		for k in n(2.0):
			await physics_frame
			highest = maxf(highest, player.flat_speed())
			if player.is_on_floor():
				landed = true
				break
		await physics_frame
		speeds.append(player.flat_speed())
		lowest = minf(lowest, player.flat_speed())
		if not landed or player.move != Player.Move.SLIDE:
			check(false, "landing %d went into a slide (move=%s)" % [i, Player.MOVE_NAMES[player.move]])
			break
	print("    speed after each landing: ", speeds.map(func(v: float) -> String: return "%.1f" % v))
	check(lowest > 8.0, "never drops below sprint speed (lowest %.1f)" % lowest)
	check(highest < 15.5, "boosts don't stack into runaway speed (highest %.1f)" % highest)
	metrics["chain_lowest"] = lowest
	metrics["chain_highest"] = highest
	release_all()


func _test_bhop() -> void:
	print("bunny hop: a jump on the landing tick skips friction")
	await place(Vector3(STRIP_X, STRIP_Y, 40), 0.0)
	hold(["move_forward", "sprint"])
	await secs(0.8)
	var start := player.flat_speed()
	for i in 6:
		await tap("jump")
		# Press again just before touching down (inside the buffer).
		for k in n(1.5):
			await physics_frame
			if player.velocity.y < 0.0 and player.global_position.y - (STRIP_Y - 0.1) < 0.3:
				break
		await tap("jump")
		await secs(0.05)
	var after := player.flat_speed()
	check(after >= start * 0.97, "speed held over 6 hops (%.2f -> %.2f)" % [start, after])
	release_all()


func _test_land_grace() -> void:
	print("fast landing: a moment without friction")
	await place(Vector3(STRIP_X, STRIP_Y + 1.5, 40), 0.0, Vector3(0, 0, -13.0))
	var landed_at := -1
	for i in n(1.0):
		await physics_frame
		if player.is_on_floor():
			landed_at = i
			break
	check(landed_at >= 0, "landed")
	check(player.landing.begins_with("高速落地"), "classified as a fast landing (%s)" % player.landing)
	var at_land := player.flat_speed()
	await secs(0.15)
	check(player.flat_speed() >= at_land - 0.05, "no friction for 0.15 s (%.2f -> %.2f)" % [at_land, player.flat_speed()])
	Input.action_press("move_forward")
	await secs(0.45)
	check(player.flat_speed() > 8.0 and player.flat_speed() < at_land,
		"holding forward bleeds speed evenly, not a brake (%.2f after 0.6 s)" % player.flat_speed())
	release_all()


func _test_jump_buffer() -> void:
	print("jump buffer: jump pressed just before landing")
	await place(Vector3(STRIP_X, STRIP_Y + 2.0, 40), 0.0)
	for i in n(1.0):
		await physics_frame
		if player.global_position.y - (STRIP_Y - 0.1) < 0.45:
			break
	await tap("jump")
	var jumped := false
	for i in n(0.2):
		await physics_frame
		if player.velocity.y > 5.0:
			jumped = true
			break
	check(jumped, "the early press still jumps on landing")


func _test_coyote() -> void:
	print("coyote time off a ledge")
	for spec in [[0.07, true], [0.25, false]]:
		await place(Vector3(-25.0, 0.1, 30.0), 0.0)
		await secs(0.2)
		hold(["move_forward"])
		var left_at := -1
		for i in n(2.0):
			await physics_frame
			if not player.is_on_floor():
				left_at = i
				break
		await secs(spec[0])
		await tap("jump")
		await physics_frame
		var jumped := player.velocity.y > 4.0
		check(jumped == spec[1], "jump %.2f s after walking off: %s" % [spec[0], "jumps" if jumped else "falls"])
		release_all()


func _test_air_steer() -> void:
	print("air steering: bends, doesn't snap")
	await place(Vector3(STRIP_X, 30.0, 40), 0.0, Vector3(0, 0, -10.0))
	Input.action_press("move_right")
	await secs(0.5)
	var v := Vector2(player.velocity.x, player.velocity.z)
	var turned := rad_to_deg(Vector2(0, -1).angle_to(v))
	check(absf(turned) > 18.0 and absf(turned) < 55.0, "0.5 s of strafe turns %.0f° at 10 m/s" % absf(turned))
	check(v.length() < 11.0 and v.length() > 9.8, "speed kept while turning (%.2f)" % v.length())
	metrics["air_turn_0.5s"] = absf(turned)
	release_all()
	await place(Vector3(STRIP_X, 30.0, 40), 0.0, Vector3(0, 0, -10.0))
	Input.action_press("move_back")
	await secs(0.5)
	check(player.flat_speed() > 6.0 and player.flat_speed() < 8.5, "0.5 s of back brakes to %.2f, not a stop" % player.flat_speed())
	release_all()
	await place(Vector3(STRIP_X, 30.0, 40), 0.0)
	Input.action_press("move_forward")
	await secs(0.5)
	check(player.flat_speed() > 4.0, "from standing, input still moves you in the air (%.2f)" % player.flat_speed())
	release_all()


func _scripted_run() -> Vector3:
	await place(Vector3(STRIP_X, STRIP_Y, 40), 0.0)
	hold(["move_forward", "sprint"])
	await secs(0.6)
	Input.action_press("crouch")
	await secs(0.3)
	await tap("jump")
	Input.action_press("move_right")
	await secs(0.4)
	Input.action_release("move_right")
	await secs(0.6)
	var at := player.global_position
	release_all()
	return at


func _test_determinism() -> void:
	print("same input, same result")
	var a := await _scripted_run()
	var b := await _scripted_run()
	check(a.distance_to(b) < 0.001, "two runs end %.5f m apart" % a.distance_to(b))


func _wall_entries() -> int:
	var count := 0
	for t in player.transitions:
		if t.to == Player.Move.WALLRUN:
			count += 1
	return count


func _test_wallrun() -> void:
	print("wall run on the 40 m practice wall")
	for wobble in [false, true]:
		await place(Vector3(43.1, 0.1, 25.0), 0.0)
		hold(["move_forward", "sprint"])
		var entries := 0
		var jumped := false
		var ran := 0.0
		var last_speed := 0.0
		var exit_speed := 0.0
		var why := ""
		var t := 0.0
		for i in n(4.0):
			await physics_frame
			t += 1.0 / ticks
			if not jumped and player.global_position.z < 21.0:
				await tap("jump")
				jumped = true
			if wobble:
				player.rotation.y = deg_to_rad(9.0 * sin(t * 30.0))
			if player.move == Player.Move.WALLRUN:
				ran += 1.0 / ticks
				last_speed = player.flat_speed()
				if not player.transitions.is_empty() and player.transitions[0].to == Player.Move.WALLRUN and clock_eq(player.transitions[0].t):
					entries += 1
			elif ran > 0.0 and why == "":
				why = player.transitions[0].why
				exit_speed = player.flat_speed()
			if ran > 0.0 and player.is_on_floor():
				break
		var label := "wobbling the view" if wobble else "steady"
		check(entries == 1, "%s: one wall run, no flicker (%d entries)" % [label, entries])
		check(ran > 1.3, "%s: runs %.2f s" % [label, ran])
		check(exit_speed >= last_speed * 0.9, "%s: leaves with %.1f of %.1f m/s (%s)" % [label, exit_speed, last_speed, why])
		if not wobble:
			metrics["wallrun_time"] = ran
		release_all()


func clock_eq(t: float) -> bool:
	return absf(player.clock - t) < 0.5 / ticks


func _start_wallrun() -> bool:
	await place(Vector3(43.1, 0.1, 25.0), 0.0)
	hold(["move_forward", "sprint"])
	var jumped := false
	for i in n(2.0):
		await physics_frame
		if not jumped and player.global_position.z < 21.0:
			await tap("jump")
			jumped = true
		if player.move == Player.Move.WALLRUN and player.global_position.z < 14.0:
			return true
	return false


func _test_wall_jump() -> void:
	print("wall jump: out along the normal plus input, keeping the run's speed")
	check(await _start_wallrun(), "on the wall")
	var along := -player.velocity.z
	Input.action_press("move_right")
	await tap("jump")
	check(player.velocity.x > 6.0, "pushed off the wall at %.1f m/s (normal + input)" % player.velocity.x)
	check(-player.velocity.z > along * 0.9, "kept %.1f of %.1f m/s along the wall" % [-player.velocity.z, along])
	check(player.velocity.y > 6.0, "and up (%.1f)" % player.velocity.y)
	release_all()


func _test_wall_coyote() -> void:
	print("wall coyote: jump just after leaving a run")
	check(await _start_wallrun(), "on the wall")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	for i in n(0.5):
		await physics_frame
		if player.move != Player.Move.WALLRUN:
			break
	await secs(0.06)
	await tap("jump")
	var why: String = player.transitions[0].why
	check(why.contains("寬限") and player.velocity.x > 4.0, "still wall-jumps (%s)" % why)
	release_all()


func _test_slam_conflict() -> void:
	print("crouch in the air: slide prep looking ahead, slam only looking down")
	await place(Vector3(STRIP_X, STRIP_Y + 4.0, 40), 0.0, Vector3(0, 0, -9.0))
	await tap("crouch")
	await physics_frame
	check(player.move != Player.Move.SLAM, "looking ahead: no slam (%s)" % Player.MOVE_NAMES[player.move])
	await place(Vector3(STRIP_X, STRIP_Y + 4.0, 40), 0.0, Vector3(0, 0, -9.0), -60.0)
	await tap("crouch")
	await physics_frame
	check(player.move == Player.Move.SLAM, "looking down: slam")
	await secs(0.5)
	release_all()


func _test_mantle() -> void:
	print("mantle keeps momentum")
	# The 1.5 m practice block at x 48, front face z 36.6.
	await place(Vector3(48.0, 0.1, 47.0), 0.0)
	hold(["move_forward", "sprint"])
	var entry := 0.0
	var mantled := false
	var jumped := false
	for i in n(3.0):
		await physics_frame
		if not jumped and player.global_position.z < 39.2:
			await tap("jump")
			jumped = true
		if player.move == Player.Move.MANTLE and not mantled:
			mantled = true
		if player.move != Player.Move.MANTLE and player.move != Player.Move.AIR and mantled:
			break
		if player.move == Player.Move.AIR:
			entry = maxf(entry, player.flat_speed())
	check(mantled, "pulled up onto the block")
	check(player.flat_speed() >= maxf(4.4, entry * 0.7), "out at %.1f m/s (came in at %.1f)" % [player.flat_speed(), entry])
	release_all()


func _test_jump_arc() -> void:
	print("jump height is the same at any tick rate")
	await place(Vector3(STRIP_X, STRIP_Y, 40), 0.0)
	await secs(0.1)
	var y0 := player.global_position.y
	await tap("jump")
	var top := y0
	for i in n(1.0):
		await physics_frame
		top = maxf(top, player.global_position.y)
	var expected := pow(player.tune.jump_speed, 2) / (2.0 * player.tune.gravity)
	check(absf((top - y0) - expected) / expected < 0.03, "apex %.3f m (ideal %.3f)" % [top - y0, expected])
	metrics["jump_apex"] = top - y0
