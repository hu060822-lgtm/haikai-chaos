extends SceneTree
## First-person arms: a few guns at rest, aimed and mid-reload, on DREAM HOME (bright, so
## the arms' shading reads) and in the movement lab.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/arms_shots.gd -- <out_dir>

var out := "user://"

const GUNS := [
	["carbine", {"frame": "carbine", "parts": {}, "tune": {}}],
	["pistol", {"frame": "service_pistol", "parts": {}, "tune": {}}],
	["shotgun", {"frame": "shotgun", "parts": {}, "tune": {}}],
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.load_all()
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	Main.map_id = "dream"
	Main.skip_title = true
	change_scene_to_file("res://scenes/main.tscn")
	await frames(8)
	var main := current_scene as Main
	main.hud.show_hint("", 0.0)
	var p := main.player
	p.input_enabled = false
	for b in main.bots:
		b.passive = true
	for g in GUNS:
		p.equip(g[1])
		p.global_position = Vector3(-12, 0.1, 4)
		p.rotation.y = deg_to_rad(-70)
		p._pitch = -0.05
		await frames(12)
		for pose in [["idle", 0.0, -1.0], ["reload", 0.0, 0.36], ["aim", 1.0, -1.0]]:
			if pose[2] >= 0.0:
				var total := p.weapon.reload_time()
				p.view.reload(total, true)
				p.view._reload = total * (1.0 - float(pose[2]))
			for i in 3:
				p.view.update_pose(0.0001, {"aim": pose[1], "speed": 0.0, "move": Player.Move.GROUND, "floor": true,
					"roll": 0.0, "vy": 0.0, "reloading": pose[2] >= 0.0, "sprint": false})
				await frames(1)
			await shot("arms_%s_%s" % [g[0], pose[0]])
			p.view._reload = 0.0
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("PRINT shot ", name)
