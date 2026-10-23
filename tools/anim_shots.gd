extends SceneTree
## C5 animation: athletes running, strafing, in the air, sliding, and going limp, side by
## side on FOLDED WORKS' floor.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/anim_shots.gd -- <out_dir>

var out := "user://"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.load_all()
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	var map := FaultYard.new()
	root.add_child(map)
	var rng := RandomNumberGenerator.new()
	var poses := [
		["idle", Vector3.ZERO, true, false],
		["walk", Vector3(0, 0, -3.5), true, false],
		["run", Vector3(0, 0, -8.0), true, false],
		["strafe", Vector3(6.0, 0, 0), true, false],
		["air", Vector3(0, 2.0, -6.0), false, false],
		["slide", Vector3(0, 0, -10.0), true, true],
	]
	var models := []
	for i in poses.size():
		rng.seed = 40 + i
		var m := CompetitorModel.build(FpUi.enemy_color() if i % 2 else FpUi.ally_color(), i % 2 == 1, rng)
		m.find_child("GunHand", true, false).add_child(GunModels.build({"frame": ["carbine", "smg", "ak", "pdw", "shotgun", "rifle"][i], "parts": {}, "tune": {}}))
		root.add_child(m)
		m.global_position = Vector3(-7.5 + i * 3.0, 0, 14)
		m.rotation.y = deg_to_rad(-70)
		models.append(m)
	var dead := []
	for i in 3:
		rng.seed = 90 + i
		var m := CompetitorModel.build(FpUi.enemy_color(), true, rng)
		m.find_child("GunHand", true, false).add_child(GunModels.build({"frame": "carbine", "parts": {}, "tune": {}}))
		root.add_child(m)
		m.global_position = Vector3(-4.5 + i * 4.5, 0, 9)
		m.rotation.y = deg_to_rad([-70, 20, 160][i])
		dead.append(m)
	var cam := Camera3D.new()
	cam.fov = 60
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.6, 24), Vector3(0, 0.9, 12))
	cam.make_current()
	var frame := 0
	for step in 90:
		var dt := 1.0 / 60.0
		for i in poses.size():
			var p: Array = poses[i]
			models[i].pose(dt, models[i].global_basis * (p[1] as Vector3), p[2], 0.0, p[3], 0, 0.0)
		if step == 30:
			for i in 3:
				dead[i].die(Vector3(0, 0, -1).rotated(Vector3.UP, i * 1.1))
		await process_frame
		if step in [20, 26, 32, 40, 50, 60, 89]:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/anim_%02d.png" % [out, frame])
			frame += 1
	quit()
