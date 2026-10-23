class_name Ram
extends Ability
## RAM's shoulder charge (C6). A WIND-second wind-up you can hear, then TIME seconds
## straight ahead at SPEED (about six metres; Player Move.CHARGE, or a lunge for a bot):
##
##   people      DAMAGE and a STAGGER: for half a second their aim spreads wide and they
##               are pushed off it (no scope), with a shove of KNOCK. Never a stun: they
##               keep moving and shooting. The charge stops on them, for the fight that
##               follows.
##   barricades  smashed (BULWARK's counter)
##   panels      the map's breakable panels give way (Breakable): new shortcuts
##   decoys      popped
##
## It can't turn once it goes, and stops dead on a wall. Jumping during the charge keeps its
## speed (a charge jump). Counter: distance and a side step.

const WIND := 0.12
const TIME := 0.34
const SPEED := 17.5
const DAMAGE := 20.0
const STAGGER := 0.5
const KNOCK := 5.0
const REACH := 1.35

enum State { IDLE, WIND_UP, GO }

var state := State.IDLE
var dir := Vector3.FORWARD
var t := 0.0
var _hit := []


func press() -> void:
	if state != State.IDLE or not alive():
		return
	if charges < 1.0:
		say("肩撞還在冷卻")
		return
	spend()
	var fwd := -aim().basis.z
	fwd.y = 0.0
	dir = fwd.normalized() if fwd.length() > 0.01 else -user.global_basis.z
	state = State.WIND_UP
	t = 0.0
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
			(user as Player)._set_move(Player.Move.CHARGE, "肩撞")
			(user as Player).burst(1.0)
		elif user.has_method("lunge"):
			user.lunge(dir * SPEED, TIME)
	if state == State.GO:
		_contacts()
		if t >= WIND + TIME:
			_end(false)


## One tick of the charge for the Player (Move.CHARGE).
func move_frame(p: Player, delta: float, _wish: Vector3) -> void:
	if state != State.GO:
		p._set_move(Player.Move.GROUND if p.is_on_floor() else Player.Move.AIR, "肩撞結束")
		return
	if p._buffer > 0.0 and (p.is_on_floor() or p._coyote > 0.0):
		# A charge jump: up, with all of the charge's speed.
		_end(false)
		p._jump()
		return
	var speed := SPEED * clampf(p.mobility, 0.8, 1.1)
	p.velocity.x = dir.x * speed
	p.velocity.z = dir.z * speed
	p.velocity.y = 0.0 if p.is_on_floor() else p.velocity.y - p.tune.gravity * delta
	p.limiter = "肩撞"
	if p.is_on_wall() and t > WIND + 0.06:
		var n := p.get_wall_normal()
		if n.dot(dir) < -0.6:
			p.view.kick(3.0, 0.0)
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
	for w in user.get_tree().get_nodes_in_group("breakables"):
		if w.broken:
			continue
		var flat := (w as Node3D).global_position - user.global_position
		flat.y = 0.0
		if flat.length() < 1.9 and flat.normalized().dot(dir) > 0.3:
			Deploy.event(w.uid, "break")


func _strike(c: Node3D) -> void:
	var info := {"damage": DAMAGE, "zone": "body", "distance": 0.0, "point": c.global_position + Vector3(0, 1.0, 0),
		"dir": dir, "attacker": user, "attacker_name": str(user.get("display_name")), "team": team(),
		"gun_name": "肩撞", "build": {}, "effects": {"knock": KNOCK, "stagger": STAGGER}, "moves": ["肩撞"],
		"through_wall": false, "blast": true}
	var killed: bool = c.take_hit(info)
	if user.has_signal("hit_confirmed"):
		user.hit_confirmed.emit({"zone": "body", "damage": DAMAGE, "target": c, "at": info.point}, killed)
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
			p._set_move(Player.Move.GROUND if p.is_on_floor() else Player.Move.AIR, "肩撞結束")
	elif user.has_method("lunge"):
		user.lunge(Vector3.ZERO, 0.0)


func cancel() -> void:
	_end(false)
	super.cancel()
