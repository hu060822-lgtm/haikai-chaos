extends SceneTree
## Throwables (C12), offline in practice on a test floor high above the map: each kind
## does its job, walls stop blasts, the belt counts and refills, bots throw and dodge, and
## the host's judge takes a grenade's damage but not more.
##   godot --headless --path . --script res://tests/throwables_test.gd

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
		_park(b)
	await _wait(0.2)
	await _belt(m)
	await _frag(m)
	await _wall(m)
	await _bounce(m)
	await _cook(m)
	await _flash(m)
	await _sticky(m)
	await _mines(m)
	await _kick(m)
	await _bots(m)
	_judge()
	print("THROWABLE TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
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


func _arena(m: Main) -> void:
	var c := Faultprint.CONCRETE
	Geo.block(m, Vector3(120, 1, 120), Vector3(0, Y - 0.5, 0), c)
	Geo.block(m, Vector3(30, 8, 1), Vector3(0, Y + 4, -30), c)           # a wall to bounce off / mine
	Geo.block(m, Vector3(0.6, 4, 6), Vector3(40, Y + 2, 0), c)           # a wall to hide behind
	Geo.block(m, Vector3(60, 1, 20), Vector3(320, Y - 0.5, 300), c)      # where idle bots wait


func _park(b: Bot) -> void:
	var i := maxi(main().bots.find(b), 0)
	b.global_position = Vector3(300 + i * 4.0, Y + 0.2, 300)
	b.velocity = Vector3.ZERO


func _place(p: Player, at: Vector3, yaw: float, pitch_deg := 0.0) -> void:
	p.spawn_at(Transform3D(Basis(Vector3.UP, yaw), at))
	p.rotation.y = yaw
	p._pitch = deg_to_rad(pitch_deg)
	p.input_enabled = true


func _bot(m: Main, at: Vector3, yaw := 0.0) -> Bot:
	var b: Bot = m.bots[0]
	if not b.alive:
		b.spawn(at, 7)
	b.health = Bot.MAX_HEALTH
	b.global_position = at
	b.rotation.y = yaw
	b.velocity = Vector3.ZERO
	b.passive = true
	b.frozen = true
	return b


func _grenades() -> Array:
	return get_nodes_in_group("grenades").filter(func(g: Node) -> bool: return is_instance_valid(g) and not g.is_queued_for_deletion())


func _throw(user: Node3D, kind: String, from: Vector3, vel: Vector3, fuse := -1.0) -> Grenade:
	Deploy.spawn("throw", user, {"kind": kind, "from": from, "vel": vel, "fuse": Throwables.info(kind).fuse if fuse < 0.0 else fuse})
	var gs := _grenades()
	return gs[-1] as Grenade if not gs.is_empty() else null


func _clear() -> void:
	for g in _grenades():
		g.queue_free()


# --- The belt --------------------------------------------------------------------------

func _belt(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(-20, Y + 0.1, 10), 0.0)
	var full := Throwables.full()
	check(p.pouch != null and p.pouch.counts == full, "belt: a full belt on spawn %s" % str(p.pouch.counts))
	p.pouch.selected = "flash"
	check(p.pouch.press(), "belt: press takes one in hand")
	await _wait(0.1)
	p.pouch.release()
	await physics_frame
	check(p.pouch.count("flash") == full.flash - 1 and _grenades().size() == 1, "belt: release throws it (%d flash left)" % p.pouch.count("flash"))
	var g: Grenade = _grenades()[0]
	check(g.user == p and g.team == p.team, "belt: the thrower's machine owns it")
	await _wait(1.4)
	p.pouch.counts.mine = 0
	p.pouch.selected = "sticky"
	p.pouch.next()
	check(p.pouch.selected == "kick", "belt: next skips an empty kind (%s)" % p.pouch.selected)
	p.pouch.counts.kick = 0
	p.pouch._kick_t = Throwables.KICK_REFILL - 0.05
	await _wait(0.2)
	check(p.pouch.count("kick") == 1, "belt: the kick comes back on its own")
	_place(p, Vector3(-20, Y + 0.1, 10), 0.0)
	check(p.pouch.counts == full, "belt: a respawn refills it")
	_clear()


# --- Frag ------------------------------------------------------------------------------

func _frag(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(0, Y + 0.1, 20), 0.0)
	var b := _bot(m, Vector3(0, Y + 0.1, 0))
	await _wait(0.1)
	_throw(p, "frag", Vector3(1.5, Y + 0.3, 0), Vector3.ZERO, 0.3)
	await _wait(0.6)
	check(not b.alive or b.health < 30.0, "frag: 1.5 m from a bot it nearly kills it (%.0f hp)" % b.health)
	b = _bot(m, Vector3(0, Y + 0.1, 0))
	_throw(p, "frag", Vector3(5.0, Y + 0.3, 0), Vector3.ZERO, 0.2)
	await _wait(0.5)
	check(b.alive and b.health > 70.0 and b.health < 100.0, "frag: at the edge only a graze (%.0f hp)" % b.health)
	check(p.health == Player.MAX_HEALTH, "frag: the thrower far away is fine")


func _wall(m: Main) -> void:
	var p := m.player
	var b := _bot(m, Vector3(42, Y + 0.1, 0))
	_throw(p, "frag", Vector3(38.5, Y + 0.3, 0), Vector3.ZERO, 0.2)
	await _wait(0.5)
	check(b.alive and b.health == Bot.MAX_HEALTH, "frag: a wall between stops the blast (%.0f hp)" % b.health)
	_park(b)


func _bounce(m: Main) -> void:
	var p := m.player
	var g := _throw(p, "frag", Vector3(0, Y + 1.5, -24), Vector3(0, 2, -20), 3.0)
	await _wait(0.5)
	check(g != null and is_instance_valid(g) and g.vel.z > 0.5 and g.pos.z > -29.6, "frag: it bounces off a wall (vz %.1f)" % (g.vel.z if is_instance_valid(g) else 0.0))
	await _wait(1.8)
	check(is_instance_valid(g) and g.state == Grenade.State.RESTING, "frag: then rolls to a stop on the floor")
	await _wait(1.0)
	_place(p, Vector3(-20, Y + 0.1, 10), 0.0)


func _cook(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(0, Y + 0.1, 10), 0.0)
	p.pouch.selected = "frag"
	Input.action_press("throw")
	await _wait(1.0)
	check(p.pouch.holding and p.pouch.cook > 0.8, "frag: holding it cooks the fuse (%.1f s)" % p.pouch.cook)
	await _wait(1.5)
	check(not p.pouch.holding and p.health < Player.MAX_HEALTH, "frag: held too long it goes off in your hand (%.0f hp)" % p.health)
	Input.action_release("throw")
	await _wait(0.1)
	_place(p, Vector3(-20, Y + 0.1, 10), 0.0)
	# A cooked one thrown goes off sooner.
	Input.action_press("throw")
	await _wait(1.0)
	Input.action_release("throw")
	await _wait(0.05)
	var g: Grenade = _grenades()[-1]
	check(g.fuse < 1.4, "frag: a cooked throw keeps what was left of the fuse (%.2f s)" % g.fuse)
	await _wait(1.6)
	_clear()


# --- Flash -----------------------------------------------------------------------------

func _flash(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(0, Y + 0.1, 10), 0.0)
	await _wait(0.1)
	_throw(p, "flash", Vector3(0, Y + 1.6, 4), Vector3.ZERO, 0.05)
	await _wait(0.2)
	check(p.flash_left > 1.5, "flash: looking at it, white for a while (%.1f s)" % p.flash_left)
	await _wait(2.6)
	check(p.flash_left == 0.0, "flash: it wears off")
	_place(p, Vector3(0, Y + 0.1, 10), PI)
	await _wait(0.1)
	_throw(p, "flash", Vector3(0, Y + 1.6, 4), Vector3.ZERO, 0.05)
	await _wait(0.2)
	check(p.flash_left < 0.5, "flash: turned away, almost nothing (%.2f s)" % p.flash_left)
	_place(p, Vector3(44, Y + 0.1, 0), PI / 2.0)
	await _wait(0.1)
	_throw(p, "flash", Vector3(37, Y + 1.6, 0), Vector3.ZERO, 0.05)
	await _wait(0.2)
	check(p.flash_left == 0.0, "flash: a wall in between, nothing")
	var b := _bot(m, Vector3(0, Y + 0.1, 0), 0.0)
	b.frozen = false
	_throw(p, "flash", Vector3(0, Y + 1.6, -5), Vector3.ZERO, 0.05)
	await _wait(0.2)
	check(b._blind > 1.0, "flash: a bot looking at it is blind (%.1f s)" % b._blind)
	b.frozen = true
	_park(b)
	_place(p, Vector3(-20, Y + 0.1, 10), 0.0)


# --- Sticky ----------------------------------------------------------------------------

func _sticky(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(0, Y + 0.1, 12), 0.0)
	var b := _bot(m, Vector3(0, Y + 0.1, 0))
	await _wait(0.1)
	var g := _throw(p, "sticky", Vector3(0, Y + 1.3, 3), Vector3(0, 1.0, -14))
	var stuck := await _until(func() -> bool: return is_instance_valid(g) and g._stuck_to == b, 1.0)
	check(stuck, "sticky: it sticks to the bot it hits")
	b.frozen = false
	b.lunge(Vector3(6, 0, 0), 0.5)
	await _wait(0.4)
	check(is_instance_valid(g) and g.pos.distance_to(b.global_position) < 1.6, "sticky: and goes where the bot goes")
	await _wait(1.3)
	check(not b.alive or b.health < 20.0, "sticky: then blows up on it (%.0f hp)" % b.health)
	b.frozen = true
	var w := _throw(p, "sticky", Vector3(0, Y + 1.2, -25), Vector3(0, 0, -15))
	await _until(func() -> bool: return is_instance_valid(w) and w.state == Grenade.State.STUCK, 1.0)
	check(is_instance_valid(w) and w.pos.z > -29.6 and w.pos.z < -29.3 and w.vel == Vector3.ZERO, "sticky: on a wall it stays on the wall")
	await _wait(1.6)
	_park(b)


# --- Mines -----------------------------------------------------------------------------

func _mines(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(0, Y + 0.1, 20), 0.0)
	var b := _bot(m, Vector3(-10, Y + 0.1, 0))
	var floor_mine := _throw(p, "mine", Vector3(0, Y + 0.5, 0), Vector3(0, -2, 0))
	await _wait(0.4)
	check(is_instance_valid(floor_mine) and floor_mine.state == Grenade.State.STUCK and floor_mine._beam == null, "mine: on the floor it sits flat (no line)")
	await _wait(1.0)
	check(floor_mine.armed, "mine: armed after a second")
	b.global_position = Vector3(-1.2, Y + 0.1, 0)
	await _wait(0.2)
	check(not is_instance_valid(floor_mine) and (not b.alive or b.health < 100.0), "mine: a bot stepping close sets it off (%.0f hp)" % b.health)
	# On a wall: a line out of it.
	b = _bot(m, Vector3(-10, Y + 0.1, -26))
	var wall_mine := _throw(p, "mine", Vector3(0, Y + 1.0, -27), Vector3(0, 0, -10))
	await _wait(1.4)
	check(is_instance_valid(wall_mine) and wall_mine._beam != null and wall_mine.beam_len > 5.0, "mine: on a wall it draws a line (%.1f m)" % (wall_mine.beam_len if is_instance_valid(wall_mine) else 0.0))
	b.global_position = Vector3(-3, Y + 0.1, -28)
	await _wait(0.1)
	check(is_instance_valid(wall_mine), "mine: standing beside the line does nothing")
	b.global_position = Vector3(0, Y + 0.1, -26)
	await _wait(0.2)
	check(not is_instance_valid(wall_mine), "mine: crossing the line sets it off")
	# One shot pops it.
	var pop := _throw(p, "mine", Vector3(5, Y + 0.5, 5), Vector3(0, -2, 0))
	await _wait(0.3)
	pop.take_hit({"team": 1, "damage": 20.0})
	await physics_frame
	await physics_frame
	check(not is_instance_valid(pop) or pop.is_queued_for_deletion(), "mine: one enemy shot pops it")
	var own := _throw(p, "mine", Vector3(-5, Y + 0.5, 5), Vector3(0, -2, 0))
	await _wait(0.3)
	own.take_hit({"team": 0, "damage": 20.0})
	await physics_frame
	check(is_instance_valid(own) and not own.is_queued_for_deletion(), "mine: a teammate's shot passes it by")
	Deploy.reset_round()
	await physics_frame
	check(not is_instance_valid(own) or own.is_queued_for_deletion(), "mine: a new round clears it")
	_park(b)


# --- Kick ------------------------------------------------------------------------------

func _kick(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(-20, Y + 0.1, 10), 0.0)
	await _wait(0.2)
	var hp := p.health
	_throw(p, "kick", p.global_position + Vector3(0, 0.3, 0.6), Vector3(0, -5, 0))
	await _wait(0.15)
	check(p.velocity.y > 6.0 and p.move == Player.Move.AIR, "kick: at your feet it throws you up (vy %.1f)" % p.velocity.y)
	check(p.health == hp, "kick: and doesn't hurt")
	await _wait(1.5)
	var b := _bot(m, Vector3(10, Y + 0.1, 0))
	b.frozen = false
	_throw(p, "kick", Vector3(8.8, Y + 0.6, 0), Vector3.ZERO, 0.02)
	await _wait(0.2)
	check(b.global_position.x > 10.5, "kick: it shoves bots about too (%.1f m)" % (b.global_position.x - 10.0))
	b.frozen = true
	_park(b)


# --- Bots ------------------------------------------------------------------------------

func _bots(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(0, Y + 0.1, -18), 0.0)
	var b := _bot(m, Vector3(0, Y + 0.1, 0))
	b.pouch.refill()
	var before := _grenades().size()
	var ok := b._lob("frag", Vector3(0, Y + 0.1, -18))
	await physics_frame
	var gs := _grenades()
	check(ok and gs.size() == before + 1 and int(gs[-1].team) == b.team, "bots: a bot lobs a frag at where it last saw you")
	var g: Grenade = gs[-1]
	var land: Vector3 = Grenade.predict(b.get_world_3d().direct_space_state, g.pos, g.vel, [], 3.0)[1]
	check(Vector2(land.x, land.z).distance_to(Vector2(0, -18)) < 4.5, "bots: ... and it lands near (%.1f m off)" % Vector2(land.x, land.z).distance_to(Vector2(0, -18)))
	_clear()
	await physics_frame
	# A live enemy frag next to a bot: it jumps away.
	b.frozen = false
	b.passive = false
	var f := _throw(p, "frag", Vector3(1.0, Y + 0.3, 0), Vector3.ZERO, 1.2)
	b._lunge_left = 0.0
	b._dodge()
	check(b._lunge_left > 0.0 and b._lunge.x < 0.0, "bots: a bot jumps away from a live frag")
	await _wait(1.4)
	check(b.alive and b.health > 40.0, "bots: ... and gets mostly clear (%.0f hp)" % b.health)
	b.passive = true
	b.frozen = true
	_park(b)
	if is_instance_valid(f):
		f.queue_free()


# --- The host's judge ------------------------------------------------------------------

func _judge() -> void:
	var j := HitJudge.new()
	var now := 10.0
	j.record("b1", Vector3(5, 0, 5), now - 0.1)
	j.record("b1", Vector3(5, 0, 5), now)
	var wire := {"throw": "frag", "damage": 90.0, "point": Vector3(5, 1, 5), "blast": true, "distance": 0.0}
	check(j.judge("p2", 2, "b1", wire, {}, now, func(_a: Vector3, _b: Vector3) -> bool: return false) == "", "judge: a frag's blast stands (%s)" % j.last_reason)
	wire.damage = 400.0
	check(j.judge("p2", 2, "b1", wire, {}, now, func(_a: Vector3, _b: Vector3) -> bool: return false) != "", "judge: more than a frag can do is thrown out")
	wire.damage = 50.0
	wire.point = Vector3(40, 1, 40)
	check(j.judge("p2", 2, "b1", wire, {}, now, func(_a: Vector3, _b: Vector3) -> bool: return false) != "", "judge: a blast nowhere near the victim is thrown out")
