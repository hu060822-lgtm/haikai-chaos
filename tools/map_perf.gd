extends SceneTree
## Map render cost, measured: build time, nodes, draw calls, primitives and frame times from
## a few real viewpoints, for each map named, so a new map can be held against the ones
## already shipped. Run it with a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/map_perf.gd -- testament folded yard dream
## Under xvfb the GPU is Mesa's software rasteriser, so frame times are only comparable
## between maps on the same machine; draw calls and primitives are exact anywhere.

const WARM := 8
const MEASURE := 40
## Testament's own viewpoints: the busiest views in the church.
const TESTAMENT_VIEWS := {
	"spawn": [Vector3(0, 1.7, 45), Vector3(-8, 1.5, 32)],
	"nave": [Vector3(-34, 1.7, -2), Vector3(40, 2.5, 0)],
	"from_dais": [Vector3(66, 2.9, 0), Vector3(-30, 2.5, 0)],
	"gallery": [Vector3(27, 6.7, 18), Vector3(-40, 5.5, 15)],
	"loft": [Vector3(-46, 6.7, 12), Vector3(30, 2.0, -4)],
	"crypt": [Vector3(-50, -2.8, 1), Vector3(-72, -3.5, -6)],
}


func _make(id: String) -> Node3D:
	match id:
		"testament": return LastTestament.new()
		"yard": return FaultYard.new()
		"dream": return DreamHome.new()
	return FoldedWorks.new()


func _views(id: String, map: Node3D) -> Dictionary:
	if id == "testament":
		return TESTAMENT_VIEWS
	var spawn: Vector3 = (map.get("player_spawn") as Transform3D).origin + Vector3(0, 1.7, 0)
	var mid := Vector3(0, 1.7, 0)
	return {"spawn": [spawn, mid], "mid_x": [mid, mid + Vector3(40, 0, 0)], "mid_-x": [mid, mid - Vector3(40, 0, 0)],
		"mid_z": [mid, mid + Vector3(0, 0, 40)]}


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PackedStringArray(["testament"])
	await process_frame
	print("map        view        draw calls  objects  primitives   avg ms   p95 ms")
	for id in ids:
		var t0 := Time.get_ticks_usec()
		var map := _make(id)
		root.add_child(map)
		var built := (Time.get_ticks_usec() - t0) / 1000.0
		var nodes := _count(map)
		var cam := Camera3D.new()
		cam.fov = 80
		cam.far = 600
		root.add_child(cam)
		cam.make_current()
		var views := _views(id, map)
		var worst := 0.0
		var all := 0.0
		for view in views:
			cam.look_at_from_position(views[view][0], views[view][1], Vector3.UP)
			for i in WARM:
				await process_frame
			var times := []
			var calls := 0
			var objects := 0
			var prims := 0
			var last := Time.get_ticks_usec()
			for i in MEASURE:
				await process_frame
				var now := Time.get_ticks_usec()
				times.append((now - last) / 1000.0)
				last = now
				calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
				objects = maxi(objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
				prims = maxi(prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			times.sort()
			var avg: float = times.reduce(func(a, b): return a + b, 0.0) / times.size()
			var p95: float = times[int(times.size() * 0.95)]
			worst = maxf(worst, p95)
			all += avg
			print("%-10s %-11s %10d %8d %11d %8.1f %8.1f" % [id, view, calls, objects, prims, avg, p95])
		print("%-10s built in %.0f ms, %d nodes, %.1f MB video memory; mean %.1f ms, worst p95 %.1f ms" % [id, built, nodes,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, all / views.size(), worst])
		cam.queue_free()
		map.queue_free()
		await process_frame
		await process_frame
	quit()


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c
