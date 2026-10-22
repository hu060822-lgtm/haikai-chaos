extends SceneTree
## Reload animation strips: first person in the movement lab, a few guns (a box magazine
## run dry so it racks, a pistol, a tube shotgun, a revolver), frozen at points through
## the reload. Also the death screen with a long build, at 1600x900 and 1280x720.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/reload_shots.gd -- <out_dir>

var out := "user://"
var main: Main

const GUNS := [
	["carbine", {"frame": "carbine", "parts": {}, "tune": {}}],
	["pistol", {"frame": "service_pistol", "parts": {}, "tune": {}}],
	["shotgun", {"frame": "shotgun", "parts": {}, "tune": {}}],
	["revolver", {"frame": "revolver", "parts": {}, "tune": {}}],
]
const STEPS := [0.08, 0.24, 0.36, 0.55, 0.66, 0.82]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.load_all()
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	Main.map_id = "lab"
	Main.skip_title = true
	change_scene_to_file("res://scenes/main.tscn")
	await frames(8)
	main = current_scene as Main
	main.hud.show_hint("", 0.0)
	var p := main.player
	var only := OS.get_environment("ONLY")
	if only == "" or only == "reload":
		for g in GUNS:
			p.equip(g[1])
			main.lab.restart("C")
			p.rotation.y = deg_to_rad(200)
			await frames(10)
			p.weapon.ammo = 0
			p.weapon.start_reload()
			p.view.reload(p.weapon.reload_time(), true)
			var total := p.weapon.reload_time()
			for t: float in STEPS:
				p.weapon.reload_left = total * (1.0 - t)
				p.view._reload = total * (1.0 - t)
				p.input_enabled = false
				await frames(2)
				p.view._reload = total * (1.0 - t)
				p.view.update_pose(0.0001, {"aim": 0.0, "speed": 0.0, "move": Player.Move.GROUND, "floor": true,
					"roll": 0.0, "vy": 0.0, "reloading": true, "sprint": false})
				await shot("reload_%s_%02d" % [g[0], roundi(t * 100)])
	if only == "" or only == "death":
		var long := {"frame": "carbine", "parts": {}, "tune": {}}
		for slot in Arsenal.SLOTS:
			for s in Arsenal.open_slots(long):
				if not long.parts.has(s):
					var fits := Arsenal.parts_for(long, s)
					if not fits.is_empty():
						long.parts[s] = fits[0]
			long = Arsenal.clean(long)
		var info := {"attacker_name": "鉚釘-42", "gun_name": "很長很長的測試步槍", "build": long, "distance": 23.4,
			"zone": "head", "moves": ["牆跑", "空中"], "through_wall": true}
		for size in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 768)]:
			root.get_window().size = size
			main.death.show_death(info, 64.0, 100.0)
			await frames(6)
			await shot("death_%dx%d" % [size.x, size.y])
		main.death.hide_death()
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("PRINT shot ", name)
