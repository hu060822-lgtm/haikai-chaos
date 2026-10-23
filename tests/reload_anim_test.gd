extends SceneTree
## Character overhaul, Phase 4: every gun reloads by its own kind of template (a magazine,
## a revolver's cylinder, a tube, a break action, a belt, a cell, a hopper, a crossbow, a
## harpoon); the third-person hands touch the part being loaded at the moment it seats;
## first and third person play the same timeline; the third-person reload stops the
## instant the weapon's does; bolt, pump and lever guns are worked after a shot.
##   godot --headless --path . --script res://tests/reload_anim_test.gd

var failures := 0


func _init() -> void:
	Settings.look = Faultprint.COUNTERFORM
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	_test_templates()
	_test_every_frame()
	for frame in ["carbine", "service_pistol", "revolver", "shotgun", "double_barrel", "lmg", "tesla", "crossbow", "harpoon", "rifle", "duck_launcher", "minigun"]:
		for dry in [false, true]:
			_test_touch(scene, frame, dry)
	_test_same_timeline(scene)
	_test_stops(scene)
	_test_cycle(scene)
	print("RELOAD ANIM TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _gun(frame: String) -> Node3D:
	return GunModels.build({"frame": frame, "parts": {}, "tune": {}})


func _test_templates() -> void:
	var want := {"carbine": "mag", "service_pistol": "mag", "revolver": "revolver", "glass_revolver": "revolver",
		"shotgun": "tube", "lever_action": "tube", "double_barrel": "break", "quad_barrel": "break", "punt_gun": "break",
		"lmg": "belt", "minigun": "belt", "tesla": "cell", "railgun": "cell", "flamethrower": "cell", "crossbow": "crossbow",
		"harpoon": "muzzle", "anchor_gun": "muzzle", "rifle": "stripper", "scout_rifle": "stripper", "anti_materiel": "mag",
		"duck_launcher": "hopper", "nail_gun": "coil", "saw_launcher": "mag"}
	var wrong := []
	for f: String in want:
		var g := _gun(f)
		if ReloadPlan.template(g) != want[f]:
			wrong.append("%s=%s" % [f, ReloadPlan.template(g)])
		g.free()
	check(wrong.is_empty(), "each gun loads its own way %s" % [wrong])
	var acts := {"rifle": "bolt", "scout_rifle": "bolt", "shotgun": "pump", "lever_action": "lever", "carbine": ""}
	var bad := []
	for f: String in acts:
		var g := _gun(f)
		if ReloadPlan.action(g) != acts[f]:
			bad.append(f)
		g.free()
	check(bad.is_empty(), "bolt, pump and lever guns are worked between shots %s" % [bad])


func _test_every_frame() -> void:
	var broken := []
	for f: String in Arsenal.FRAMES:
		var g := _gun(f)
		for dry in [false, true]:
			var p := ReloadPlan.for_gun(g, 2.5, dry)
			var rest := Vector3(0, 0.02, -0.2)
			var a := p.sample(0.0, rest)
			var z := p.sample(1.0, rest)
			var ok := (a.at as Vector3).is_equal_approx(rest) and (z.at as Vector3).is_equal_approx(rest)
			ok = ok and (z.mag as Vector3).is_zero_approx() and (z.tilt as Vector3).is_zero_approx() and z.prop == ""
			for i in 101:
				var s := p.sample(i / 100.0, rest)
				var v: Vector3 = s.at
				if is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or v.length() > 1.5:
					ok = false
			for i in range(1, p.keys.size()):
				ok = ok and float(p.keys[i].t) >= float(p.keys[i - 1].t)
			if not ok:
				broken.append("%s%s" % [f, " dry" if dry else ""])
		g.free()
	check(broken.is_empty(), "all %d guns: the reload starts and ends with everything home, no jumps out of reach %s" % [Arsenal.FRAMES.size(), broken])


func _rig(scene: Node3D, frame: String) -> AthleteRig:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var a := CompetitorModel.build(Color.RED, true, rng) as AthleteRig
	scene.add_child(a)
	a.steps = false
	a.hold(_gun(frame))
	return a


func _palm_l(a: AthleteRig) -> Vector3:
	a.skel.force_update_all_bone_transforms()
	var h := a.skel.get_bone_global_pose(AthleteBones.index("hand_l"))
	return h.origin + h.basis.y * 0.05


## At each moment something seats (a magazine home, a shell in the port, a cylinder shut),
## the third-person left palm is on that spot of the gun.
func _test_touch(scene: Node3D, frame: String, dry: bool) -> void:
	var a := _rig(scene, frame)
	var total := 2.5
	a.reload_state(total, total, dry)
	var plan := a._plan
	var worst := 0.0
	var where := ""
	for seat in plan.seats:
		a.reload_state(total * (1.0 - seat), total, dry)
		a.animate(0.0, {"vel": Vector3.ZERO, "floor": true, "move": AthleteMotion.GROUND, "pitch": 0.0})
		var fg: Vector3 = a._slots.get("foregrip", Vector3(0, 0, -0.2)) + Vector3(0, 0.03, 0)
		var want := a.gun_hand.transform * (plan.sample(seat, fg).at as Vector3)
		var miss := _palm_l(a).distance_to(want)
		if miss > worst:
			worst = miss
			where = "t %.2f" % seat
	check(plan.seats.size() > 0 and worst < 0.07, "%s%s (%s): the hand is on the part as it seats (worst %.3f m, %s)" % [frame, " dry" if dry else "", plan.kind, worst, where])
	a.queue_free()


func _test_same_timeline(scene: Node3D) -> void:
	var view := ViewModel.new()
	scene.add_child(view)
	var ok := true
	for frame in ["carbine", "revolver", "shotgun", "double_barrel", "tesla"]:
		view.set_build({"frame": frame, "parts": {}, "tune": {}})
		view.reload(2.0, true)
		var a := _rig(scene, frame)
		a.reload_state(2.0, 2.0, true)
		ok = ok and view._plan.kind == a._plan.kind and view._plan.keys.size() == a._plan.keys.size() and view._plan.seats == a._plan.seats
		a.queue_free()
	check(ok, "first and third person play the same reload timeline")
	view.queue_free()


func _test_stops(scene: Node3D) -> void:
	var a := _rig(scene, "carbine")
	a.reload_state(1.7, 2.5, false)
	a.animate(0.0, {"vel": Vector3.ZERO, "floor": true, "move": AthleteMotion.GROUND})
	var mid := _palm_l(a)
	# The weapon's reload ends early (a refill): the next frame the hand is back on the gun.
	a.reload_state(0.0, 2.5, false)
	a.animate(0.0, {"vel": Vector3.ZERO, "floor": true, "move": AthleteMotion.GROUND})
	var fg: Vector3 = a._slots.get("foregrip", Vector3(0, 0, -0.2))
	var home := a.gun_hand.transform * fg
	check(mid.distance_to(home) > 0.15 and _palm_l(a).distance_to(home) < 0.1 and a.reload_progress() == 1.0,
		"the third-person reload stops the moment the weapon's does (%.2f m out, then %.2f m from the handguard)" % [mid.distance_to(home), _palm_l(a).distance_to(home)])
	var mag := a._gun.get_node("Magazine") as Node3D
	check(mag.position.is_zero_approx(), "and the magazine is back in the gun")
	a.queue_free()


func _test_cycle(scene: Node3D) -> void:
	var a := _rig(scene, "rifle")
	a.animate(0.0, {"vel": Vector3.ZERO, "floor": true, "move": AthleteMotion.GROUND})
	var grip := a.gun_hand.transform * (a._slots.grip as Vector3)
	a.fired(1.0)
	a._process(a._cycle_total * 0.45)
	a.animate(0.0, {"vel": Vector3.ZERO, "floor": true, "move": AthleteMotion.GROUND})
	a.skel.force_update_all_bone_transforms()
	var h := a.skel.get_bone_global_pose(AthleteBones.index("hand_r"))
	var palm := h.origin + h.basis.y * 0.065
	var bolt := a.gun_hand.transform * (a._slots.bolt as Vector3)
	check(palm.distance_to(grip) > 0.06 and palm.distance_to(bolt) < 0.14, "a bolt gun: after the shot the right hand works the bolt (%.2f m from it)" % palm.distance_to(bolt))
	a._process(a._cycle_total)
	a.animate(0.0, {"vel": Vector3.ZERO, "floor": true, "move": AthleteMotion.GROUND})
	a.skel.force_update_all_bone_transforms()
	h = a.skel.get_bone_global_pose(AthleteBones.index("hand_r"))
	check((h.origin + h.basis.y * 0.065).distance_to(grip) < 0.05, "and goes back to the grip")
	a.queue_free()
