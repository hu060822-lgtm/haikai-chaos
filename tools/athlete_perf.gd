extends SceneTree
## Character overhaul: what the athlete costs on the CPU. Builds ten competitors, then
## times their pose solve (run, crouch, slide, air, pitch) over many frames.
##   godot --headless --path . --script res://tools/athlete_perf.gd

func _init() -> void:
	Settings.look = Faultprint.COUNTERFORM
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
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
	var frames := 600
	t0 = Time.get_ticks_usec()
	for f in frames:
		var t := f / 60.0
		for i in rigs.size():
			rigs[i].pose(1.0 / 60.0, Vector3(sin(t + i) * 6.0, 0, -7), (f + i * 7) % 50 < 40, 0.5 if i % 3 == 0 else 0.0, i % 4 == 1, 0, sin(t) * 0.5)
	var per := (Time.get_ticks_usec() - t0) / float(frames)
	print("pose, ten competitors: %.3f ms per frame (%.3f ms each)" % [per / 1000.0, per / 10000.0])
	var mesh := rigs[0].body.mesh as ArrayMesh
	var verts := 0
	var tris := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("mesh: %d surfaces, %d vertices, %d triangles" % [mesh.get_surface_count(), verts, tris])
	quit()
