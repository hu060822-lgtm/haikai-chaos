extends SceneTree
## C7 checks: any wall runs, gun weight doesn't slow you, every part fits every gun (and
## the new slot types do something), aim assist slows and follows but never snaps,
## ragdolls and loose props react, and the maps have their new passages.
##   godot --headless --path . --script res://tests/c7_test.gd

const Y := 300.0

var player: Player
var failures := 0


func _init() -> void:
	InputSetup.register()
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	# A bare test floor high up: a long plain wall (no orange band, no RUNNABLE layer).
	var c := Faultprint.CONCRETE
	Geo.block(scene, Vector3(80, 1, 80), Vector3(0, Y - 0.5, 0), c)
	var plain := Geo.block(scene, Vector3(1, 8, 60), Vector3(-3, Y + 4, 0), c)
	plain.collision_layer = Geo.WORLD
	player = Player.new()
	scene.add_child(player)
	await physics_frame
	await _test_any_wall(plain)
	await _test_weight()
	_test_free_fit()
	await _test_aim_assist(scene)
	await _test_physics(scene)
	await _test_maps(scene)
	print("C7 TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
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
	player._pitch = 0.0
	player.velocity = vel
	for i in 3:
		await physics_frame


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _test_any_wall(plain: StaticBody3D) -> void:
	print("wall run on a plain wall")
	check(not plain.is_in_group("runnable") and player._is_runnable(plain), "a wall with no band counts as runnable")
	# Running north beside the wall (it is on our left), jump, hold forward.
	await place(Vector3(-2.0, Y + 0.1, 20.0), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(40)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	Input.action_press("move_left")
	var ran := false
	for i in 60:
		await physics_frame
		if player.move == Player.Move.WALLRUN:
			ran = true
			break
	check(ran, "the run starts on it (%s)" % Player.MOVE_NAMES[player.move])
	if ran:
		await frames(10)
		Input.action_press("jump")
		await physics_frame
		Input.action_release("jump")
		await frames(2)
		check(player.move == Player.Move.AIR and player.velocity.x > 2.0, "and a wall jump leaves it (vx %.1f)" % player.velocity.x)
	release_all()
	var t := player.tune
	check(t.wall_reach >= 0.9 and t.wall_coyote >= 0.25 and t.wallrun_min <= 4.0, "the catch is forgiving (reach %.2f m, grace %.2f s, from %.1f m/s)" % [t.wall_reach, t.wall_coyote, t.wallrun_min])


func _test_weight() -> void:
	print("gun weight and movement")
	player.equip({"frame": "anti_materiel", "parts": {}, "tune": {}})
	await place(Vector3(10, Y + 0.1, 20), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(90)
	var heavy := player.flat_speed()
	release_all()
	player.equip({"frame": "service_pistol", "parts": {}, "tune": {}})
	await place(Vector3(10, Y + 0.1, 20), 0.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(90)
	var light := player.flat_speed()
	release_all()
	check(absf(heavy - light) < 0.05, "a 13 kg rifle sprints as fast as a pistol (%.2f vs %.2f m/s)" % [heavy, light])


func _test_free_fit() -> void:
	print("every part on every gun")
	var bad := []
	for fid in Arsenal.FRAMES:
		if Arsenal.open_slots({"frame": fid, "parts": {}}).size() != Arsenal.SLOTS.size():
			bad.append(fid)
	check(bad.is_empty(), "all %d frames open all %d slots %s" % [Arsenal.FRAMES.size(), Arsenal.SLOTS.size(), bad])
	var misfit := 0
	for fid in ["revolver", "flamethrower", "bubble_gun", "minigun"]:
		for pid in Arsenal.PARTS:
			var p: Dictionary = Arsenal.PARTS[pid]
			var slot: String = "rail_l" if p.slot == "rail" else p.slot
			if not pid in Arsenal.parts_for({"frame": fid, "parts": {}}, slot):
				misfit += 1
	check(misfit == 0, "any part goes on a revolver, a flamethrower, a bubble gun or a minigun (%d refused)" % misfit)
	# A silencer barrel no longer blocks the muzzle.
	var b := Arsenal.clean({"frame": "carbine", "parts": {"barrel": "integral_suppressor", "muzzle": Arsenal.parts_for("carbine", "muzzle")[0]}})
	check(b.parts.has("muzzle"), "an integral suppressor still leaves room for a muzzle device")
	for slot in ["tactical", "spring", "magwell", "cheek", "sling"]:
		check(Arsenal.parts_for("smg", slot).size() >= 4, "new slot %s has parts (%d)" % [Arsenal.slot_name(slot), Arsenal.parts_for("smg", slot).size()])
	var bare := Arsenal.stats({"frame": "carbine", "parts": {}})
	var fast := Arsenal.stats({"frame": "carbine", "parts": {"magwell": "funnel_magwell"}})
	var soft := Arsenal.stats({"frame": "carbine", "parts": {"spring": "hydraulic_buffer"}})
	check(float(fast.reload) < float(bare.reload) and float(soft.recoil) < float(bare.recoil), "they change the numbers (reload %.2f → %.2f, recoil %.2f → %.2f)" % [bare.reload, fast.reload, bare.recoil, soft.recoil])
	for fid in ["vector_smg", "scout_rifle", "silent_rifle"]:
		var m := GunModels.build({"frame": fid, "parts": {}})
		check(Arsenal.FRAMES.has(fid) and m.has_node("Muzzle"), "new frame %s builds" % Arsenal.name_of(fid))
		m.free()


func _test_aim_assist(scene: Node3D) -> void:
	print("aim assist")
	player.equip({"frame": "carbine", "parts": {}, "tune": {}})
	var bot := Bot.new()
	scene.add_child(bot)
	bot.spawn(Vector3(20, Y + 0.1, 0), 5)
	bot.team = 1
	bot.passive = true
	bot.frozen = true
	await place(Vector3(20, Y + 0.1, 15), 0.0)
	player.input_enabled = true
	Settings.aim_assist = true
	# Look 3° to the right of the bot's chest.
	var chest := bot.global_position + Vector3(0, 1.15, 0)
	var d := chest - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z) - deg_to_rad(3.0)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await frames(3)
	check(player.assist_target == bot and player.assist > 0.2, "a target near the crosshair is picked up (%.2f)" % player.assist)
	var before := absf(rad_to_deg(player._angles(-player.camera.global_basis.z, (chest - player.camera.global_position).normalized()).x))
	Input.action_press("aim")
	await frames(30)
	var after := absf(rad_to_deg(player._angles(-player.camera.global_basis.z, (chest - player.camera.global_position).normalized()).x))
	Input.action_release("aim")
	check(after < before and after > 0.2, "aiming pulls toward it, gently (%.2f° → %.2f°)" % [before, after])
	player.rotation.y += deg_to_rad(25.0)
	await frames(3)
	check(player.assist_target == null, "nothing far off the crosshair is touched")
	Settings.aim_assist = false
	player.rotation.y -= deg_to_rad(23.0)
	await frames(3)
	check(player.assist_target == null, "and it can be turned off")
	Settings.aim_assist = true
	bot.queue_free()
	await frames(2)


func _test_physics(scene: Node3D) -> void:
	print("ragdolls and loose things")
	check(CompetitorRig.kill_force({"damage": 20.0}) < CompetitorRig.kill_force({"damage": 20.0, "blast": true}), "a blast throws harder than a bullet")
	var rig := CompetitorModel.build(Color.RED, true, RandomNumberGenerator.new())
	scene.add_child(rig)
	rig.global_position = Vector3(-20, Y, -20)
	await frames(2)
	CompetitorRig.leave_corpse(rig, Vector3.BACK, 6.0, CompetitorRig.kill_force({"blast": true}), Vector3.ZERO)
	await frames(2)
	var pieces := 0
	var fastest := 0.0
	for n in scene.get_children():
		if n is RigidBody3D and str(n.name).begins_with("Rag"):
			pieces += 1
			fastest = maxf(fastest, (n as RigidBody3D).linear_velocity.length())
	check(pieces >= 8, "the body comes apart into %d linked pieces" % pieces)
	check(fastest > 5.0, "and a blast throws it (%.1f m/s)" % fastest)
	await frames(60)
	var low := INF
	for n in scene.get_children():
		if n is RigidBody3D and str(n.name).begins_with("Rag"):
			low = minf(low, (n as RigidBody3D).global_position.y)
	check(low > Y - 0.3, "it lands on the floor, not through it (lowest %.2f)" % (low - Y))
	var prop := PhysProp.make("drum", Color.ORANGE, RandomNumberGenerator.new())
	scene.add_child(prop)
	prop.global_position = Vector3(25, Y + prop.rest_height() + 0.05, -20)
	await frames(30)
	var at := prop.global_position
	PhysicsFx.shot(player, Vector3(25, at.y, -10), Vector3(25, at.y, -30), Vector3.FORWARD, 3.0)
	await frames(20)
	check(prop.global_position.z < at.z - 0.05, "a shot knocks a drum back (%.2f m)" % (at.z - prop.global_position.z))
	at = prop.global_position
	PhysicsFx.blast(self, at + Vector3(1.0, -0.3, 0), 4.0)
	await frames(20)
	check(prop.global_position.distance_to(at) > 0.5, "a blast throws it (%.1f m)" % prop.global_position.distance_to(at))


func _test_maps(scene: Node3D) -> void:
	print("map passages")
	for M in [FoldedWorks, DreamHome, FaultYard, LastTestament]:
		var m: Node3D = M.new()
		scene.add_child(m)
		await frames(3)
		var l: Layout = m.get("layout")
		var props := m.get_node_or_null("Props")
		check(l.passages.size() + l.windows.size() >= 4 and l.ledges.size() >= 4 and l.breaches.size() == 4,
			"%s: %d passages, %d windows, %d ledges, %d panels" % [m.name, l.passages.size(), l.windows.size(), l.ledges.size(), l.breaches.size()])
		check(props != null and props.get_child_count() >= 20, "%s: %d loose props" % [m.name, props.get_child_count() if props != null else 0])
		# Bots can still get between the two spawns.
		var spawns := l.rects("s")
		var path: Array[Vector3] = l.path(Vector3(spawns[0].get_center().x, 0, spawns[0].get_center().y), Vector3(spawns[-1].get_center().x, 0, spawns[-1].get_center().y))
		check(not path.is_empty(), "%s: spawn to spawn still has a way" % m.name)
		check(_holes(m) == 0, "%s: no hole in the floor anywhere you can stand (C8)" % m.name)
		m.queue_free()
		await frames(2)


## Columns 0.5 m apart over the play area with standing room just above floor level and
## nothing under it (see tools/hole_probe.gd).
func _holes(m: Node3D) -> int:
	var area: Rect2 = m.get("play_area")
	var low := float(m.get("lowest_floor"))
	var space := m.get_world_3d().direct_space_state
	var n := 0
	var x := area.position.x + 0.25
	while x < area.end.x:
		var z := area.position.y + 0.25
		while z < area.end.y:
			var pq := PhysicsPointQueryParameters3D.new()
			pq.position = Vector3(x, 0.3, z)
			pq.collision_mask = Geo.WORLD
			if space.intersect_point(pq, 1).is_empty():
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 0.3, z), Vector3(x, low - 8.0, z), Geo.WORLD))
				if hit.is_empty() or hit.position.y < low - 0.5:
					n += 1
			z += 0.5
		x += 0.5
	if n > 0:
		print("    %d hole columns" % n)
	return n
