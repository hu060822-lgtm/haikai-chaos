extends SceneTree
## Drives the three MOVEMENT LAB routes with a scripted pilot (fake input, reacting to
## where the player is), at a chosen physics tick rate, and reports for each route:
## finished or not, time, average / lowest speed, momentum breaks, unexplained speed drops
## (a sudden loss not caused by hitting something), ticks spent inside geometry, and how
## hard the camera effects moved per second.
##   godot --headless --fixed-fps 120 --path . --script res://tests/route_test.gd -- 120 [A B C]
## Machine-readable lines start with "ROUTE".

var main: Main
var lab: MovementLab
var player: Player
var ticks := 120
var failures := 0
var _stats := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		ticks = int(args[0])
	var which: Array = args.slice(1) if args.size() > 1 else ["A", "B", "C"]
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = 64
	Main.map_id = "lab"
	Main.skip_title = true
	change_scene_to_file("res://scenes/main.tscn")
	for i in 6:
		await process_frame
	main = current_scene as Main
	lab = main.lab
	player = main.player
	await physics_frame
	print("physics ticks: %d Hz" % ticks)
	for id in which:
		await call("_route_" + id.to_lower())
	print("ROUTE TESTS @%d Hz: %s" % [ticks, "PASS" if failures == 0 else "%d FAILED" % failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "dash", "fire", "aim"]:
		Input.action_release(a)


func press(a: String, on := true) -> void:
	if on:
		Input.action_press(a)
	else:
		Input.action_release(a)


## One tick of the run: records the stats, returns false when the route is over.
func step() -> bool:
	var before := player.flat_speed()
	var roll := player.camera.rotation.z
	var fov := player.camera.fov
	var pitch := player.head.rotation.x
	await physics_frame
	var s := player.flat_speed()
	var drop := (before - s) * ticks
	if drop > 40.0:
		var hit_something := false
		for i in player.get_slide_collision_count():
			if player.get_slide_collision(i).get_normal().y < 0.7:
				hit_something = true
		var deliberate := player.move == Player.Move.SLAM or player.move == Player.Move.MANTLE
		# The pull-up moves you by animation; its exit speed replaces that, so the tick it
		# ends is not a loss either.
		if not player.transitions.is_empty() and player.transitions[0].from == Player.Move.MANTLE \
				and absf(player.clock - float(player.transitions[0].t)) < 0.5 / ticks:
			deliberate = true
		# Catching a wall absorbs the speed going into it (counted, not a fault); a pit
		# reset stops you on purpose.
		var caught: bool = not player.transitions.is_empty() and player.transitions[0].to == Player.Move.WALLRUN \
			and absf(player.clock - float(player.transitions[0].t)) < 0.5 / ticks
		if caught:
			_stats.absorbed += 1
		elif not lab.last_result.is_empty():
			pass
		elif not hit_something and not deliberate:
			_stats.drops.append("%.1f→%.1f m/s（%s）" % [before, s, Player.MOVE_NAMES[player.move]])
		elif hit_something:
			_stats.bumps += 1
	_stats.roll_rate = maxf(_stats.roll_rate, rad_to_deg(absf(player.camera.rotation.z - roll)) * ticks)
	_stats.fov_rate = maxf(_stats.fov_rate, absf(player.camera.fov - fov) * ticks if not Input.is_action_pressed("aim") else 0.0)
	_stats.pitch_fx = maxf(_stats.pitch_fx, rad_to_deg(absf(player.head.rotation.x - pitch - (player._pitch - _stats.last_pitch))) * ticks)
	_stats.last_pitch = player._pitch
	if _inside_geometry():
		_stats.inside += 1
		if OS.get_environment("DBG") != "":
			print("    INSIDE at %s %s v=%s" % [player.global_position, Player.MOVE_NAMES[player.move], player.velocity])
	_stats.ticks += 1
	if OS.get_environment("DBG") != "" and _stats.ticks % (ticks / 10) == 0:
		print("    t=%.1f %s v=%.1f vy=%.1f p=(%.1f, %.1f, %.1f) %s" % [float(_stats.ticks) / ticks, Player.MOVE_NAMES[player.move],
			player.flat_speed(), player.velocity.y, player.global_position.x, player.global_position.y, player.global_position.z, player.limiter])
	return lab.last_result.is_empty()


func _inside_geometry() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	var shape: CapsuleShape3D = player.get_node("Shape").shape
	cap.radius = shape.radius * 0.8
	cap.height = shape.height * 0.8
	params.shape = cap
	params.collision_mask = Geo.WORLD
	params.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3(0, shape.height / 2.0, 0))
	return not player.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func begin(id: String) -> void:
	release_all()
	lab.restart(id)
	player.rotation.y = 0.0
	player._pitch = 0.0
	lab.last_result = {}
	_stats = {"drops": [], "bumps": 0, "absorbed": 0, "roll_rate": 0.0, "fov_rate": 0.0, "pitch_fx": 0.0, "last_pitch": 0.0, "inside": 0, "ticks": 0}
	for i in 3:
		await physics_frame


