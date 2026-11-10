extends SceneTree
## Melee weapons (C13), offline in practice on a test floor high above the map: each one
## does its job (the knife's backstab, the sledge's knock, the chain's reach and pull, the
## baton's stagger, the fist's lunge, the axe through a shield wall), walls stop a swing,
## speed adds to it, bots swing back, and the host's judge caps it.
##   godot --headless --path . --script res://tests/melee_test.gd

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
	await _basics(m)
	await _knife(m)
	await _wall(m)
	await _sledge(m)
	await _sickle(m)
	await _baton(m)
	await _fist(m)
	await _axe(m)
	await _bots(m)
	_judge()
	print("MELEE TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
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
	Geo.block(m, Vector3(4, 4, 0.3), Vector3(30, Y + 2, -1.0), c)        # a thin wall between
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


## An enemy bot standing at `at`, facing `yaw`.
func _bot(m: Main, at: Vector3, yaw := 0.0) -> Bot:
	var b: Bot = m.bots[0]
	if not b.alive:
		b.spawn(at, 7)
	b.team = 1
	b.health = Bot.MAX_HEALTH
	b._burn = 0.0
	b._stagger = 0.0
	b._slow = 0.0
	b.global_position = at
	b.rotation.y = yaw
	b.velocity = Vector3.ZERO
	b.passive = true
	b.frozen = true
	return b


## Player at x, facing -Z (yaw 0), with weapon `id`; a bot `dist` m ahead.
func _setup(m: Main, id: String, x: float, dist: float, bot_yaw := 0.0) -> Array:
	var p := m.player
	p.team = 0
	_place(p, Vector3(x, Y + 0.1, 10), 0.0)
	p.set_melee(id)
	var b := _bot(m, Vector3(x, Y + 0.1, 10 - dist), bot_yaw)
	await _wait(0.15)
	return [p, b]


## Swings and waits for it to land.
func _swing(p: Player) -> bool:
	var ok := p.melee.press()
	await _wait(float(p.melee.info().windup) + 0.06)
	return ok


func _ready_again(p: Player) -> void:
	await _wait(float(p.melee.info().recover) + 0.05)


func _basics(m: Main) -> void:
	var p := m.player
	check(InputMap.has_action("melee") and p.melee != null, "the melee key is bound and everyone carries one")
	check(p.melee.id == Melee.DEFAULT, "the knife by default")
	check(Melee.damage_at("axe", 18.0) > Melee.damage_at("axe", 4.0) * 1.3, "speed adds to a swing (%.0f vs %.0f)" % [Melee.damage_at("axe", 18.0), Melee.damage_at("axe", 4.0)])
	check(Melee.damage_at("axe", 60.0) <= Melee.max_damage("axe"), "... up to a cap")


# --- Knife -----------------------------------------------------------------------------

func _knife(m: Main) -> void:
	var r: Array = await _setup(m, "knife", 0.0, 1.5, PI)   # the bot faces us
	var p: Player = r[0]
	var b: Bot = r[1]
	check(await _swing(p), "knife: Z swings")
	check(p.view.swinging(), "knife: the swing shows in first person")
	check(b.health < Bot.MAX_HEALTH and b.health > 30.0 and not p.melee.last_backstab, "knife: from the front it cuts (%.0f left)" % b.health)
	var fired := p.weapon.ammo
	Input.action_press("fire")
	await physics_frame
	await physics_frame
	Input.action_release("fire")
	check(p.weapon.ammo == fired, "knife: no shooting mid-swing")
	await _ready_again(p)
	# Facing away: one stab.
	b.rotation.y = 0.0
	b.health = Bot.MAX_HEALTH
	await physics_frame
	await _swing(p)
	check(p.melee.last_backstab and not b.alive, "knife: from behind it kills")
	await _ready_again(p)
	# Out of reach.
	r = await _setup(m, "knife", 0.0, 3.5, PI)
	b = r[1]
	await _swing(p)
	check(b.health == Bot.MAX_HEALTH, "knife: 3.5 m away it misses")
	await _ready_again(p)
	# Someone right below the crosshair (slid into, crouched) still gets hit.
	r = await _setup(m, "knife", 0.0, 1.0, PI)
	b = r[1]
	p._pitch = deg_to_rad(25.0)
	await _swing(p)
	check(b.health < Bot.MAX_HEALTH, "knife: a body right next to you counts, looking a bit off")
	p._pitch = 0.0
	await _ready_again(p)
	_park(b)


func _wall(m: Main) -> void:
	# The thin wall at z=-1 between player (z=0.4) and bot (z=-1.6), x=30.
	var p := m.player
	_place(p, Vector3(30, Y + 0.1, 0.4), 0.0)
	p.set_melee("axe")
	var b := _bot(m, Vector3(30, Y + 0.1, -1.6), PI)
	await _wait(0.15)
	await _swing(p)
	check(b.health == Bot.MAX_HEALTH, "a wall stops a swing")
	await _ready_again(p)
	_park(b)


# --- Sledge / sickle / baton / fist ----------------------------------------------------

func _sledge(m: Main) -> void:
	var r: Array = await _setup(m, "sledge", -10.0, 1.6, PI)
	var p: Player = r[0]
	var b: Bot = r[1]
	b.frozen = false
	var z0 := b.global_position.z
	await _swing(p)
	await _wait(0.25)
	check(b.health < Bot.MAX_HEALTH and z0 - b.global_position.z > 1.0, "sledge: it knocks them flying (%.1f m)" % (z0 - b.global_position.z))
	b.frozen = true
	await _ready_again(p)
	_park(b)


func _sickle(m: Main) -> void:
	var r: Array = await _setup(m, "sickle", -20.0, 4.0, PI)
	var p: Player = r[0]
	var b: Bot = r[1]
	b.frozen = false
	var z0 := b.global_position.z
	await _swing(p)
	await _wait(0.25)
	check(b.health < Bot.MAX_HEALTH, "sickle: the chain reaches 4 m")
	check(b.global_position.z - z0 > 0.8, "sickle: and pulls them in (%.1f m)" % (b.global_position.z - z0))
	check(b._burn > 0.0, "sickle: they bleed")
	b.frozen = true
	await _ready_again(p)
	_park(b)


func _baton(m: Main) -> void:
	var r: Array = await _setup(m, "baton", -30.0, 1.5, PI)
	var p: Player = r[0]
	var b: Bot = r[1]
	await _swing(p)
	check(b._stagger > 0.0 and b._slow > 0.0, "baton: the hit staggers and slows")
	check(b.health >= Bot.MAX_HEALTH - 31.0, "baton: but does little damage")
	await _ready_again(p)
	_park(b)


func _fist(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(10, Y + 0.1, 30), 0.0)
	p.set_melee("fist")
	await _wait(0.2)
	var z0 := p.global_position.z
	p.melee.press()
	await _wait(0.3)
	check(z0 - p.global_position.z > 1.5, "fist: the punch throws you forward (%.1f m)" % (z0 - p.global_position.z))
	await _ready_again(p)


# --- Axe through a shield wall ---------------------------------------------------------

func _axe(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(-40, Y + 0.1, 10), 0.0)
	p.set_melee("axe")
	var b := _bot(m, Vector3(-40, Y + 0.1, 0), 0.0)
	Deploy.spawn("barricade", b, {"at": Vector3(-40, Y, 8.6), "yaw": 0.0})
	await _wait(Barricade.RISE + 0.3)
	var walls := get_nodes_in_group("barricades")
	check(walls.size() == 1, "axe: a shield wall stands in front")
	if walls.is_empty():
		return
	var w: Barricade = walls[0]
	var before := float(w.hp)
	await _swing(p)
	await physics_frame
	check(not is_instance_valid(w) or w.hp < before - 300.0 or w._gone, "axe: one swing chops through a shield wall")
	await _ready_again(p)
	_park(b)


# --- Bots ------------------------------------------------------------------------------

func _bots(m: Main) -> void:
	var p := m.player
	_place(p, Vector3(50, Y + 0.1, 10), 0.0)
	var b := _bot(m, Vector3(50, Y + 0.1, 11.4), 0.0)
	b.melee.id = "knife"
	b.frozen = false
	b.passive = false
	b.target = p
	b._see = true
	var hp := p.health
	b._use_melee()
	check(b.melee.busy(), "bots: someone right up close gets a swing")
	await _wait(0.4)
	check(p.health < hp, "bots: and it lands (%.0f, backstab %s)" % [p.health, b.melee.last_backstab])
	b.passive = true
	b.frozen = true
	_park(b)


# --- The host's judge ------------------------------------------------------------------

func _judge() -> void:
	var j := HitJudge.new()
	var now := 10.0
	for t in [now - 0.1, now]:
		j.record("p2", Vector3(0, 0, 0), t)
		j.record("b1", Vector3(0, 0, 1.8), t)
	var no_wall := func(_a: Vector3, _b: Vector3) -> bool: return false
	var wire := {"melee": "knife", "damage": 45.0, "point": Vector3(0, 1, 1.8), "distance": 1.8}
	check(j.judge("p2", 2, "b1", wire, {}, now, no_wall) == "", "judge: a stab stands (%s)" % j.last_reason)
	wire.damage = 150.0
	check(j.judge("p2", 2, "b1", wire, {}, now, no_wall) == "", "judge: a backstab stands")
	wire.damage = 400.0
	check(j.judge("p2", 2, "b1", wire, {}, now, no_wall) != "", "judge: more than the weapon does is thrown out")
	wire.damage = 40.0
	wire.melee = "spoon"
	check(j.judge("p2", 2, "b1", wire, {}, now, no_wall) != "", "judge: an unknown weapon is thrown out")
	wire.melee = "knife"
	j.record("b2", Vector3(0, 0, 20), now - 0.1)
	j.record("b2", Vector3(0, 0, 20), now)
	check(j.judge("p2", 2, "b2", wire, {}, now, no_wall) != "", "judge: a swing at someone 20 m away is thrown out")
