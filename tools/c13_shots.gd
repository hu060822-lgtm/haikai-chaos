extends SceneTree
## C13: the smoke grenade, 霧行者's smoke wall, the melee weapons in first person, and the
## bench's melee row, for the report.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/c13_shots.gd -- <out_dir>

var out := "user://"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://"
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
	var spot: Vector3 = m.map.mid_zone if m.map.mid_zone.y > -1.0 else m.map.player_spawn.origin
	var floor_y := _floor(p, spot)
	spot.y = floor_y
	# Melee weapons, one shot each mid-swing, a bot in front.
	var b: Bot = m.bots[0]
	p.spawn_at(Transform3D(Basis.IDENTITY, spot + Vector3(0, 0.1, 0)))
	p.rotation.y = 0.0
	p._pitch = 0.0
	b.global_position = spot + Vector3(0, 0.1, -1.8)
	b.rotation.y = PI
	for i in 10:
		await physics_frame
	for id in Melee.IDS:   # once round first: the first draws compile shaders and stall
		p.set_melee(id)
		p.melee.press()
		await create_timer(0.9).timeout
	for id in Melee.IDS:
		if not b.alive:
			b.spawn(spot + Vector3(0, 0.1, -1.8), 7)
		b.frozen = true
		b.health = Bot.MAX_HEALTH
		b.rotation.y = PI
		p.set_melee(id)
		p.melee.press()
		var k := float(Melee.info(id).windup) + 0.08
		await create_timer(k).timeout
		p.view._swing = p.view._swing_total * 0.5   # the follow-through, whatever the frame rate did
		await _snap("melee_%s" % id)
		await create_timer(1.0).timeout
		b.global_position = spot + Vector3(0, 0.1, -1.8)
		b.velocity = Vector3.ZERO
		p.global_position = spot + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
	# 霧行者: a run across the yard's middle, the smoke wall seen from the side.
	b.global_position = Vector3(0, -50, 0)
	p.set_kit("veil")
	p.ability.press()
	for i in 40:
		p.global_position = spot + Vector3(-6 + i * 0.3, 0.1, -6)
		p.velocity = Vector3.ZERO
		await physics_frame
	p.ability.press()
	for i in 60:
		await physics_frame
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 400
	m.add_child(cam)
	m.hud.visible = false
	cam.look_at_from_position(spot + Vector3(0, 2.2, 6), spot + Vector3(0, 1.2, -6), Vector3.UP)
	cam.make_current()
	await _snap("veil_wall")
	cam.look_at_from_position(spot + Vector3(-12, 7, 2), spot + Vector3(0, 0.5, -6), Vector3.UP)
	await _snap("veil_wall_above")
	for n in Deploy.objects():
		if n is SmokeCloud:
			n.queue_free()
	# The smoke grenade's cloud.
	Deploy.spawn("throw", p, {"kind": "smoke", "from": spot + Vector3(4, 1.0, -10), "vel": Vector3.ZERO, "fuse": 0.05})
	for i in 90:
		await physics_frame
	cam.look_at_from_position(spot + Vector3(4, 2.0, 2), spot + Vector3(4, 1.5, -10), Vector3.UP)
	await _snap("smoke_grenade")
	m.hud.visible = true
	p.camera.make_current()
	await _snap("hud_belt")
	# The bench with the melee row.
	m._try_bench()
	for i in 10:
		await process_frame
	await _snap("bench_melee")
	quit()


func _floor(p: Player, at: Vector3) -> float:
	var hit := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 20, 0), at - Vector3(0, 30, 0), Geo.WORLD))
	return hit.position.y if not hit.is_empty() else at.y


func _snap(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
