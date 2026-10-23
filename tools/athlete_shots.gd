extends SceneTree
## Character overhaul: the athlete on a studio backdrop from several sides and distances,
## plus a joint sheet (elbows, knees, hips, spine bent hard) to check the skinning.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/athlete_shots.gd -- <out_dir> [views...]

var out := "user://"
var cam: Camera3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://"
	var only := args.slice(1)
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	var world := Node3D.new()
	root.add_child(world)
	_studio(world)
	cam = Camera3D.new()
	cam.fov = 35
	world.add_child(cam)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := CompetitorModel.build(Color("#E8506A"), true, rng)
	world.add_child(a)
	a.global_position = Vector3.ZERO
	var build := {"frame": "carbine", "parts": {}, "tune": {}}
	a.hold(GunModels.build(build))
	await _frames(3)
	var views := {
		"front": [Vector3(0, 1.1, -3.6), Vector3(0, 1.0, 0)],
		"three_q": [Vector3(-2.2, 1.4, -2.8), Vector3(0, 1.0, 0)],
		"side": [Vector3(3.6, 1.1, 0), Vector3(0, 1.0, 0)],
		"back": [Vector3(1.2, 1.4, 3.4), Vector3(0, 1.0, 0)],
		"face": [Vector3(-0.35, 1.68, -0.8), Vector3(0, 1.62, 0)],
		"mid": [Vector3(-4, 1.6, -9), Vector3(0, 1.0, 0)],
		"far": [Vector3(-8, 1.7, -24), Vector3(0, 1.0, 0)],
	}
	for v in views:
		if not only.is_empty() and not v in only:
			continue
		cam.fov = 35 if not v in ["mid", "far"] else 60
		await _shot(views[v][0], views[v][1], "athlete_" + v)
	if only.is_empty() or "lineup" in only:
		# Four competitors (their own palettes) with four kinds of gun, at mid range.
		a.visible = false
		var line: Array[Node3D] = []
		var frames := ["pistol", "carbine", "shotgun", "minigun"]
		for i in 4:
			var r2 := RandomNumberGenerator.new()
			r2.seed = 100 + i * 17
			var m := CompetitorModel.build(Color("#E8506A") if i % 2 == 0 else Color("#4FA3E0"), i % 2 == 0, r2)
			world.add_child(m)
			m.position = Vector3(-1.8 + i * 1.2, 0, 0)
			m.rotation.y = 0.5
			m.hold(GunModels.build({"frame": frames[i], "parts": {}, "tune": {}}))
			line.append(m)
		await _frames(3)
		cam.fov = 40
		await _shot(Vector3(-1.5, 1.5, -5.5), Vector3(0, 1.0, 0), "athlete_lineup")
		var px := line[0].global_transform
		await _shot(px * Vector3(0.7, 1.55, -1.2), px * Vector3(0, 1.3, -0.3), "athlete_pistol")
		px = line[1].global_transform
		await _shot(px * Vector3(-0.8, 1.5, -0.9), px * Vector3(0, 1.35, -0.3), "athlete_hands")
		for m in line:
			m.queue_free()
		a.visible = true
	if "reloads" in only:
		# Phase 4: third-person reloads, frozen through each gun's template (not in the
		# default set: ask for it by name).
		for frame in ["carbine", "service_pistol", "revolver", "shotgun", "double_barrel", "lmg", "tesla", "crossbow", "harpoon", "rifle"]:
			a.hold(GunModels.build({"frame": frame, "parts": {}, "tune": {}}))
			await _frames(2)
			for t: float in [0.1, 0.25, 0.45, 0.62, 0.75, 0.9]:
				a.reload_state(2.5 * (1.0 - t), 2.5, true)
				a.animate(0.0, {"vel": Vector3.ZERO, "floor": true, "move": AthleteMotion.GROUND, "pitch": -0.15})
				await _shot(Vector3(-0.9, 1.55, -1.3), Vector3(0.05, 1.2, -0.25), "reload3p_%s_%02d" % [frame, roundi(t * 100)])
			a.reload_state(0.0, 2.5, true)
		a.hold(GunModels.build(build))
	if only.is_empty() or "moves" in only:
		# The moves, side by side after a second of the same input: stand, run, sprint
		# strafe, crouch, slide, airborne.
		a.visible = false
		var cases := [[Vector3.ZERO, true, 0.0, false], [Vector3(0, 0, -6.5), true, 0.0, false], [Vector3(4, 0, -3), true, 0.0, false],
			[Vector3.ZERO, true, 1.0, false], [Vector3(0, 0, -11), true, 0.0, true], [Vector3(0, -3, -6), false, 0.0, false]]
		var row: Array[Node3D] = []
		for i in cases.size():
			var r3 := RandomNumberGenerator.new()
			r3.seed = 40 + i
			var m := CompetitorModel.build(Color("#E8506A"), true, r3)
			world.add_child(m)
			m.position = Vector3(-3.0 + i * 1.2, 0, 0)
			m.hold(GunModels.build({"frame": "carbine", "parts": {}, "tune": {}}))
			m.steps = false
			row.append(m)
		for f in 75:
			for i in cases.size():
				var c: Array = cases[i]
				row[i].pose(1.0 / 60.0, c[0], c[1], c[2], c[3], 0, 0.0)
		await _frames(3)
		cam.fov = 40
		await _shot(Vector3(5.5, 1.3, -1.2), Vector3(0, 0.9, 0), "athlete_moves")
		await _shot(Vector3(-0.5, 1.4, -6.5), Vector3(0, 0.9, 0), "athlete_moves_front")
		for m in row:
			m.queue_free()
		a.visible = true
	if only.is_empty() or "joints" in only:
		# Joint sheet: the arms folded, a deep squat, a lunge, a twist.
		a.debug_pose({"elbow_l": 2.3, "elbow_r": 2.3, "shoulder_l": Vector3(-1.2, 0, 0.3), "shoulder_r": Vector3(-1.2, 0, -0.3),
			"hip_l": 1.9, "hip_r": 0.6, "knee_l": -2.3, "knee_r": -1.2, "spine": Vector3(-0.35, 0.4, 0.0)})
		await _frames(2)
		cam.fov = 35
		await _shot(Vector3(-2.4, 1.2, -2.6), Vector3(0, 0.8, 0), "athlete_joints")
		await _shot(Vector3(2.8, 1.0, 0.2), Vector3(0, 0.8, 0), "athlete_joints_side")
	quit()


func _studio(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#B9B4AA")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C8CCD0")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -140, 0)
	key.light_energy = 1.1
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 40, 0)
	rim.light_energy = 0.55
	rim.light_color = Color("#D8E4FF")
	world.add_child(rim)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mesh.mesh = pm
	floor_mesh.material_override = Counterform.material("concrete", Color("#6E6A63"))
	world.add_child(floor_mesh)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(from: Vector3, to: Vector3, name: String) -> void:
	cam.look_at_from_position(from, to, Vector3.UP)
	cam.make_current()
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
