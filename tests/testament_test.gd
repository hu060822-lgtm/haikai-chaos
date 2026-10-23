extends SceneTree
## 最後的遺訓 THE LAST TESTAMENT, Phase 2 (C10): the graybox is fair (mirrored, the same
## way to everything from both spawns), nobody can get stuck anywhere, no spawn sees the
## other, the real player gets up and down every floor, and bots walk every floor too.
## Phase 5: every word and egg from the design book is there, all of it static, the hum is
## quiet, and nothing of it sits on a spawn or a site.
##   godot --headless --path . --script res://tests/testament_test.gd

var map: LastTestament
var l: Layout
var failures := 0


func _init() -> void:
	InputSetup.register()
	map = LastTestament.new()
	root.add_child(map)
	current_scene = map
	await physics_frame
	await physics_frame
	l = map.layout
	_test_mirror()
	_test_floors()
	_test_sightlines()
	_test_dressing()
	await _test_player()
	await _test_bots()
	print("TESTAMENT TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _length(points: Array, from: Vector3) -> float:
	var d := 0.0
	var at := from
	for p in points:
		d += at.distance_to(p)
		at = p
	return d


func _test_mirror() -> void:
	print("fairness")
	var same := true
	for r in l.rows:
		for c in l.cols:
			if l.at(c, r) != l.at(c, l.rows - 1 - r) or l.height(0, Vector2i(c, r)) != l.height(0, Vector2i(c, l.rows - 1 - r)):
				same = false
	check(same, "the floor plan is mirrored north–south, heights too")
	var spots := {"mid": map.mid_zone, "A": map.bomb_sites[0], "B": map.bomb_sites[1]}
	# The spots sit on the centre line, between two rows of cells: each team aims at its own
	# side of it (the same point mirrored), or the search breaks near-ties differently.
	for name in spots:
		var near: Vector3 = spots[name] + Vector3(0, 0, 0.5)
		var d0 := _length(l.path(map.team_zones[0], near), map.team_zones[0])
		var d1 := _length(l.path(map.team_zones[1], l.twin(near)), map.team_zones[1])
		check(d0 > 0.0 and absf(d0 - d1) < 0.5, "spawn -> %s: blue %.1f m, red %.1f m" % [name, d0, d1])
	var g0 := _length(l.path(map.team_zones[0], Vector3(0, LastTestament.GALLERY_Y, 17)), map.team_zones[0])
	var g1 := _length(l.path(map.team_zones[1], Vector3(0, LastTestament.GALLERY_Y, -17)), map.team_zones[1])
	check(g0 > 0.0 and absf(g0 - g1) < 0.5, "spawn -> own gallery: blue %.1f m, red %.1f m" % [g0, g1])


## Every open cell on every floor has a way back to a spawn (no pit to get stuck in), and
## every floor has more than one way on and off.
func _test_floors() -> void:
	print("floors")
	var per := l.cols * l.rows
	var back := {}   # node -> nodes that link into it
	for a in l.links:
		for e in l.links[a]:
			back[e[0]] = back.get(e[0], []) + [a]
	var start := l._node(0, l.cell_of(map.team_zones[0]))
	var seen := {start: true}
	var front: Array = [start]
	while not front.is_empty():
		var next := []
		for nd in front:
			var level: int = nd / per
			var ci: int = nd % per
			var cur := Vector2i(ci % l.cols, ci / l.cols)
			for d in Layout.DIRS:
				var n: Vector2i = cur + d
				if not l.open_on(level, n) or not l._step_ok(level, cur, n):
					continue
				if d.x != 0 and d.y != 0 and (not l.open_on(level, Vector2i(cur.x + d.x, cur.y)) or not l.open_on(level, Vector2i(cur.x, cur.y + d.y))):
					continue
				var nn := l._node(level, n)
				if not seen.has(nn):
					seen[nn] = true
					next.append(nn)
			for nn in back.get(nd, []):
				if not seen.has(nn):
					seen[nn] = true
					next.append(nn)
		front = next
	var stuck := []
	var count := [0, 0, 0]
	for level in l.decks.size() + 1:
		for r in l.rows:
			for c in l.cols:
				if l.open_on(level, Vector2i(c, r)):
					count[level] += 1
					if not seen.has(l._node(level, Vector2i(c, r))):
						stuck.append([level, l.centre(c, r, l.height(level, Vector2i(c, r)))])
	check(stuck.is_empty(), "every open cell on every floor has a way back to spawn (%d stuck: %s)" % [stuck.size(), str(stuck.slice(0, 4))])
	check(count[map.gallery] > 60 and count[map.crypt] > 60, "the gallery has %d cells, the crypt %d" % [count[map.gallery], count[map.crypt]])
	var ways := [0, 0, 0]
	for a in l.links:
		ways[a / per] += 1
	check(ways[map.gallery] >= 6 and ways[map.crypt] >= 4, "ways off the galleries: %d, out of the crypt: %d" % [ways[map.gallery], ways[map.crypt]])


func _labels(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Label3D:
			out.append((c as Label3D).text)
		_labels(c, out)


func _scripted(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c.get_script() != null or c is Area3D or c is RigidBody3D:
			out.append(c.name)
		_scripted(c, out)


func _test_dressing() -> void:
	print("words and eggs")
	var texts := []
	_labels(map, texts)
	var all := "\n".join(texts).replace("\n", " ")
	for want in ["CONFESS YOUR BUILD.", "NO ATTACHMENT IS INNOCENT.", "YOUR RECOIL HAS BEEN NOTED.", "THE SAINT OF RECOIL",
			"BLESSED ARE THE FLEXIBLE.", "FOR THEY SHALL NOT BE PREDICTABLE.", "KEEP YOUR MOMENTUM.", "APPROVED BY NO ONE.",
			"TIME IS A SUGGESTION.", "PLAYER NOT FOUND.", "HERE LIES THE PERFECT BUILD.", "BUILD SHEET"]:
		check(want in all, "on the walls: %s" % want)
	var signs := 0
	for t in texts:
		if "CONFESSIONALS" in t or "GALLERY" in t or "ALTAR" in t or "ORGAN" in t or "CRYPT" in t:
			signs += 1
	check(signs >= 10, "%d area signs (confessionals, gallery, altar, organ, crypt, both sides)" % signs)
	var moving := []
	for n in ["EasterEggs", "Signs", "StainedGlass", "CentralHall"]:
		_scripted(map.get_node(n), moving)
	check(moving.is_empty(), "the eggs and the art are static: no scripts, areas or bodies that move (%s)" % str(moving))
	var hums := 0
	var loud := 0
	for c in map.get_children():
		if c is AudioStreamPlayer3D and str(c.name).begins_with("OrganHum"):
			hums += 1
			if (c as AudioStreamPlayer3D).volume_db > -20.0:
				loud += 1
	check(hums >= 1 and loud == 0, "the organ hums (%d sources), quieter than the quietest footstep" % hums)
	# Nothing new stands on a spawn or a bomb site.
	var space := map.get_world_3d().direct_space_state
	var blocked := []
	var spots: Array = map.team_spawns[0] + map.team_spawns[1] + map.bomb_sites
	for p in spots:
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		q.shape = cap
		q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, p.y + 1.1, p.z))
		q.collision_mask = Geo.WORLD
		if not space.intersect_shape(q, 1).is_empty():
			blocked.append(p)
	check(blocked.is_empty(), "every spawn and both sites stay clear (%s)" % str(blocked))


func _sees(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Geo.WORLD)
	return map.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Points over a rect, every `step` metres, at height y.
func _grid(r: Rect2, y: float, step := 2.0) -> Array:
	var out := []
	var x := r.position.x + 1.0
	while x < r.end.x:
		var z := r.position.y + 1.0
		while z < r.end.y:
			out.append(Vector3(x, y, z))
			z += step
		x += step
	return out


func _test_sightlines() -> void:
	print("sightlines")
	var spawn := [Rect2(-14, 36, 28, 10), Rect2(-14, -46, 28, 10)]
	var seen := 0
	for a in _grid(spawn[0], 1.6):
		for b in _grid(spawn[1], 1.2):
			if _sees(a, b):
				seen += 1
	check(seen == 0, "neither spawn sees into the other (%d lines)" % seen)
	var perches := {
		"the altar dais": _grid(LastTestament.DAIS, LastTestament.DAIS_Y + 1.6, 2.0),
		"the galleries": _grid(LastTestament.GALLERY, LastTestament.GALLERY_Y + 1.6, 4.0) + _grid(l.turned(LastTestament.GALLERY), LastTestament.GALLERY_Y + 1.6, 4.0),
		"the organ loft": _grid(LastTestament.LOFT, LastTestament.GALLERY_Y + 1.6, 4.0),
	}
	for name in perches:
		var n := 0
		for a in perches[name]:
			for s in spawn:
				for b in _grid(s, 1.2, 4.0):
					if _sees(a, b):
						n += 1
		check(n == 0, "%s can't see into either spawn (%d lines)" % [name, n])
	# No perch rules the map: nowhere sees both sites, and the dais sees only part of the nave.
	var both := []
	for level in l.decks.size() + 1:
		for r in range(0, l.rows, 2):
			for c in range(0, l.cols, 2):
				var g := Vector2i(c, r)
				if not l.open_on(level, g):
					continue
				var eye := l.centre(c, r, l.height(level, g) + 1.6)
				if _sees_site(eye, 0) and _sees_site(eye, 1):
					both.append(eye)
	check(both.is_empty(), "no spot on any floor sees both sites (%s)" % str(both.slice(0, 3)))
	var nave := _grid(Rect2(-36, -12, 76, 24), 1.2)
	var from_dais := Vector3(64, LastTestament.DAIS_Y + 1.6, 0)
	var seen_n := nave.filter(func(p: Vector3) -> bool: return _sees(from_dais, p)).size()
	check(seen_n < nave.size() * 0.6, "the top of the dais sees %d%% of the nave floor" % (100 * seen_n / nave.size()))


func _sees_site(eye: Vector3, i: int) -> bool:
	var site: Vector3 = map.bomb_sites[i]
	for off in [Vector3.ZERO, Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]:
		if _sees(eye, site + off + Vector3(0, 1.0, 0)):
			return true
	return false


# --- The real player on fixed routes ---------------------------------------------------

var player: Player


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch"]:
		Input.action_release(a)


func _face(to: Vector3) -> void:
	var d := to - player.global_position
	player.rotation.y = atan2(-d.x, -d.z)


## Runs to each point in turn (flat distance under `near`), sprinting; false if it takes
## longer than `limit` seconds for any of them.
func _run(points: Array, limit := 8.0, near := 1.2) -> bool:
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for p in points:
		var t := 0.0
		while Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > near:
			_face(p)
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			if t > limit:
				print("    stuck on the way to %s at %s" % [str(p), str(player.global_position.snapped(Vector3.ONE * 0.1))])
				release_all()
				return false
	release_all()
	return true


func _place(at: Vector3) -> void:
	release_all()
	player.spawn_at(Transform3D(Basis.IDENTITY, at))
	player.velocity = Vector3.ZERO
	await frames(4)


func _test_player() -> void:
	print("player routes")
	player = Player.new()
	map.add_child(player)
	player.input_enabled = true
	await frames(2)
	var hp := player.health
	# Up the east ramp onto the gallery, along it, down through a gap in the railing.
	await _place(Vector3(39, 0.1, 13))
	var ok := await _run([Vector3(39.5, 0, 18), Vector3(27, 0, 18)])
	check(ok and player.global_position.y > LastTestament.GALLERY_Y - 0.2, "up the ramp onto the gallery (y %.1f)" % player.global_position.y)
	ok = await _run([Vector3(-25, 0, 17)], 12.0)
	check(ok and player.global_position.y > LastTestament.GALLERY_Y - 0.2, "along the gallery to the west end")
	ok = await _run([Vector3(-25, 0, 9)], 4.0)
	for i in 120:
		await physics_frame
		if player.is_on_floor():
			break
	if player.global_position.y > 0.5:
		print("    landed at %s (%s)" % [str(player.global_position.snapped(Vector3.ONE * 0.1)), Player.MOVE_NAMES[player.move]])
	check(ok and player.global_position.y < 0.5 and player.health >= hp, "jump down through the railing gap into the nave (y %.1f, health %d)" % [player.global_position.y, player.health])
	# Through the organ loft to the other gallery and back down its ramp.
	await _place(Vector3(-30, LastTestament.GALLERY_Y + 0.1, 17))
	ok = await _run([Vector3(-43, 0, 12), Vector3(-43, 0, -16), Vector3(26, 0, -18), Vector3(39.5, 0, -18)], 12.0)
	check(ok and player.global_position.y < 0.5, "across the organ loft to the north gallery, down its ramp")
	# Down the trench stair into the crypt, out by the south ramp to the lane.
	await _place(Vector3(-30, 0.1, 0))
	ok = await _run([Vector3(-36, 0, 0), Vector3(-50, 0, 0), Vector3(-55, 0, 4.5), Vector3(-62, 0, 4.5), Vector3(-58.5, 0, 10), Vector3(-59.5, 0, 17), Vector3(-61, 0, 21), Vector3(-61, 0, 34)])
	check(ok and player.global_position.y > -0.3, "down the trench into the crypt and up the lane ramp (y %.1f)" % player.global_position.y)
	# Up the pulpit and over the railing onto the gallery.
	await _place(Vector3(5, 0.1, 8))
	Input.action_press("move_forward")
	var top := 0.0
	var held := 0
	for i in 150:
		player.rotation.y = PI   # facing +z
		# Jump at the pulpit, and again (held: climbing the sounding board) once on it.
		var p := player.global_position
		if held == 0 and player.is_on_floor() and (p.z > 10.0 or p.y > 2.0):
			Input.action_press("jump")
			held = 3 if p.y < 1.0 else 50
		elif held > 0:
			held -= 1
			if held == 0:
				Input.action_release("jump")
		await physics_frame
		top = maxf(top, player.global_position.y)
	release_all()
	check(top > LastTestament.GALLERY_Y - 0.2, "climb the pulpit onto the gallery (highest %.1f m)" % top)
	# A slide down the centre aisle.
	await _place(Vector3(-34, 0.1, 0))
	player.rotation.y = -PI / 2.0   # facing +x
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(70)
	Input.action_press("crouch")
	var low := 99.0
	for i in 40:
		await physics_frame
		low = minf(low, player.flat_speed())
	release_all()
	check(low > 6.0, "slide down the centre aisle without catching on anything (slowest %.1f m/s)" % low)
	player.queue_free()
	await frames(2)


# --- Bots on every floor -----------------------------------------------------------------

func _bot_to(from: Vector3, to: Vector3, limit := 40.0) -> Bot:
	var bot := Bot.new()
	bot.passive = true
	bot.waypoints = map.waypoints
	bot.nav = l
	map.add_child(bot)
	bot.spawn(from, 11)
	bot.objective = to
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < limit * 1000.0 / Engine.time_scale:
		await physics_frame
		var p := bot.global_position
		if Vector2(p.x - to.x, p.z - to.z).length() < 2.5 and absf(p.y - to.y) < 1.0:
			return bot
	print("    bot ended at %s" % str(bot.global_position.snapped(Vector3.ONE * 0.1)))
	bot.queue_free()
	return null


func _test_bots() -> void:
	print("bots")
	Engine.time_scale = 4.0
	var y := LastTestament.GALLERY_Y
	var gal := 0
	var low := 0
	for p in map.waypoints:
		gal += 1 if p.y > 4.0 else 0
		low += 1 if p.y < -4.0 else 0
	check(gal > 4 and low > 4, "bots wander every floor: %d spots up on the galleries, %d in the crypt" % [gal, low])
	var trips := [
		["blue spawn -> its gallery", map.team_spawns[0][0], Vector3(0, y, 17)],
		["gallery -> across the loft -> red's gallery", Vector3(0, y + 0.1, 17), Vector3(0, y, -17)],
		["gallery -> down to the nave", Vector3(-10, y + 0.1, 17), Vector3(0, 0, 0)],
		["blue spawn -> site B in the crypt", map.team_spawns[0][0], map.bomb_sites[1]],
		["crypt -> the organ loft", map.bomb_sites[1] + Vector3(0, 0.1, 0), Vector3(-43, y, 0)],
		["red spawn -> site A on the dais", map.team_spawns[1][0], Vector3(66, LastTestament.DAIS_Y, 0)],
	]
	for t in trips:
		var b := await _bot_to(t[1], t[2])
		check(b != null, "a bot walks %s" % t[0])
		if b != null:
			b.queue_free()
		await physics_frame
	Engine.time_scale = 1.0
