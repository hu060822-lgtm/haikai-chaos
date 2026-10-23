extends SceneTree
## C5's big maps: every map is large, every spawn has a way to every bomb site and to the
## middle, a bot finds its own way from its spawn to a site, and nobody stays out of
## bounds (MapGuard).
##   godot --headless --path . --script res://tests/maps_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	Engine.time_scale = 4.0
	for id in ["folded", "dream", "yard", "testament"]:
		await _map(id)
	Engine.time_scale = 1.0
	print("MAPS TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _make(id: String) -> Node3D:
	match id:
		"dream": return DreamHome.new()
		"yard": return FaultYard.new()
		"testament": return LastTestament.new()
	return FoldedWorks.new()


func _length(points: Array, from: Vector3) -> float:
	var d := 0.0
	var at := from
	for p in points:
		d += Vector2(at.x, at.z).distance_to(Vector2(p.x, p.z))
		at = p
	return d


func _map(id: String) -> void:
	print(id)
	var map: Node3D = _make(id)
	root.add_child(map)
	var guard := MapGuard.new(map)
	root.add_child(guard)
	await process_frame
	var g: Layout = map.layout
	var area: Rect2 = map.play_area
	check(area.size.x >= 140.0 and area.size.y >= 95.0, "%.0f × %.0f m" % [area.size.x, area.size.y])
	var spots := {"mid": map.mid_zone if map.mid_zone.y > -1.0 else Vector3(0, 0, 0)}
	spots.A = map.bomb_sites[0]
	spots.B = map.bomb_sites[1]
	for team in 2:
		var from: Vector3 = map.team_zones[team]
		check(g.walkable(g.cell_of(from).x, g.cell_of(from).y), "team %d's spawn is open floor" % team)
		for name in spots:
			var path := g.path(from, spots[name])
			var straight := Vector2(from.x, from.z).distance_to(Vector2(spots[name].x, spots[name].z))
			check(not path.is_empty() and _length(path, from) < straight * 2.2 + 20.0,
				"team %d spawn -> %s: %.0f m (straight %.0f m)" % [team, name, _length(path, from) if not path.is_empty() else -1.0, straight])
	# More than one way: block the shortest way to A and there's still another.
	var from0: Vector3 = map.team_zones[0]
	var first := g.path(from0, spots.A)
	if first.size() >= 2:
		var cut := g.cell_of(first[first.size() / 2])
		for r in range(cut.y - 2, cut.y + 3):
			for c in range(cut.x - 2, cut.x + 3):
				if g.walkable(c, r):
					g.set_cell(c, r, "o")
		check(not g.path(from0, spots.A).is_empty(), "with the shortest way to A blocked there's still another")
	# A bot walks from blue's spawn to site A on its own.
	map.queue_free()
	await process_frame
	map = _make(id)
	root.add_child(map)
	guard.map = map
	await process_frame
	var bot := Bot.new()
	bot.passive = true
	bot.waypoints = map.waypoints
	bot.nav = map.layout
	root.add_child(bot)
	bot.spawn(map.team_spawns[0][0], 7)
	bot.objective = map.bomb_sites[0]
	var start := Time.get_ticks_msec()
	var reached := false
	while Time.get_ticks_msec() - start < 30000:
		await physics_frame
		if Vector2(bot.global_position.x, bot.global_position.z).distance_to(Vector2(bot.objective.x, bot.objective.z)) < 3.0:
			reached = true
			break
	check(reached, "a bot walks from blue's spawn to site A (at %s)" % str(bot.global_position.snapped(Vector3.ONE)))
	# Out of bounds: under the floor, and outside the walls.
	bot.objective = Vector3.INF
	bot.frozen = true
	await create_timer(0.6).timeout
	var good := bot.global_position
	bot.global_position = Vector3(good.x, -30.0, good.z)
	await physics_frame
	await physics_frame
	check(bot.global_position.y > -1.0, "fallen under the map: pulled back up (y %.1f)" % bot.global_position.y)
	bot.global_position = Vector3(area.end.x + 10.0, 2.0, 0.0)
	await physics_frame
	await physics_frame
	check(area.has_point(Vector2(bot.global_position.x, bot.global_position.z)), "outside the walls: pulled back in")
	bot.queue_free()
	guard.queue_free()
	map.queue_free()
	await process_frame
