extends SceneTree
## Screenshots of FOLDED WORKS from fixed spots.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/map_shots.gd -- <out_dir>

const VIEWS := {
	"spawn": [Vector3(0, 1.7, 24), Vector3(0, 3, 0)],
	"overview": [Vector3(30, 26, 34), Vector3(0, 2, 0)],
	"gallery_gap": [Vector3(-31, 6.2, 14), Vector3(-31, 5.5, -6)],
	"south_run": [Vector3(-14, 6.2, 24), Vector3(6, 5, 20)],
	"tower": [Vector3(4, 2, 12), Vector3(8, 6, -4)],
	"duct": [Vector3(6, 1.0, -12), Vector3(18, 0.8, -12)],
	"top_beam": [Vector3(10, 10.8, -4), Vector3(34, 9, -4)],
}


func _init() -> void:
	var out := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var map := FoldedWorks.new()
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
		root.get_viewport().get_texture().get_image().save_png("%s/map_%s.png" % [out, view])
	quit()
