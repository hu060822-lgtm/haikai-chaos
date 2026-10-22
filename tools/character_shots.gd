extends SceneTree
## Competitor model sheet: three athletes holding random builds, seen from the front
## three-quarter, the side and the back, on the gallery's studio backdrop.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/character_shots.gd -- <out_dir>

var out := "user://"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#C9C3B8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#B9BEC2")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	for spec in [[Vector3(-40, -30, 0), Color("#FFF0DA"), 1.5], [Vector3(-15, 140, 0), Color("#B8C4CC"), 0.5]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = spec[0]
		l.light_color = spec[1]
		l.light_energy = spec[2]
		l.shadow_enabled = true
		world.add_child(l)
	var floor_m := MeshInstance3D.new()
	floor_m.mesh = PlaneMesh.new()
	(floor_m.mesh as PlaneMesh).size = Vector2(20, 20)
	floor_m.material_override = Counterform.material("concrete", Color("#9E978A"))
	world.add_child(floor_m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 3:
		var m := CompetitorModel.build(Faultprint.INFO_ENEMY if i != 1 else Faultprint.INFO_ALLY, i != 1, rng)
		world.add_child(m)
		m.position = Vector3((i - 1) * 1.1, 0, 0)
		m.rotation_degrees.y = [20.0, 90.0, 180.0][i]
		var gun := GunModels.build(GunNames.random_build(rng))
		m.get_node("GunHand").add_child(gun)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	cam.fov = 32
	await process_frame
	cam.look_at_from_position(Vector3(0.0, 1.35, -5.4), Vector3(0, 1.0, 0), Vector3.UP)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("characters.png"))
	cam.look_at_from_position(Vector3(-1.4, 1.7, -1.6), Vector3(-1.1, 1.35, 0), Vector3.UP)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("character_close.png"))
	print("saved")
	quit()
