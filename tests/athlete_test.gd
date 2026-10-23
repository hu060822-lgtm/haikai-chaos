extends SceneTree
## Character overhaul checks: the skinned athlete builds with its full skeleton and every
## surface has a material; posing never moves the body (only its bones); both hands land
## on the gun's own grip and handguard for long guns and pistols, at any look pitch; the
## feet stay planted under a standing or crouching body and above the floor; a death goes
## limp with the gun still in hand; a ragdoll's bones follow its bodies; nothing goes NaN.
##   godot --headless --path . --script res://tests/athlete_test.gd

var failures := 0


func _init() -> void:
	Settings.look = Faultprint.COUNTERFORM
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var floor_body := Geo.block(scene, Vector3(40, 1, 40), Vector3(0, -0.5, 0), Faultprint.CONCRETE)
	floor_body.collision_layer = Geo.WORLD
	await process_frame
	_test_build(scene)
	_test_pose_reads_only(scene)
	for frame in ["carbine", "revolver", "shotgun", "minigun", "punt_gun", "smg"]:
		for pitch in [-0.9, 0.0, 0.9]:
			_test_hands(scene, frame, pitch)
	_test_feet(scene)
	_test_landing()
	_test_wall_push(scene)
	_test_no_teleport(scene)
	await _test_death(scene)
	print("ATHLETE TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _make(scene: Node3D, frame := "carbine", seed := 1) -> AthleteRig:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a := CompetitorModel.build(Color.RED, true, rng) as AthleteRig
	scene.add_child(a)
	a.steps = false
	if frame != "":
		a.hold(GunModels.build({"frame": frame, "parts": {}, "tune": {}}))
	return a


## A bone's model-space pose, up to date (the skeleton otherwise updates once a frame).
func _g(a: AthleteRig, bone: int) -> Transform3D:
	a.skel.force_update_all_bone_transforms()
	return a.skel.get_bone_global_pose(bone)


func _test_build(scene: Node3D) -> void:
	var a := _make(scene)
	check(a != null, "Counterform competitors are skinned athletes")
	check(a.skel.get_bone_count() == AthleteBones.count() and AthleteBones.count() == 24, "the skeleton has its 24 bones")
	var mesh := a.body.mesh as ArrayMesh
	var missing := 0
	for i in mesh.get_surface_count():
		if a.body.get_surface_override_material(i) == null:
			missing += 1
	check(mesh.get_surface_count() == 14 and missing == 0, "body and gear: 14 surfaces, every one with a material (%d missing)" % missing)
	check(a.find_child("GunHand", true, false) != null and a.get_node_or_null("Marker") != null, "GunHand and Marker are where the game looks")
	var other := _make(scene, "carbine", 99)
	check(other.body.mesh == a.body.mesh, "competitors share one mesh (only their materials differ)")
	a.queue_free()
	other.queue_free()


func _test_pose_reads_only(scene: Node3D) -> void:
	var a := _make(scene)
	a.global_position = Vector3(3, 0, 2)
	var before := a.global_transform
	var nan := false
	for f in 120:
		var t := f / 60.0
		a.pose(1.0 / 60.0, Vector3(sin(t) * 6.0, 0, -7), f % 40 < 30, 0.5 if f > 60 else 0.0, f > 90, 0, sin(t))
		for i in a.skel.get_bone_count():
			var q := a.skel.get_bone_pose_rotation(i)
			if is_nan(q.x) or is_nan(q.w):
				nan = true
	check(a.global_transform.is_equal_approx(before), "posing moves only bones, never the body")
	check(not nan, "no bone goes NaN through run, jump, crouch and slide")
	a.queue_free()


func _test_hands(scene: Node3D, frame: String, pitch: float) -> void:
	var a := _make(scene, frame)
	a.pose(0.0, Vector3.ZERO, true, 0.0, false, 0, pitch)
	var gun := a.gun_hand.get_child(0) as Node3D
	var slots: Dictionary = gun.get_meta("slots")
	var to_model := a.gun_hand.transform
	var grip: Vector3 = to_model * (slots.grip as Vector3)
	var hand_r := _g(a, AthleteBones.index("hand_r"))
	var palm_r := hand_r.origin + hand_r.basis.y * 0.065
	var dir := -to_model.basis.z
	check(palm_r.distance_to(grip) < 0.05, "%s at pitch %.1f: the right hand is on the grip (%.3f m)" % [frame, pitch, palm_r.distance_to(grip)])
	var hand_l := _g(a, AthleteBones.index("hand_l"))
	var palm_l := hand_l.origin + hand_l.basis.y * 0.05
	# The left hand is on the gun: close to the line of the bore, somewhere along it.
	var rel := palm_l - to_model.origin
	var off_line := (rel - dir * rel.dot(dir)).length()
	check(off_line < 0.12, "%s at pitch %.1f: the left hand is on the gun (%.3f m off its line)" % [frame, pitch, off_line])
	check(absf(dir.y - sin(pitch)) < 0.05, "%s at pitch %.1f: the gun points where the body looks" % [frame, pitch])
	a.queue_free()


func _test_feet(scene: Node3D) -> void:
	var a := _make(scene)
	for crouch in [0.0, 1.0]:
		for f in 40:
			a.pose(1.0 / 60.0, Vector3.ZERO, true, crouch, false, 0, 0.0)
		var low := 9.0
		for s in ["l", "r"]:
			var foot := _g(a, AthleteBones.index("foot_" + s))
			low = minf(low, foot.origin.y)
			check(absf(foot.origin.y - 0.088) < 0.02, "crouch %.0f: the %s ankle stays at its height over the floor (%.3f)" % [crouch, s, foot.origin.y])
		var hips := _g(a, AthleteBones.index("hips"))
		check(hips.origin.y < 0.97 - crouch * 0.3, "crouch %.0f: the pelvis drops with the crouch (%.2f)" % [crouch, hips.origin.y])
	a.queue_free()


func _test_death(scene: Node3D) -> void:
	var a := _make(scene)
	a.die(Vector3(0, 0, 1))
	for f in 60:
		a._process(1.0 / 60.0)
	var hips := _g(a, AthleteBones.index("hips"))
	check(hips.origin.y < 0.3, "a death goes limp: the pelvis on the floor (%.2f)" % hips.origin.y)
	var hand := _g(a, AthleteBones.index("hand_r"))
	check(a.gun_hand.transform.origin.distance_to(hand.origin) < 0.6, "the gun falls with the right hand")
	a.queue_free()
	var b := _make(scene)
	b.global_position = Vector3(0, 0.02, 0)
	CompetitorRig.leave_corpse(b, Vector3(0, 0, 1), 6.0, 3.0, Vector3.ZERO)
	var start := b.skel.get_bone_global_pose(AthleteBones.index("spine")).origin
	for f in 50:
		await physics_frame
	await process_frame
	var bodies := 0
	for n in scene.get_children():
		if n is RigidBody3D and str(n.name).begins_with("Rag_"):
			bodies += 1
	check(bodies == 11, "a ragdoll is 11 linked bodies (%d)" % bodies)
	var now := b.skel.get_bone_global_pose(AthleteBones.index("spine")).origin
	check(now.distance_to(start) > 0.2, "its bones follow the bodies as it falls (%.2f m)" % now.distance_to(start))
	check(b.gun_hand.get_child_count() == 0, "the gun flies loose")


## Phase 3: a landing squashes with the speed it came down at; a soft one barely does.
func _test_landing() -> void:
	var deepest: Array[float] = []
	for vy in [-2.0, -8.0, -20.0]:
		var m := AthleteMotion.new()
		var dt := 1.0 / 60.0
		for f in 20:
			m.update(dt, {"vel": Vector3(0, vy, -4), "floor": false, "move": AthleteMotion.AIR})
		var low := 9.0
		var rest := 0.0
		for f in 40:
			var d := m.update(dt, {"vel": Vector3(0, 0, -4), "floor": true, "move": AthleteMotion.GROUND})
			low = minf(low, d.hip.y)
			rest = d.hip.y
		deepest.append(rest - low)
	check(deepest[0] < 0.03, "a soft landing barely squashes (%.3f m)" % deepest[0])
	check(deepest[2] > deepest[1] + 0.03 and deepest[1] > deepest[0] + 0.02,
		"landing squash grows with the fall speed (%.3f, %.3f, %.3f m)" % [deepest[0], deepest[1], deepest[2]])


## Phase 3: running on a wall, the soles touch the wall (not inside it); leaving it, the
## foot on the wall's side drives the body off: it starts where it stood on the wall and
## the leg stays straight toward the wall while the body flies away (the push is seen).
func _test_wall_push(scene: Node3D) -> void:
	var a := _make(scene)
	var dt := 1.0 / 60.0
	a.global_position = Vector3(0, 2, 0)
	var vel := Vector3(0, 0, -10)
	var wall_x := -AthleteMotion.WALL_GAP
	var inside := -9.0
	var foot := AthleteBones.index("foot_l")
	for f in 30:
		a.global_position += vel * dt
		a.animate(dt, {"vel": vel, "floor": false, "move": AthleteMotion.WALLRUN, "wall": Vector3(1, 0, 0)})
		if f > 15:
			inside = maxf(inside, wall_x - (a.global_transform * _g(a, foot).origin).x + a.global_position.x)
	check(inside < 0.0, "wall run: the wall-side foot stays out of the wall (%.3f m in)" % inside)
	var on_wall := a.global_transform * _g(a, foot).origin
	vel = Vector3(6, 4, -10)
	var first := 9.0
	var straight := true
	var toward := 9.0
	for f in 6:
		a.global_position += vel * dt
		a.animate(dt, {"vel": vel, "floor": false, "move": AthleteMotion.AIR})
		var w := a.global_transform * _g(a, foot).origin
		if f == 0:
			first = w.distance_to(on_wall)
		var th := _g(a, AthleteBones.index("thigh_l")).basis.y
		var sh := _g(a, AthleteBones.index("shin_l")).basis.y
		straight = straight and th.angle_to(sh) < deg_to_rad(15.0)
		toward = minf(toward, (a.global_transform * _g(a, 0).origin).x - w.x)
	check(a.motion.push_foot == 0, "the push foot is the one on the wall's side")
	check(first < 0.1, "the push starts from where the foot stood on the wall (%.3f m)" % first)
	check(straight and toward > 0.3, "the leg stays straight toward the wall as the body leaves (%.2f m to the wall side)" % toward)
	a.queue_free()


## Phase 3: no state change teleports a limb: run -> slide -> slide jump -> land -> dash
## -> run, every bone moves at most what a running stride moves it in a frame.
func _test_no_teleport(scene: Node3D) -> void:
	var a := _make(scene)
	var dt := 1.0 / 60.0
	var plan := []
	for f in 30:
		plan.append([AthleteMotion.GROUND, Vector3(0, 0, -5), true, 0.0])
	for f in 30:
		plan.append([AthleteMotion.SLIDE, Vector3(0, 0, -8), true, 1.0])
	for f in 25:
		plan.append([AthleteMotion.AIR, Vector3(0, 5.0 - f * 0.5, -8), false, 0.0])
	for f in 30:
		plan.append([AthleteMotion.GROUND, Vector3(0, 0, -5), true, 0.0])
	for f in 15:
		plan.append([AthleteMotion.DASH, Vector3(-9, 0, 0), true, 0.0])
	for f in 20:
		plan.append([AthleteMotion.GROUND, Vector3(0, 0, -5), true, 0.0])
	# A teleport is a jump out of step with the frames before it: the change in how far a
	# bone moves from one frame to the next stays small (a fast limb is fine, a pop is not).
	var prev: Array[Vector3] = []
	var last: Array[float] = []
	var worst := 0.0
	var worst_at := ""
	var fastest := 0.0
	for f in plan.size():
		var st: Array = plan[f]
		a.animate(dt, {"vel": st[1], "floor": st[2], "move": st[0], "crouch": st[3]})
		a.skel.force_update_all_bone_transforms()
		for i in a.skel.get_bone_count():
			var o := a.skel.get_bone_global_pose(i).origin
			if f == 0:
				prev.append(o)
				last.append(0.0)
				continue
			var jump := o.distance_to(prev[i])
			fastest = maxf(fastest, jump)
			if f > 1 and jump - last[i] > worst:
				worst = jump - last[i]
				worst_at = "%s at frame %d" % [a.skel.get_bone_name(i), f]
			prev[i] = o
			last[i] = jump
	check(fastest < 0.25, "run, slide, slide jump, land, dash, run: no bone moves more than 0.25 m in a frame (%.3f)" % fastest)
	check(worst < 0.16, "run, slide, slide jump, land, dash, run: no bone pops (worst %.3f m/frame more than the frame before, %s)" % [worst, worst_at])
	a.queue_free()
