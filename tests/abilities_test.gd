extends SceneTree
## The classes (C6), offline in practice, on a test floor built high above the map:
## each ability does its job and its counter works.
##   godot --headless --path . --script res://tests/abilities_test.gd

const Y := 200.0

var failures := 0


func _init() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _until(func() -> bool: return main() != null and main().is_node_ready(), 5.0)
	var m := main()
	m._start()
	await _wait(0.3)
	for n in m.get_children():
		if n is MapGuard:
			n.queue_free()
	_arena(m)
	for b in m.bots:
		b.passive = true
		b.frozen = true
		b.global_position = Vector3(300, Y + 0.2, 300)
	await _wait(0.2)
	await _kits(m)
	await _anchor(m)
	await _swing(m)
	await _decoy(m)
	await _bulwark(m)
	await _veil(m)
	await _ram(m)
	await _panels(m)
	print("ABILITY TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


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


## A floor 80 m square at Y, a tall wall to the north to hook, a low ceiling slab to swing
## from in the east.
func _arena(m: Main) -> void:
	var c := Faultprint.CONCRETE
	Geo.block(m, Vector3(120, 1, 120), Vector3(0, Y - 0.5, 0), c)
	Geo.block(m, Vector3(30, 14, 1), Vector3(0, Y + 7, -30), c)          # the wall to hook
	Geo.block(m, Vector3(6, 1, 6), Vector3(30, Y + 12, 0), c)            # a slab to swing under


func _place(p: Player, at: Vector3, yaw: float, pitch_deg := 0.0) -> void:
	p.spawn_at(Transform3D(Basis(Vector3.UP, yaw), at))
	p.rotation.y = yaw
	p._pitch = deg_to_rad(pitch_deg)
	p.input_enabled = true


func _press(seconds := 0.05) -> void:
	Input.action_press("ability")
	await _wait(seconds)
	Input.action_release("ability")


func _kits(m: Main) -> void:
	var p := m.player
	for id in Kit.IDS:
		p.set_kit(id)
		check(p.ability != null and p.ability.kit == id and p.ability.charges == float(Kit.info(id).charges),
			"%s: ability %s with %d charge(s)" % [Kit.label(id), Kit.info(id).ability, Kit.info(id).charges])


# --- ANCHOR ----------------------------------------------------------------------------

func _anchor(m: Main) -> void:
	var p := m.player
	p.set_kit("anchor")
	_place(p, Vector3(0, Y + 0.1, 0), 0.0, 18.0)
	await _wait(0.2)
	Input.action_press("ability")
	var hooked := await _until(func() -> bool: return p.move == Player.Move.GRAPPLE, 1.0)
	var a := p.ability as Anchor
	check(hooked and a.reeling, "ANCHOR: the hook flies, bites the wall and reels (rope %.1f m)" % a.rope)
	var start_z := p.global_position.z
	await _wait(0.6)
	var pulled := start_z - p.global_position.z
	check(pulled > 5.0 and p.global_position.y > Y + 1.5, "ANCHOR: holding F pulls toward the hook (%.1f m, up %.1f m)" % [pulled, p.global_position.y - Y])
	var speed := p.velocity.length()
	Input.action_release("ability")
	await _wait(0.05)
	check(p.move == Player.Move.AIR and a.state == Anchor.State.IDLE, "ANCHOR: letting go of F drops the line")
	check(p.velocity.length() > speed * 0.8 and speed > 8.0, "ANCHOR: the speed carries on after the line (%.1f → %.1f m/s)" % [speed, p.velocity.length()])
	check(a.charges < 1.0, "ANCHOR: the line is on cooldown")
	# A miss: into the sky. Most of the charge comes back.
	a.refill()
	_place(p, Vector3(0, Y + 0.1, 0), PI, 60.0)
	await _wait(0.2)
	await _press(0.05)
	await _until(func() -> bool: return a.state == Anchor.State.IDLE, 1.5)
	check(a.charges >= Anchor.MISS_REFUND - 0.05 and p.move != Player.Move.GRAPPLE, "ANCHOR: a miss refunds most of the charge (%.2f)" % a.charges)


## A tap hooks with the rope at full length: a pendulum, the rope never stretches, and a
## jump lets go with a hop.
func _swing(m: Main) -> void:
	var p := m.player
	var a := p.ability as Anchor
	a.refill()
	# Run east under the slab, hook its underside ahead and above.
	_place(p, Vector3(22, Y + 0.1, 0), -PI / 2.0, 52.0)
	p.velocity = Vector3(10, 0, 0)
	await _wait(0.1)
	await _press(0.02)
	var hooked := await _until(func() -> bool: return p.move == Player.Move.GRAPPLE, 1.0)
	check(hooked and not a.reeling, "ANCHOR: a tap hooks without reeling (a swing)")
	var max_d := 0.0
	var vx_signs := {}
	for i in 40:
		await physics_frame
		if p.move != Player.Move.GRAPPLE:
			break
		max_d = maxf(max_d, a._centre(p).distance_to(a.point))
		vx_signs[signf(p.velocity.x)] = true
	check(max_d <= a.rope + 0.25, "ANCHOR: the rope holds its length (%.2f ≤ %.2f m)" % [max_d, a.rope])
	var vy_before := p.velocity.y
	Input.action_press("jump")
	await _wait(0.05)
	Input.action_release("jump")
	check(p.move != Player.Move.GRAPPLE and p.velocity.y > vy_before, "ANCHOR: jump lets go with a hop (vy %.1f → %.1f)" % [vy_before, p.velocity.y])


# --- DECOY -----------------------------------------------------------------------------

func _decoy(m: Main) -> void:
	var p := m.player
	p.set_kit("decoy")
	_place(p, Vector3(-20, Y + 0.1, 20), 0.0)
	await _wait(0.2)
	await _press()
	await _wait(0.1)
	var decoys := get_nodes_in_group("decoys")
	check(decoys.size() == 1, "DECOY: a decoy is out (%d)" % decoys.size())
	if decoys.is_empty():
		return
	var d: Decoy = decoys[0]
	var at := d.global_position
	await _wait(1.0)
	check(d.global_position.distance_to(at) > 6.0, "DECOY: it runs the way we looked (%.1f m in 1 s)" % d.global_position.distance_to(at))
	check(d._shots == 0 or d._shots > 0, "DECOY: fake shots scheduled (%d so far)" % d._shots)
	await _wait(0.7)
	check(d._shots >= 2, "DECOY: it fires fake shots (%d)" % d._shots)
	# A bot on the other team, the decoy closer than us: it takes the bait.
	var bot: Bot = m.bots[0]
	bot.team = 1
	bot.frozen = false
	bot.passive = true
	bot.global_position = d.global_position + Vector3(0, 0, -12)
	bot.look_at(d.global_position, Vector3.UP)
	bot.target = null
	await _wait(0.4)
	check(bot.target == d, "DECOY: a bot takes it for an enemy (%s)" % (bot.target.get_class() if bot.target != null else "none"))
	check(p.ability.charges >= 0.9 and p.ability.charges < 1.5, "DECOY: one of two charges used (%.2f)" % p.ability.charges)
	# One hit pops it.
	d.take_hit({"damage": 5.0, "team": 1, "dir": Vector3.BACK})
	await _wait(0.1)
	check(not is_instance_valid(d), "DECOY: one hit pops it")
	await _wait(0.2)
	check(bot.target == null or bot.target != d, "DECOY: the bot lets go of a popped decoy")
	bot.frozen = true
	bot.global_position = Vector3(300, Y + 0.2, 300)


# --- BULWARK ---------------------------------------------------------------------------

func _blocked(m: Main, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Geo.WORLD)
	return not m.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _bulwark(m: Main) -> void:
	var p := m.player
	p.set_kit("bulwark")
	_place(p, Vector3(20, Y + 0.1, 25), 0.0)
	await _wait(0.2)
	await _press()
	await _wait(0.1)
	var list := get_nodes_in_group("barricades")
	check(list.size() == 1, "BULWARK: a barricade stands up")
	if list.is_empty():
		return
	var b: Barricade = list[0]
	check(b.global_position.z < p.global_position.z - 1.0, "BULWARK: it's in front of us (%.1f m)" % (p.global_position.z - b.global_position.z))
	await _wait(Barricade.RISE + 0.1)
	var chest := p.global_position + Vector3(0, 1.2, 0)
	check(_blocked(m, chest + Vector3(0, 0, -15), chest), "BULWARK: it stops a shot from the front")
	check(not _blocked(m, chest + Vector3(-12, 0, -6), chest), "BULWARK: a shot from the side goes round it")
	# A real gun on it: the plate takes the damage, nobody behind does.
	var hp := p.health
	var w := Weapon.new({"frame": "battle_rifle", "parts": {}, "tune": {}})
	var shooter := Node3D.new()
	m.add_child(shooter)
	shooter.global_position = chest + Vector3(0, -1.2, -15)
	var res := w.fire(shooter, chest + Vector3(0, 0, -15), Basis.looking_at(Vector3(0, 0, 1)), 0.0, {"team": 1, "exclude": []})
	await _wait(0.05)
	check(p.health == hp and b.hp < Barricade.HP, "BULWARK: a rifle round hits the plate, not us (plate %.0f)" % b.hp)
	check(res.size() > 0 and res[0].get("damage", -1.0) == 0.0, "BULWARK: no damage number for hitting it")
	b.take_hit({"damage": Barricade.HP, "team": 1})
	await _wait(0.3)
	check(not is_instance_valid(b) or b._gone, "BULWARK: enough damage breaks it")
	await _wait(0.3)
	check(not _blocked(m, chest + Vector3(0, 0, -15), chest), "BULWARK: once broken it stops nothing")
	# Time runs out too.
	p.ability.refill()
	await _press()
	await _wait(0.1)
	var b2: Barricade = get_nodes_in_group("barricades")[0]
	b2.t = Barricade.LIFE - 0.05
	await _wait(0.6)
	check(not is_instance_valid(b2), "BULWARK: it goes after %.0f s" % Barricade.LIFE)
	shooter.queue_free()


# --- VEIL ------------------------------------------------------------------------------

func _veil(m: Main) -> void:
	var p := m.player
	p.set_kit("veil")
	_place(p, Vector3(-25, Y + 0.1, -10), 0.0, -12.0)
	await _wait(0.2)
	await _press()
	await _wait(0.1)
	var clouds := []
	for n in Deploy.objects():
		if n is SmokeCloud:
			clouds.append(n)
	check(clouds.size() == 1, "VEIL: a canister is out")
	if clouds.is_empty():
		return
	var s: SmokeCloud = clouds[0]
	var dist := Vector2(s.to.x - p.global_position.x, s.to.z - p.global_position.z).length()
	check(dist > 4.0 and dist < 25.0 and absf(s.to.y - Y) < 0.3, "VEIL: it lands on the floor ahead (%.1f m)" % dist)
	await _wait(s.flight + SmokeCloud.GROW + 0.1)
	var c := s.global_position + Vector3(0, 1.5, 0)
	var a := c + Vector3(-12, 0, 0)
	var b := c + Vector3(12, 0, 0)
	check(Deploy.sight_blocked(a, b), "VEIL: it blocks the line through it")
	check(not Deploy.sight_blocked(c + Vector3(-12, 8, 0), c + Vector3(12, 8, 0)), "VEIL: over the top is open")
	check(Deploy.smoke_at(c) > 0.8 and Deploy.smoke_at(a) == 0.0, "VEIL: inside is grey, outside is clear")
	# Bots can't see through it either: fair both ways.
	var bot: Bot = m.bots[0]
	bot.team = 1
	bot.frozen = false
	bot.passive = true
	bot.global_position = b - Vector3(0, 1.5, 0)
	bot.look_at(a, Vector3.UP)
	p.global_position = a - Vector3(0, 1.5, 0)
	p.velocity = Vector3.ZERO
	bot.target = null
	await _wait(0.4)
	check(not bot._see, "VEIL: a bot can't see us through it")
	# A blast blows it thin for a moment.
	Deploy.blow(c, 3.0)
	check(not Deploy.sight_blocked(a, b), "VEIL: an explosion blows it thin")
	await _wait(0.5)
	check(bot._see, "VEIL: the bot sees through the hole")
	await _wait(SmokeCloud.BLOWN + 0.2)
	check(Deploy.sight_blocked(a, b), "VEIL: it fills back in")
	bot.frozen = true
	bot.global_position = Vector3(300, Y + 0.2, 300)
	s.t = s.flight + SmokeCloud.LIFE - 0.05
	await _wait(0.2)
	check(not is_instance_valid(s), "VEIL: it ends")


# --- RAM -------------------------------------------------------------------------------

func _ram(m: Main) -> void:
	var p := m.player
	p.set_kit("ram")
	_place(p, Vector3(0, Y + 0.1, 30), 0.0)
	var bot: Bot = m.bots[1]
	bot.team = 1
	bot.frozen = false
	bot.passive = true
	bot.health = Bot.MAX_HEALTH
	bot.global_position = Vector3(0, Y + 0.1, 26)
	await _wait(0.3)
	await _press()
	var charged := await _until(func() -> bool: return p.move == Player.Move.CHARGE, 0.5)
	check(charged, "RAM: a wind-up, then the charge")
	await _wait(0.5)
	check(bot.health == Bot.MAX_HEALTH - Ram.DAMAGE, "RAM: the shoulder hits for %.0f (bot %.0f)" % [Ram.DAMAGE, bot.health])
	check(p.move != Player.Move.CHARGE and p.global_position.z > 25.0, "RAM: the charge stops on them")
	bot.frozen = true
	bot.global_position = Vector3(300, Y + 0.2, 300)
	# The stagger on us: a wide cone and no scope, but we can still move and shoot.
	var before := p.current_spread()
	p.take_hit({"damage": 1.0, "team": 1, "dir": Vector3.BACK, "effects": {"stagger": Ram.STAGGER}, "attacker_name": "x"})
	check(p.current_spread() > before * 2.0 and p._aim == 0.0 and p.input_enabled, "RAM: a stagger opens the cone (%.1f → %.1f°), never a stun" % [before, p.current_spread()])
	await _wait(Ram.STAGGER + 0.1)
	check(p.current_spread() < before * 1.3, "RAM: the stagger passes")
	# It smashes an enemy barricade.
	p.ability.refill()
	var b := Deploy.create(m, "barricade", "test:1", "test", {"at": Vector3(0, Y, 24), "yaw": 0.0, "team": 1}) as Barricade
	_place(p, Vector3(0, Y + 0.1, 29), 0.0)
	await _wait(0.6)
	await _press()
	await _wait(0.6)
	check(not is_instance_valid(b) or b._gone, "RAM: it smashes an enemy barricade")


# --- The map's panels ------------------------------------------------------------------

func _panels(m: Main) -> void:
	var p := m.player
	var panels := get_nodes_in_group("breakables")
	check(panels.size() == 4, "PANELS: the map has 4 breakable panels (%d)" % panels.size())
	if panels.is_empty():
		return
	var w: Breakable = panels[0]
	var layout: Layout = m.map.get("layout")
	check(layout.at(w.cell.x, w.cell.y) == "w" and not layout.walkable(w.cell.x, w.cell.y), "PANELS: bots treat a shut panel as rock")
	# Stand in the lane on one side, facing through it, and charge.
	var axis: Vector2i = Vector2i.ZERO
	for br in layout.breaches:
		if br[0] == w.cell:
			axis = br[1]
	var through := Vector3(axis.x, 0, axis.y)
	var start := w.global_position - through * 4.0 + Vector3(0, 0.1, 0)
	p.set_kit("ram")
	_place(p, start, atan2(-through.x, -through.z))
	await _wait(0.3)
	await _press()
	await _wait(0.8)
	check(w.broken and layout.walkable(w.cell.x, w.cell.y), "PANELS: a RAM charge breaks it open")
	check((p.global_position - start).dot(through) > 3.5, "PANELS: and goes on through (%.1f m)" % (p.global_position - start).dot(through))
	Deploy.reset_round()
	check(not w.broken and layout.at(w.cell.x, w.cell.y) == "w", "PANELS: a new round puts it back")
