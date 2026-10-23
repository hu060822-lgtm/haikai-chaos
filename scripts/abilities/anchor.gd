class_name Anchor
extends Ability
## ANCHOR's grappling line (C6). Not a fixed pull: the hook flies out at HOOK_SPEED, and
## once it bites the player is on a rope (Player Move.GRAPPLE) where gravity, the reel and
## the rope's length shape the arc together:
##
##   hold F     reel in (the rope shortens at REEL m/s and pulls at PULL m/s²): a fast zip
##   tap F      the hook bites with the rope at its length: a pendulum swing
##   move keys  pump the swing (STEER m/s² of air control on the rope)
##   let go     release F (after a hold) or press F again (after a tap): off the rope with
##              all the speed of the arc, aimed wherever the swing was going
##   jump       a release that adds a hop (RELEASE_HOP up)
##   dash       cuts the rope and dashes
##
## A slide or a wall run straight after keeps the speed, like any landing. Counter: the line
## is drawn and heard by everyone, the hook takes time to land, the path follows the rope
## (a circle round the hook point) so it can be read and shot.

const RANGE := 34.0
const HOOK_SPEED := 95.0
const REEL := 13.0
const PULL := 24.0
const STEER := 9.0
const MIN_ROPE := 2.0
const MAX_TIME := 3.2
const MAX_SPEED := 27.0
const RELEASE_HOP := 5.5
## While reeling the line carries most of the weight, and a bite from the floor lifts off.
const REEL_GRAVITY := 0.35
const LIFT_OFF := 4.0
## A miss only costs this much of the cooldown.
const MISS_REFUND := 0.7

enum State { IDLE, FLYING, ATTACHED }

var state := State.IDLE
var hook := Vector3.ZERO
var point := Vector3.ZERO
var rope := 0.0
var held := false
var reeling := false
var _dir := Vector3.FORWARD
var _flown := 0.0
var _time := 0.0


func press() -> void:
	if state == State.ATTACHED:
		if not reeling:
			_let_go(user as Player, false)
		return
	if state != State.IDLE or not alive():
		return
	if charges < 1.0:
		say("勾索還在冷卻")
		return
	spend()
	held = true
	var a := aim()
	hook = a.origin
	_dir = -a.basis.z
	_flown = 0.0
	state = State.FLYING
	busy = true
	Sfx.play(user, "hook_fire", -6.0)
	Deploy.fx(user, "hook", {"from": hook, "dir": _dir})


func release() -> void:
	held = false
	if state == State.ATTACHED and reeling:
		_let_go(user as Player, false)


func tick(delta: float) -> void:
	super.tick(delta)
	if state == State.ATTACHED and user is Player and (user as Player).move != Player.Move.GRAPPLE:
		_let_go(null, false)
	if state != State.FLYING:
		return
	if not alive():
		cancel()
		return
	var step := HOOK_SPEED * delta
	var to := hook + _dir * step
	var exclude: Array = user.exclusions() if user.has_method("exclusions") else []
	exclude.append((user as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(hook, to, Geo.WORLD, exclude)
	var hit := user.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_bite(hit.position)
		return
	hook = to
	_flown += step
	if _flown >= RANGE:
		# Nothing to bite: the line comes back and most of the charge with it.
		charges = minf(charges + MISS_REFUND, max_charges())
		state = State.IDLE
		busy = false
		Deploy.fx(user, "rope_off", {})
		say("勾索沒勾到東西")


func _bite(at: Vector3) -> void:
	var p := user as Player
	point = at
	hook = at
	state = State.ATTACHED
	reeling = held
	_time = 0.0
	rope = maxf(_centre(p).distance_to(point), MIN_ROPE)
	Sfx.play(user, "hook_hit", -4.0)
	if reeling:
		Sfx.play(user, "hook_reel", -10.0)
	Deploy.fx(user, "rope_on", {"at": point})
	if p != null:
		if reeling and p.is_on_floor():
			p.velocity.y = maxf(p.velocity.y, LIFT_OFF)
		p._set_move(Player.Move.GRAPPLE, "勾索勾到")


func _centre(p: Node3D) -> Vector3:
	return p.global_position + Vector3(0, 1.0, 0)


## One physics tick on the rope (called by the Player while in GRAPPLE).
func move_frame(p: Player, delta: float, wish: Vector3) -> void:
	if state != State.ATTACHED:
		p._set_move(Player.Move.AIR, "勾索斷了")
		return
	_time += delta
	if p._want("dash", true) and p._dash_charge >= 1.0:
		_let_go(p, false)
		p._start_dash(wish)
		return
	if p._buffer > 0.0:
		p._buffer = 0.0
		_let_go(p, true)
		return
	var c := _centre(p)
	var to := point - c
	var d := to.length()
	var n := to / maxf(d, 0.001)
	# The rope can't pass through walls: lose sight of the hook, lose the hook.
	var exclude: Array = p.exclusions()
	exclude.append(p.get_rid())
	var q := PhysicsRayQueryParameters3D.create(c, point - n * 0.25, Geo.WORLD, exclude)
	if not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		_let_go(p, false, "勾索被擋住了")
		return
	var v := p.velocity
	v.y -= p.tune.gravity * (REEL_GRAVITY if reeling else 1.0) * delta
	if reeling:
		rope = maxf(rope - REEL * delta, MIN_ROPE)
		v += n * PULL * delta
	v += wish * STEER * delta
	# The rope: no moving outward once it's taut, and a firm tug back if past its length.
	var radial := v.dot(n)
	if d >= rope - 0.02 and radial < 0.0:
		v -= n * radial
	if d > rope + 0.05:
		v += n * minf((d - rope) * 12.0, 30.0) * delta * 10.0
	if v.length() > MAX_SPEED:
		v = v.normalized() * MAX_SPEED
	p.velocity = v
	p.limiter = "勾索（收索中）" if reeling else "勾索（擺盪）"
	if _time >= MAX_TIME:
		_let_go(p, false, "勾索到時間了")
	elif reeling and d <= MIN_ROPE + 0.4:
		_let_go(p, true)


func _let_go(p: Player, hop: bool, why := "放開勾索") -> void:
	state = State.IDLE
	busy = false
	reeling = false
	Deploy.fx(user, "rope_off", {})
	if p == null:
		return
	if hop:
		p.velocity.y = maxf(p.velocity.y, 0.0) + RELEASE_HOP
		why = "放索跳"
		Sfx.play(p, "jump", -6.0)
	if p.move == Player.Move.GRAPPLE:
		p._set_move(Player.Move.AIR, why)


func cancel() -> void:
	if state != State.IDLE:
		Deploy.fx(user, "rope_off", {})
	state = State.IDLE
	busy = false
	reeling = false
	held = false
	var p := user as Player
	if p != null and p.move == Player.Move.GRAPPLE:
		p._set_move(Player.Move.AIR, "勾索取消")


## Where the line goes now, for drawing it (INF when there is none).
func line_end() -> Vector3:
	return hook if state != State.IDLE else Vector3.INF