func finish(id: String, title: String) -> void:
	release_all()
	await physics_frame
	var r := lab.last_result
	var ok: bool = r.get("ok", false)
	print("%s %s" % [id, title])
	if ok:
		print("    %.2f s　平均 %.1f m/s　最低 %.1f　最高 %.1f　動量中斷 %d 次　分段 %s" % [r.time, r.avg, r.min, r.max, r.breaks,
			r.splits.map(func(v: float) -> String: return "%.2f" % v)])
	else:
		print("    did not finish: %s (gate %s)" % [r.get("why", "time out"), r.get("gate", "?")])
		print("    last transitions: ", player.transitions.slice(0, 5).map(func(t: Dictionary) -> String:
			return "%s→%s %s" % [Player.MOVE_NAMES[t.from], Player.MOVE_NAMES[t.to], t.why]))
		print("    last failures: ", player.failures.slice(0, 3).map(func(f: Dictionary) -> String: return f.why))
		print("    at ", player.global_position)
	check(ok, "%s: route finished" % id)
	check(_stats.drops.is_empty(), "%s: no unexplained speed drops %s" % [id, _stats.drops])
	check(_stats.inside == 0, "%s: never inside geometry (%d ticks)" % [id, _stats.inside])
	check(_stats.roll_rate < 120.0, "%s: camera roll moves at most %.0f°/s" % [id, _stats.roll_rate])
	check(_stats.fov_rate < 60.0, "%s: FOV moves at most %.0f°/s" % [id, _stats.fov_rate])
	print("ROUTE %s %d %s %.3f %.2f %.2f %d %d %d %.0f %.0f %.0f" % [id, ticks, "ok" if ok else "fail", r.get("time", 0.0),
		r.get("avg", 0.0), r.get("min", 0.0), r.get("breaks", -1), _stats.drops.size(), _stats.inside,
		_stats.roll_rate, _stats.fov_rate, _stats.pitch_fx])


## Turn toward a point on the ground plane (yaw only).
func face(target: Vector3) -> void:
	var d := target - player.global_position
	player.rotation.y = atan2(-d.x, -d.z)


func tap(a: String) -> void:
	Input.action_press(a)
	await step()
	await step()
	Input.action_release(a)


# --- A: the slide loop ----------------------------------------------------------------------

func _route_a() -> void:
	await begin("A")
	press("move_forward")
	press("sprint")
	var jumped := {}
	for i in ticks * 20:
		var z := player.global_position.z
		var s := player.flat_speed()
		if z < 33.5 and z > 31.0:
			press("crouch")
		for hurdle in [-6.0, -26.0]:
			if z < hurdle + 2.8 and z > hurdle and not jumped.has(hurdle):
				jumped[hurdle] = true
				press("crouch")
				await tap("jump")
		# The loop: stand up when the slide runs out of speed, slide again when fast.
		if player.move == Player.Move.SLIDE and s < 7.0 and z < 10.0:
			press("crouch", false)
		elif player.move == Player.Move.GROUND and s > 8.2 and z < 10.0 and not Input.is_action_pressed("crouch"):
			press("crouch")
		if not await step():
			break
	await finish("A", "滑鏟循環")


# --- B: wall run chain ------------------------------------------------------------------------

func _route_b() -> void:
	await begin("B")
	press("move_forward")
	press("sprint")
	var jumped := false
	# [wall's x, jump when z below this, side key toward the next wall]
	var plan := [[-28.0, 13.0, "move_right"], [-22.0, -0.5, "move_left"], [-28.0, -12.5, "move_right"], [-22.0, -25.0, "move_left"]]
	var leg := 0
	for i in ticks * 20:
		var p := player.global_position
		if not jumped and p.z < 25.6:
			jumped = true
			await tap("jump")
			continue
		if leg < plan.size() and player.move == Player.Move.WALLRUN and absf(p.x - plan[leg][0]) < 2.0 and p.z < plan[leg][1]:
			press(plan[leg][2])
			await tap("jump")
			leg += 1
			continue
		if player.move == Player.Move.WALLRUN:
			press("move_left", false)
			press("move_right", false)
		if not await step():
			break
	await finish("B", "牆跑連段")


# --- C: fast slide, air shots, wall kick onto a ledge ---------------------------------------

func _route_c() -> void:
	await begin("C")
	press("move_forward")
	press("sprint")
	var phase := "ramp"
	var shots := 0
	var targets := lab.range_targets.map(func(t: Transform3D) -> Vector3: return t.origin + Vector3(0, 1.6, 0))
	for i in ticks * 20:
		var p := player.global_position
		match phase:
			"ramp":
				if p.z < 34.5:
					press("crouch")
				if p.z < 3.2:
					await tap("jump")
					phase = "air"
					continue
			"air":
				# Look at the boards and shoot while flying (input released so the view doesn't steer).
				press("move_forward", false)
				var t: Vector3 = targets[mini(shots / 2, 1)]
				var d := t - player.camera.global_position
				player.rotation.y = atan2(-d.x, -d.z)
				player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
				if i % 6 == 0 and shots < 4:
					press("fire")
					shots += 1
				else:
					press("fire", false)
				if player.is_on_floor():
					press("fire", false)
					press("crouch", false)
					player._pitch = 0.0
					press("move_forward")
					phase = "to_wall"
			"to_wall":
				face(Vector3(26.4, 0, -19.0))
				if p.z < -18.2:
					player.rotation.y = 0.0
					await tap("jump")
					phase = "kick"
					continue
			"kick":
				player.rotation.y = 0.0
				if player.wall_info.get("side", 0) == 1 and p.z > -22.6 and player.velocity.y < 3.0:
					await tap("jump")
					phase = "ledge"
					continue
			"ledge":
				player.rotation.y = 0.0
		if not await step():
			break
	print("    shots fired in the air: %d" % shots)
	await finish("C", "高速綜合")
