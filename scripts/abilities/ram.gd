class_name Ram
extends Ability
## RAM's charge (C6, reworked in C8): after a WIND-second wind-up you can hear, a run
## straight ahead that doesn't stop until it hits someone or something (Player
## Move.CHARGE, or a lunge for a bot). It starts at SPEED and keeps building ACCEL m/s²
## with no top speed; it follows where you face, turning at most TURN rad/s:
##
##   people      DAMAGE (more the faster you were going, + PER_MS per m/s over SPEED) and a
##               STAGGER: for half a second their aim spreads wide and they are pushed
##               off it (no scope), with a shove that grows with the speed. Never a stun.
##               The charge stops on them, for the fight that follows.
##   walls       stop it dead (anything square across the way)
##   barricades  smashed, and the charge stops there (BULWARK's counter)
##   panels      the map's breakable panels give way (Breakable) and it runs on through
##   decoys      popped on the way past
##
## F again ends it where you are; jumping keeps its speed (a charge jump). SAFETY seconds
## at most, so it can't run forever round an open map. Counter: a side step (it turns
## slowly at speed), or anything solid in its way.

const WIND := 0.12
const SPEED := 13.0
const ACCEL := 7.0
## Turn rate toward where you face (rad/s); a bit slower at speed.
const TURN := 3.2
const DAMAGE := 20.0
const PER_MS := 1.2
const STAGGER := 0.5
const KNOCK := 5.0
const REACH := 1.35
const SAFETY := 8.0

enum State { IDLE, WIND_UP, GO }

var state := State.IDLE
var dir := Vector3.FORWARD
var t := 0.0
## How fast the charge is going now.
var speed := SPEED
var _hit := []


func press() -> void:
	if state == State.GO:
		_end(false)
		return
	if state != State.IDLE or not alive():
		return
	if charges < 1.0:
		say("衝撞還在冷卻")
		return
	spend()
	var fwd := -aim().basis.z
	fwd.y = 0.0
	dir = fwd.normalized() if fwd.length() > 0.01 else -user.global_basis.z
	state = State.WIND_UP
	t = 0.0
	speed = SPEED
	_hit.clear()
	busy = true
	Sfx.play(user, "ram_wind", -4.0)
	Deploy.fx(user, "ram", {"dir": dir})


func tick(delta: float) -> void:
	super.tick(delta)
	if state == State.IDLE:
		return
	if not alive():
		cancel()
		return
	t += delta
	if state == State.WIND_UP and t >= WIND:
		state = State.GO
		Sfx.play(user, "ram", -2.0)
		if user is Player:
			(user as Player)._set_move(Player.Move.CHARGE, "衝撞")
			(user as Player).burst(1.0)
	if state == State.GO:
		speed += ACCEL * delta
		_steer(delta)
		if not (user is Player) and user.has_method("lunge"):
			user.lunge(dir * speed, 0.1)
			if (user as CharacterBody3D).is_on_wall() and t > WIND + 0.1 and (user as CharacterBody3D).get_wall_normal().dot(dir) < -0.5:
				_end(true)
				return
		_contacts()
		if state == State.GO and t >= WIND + SAFETY:
			_end(false)


## Turn toward where the user faces (a bot: toward its target), slower the faster it goes.
func _steer(delta: float) -> void:
	var want := -aim().basis.z
	var tgt: Variant = user.get("target")
	if not (user is Player) and tgt is Node3D and is_instance_valid(tgt):
		want = (tgt as Node3D).global_position - user.global_position
	want.y = 0.0
	if want.length() < 0.01:
		return
	want = want.normalized()
	var turn := TURN * clampf(18.0 / maxf(speed, 1.0), 0.45, 1.0) * delta
	var a := dir.signed_angle_to(want, Vector3.UP)
	dir = dir.rotated(Vector3.UP, clampf(a, -turn, turn)).normalized()


