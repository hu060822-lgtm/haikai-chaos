extends SceneTree
## C12: throwables and the maps' moving parts, for the report.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c12_shots.gd -- <out_dir> [game]

var out := "user://"
var cam: Camera3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://"
	if not "game" in args:
		for id in ["yard", "dream", "folded", "testament"]:
			await _map_parts(id)
	await _in_game()
	quit()


func _shot(from: Vector3, to: Vector3, name: String) -> void:
	cam.look_at_from_position(from, to, Vector3.UP)
	cam.make_current()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _map_parts(id: String) -> void:
	Main.map_id = id
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	while root.get_node_or_null("Main") == null or not root.get_node("Main").is_node_ready():
		await process_frame
	var m: Main = root.get_node("Main")
	m._start()
	for i in 20:
		await physics_frame
	m.hud.visible = false
	for b in m.bots:
		b.frozen = true
		b.global_position = Vector3(0, -50, 0)
	m.player.visible = false
	cam = Camera3D.new()
	cam.fov = 75
	cam.far = 600
	m.add_child(cam)
	var d := m.dynamics
	if d.doors.size() > 0:
		var door: MapDoor = d.doors[0]
		await _shot(door.to_global(Vector3(0.8, 1.7, 5.5)), door.to_global(Vector3(0, 1.4, 0)), "%s_door_shut" % id)
		door.set_open(true, true)
		await _shot(door.to_global(Vector3(0.8, 1.7, 5.5)), door.to_global(Vector3(0, 1.4, -3)), "%s_door_open" % id)
	for s in d.shutters:
		if s.closed:
			s.warn(true)
			await _shot(s.to_global(Vector3(1.5, 2.2, 9.0)), s.to_global(Vector3(0, 2.5, 0)), "%s_gate_shut" % id)
			s.warn(false)
			break
	for s in d.shutters:
		if not s.closed:
			await _shot(s.to_global(Vector3(1.0, 2.0, 7.0)), s.to_global(Vector3(0, 0, 0)), "%s_gate_open" % id)
			break
	if d.lifts.size() > 0:
		var lift: MapLift = d.lifts[0]
		d.lift_clock = MapLift.DOWN + MapLift.RISE + 1.0
		for i in 4:
			await physics_frame
		await _shot(lift.global_position + Vector3(9, 3.0, 9), lift.global_position + Vector3(0, 2.5, 0), "%s_lift_up" % id)
	if d.covers.size() > 0:
		var c: MapCover = d.covers[0]
		await _shot(c.global_position + Vector3(3.5, 2.2, 3.5), c.global_position + Vector3(0, 0.6, 0), "%s_cover" % id)
		Deploy.event(c.uid, "hit", 160.0)
		for i in 3:
			await physics_frame
		await _shot(c.global_position + Vector3(3.5, 2.2, 3.5), c.global_position + Vector3(0, 0.6, 0), "%s_cover_worn" % id)


## In a match view: the arc while aiming, the belt on the HUD, a frag going off, a wall
## mine's line, a sticky on a wall, a flash's white.
func _in_game() -> void:
	Main.map_id = "yard"
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	while root.get_node_or_null("Main") == null or not root.get_node("Main").is_node_ready():
		await process_frame
	var m: Main = root.get_node("Main")
	m._start()
	for i in 20:
		await physics_frame
	for b in m.bots:
		b.frozen = true
		b.passive = true
	var p := m.player
	var d := m.dynamics
	# Out in the yard's mid, facing a lift, the throw key held: the arc and the belt.
	var lift: MapLift = d.lifts[0]
	var spot := lift.global_position + Vector3(0, 0.1, 13.0)
	p.spawn_at(Transform3D(Basis.IDENTITY, spot))
	p.rotation.y = 0.0
	p._pitch = deg_to_rad(-4.0)
	p.input_enabled = true
	for i in 10:
		await physics_frame
	Input.action_press("throw")
	for i in 30:
		await physics_frame
	await _snap("game_aim_arc")
	Input.action_release("throw")
	for i in 5:
		await physics_frame
	# A frag going off next to a bot.
	var b: Bot = m.bots[0]
	b.global_position = spot + Vector3(-2, 0, -6)
	b.frozen = true
	Deploy.spawn("throw", p, {"kind": "frag", "from": b.global_position + Vector3(1.0, 0.3, 0), "vel": Vector3.ZERO, "fuse": 0.05})
	for i in 4:
		await physics_frame
	await _snap("game_frag")
	for i in 60:
		await physics_frame
	# A wall mine's line across a door's corridor, and a sticky on the wall, seen from the side.
	var door: MapDoor = d.doors[0]
	door.set_open(true, true)
	Deploy.spawn("throw", b, {"kind": "mine", "from": door.to_global(Vector3(-0.4, 0.5, 3.0)), "vel": door.global_basis * Vector3(-9, 0, 0)})
	for i in 150:
		await physics_frame
	var cam2 := Camera3D.new()
	cam2.fov = 70
	m.add_child(cam2)
	cam2.look_at_from_position(door.to_global(Vector3(0.5, 1.5, 7.5)), door.to_global(Vector3(0, 0.6, 3.0)), Vector3.UP)
	cam2.make_current()
	m.hud.visible = false
	await _snap("game_mine_line")
	m.hud.visible = true
	p.camera.make_current()
	# White from a flash.
	Deploy.spawn("throw", b, {"kind": "flash", "from": p.camera.global_position - p.camera.global_basis.z * 5.0, "vel": Vector3.ZERO, "fuse": 0.05})
	for i in 30:
		await physics_frame
	await _snap("game_flash")


func _wall_ahead(p: Player) -> Array:
	var from := p.camera.global_position
	var hit := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - p.camera.global_basis.z * 40.0 + Vector3(0, -2, 0), Geo.WORLD))
	if hit.is_empty():
		return [Vector3.INF, Vector3.ZERO]
	return [hit.position, hit.normal]


func _snap(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
