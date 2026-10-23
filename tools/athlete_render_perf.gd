extends SceneTree
## Character overhaul, Phase 6: what ten athletes cost to draw, against ten of the old
## rigid figures and an empty scene, in the motion arena under the filming light (with
## shadows). Run it on the machine you play on: in a container's software renderer only
## the ratios mean anything.
##   godot --path . --script res://tools/athlete_render_perf.gd [-- frames]

const Arena := preload("res://tools/motion/arena.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var frames := int(args[0]) if args.size() > 0 else 240
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	Arena.build(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -140, 0)
	key.shadow_enabled = true
	world.add_child(key)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 3, 9), Vector3(0, 1, -4), Vector3.UP)
	cam.make_current()
	AthleteRig.prewarm()
	for look in [-1, Faultprint.COUNTERFORM, 0]:
		var group := Node3D.new()
		world.add_child(group)
		if look >= 0:
			Settings.look = look
			for i in 10:
				var rng := RandomNumberGenerator.new()
				rng.seed = i
				var m := CompetitorModel.build(Color.RED, true, rng)
				m.steps = false
				group.add_child(m)
				m.position = Vector3(-6 + (i % 5) * 3.0, 0, -2 - (i / 5) * 4.0)
				m.find_child("GunHand", true, false).add_child(GunModels.build({"frame": ["carbine", "shotgun", "smg", "revolver", "lmg"][i % 5], "parts": {}, "tune": {}}))
		Settings.look = Faultprint.COUNTERFORM
		for i in 30:
			await process_frame
		var t0 := Time.get_ticks_usec()
		for f in frames:
			var t := f / 60.0
			for m in group.get_children():
				var st := CompetitorRig.anim(Player.Move.GROUND, sin(t) * 0.3, 0.0, Vector3.ZERO, null, 0, f / 30, true)
				(m as CompetitorRig).play_state(1.0 / 60.0, Vector3(sin(t + m.position.x) * 5.0, 0, -5), st)
			await process_frame
		var per := (Time.get_ticks_usec() - t0) / 1000.0 / frames
		print("%s: %.2f ms a frame (%.0f fps)" % [["empty scene", "ten athletes", "ten old figures"][[-1, Faultprint.COUNTERFORM, 0].find(look)], per, 1000.0 / per])
		group.queue_free()
	quit()
