extends SceneTree
## Character overhaul: what the athlete costs on the CPU. Builds ten competitors on a
## floor next to a wall, then times their whole animation (Phase 6: the state machine,
## foot and wall rays, IK, reloads, bolt cycles) through runs, slides, jumps, wall runs
## and reloads over many frames, against the old rigid figure's pose.
##   godot --headless --path . --script res://tools/athlete_perf.gd

func _init() -> void:
	Settings.look = Faultprint.COUNTERFORM
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var floor_body := Geo.block(scene, Vector3(80, 1, 80), Vector3(0, -0.5, 0), Faultprint.CONCRETE)
	floor_body.collision_layer = Geo.WORLD
	var wall := Geo.block(scene, Vector3(1, 6, 80), Vector3(-1.0, 3, 0), Faultprint.CONCRETE)
	wall.collision_layer = Geo.WORLD
	await process_frame
	var t0 := Time.get_ticks_usec()
	var rigs: Array[AthleteRig] = []
	for i in 10:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var a := CompetitorModel.build(Color.RED, true, rng) as AthleteRig
		scene.add_child(a)
		a.steps = false
		a.hold(GunModels.build({"frame": ["carbine", "revolver", "shotgun", "minigun", "smg"][i % 5], "parts": {}, "tune": {}}))
		rigs.append(a)
		if i == 0:
			print("first build (mesh made once): %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	print("ten builds: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for i in rigs.size():
		rigs[i].position = Vector3(i * 2.0, 0, 0)
	var frames := 600
	t0 = Time.get_ticks_usec()
	var worst := 0.0
	for f in frames:
		var t := f / 60.0
		var f0 := Time.get_ticks_usec()
		for i in rigs.size():
			var phase := (f / 120 + i) % 5
			var m: int = [Player.Move.GROUND, Player.Move.SLIDE, Player.Move.AIR, Player.Move.WALLRUN, Player.Move.GROUND][phase]
			var st := CompetitorRig.anim(m, sin(t) * 0.5, 1.0 if m == Player.Move.SLIDE else 0.0,
				Vector3(1, 0, 0) if m == Player.Move.WALLRUN else Vector3.ZERO, null, f / 90, f / 25, m != Player.Move.AIR and m != Player.Move.WALLRUN)
			if phase == 4:
				st[4] = 2.0 - fmod(t, 2.0)
				st[5] = 2.0
			rigs[i].play_state(1.0 / 60.0, Vector3(sin(t + i) * 6.0, 0, -7), st)
		var took := (Time.get_ticks_usec() - f0) / 1000.0
		if took > 3.0 * 2.5:
			print("  slow frame %d: %.2f ms" % [f, took])
		worst = maxf(worst, took)
	var per := (Time.get_ticks_usec() - t0) / float(frames)
	print("animate, ten competitors: %.3f ms per frame (%.3f ms each), worst frame %.3f ms" % [per / 1000.0, per / 10000.0, worst])
	var old: Array[CompetitorRig] = []
	Settings.look = 0
	for i in 10:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var o := CompetitorModel.build(Color.RED, true, rng)
		scene.add_child(o)
		o.steps = false
		old.append(o)
	Settings.look = Faultprint.COUNTERFORM
	t0 = Time.get_ticks_usec()
	for f in frames:
		var t := f / 60.0
		for i in old.size():
			old[i].pose(1.0 / 60.0, Vector3(sin(t + i) * 6.0, 0, -7), (f + i * 7) % 50 < 40, 0.0, false, 0, sin(t) * 0.5)
	per = (Time.get_ticks_usec() - t0) / float(frames)
	print("old rigid figure, ten: %.3f ms per frame" % (per / 1000.0))
	var mesh := rigs[0].body.mesh as ArrayMesh
	var verts := 0
	var tris := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("mesh: %d surfaces, %d vertices, %d triangles" % [mesh.get_surface_count(), verts, tris])
	quit()
