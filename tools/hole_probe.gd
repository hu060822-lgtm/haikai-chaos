extends SceneTree
## Looks for holes in a map's floor: every column over the play area, 0.5 m apart, cast
## from high above straight down. A column that meets nothing (or only meets something
## far below the floor) is a hole you could fall through.
##   godot --headless --path . --script res://tools/hole_probe.gd -- <folded|dream|yard>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "folded"
	var map: Node3D
	match id:
		"dream": map = DreamHome.new()
		"yard": map = FaultYard.new()
		_: map = FoldedWorks.new()
	root.add_child(map)
	current_scene = map
	for i in 4:
		await physics_frame
	var area: Rect2 = map.get("play_area")
	var low := float(map.get("lowest_floor"))
	var space := map.get_world_3d().direct_space_state
	var holes := []
	var step := float(args[1]) if args.size() > 1 else 0.5
	var x := area.position.x + step / 2.0
	while x < area.end.x:
		var z := area.position.y + step / 2.0
		while z < area.end.y:
			# Standing room just above floor level with nothing under it is a hole.
			var pq := PhysicsPointQueryParameters3D.new()
			pq.position = Vector3(x, 0.3, z)
			pq.collision_mask = Geo.WORLD
			if space.intersect_point(pq, 1).is_empty():
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, 0.3, z), Vector3(x, low - 8.0, z), Geo.WORLD)
				var hit := space.intersect_ray(q)
				if hit.is_empty() or hit.position.y < low - 0.5:
					holes.append(Vector2(x, z))
			z += step
		x += step
	print("%s area %s lowest %.1f holes %d" % [id, area, low, holes.size()])
	var l: Layout = map.get("layout")
	var seen := {}
	for h: Vector2 in holes:
		var key := Vector2i(int(floor(h.x / 2.0)), int(floor(h.y / 2.0)))
		if seen.has(key):
			seen[key] += 1
			continue
		seen[key] = 1
	for k in seen:
		var c := l.cell_of(Vector3(k.x * 2.0 + 1.0, 0, k.y * 2.0 + 1.0)) if l != null else Vector2i.ZERO
		print("  hole near (%d, %d) x%d  cell %s '%s'" % [k.x * 2, k.y * 2, seen[k], c, l.at(c.x, c.y) if l != null else "?"])
	# The outer wall: rays from just inside the play area outward at several heights.
	var leaks := 0
	for h in [0.4, 1.2, 2.5, 5.0, 9.0, 15.0, 25.0, 38.0]:
		for side in 4:
			var n := int((area.size.x if side < 2 else area.size.y) / 0.25)
			for i in n:
				var t := area.position.x + i * 0.25 if side < 2 else area.position.y + i * 0.25
				var a: Vector3
				var b: Vector3
				match side:
					0: a = Vector3(t, h, area.position.y + 6.0); b = Vector3(t, h, area.position.y - 6.0)
					1: a = Vector3(t, h, area.end.y - 6.0); b = Vector3(t, h, area.end.y + 6.0)
					2: a = Vector3(area.position.x + 6.0, h, t); b = Vector3(area.position.x - 6.0, h, t)
					_: a = Vector3(area.end.x - 6.0, h, t); b = Vector3(area.end.x + 6.0, h, t)
				var q2 := PhysicsRayQueryParameters3D.create(a, b, Geo.WORLD | Geo.BOUNDS)
				if space.intersect_ray(q2).is_empty():
					leaks += 1
					if leaks < 12:
						print("  edge leak side %d at %.2f h %.1f" % [side, t, h])
	print("%s edge leaks %d" % [id, leaks])
	quit()