## One tick of the charge for the Player (Move.CHARGE).
func move_frame(p: Player, delta: float, _wish: Vector3) -> void:
	if state != State.GO:
		p._set_move(Player.Move.GROUND if p.is_on_floor() else Player.Move.AIR, "衝撞結束")
		return
	if p._buffer > 0.0 and (p.is_on_floor() or p._coyote > 0.0):
		# A charge jump: up, with all of the charge's speed.
		_end(false)
		p._jump()
		return
	p.velocity.x = dir.x * speed
	p.velocity.z = dir.z * speed
	p.velocity.y = 0.0 if p.is_on_floor() else p.velocity.y - p.tune.gravity * delta
	p.limiter = "衝撞 %.0f m/s" % speed
	if p.is_on_wall() and t > WIND + 0.06:
		var n := p.get_wall_normal()
		if n.dot(dir) < -0.5:
			p.view.kick(clampf(speed * 0.2, 3.0, 9.0), 0.0)
			p.hit_punch(false)
			_end(true)


func _contacts() -> void:
	var centre := user.global_position + Vector3(0, 1.0, 0) + dir * 0.6
	for c in user.get_tree().get_nodes_in_group("combatants"):
		if c == user or not (c is Node3D) or not c.get("alive") or c.get("team") == null or int(c.team) == team():
			continue
		if c in _hit or ((c as Node3D).global_position + Vector3(0, 1.0, 0)).distance_to(centre) > REACH:
			continue
		_hit.append(c)
		_strike(c)
	for d in user.get_tree().get_nodes_in_group("decoys"):
		if d.alive and int(d.team) != team() and ((d as Node3D).global_position + Vector3(0, 1.0, 0)).distance_to(centre) < REACH:
			Deploy.event(d.uid, "pop")
	for b in user.get_tree().get_nodes_in_group("barricades"):
		if int(b.team) == team():
			continue
		var local: Vector3 = (b as Node3D).global_transform.affine_inverse() * centre
		if absf(local.x) < Barricade.WIDTH / 2.0 + 0.5 and absf(local.z) < 1.0 and local.y > -0.5 and local.y < Barricade.TALL + 0.5:
			Deploy.event(b.uid, "break")
			_end(true)
			return
	for w in user.get_tree().get_nodes_in_group("breakables"):
		if w.broken:
			continue
		var flat := (w as Node3D).global_position - user.global_position
		flat.y = 0.0
		if flat.length() < 1.9 and flat.normalized().dot(dir) > 0.3:
			Deploy.event(w.uid, "break")


## What a hit at the current speed does.
func damage() -> float:
	return DAMAGE + maxf(speed - SPEED, 0.0) * PER_MS


func _strike(c: Node3D) -> void:
	var dmg := damage()
	var info := {"damage": dmg, "zone": "body", "distance": 0.0, "point": c.global_position + Vector3(0, 1.0, 0),
		"dir": dir, "attacker": user, "attacker_name": str(user.get("display_name")), "team": team(),
		"gun_name": "衝撞", "build": {}, "effects": {"knock": KNOCK + speed * 0.25, "stagger": STAGGER}, "moves": ["衝撞"],
		"through_wall": false, "blast": true}
	var killed: bool = c.take_hit(info)
	if user.has_signal("hit_confirmed"):
		user.hit_confirmed.emit({"zone": "body", "damage": dmg, "target": c, "at": info.point}, killed)
	if user is Player:
		(user as Player).view.kick(2.5, 0.0)
		(user as Player).combat_left = Player.COMBAT_LOCK
	_end(true)


func _end(stopped: bool) -> void:
	if state == State.IDLE:
		return
	state = State.IDLE
	busy = false
	if user is Player:
		var p := user as Player
		if stopped:
			p.velocity.x *= 0.25
			p.velocity.z *= 0.25
		if p.move == Player.Move.CHARGE:
			p._set_move(Player.Move.GROUND if p.is_on_floor() else Player.Move.AIR, "衝撞結束")
	elif user.has_method("lunge"):
		user.lunge(Vector3.ZERO, 0.0)


func cancel() -> void:
	_end(false)
	super.cancel()
