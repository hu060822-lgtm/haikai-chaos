extends SceneTree
## C5 big maps: a plan view from above plus views from the spawns, lanes and sites.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c5_map_shots.gd -- <out_dir> <map> [view...]

const VIEWS := {
	"folded": {
		"plan": [Vector3(0, 190, 0.01), Vector3(0, 0, 0)],
		"spawn": [Vector3(0, 1.7, 50), Vector3(0, 1.5, 20)],
		"lane_west": [Vector3(-36, 1.7, 47), Vector3(-50, 1.7, 47)],
		"lane_north": [Vector3(-49, 1.7, 48), Vector3(-49, 1.5, 10)],
		"site_a": [Vector3(-48, 2.2, 14), Vector3(-64, 1.0, -4)],
		"a_from_shelf": [Vector3(-72, 4.8, 10), Vector3(-52, 1.0, -6)],
		"short_a": [Vector3(-30, 1.7, -12), Vector3(-60, 1.5, -10)],
		"hall": [Vector3(0, 1.7, 26), Vector3(0, 3, 0)],
	},
	"dream": {
		"plan": [Vector3(0, 190, 0.01), Vector3(0, 0, 0)],
		"spawn": [Vector3(0, 1.7, 48), Vector3(0, 1.5, 20)],
		"corridor": [Vector3(-16, 1.7, 45), Vector3(-46, 1.7, 45)],
		"site_a": [Vector3(-45, 2.2, 14), Vector3(-64, 1.0, -6)],
		"short_a": [Vector3(-26, 1.7, -21), Vector3(-60, 1.5, -18)],
		"house_door": [Vector3(-8, 1.7, 36), Vector3(-8, 1.5, 10)],
	},
	"yard": {
		"plan": [Vector3(0, 220, 0.01), Vector3(0, 0, 0)],
		"spawn": [Vector3(0, 1.7, 55), Vector3(-9, 1.5, 24)],
		"mid": [Vector3(-9, 1.7, 26), Vector3(0, 2, 0)],
		"mid_crane": [Vector3(2, 4.0, 6), Vector3(-30, 1.5, -3)],
		"a_long": [Vector3(-56, 1.7, 54), Vector3(-56, 1.5, 10)],
		"site_a": [Vector3(-50, 2.2, 16), Vector3(-72, 1.0, -6)],
		"a_gantry": [Vector3(-82.5, 5.2, -14), Vector3(-56, 1.0, 10)],
		"office": [Vector3(-30, 1.7, 39), Vector3(-41, 1.5, 29)],
		"tunnel": [Vector3(20, 1.7, 49), Vector3(54, 1.5, 49)],
	},
	"testament": {
		"plan": [Vector3(0, 190, 0.01), Vector3(0, 0, 0)],
		"spawn": [Vector3(0, 1.7, 45), Vector3(-8, 1.5, 32)],
		"confessionals": [Vector3(24, 1.7, 23), Vector3(-24, 1.5, 23)],
		"nave": [Vector3(-34, 1.7, -2), Vector3(40, 2.5, 0)],
		"from_dais": [Vector3(66, 2.9, 0), Vector3(-30, 2.5, 0)],
		"aisle": [Vector3(38, 1.7, 14), Vector3(-40, 2.5, 14)],
		"gallery": [Vector3(27, 6.7, 18), Vector3(-40, 5.5, 15)],
		"loft": [Vector3(-46, 6.7, 12), Vector3(30, 2.0, -4)],
		"organ_room": [Vector3(-53, 1.7, 13), Vector3(-70, 3.0, -4)],
		"trench": [Vector3(-34, 1.9, 0), Vector3(-50, -3.0, 0)],
		"crypt": [Vector3(-50, -2.8, 1), Vector3(-72, -3.5, -6)],
		"lane_ramp": [Vector3(-61, 1.7, 42), Vector3(-61, -3.0, 16)],
		"site_a": [Vector3(46, 1.7, 13), Vector3(66, 1.0, 0)],
		# Phase 5: the words and the eggs, close up.
		"tablet": [Vector3(66, 2.9, 1.5), Vector3(73, 4.5, 0)],
		"tablet_back": [Vector3(73.5, 1.7, 5.5), Vector3(72.8, 2.4, 0)],
		"slogan": [Vector3(-8, 1.7, 23.5), Vector3(-8, 2.2, 21)],
		"egg_a": [Vector3(-40, 1.7, 43), Vector3(-52, 1.2, 38)],
		"egg_b": [Vector3(-1.2, 1.7, 26.4), Vector3(-0.2, 1.0, 27.4)],
		"egg_c": [Vector3(-46.3, 6.6, 18.4), Vector3(-48, 6.2, 19.2)],
		"egg_d": [Vector3(-14.2, 5.6, 16.2), Vector3(-14.6, 5.2, 19.4)],
		"egg_e": [Vector3(-69.6, -2.5, 0.8), Vector3(-70.3, -3.9, 3.0)],
		"egg_f_front": [Vector3(1, 6.5, 2), Vector3(1, 9.8, 11.7)],
		"egg_f_side": [Vector3(-3.5, 9.6, 10.2), Vector3(1, 9.8, 11.7)],
		"signs": [Vector3(30, 1.7, 15), Vector3(36, 3.8, 20)],
	},
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var id: String = args[1] if args.size() > 1 else "folded"
	var map: Node3D
	match id:
		"dream": map = DreamHome.new()
		_: map = FoldedWorks.new()
	if id == "testament":
		map = LastTestament.new()
	if id == "yard":
		map = load("res://scripts/maps/fault_yard.gd").new()
	root.add_child(map)
	var layout: Layout = map.get("layout")
	if layout != null:
		print(layout.draw())
	var cam := Camera3D.new()
	cam.fov = 80
	cam.far = 600
	root.add_child(cam)
	var views: Dictionary = VIEWS.get(id, {})
	for view in views:
		if args.size() > 2 and not view in args.slice(2):
			continue
		if view == "plan":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 190.0 if id != "yard" else 220.0
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.look_at_from_position(views[view][0], views[view][1], Vector3.UP if view != "plan" else Vector3(0, 0, -1))
		cam.make_current()
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, id, view])
	quit()
