extends SceneTree
## Bench screenshots for ammo-by-calibre and the strip-all button.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/ammo_shots.gd -- <out_dir>

var out := "user://"
var main: Main


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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.hud.show_hint("", 0.0)
	var b := main.bench
	for spec in [["shotgun", "ammo_shotgun"], ["carbine", "ammo_carbine"], ["flamethrower", "ammo_flamer"]]:
		b.open({"frame": spec[0], "parts": {"sight": "red_dot", "muzzle": "compensator", "stock": "heavy_stock"}, "tune": {}}, "")
		b._slot = "ammo"
		b._refresh()
		await frames(20)
		await shot(spec[1])
	b.strip_all()
	await frames(20)
	await shot("strip_all")
	quit()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)
