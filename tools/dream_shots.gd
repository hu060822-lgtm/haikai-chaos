extends SceneTree
## Screenshots of DREAM HOME (夢核之家) from fixed spots.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/dream_shots.gd -- <out_dir> [view...]

const VIEWS := {
	"blue_spawn": [Vector3(0, 1.7, 24.5), Vector3(0, 1.5, 0)],
	"red_spawn": [Vector3(0, 1.7, -24.0), Vector3(0, 1.0, 0)],
	"overview": [Vector3(30, 24, 34), Vector3(0, 0, 0)],
	"pool": [Vector3(-12, 2.2, 6), Vector3(4, -1.2, -2)],
	"hallway": [Vector3(-29.5, 1.7, 17), Vector3(-29.5, 1.6, -10)],
	"dining": [Vector3(8, 1.8, 10), Vector3(22, 2.0, 0)],
	"beam": [Vector3(-24, 6.6, -12), Vector3(10, 5.5, -12)],
	"mezzanine": [Vector3(30, 6.2, -16), Vector3(0, 1.0, 4)],
	"panels": [Vector3(-14, 2.0, 0), Vector3(4, 1.5, 0)],
	"blocks": [Vector3(-2, 1.8, 2), Vector3(-10, 3.0, 11)],
	"slide": [Vector3(-8, 2.0, 2), Vector3(-22, 2.5, 8)],
}


func _init() -> void:
	var out := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.load_all()
	var map := DreamHome.new()
	root.add_child(map)
	var cam := Camera3D.new()
	cam.fov = 80
	cam.far = 400
	root.add_child(cam)
	for view in VIEWS:
		if args.size() > 1 and not view in args.slice(1):
			continue
		cam.look_at_from_position(VIEWS[view][0], VIEWS[view][1])
		cam.make_current()
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/dream_%s.png" % [out, view])
		print("PRINT ", view)
	quit()
