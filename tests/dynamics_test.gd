extends SceneTree
## The maps' moving parts (C12, MapDynamics), on all four big maps in practice: every map
## gets doors, two groups of blast gates, a pair of lifts and breakable cover, all in twin
## pairs; no gate phase ever cuts a spawn off a site; doors open and break; gates swap on
## the timer and push people clear; lifts carry you up; cover breaks and a new round puts
## it all back.
##   godot --headless --path . --script res://tests/dynamics_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	for id in ["folded", "dream", "yard", "testament"]:
		await _map(id)
	print("DYNAMICS TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func main() -> Main:
	return root.get_node_or_null("Main") as Main


func _until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _map(id: String) -> void:
	print(id)
	Main.map_id = id
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await _until(func() -> bool: return main() != null and main().is_node_ready() and main().map_id == id, 8.0)
	var m := main()
	m._start()
	await _wait(0.3)
	for b in m.bots:
		b.passive = true
		b.frozen = true
	var d := m.dynamics
	check(d != null, "%s: the map has moving parts" % id)
	if d == null:
		return
	var groups := {}
	for s in d.shutters:
		groups[s.group] = true
	check(d.doors.size() >= 2 and d.doors.size() % 2 == 0, "%s: doors in twin pairs (%d)" % [id, d.doors.size()])
	check(d.shutters.size() >= 2 and d.shutters.size() % 2 == 0, "%s: blast gates in twin pairs (%d, %d group(s))" % [id, d.shutters.size(), groups.size()])
	check(d.lifts.size() == 2, "%s: a pair of lifts" % id)
	check(d.covers.size() == 8, "%s: four pairs of breakable cover" % id)
	var twins_ok := true
	var l: Layout = m.map.layout
	for list in [d.doors, d.covers, d.lifts]:
		for i in range(0, list.size(), 2):
			var a: Vector3 = list[i].position
			var b: Vector3 = list[i + 1].position
			if l.twin(a).distance_to(b) > 0.5:
				twins_ok = false
	check(twins_ok, "%s: every part has its twin on the other half" % id)
	_paths(m, d, id)
	await _doors(m, d, id)
	await _cover(m, d, id)
	await _shutters(m, d, id)
	await _lift(m, d, id)
	_reset(m, d, id)


## In each gate phase, both spawns still reach both sites and the middle.
func _paths(m: Main, d: MapDynamics, id: String) -> void:
	var l: Layout = m.map.layout
	var spots := [m.map.bomb_sites[0], m.map.bomb_sites[1], m.map.mid_zone if m.map.mid_zone.y > -1.0 else Vector3.ZERO]
	for ph in 2:
		d.phase = ph
		d._apply_phase(true)
		var ok := true
		for team in 2:
			for s in spots:
				if l.path(m.map.team_zones[team], s).is_empty():
					ok = false
		check(ok, "%s: phase %d leaves every spawn a way to both sites and the middle" % [id, ph])
	d.phase = 0
	d._apply_phase(true)


func _doors(m: Main, d: MapDynamics, id: String) -> void:
	var door: MapDoor = d.doors[0]
	check(not door.open and door._area.collision_layer != 0, "%s: doors start shut (and stop shots)" % id)
	var p := m.player
	# Stand in front of it, face it, press E.
	var front := door.to_global(Vector3(0, 0, 1.6))
	p.spawn_at(Transform3D(Basis.IDENTITY, front + Vector3(0, 0.1, 0)))
	var to := door.global_position - front
	p.rotation.y = atan2(-to.x, -to.z)
	p._pitch = 0.0
	await _wait(0.1)
	check(d.door_for(p) == door, "%s: E works the door you face" % id)
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	await _wait(0.5)
	check(door.open and door._k > 0.99 and door._area.collision_layer == 0, "%s: E opens it" % id)
	# Shut it on someone standing in the doorway: they're pushed clear.
	p.global_position = door.global_position + Vector3(0, 0.1, 0)
	door.toggle()
	await _wait(0.5)
	var lp := door.to_local(p.global_position)
	check(not door.open and absf(lp.z) >= 0.5, "%s: shutting it nudges you out of the doorway (%.2f m)" % [id, lp.z])
	# Shot to pieces: open for good.
	Deploy.event(door.uid, "hit", MapDoor.HP + 1.0)
	await _wait(0.5)
	check(door.broken and door._leaves[0].collision_layer == 0, "%s: enough damage tears it off" % id)
	# A bot walks up to a shut door: it opens.
	var other: MapDoor = d.doors[1]
	var b: Bot = m.bots[0]
	b.frozen = false
	b.global_position = other.to_global(Vector3(0, 0.1, 1.5))
	await _wait(0.6)
	check(other.open, "%s: bots open doors they walk up to" % id)
	b.frozen = true
	p.spawn_at(m.map.player_spawn)


func _cover(m: Main, d: MapDynamics, id: String) -> void:
	var c: MapCover = d.covers[0]
	var l: Layout = m.map.layout
	var g := l.cell_of(c.global_position)
	check(l.at(g.x, g.y) == "c" and c.collision_layer == Geo.WORLD, "%s: cover stands (low cover for bots)" % id)
	Deploy.event(c.uid, "hit", 150.0)
	await physics_frame
	check(not c.broken and c.hp < MapCover.HP, "%s: cover takes a beating" % id)
	# A frag next to it finishes it.
	var p := m.player
	Deploy.spawn("throw", p, {"kind": "frag", "from": c.global_position + Vector3(0, 1.6, 1.0), "vel": Vector3.ZERO, "fuse": 0.05})
	await _wait(0.4)
	check(c.broken and c.collision_layer == 0 and l.at(g.x, g.y) != "c", "%s: a frag breaks it (and the cell opens)" % id)


func _shutters(m: Main, d: MapDynamics, id: String) -> void:
	var l: Layout = m.map.layout
	var shut: Array = d.shutters.filter(func(s: MapShutter) -> bool: return s.closed)
	var open: Array = d.shutters.filter(func(s: MapShutter) -> bool: return not s.closed)
	check(not shut.is_empty() and shut[0].k > 0.99 and l.at(shut[0].cells[0].x, shut[0].cells[0].y) == "#",
		"%s: phase 0: group 0's gates stand (rock for bots)" % id)
	if open.is_empty():
		check(true, "%s: (one gate group only)" % id)
	# Stand under a gate that's about to shut.
	var p := m.player
	var target: MapShutter = open[0] if not open.is_empty() else shut[0]
	if not open.is_empty():
		p.spawn_at(Transform3D(Basis.IDENTITY, target.global_position + Vector3(0, 0.1, 0)))
	d.next_in = MapDynamics.WARN - 0.1
	await _wait(0.2)
	check(d._warned and target._warn, "%s: the lamps warn before a change" % id)
	d.next_in = 0.05
	await _wait(0.2)
	check(d.phase == 1, "%s: the timer swaps the gate groups" % id)
	await _wait(MapShutter.MOVE + 0.4)
	check(shut[0].k < 0.01 and not shut[0].closed and l.at(shut[0].cells[0].x, shut[0].cells[0].y) != "#", "%s: the shut ones sink into the floor" % id)
	if not open.is_empty():
		check(target.k > 0.99, "%s: the open ones rise" % id)
		var lp := target.to_local(p.global_position)
		check(absf(lp.z) > MapShutter.THICK / 2.0, "%s: someone under a rising gate is pushed clear (%.2f m)" % [id, lp.z])
	p.spawn_at(m.map.player_spawn)


func _lift(m: Main, d: MapDynamics, id: String) -> void:
	var lift: MapLift = d.lifts[0]
	d.lift_clock = 0.5
	await _wait(0.1)
	var p := m.player
	p.spawn_at(Transform3D(Basis.IDENTITY, lift.global_position + Vector3(0, 0.3, 0)))
	await _wait(0.3)
	d.lift_clock = MapLift.DOWN - 0.2
	await _wait(MapLift.RISE + 0.6)
	check(lift.top() > MapLift.HIGH - 0.1, "%s: the lift rises (%.1f m)" % [id, lift.top()])
	check(p.global_position.y > MapLift.HIGH - 0.5 and p.is_on_floor(), "%s: and carries you up (%.1f m)" % [id, p.global_position.y])
	p.spawn_at(m.map.player_spawn)


func _reset(m: Main, d: MapDynamics, id: String) -> void:
	Deploy.reset_round()
	var kept := (d.lifts + d.shutters + d.doors + d.covers).all(func(x: Node) -> bool: return is_instance_valid(x) and not x.is_queued_for_deletion())
	check(kept, "%s: a new round keeps every part (none freed)" % id)
	var whole := d.covers.all(func(c: MapCover) -> bool: return not c.broken and c.hp == MapCover.HP)
	var doors := d.doors.all(func(x: MapDoor) -> bool: return not x.open and not x.broken)
	check(whole and doors and d.phase == 0 and d.next_in == MapDynamics.SHIFT_EVERY, "%s: a new round puts it all back" % id)
	var groups_ok := d.shutters.all(func(s: MapShutter) -> bool: return s.closed == (s.group == 0))
	check(groups_ok, "%s: ... gates back to phase 0" % id)
