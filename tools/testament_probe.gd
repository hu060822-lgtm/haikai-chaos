extends SceneTree
## Prints THE LAST TESTAMENT's floor plan, its gaps, and paths between its spots.
##   godot --headless --path . --script res://tools/testament_probe.gd

func _init() -> void:
	var m := LastTestament.new()
	root.add_child(m)
	await process_frame
	await physics_frame
	var l: Layout = m.layout
	print(l.draw())
	print("passages %d windows %d ledges %d breaches %d props %d" % [l.passages.size(), l.windows.size(), l.ledges.size(), l.breaches.size(), m.get_node("Props").get_child_count()])
	for team in 2:
		for to in [m.mid_zone, m.bomb_sites[0], m.bomb_sites[1], Vector3(0, 5, 17 * (1 - 2 * team))]:
			var p := l.path(m.team_zones[team], to)
			var d := 0.0
			var at: Vector3 = m.team_zones[team]
			for q in p:
				d += at.distance_to(q)
				at = q
			print("team %d -> %s: %d points, %.1f m" % [team, str(to), p.size(), d])
	print(l.path(m.team_zones[0], m.bomb_sites[1]))
	quit()
