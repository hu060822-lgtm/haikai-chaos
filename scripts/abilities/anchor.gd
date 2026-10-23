class_name Anchor
extends Ability
## ANCHOR's grappling line (C6, reworked in C8 after ULTRAKILL's whiplash and Apex's
## Pathfinder). The hook flies out at HOOK_SPEED; once it bites, the line pulls you at
## the hook (Player Move.GRAPPLE): the speed toward it builds to PULL_SPEED, while all the
## sideways speed you came in with stays, so coming in from an angle swings you round it.
##
##   tap F      fire and forget: it pulls you all the way in and pops you over the top
##   hold F     pull while held, let go of F to drop off with all the speed
##   F again    drop off now (after a tap)
##   move keys  steer the swing (STEER m/s² of air control on the line)
##   jump       drop off with a hop (RELEASE_HOP up)
##   dash       cuts the line and dashes
##
## Short cooldown (Kit: 0.5 s): it's a movement tool, chained hook to hook. A slide or a
## wall run straight after keeps the speed. Counter: the line is drawn and heard by
## everyone, and the path is a straight pull at a point you can see, so it can be read
## and shot.

const RANGE := 38.0
const HOOK_SPEED := 120.0
## The pull: speed toward the hook builds at PULL_ACCEL up to PULL_SPEED.
const PULL_SPEED := 26.0
const PULL_ACCEL := 75.0
## The line shortens at least this fast, so a swing still closes in.
const REEL := 16.0
const STEER := 12.0
const MIN_ROPE := 1.6
const MAX_TIME := 2.5
const MAX_SPEED := 36.0
const RELEASE_HOP := 5.5
## Arriving pops you up this much, over a ledge or a wall top.
const ARRIVE_POP := 6.5
## On the line gravity is mostly off.
const REEL_GRAVITY := 0.25
const LIFT_OFF := 4.0
## A press shorter than this is a tap (fire and forget).
const TAP := 0.22
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
var _held_t := 0.0
## Fire and forget (the press was a tap).
var tapped := false


func press() -> void:
	if state == State.ATTACHED:
		_let_go(user as Player, false)
		return
	if state != State.IDLE or not alive():
		return
	if charges < 1.0:
		say("勾索還在冷卻")
		return
	spend()
	held = true
	tapped = false
	_held_t = 0.0
	var a := aim()
	hook = a.origin
	_dir = -a.basis.z
	_flown = 0.0
	state = State.FLYING
	busy = true
	Sfx.play(user, "hook_fire", -6.0)
	Deploy.fx(user, "hook", {"from": hook, "dir": _dir})


func release() -> void:
	if not held:
		return
	held = false
	if _held_t < TAP:
		tapped = true
	elif state == State.ATTACHED:
		_let_go(user as Player, false)


func tick(delta: float) -> void:
	super.tick(delta)
	if held:
		_held_t += delta
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
	reeling = true
	_time = 0.0
	rope = maxf(_centre(p).distance_to(point), MIN_ROPE)
	Sfx.play(user, "hook_hit", -4.0)
	Sfx.play(user, "hook_reel", -10.0)
	Deploy.fx(user, "rope_on", {"at": point})
	if p != null:
		if p.is_on_floor():
			p.velocity.y = maxf(p.velocity.y, LIFT_OFF)
		p.burst(0.5)
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
	v.y -= p.tune.gravity * REEL_GRAVITY * delta
	rope = maxf(minf(rope, d) - REEL * delta, MIN_ROPE)
	# The pull: speed toward the hook builds to PULL_SPEED; sideways speed is left alone.
	var toward := v.dot(n)
	if toward < PULL_SPEED:
		v += n * minf(PULL_ACCEL * delta, PULL_SPEED - toward)
	v += (wish - n * wish.dot(n)) * STEER * delta
	# The line: no moving away once it's taut, and a firm tug back if past its length.
	var radial := v.dot(n)
	if d >= rope - 0.02 and radial < 0.0:
		v -= n * radial
	if d > rope + 0.05:
		v += n * minf((d - rope) * 12.0, 30.0) * delta * 10.0
	if v.length() > MAX_SPEED:
		v = v.normalized() * MAX_SPEED
	p.velocity = v
	p.limiter = "勾索（拉過去）"
	if _time >= MAX_TIME:
		_let_go(p, false, "勾索到時間了")
	elif d <= MIN_ROPE + 0.5 or (d < 4.0 and v.dot(n) < 1.0 and _time > 0.25):
		_arrive(p)


## Pulled all the way in: off the line with a pop up, over whatever the hook was on.
func _arrive(p: Player) -> void:
	_let_go(p, false, "勾索拉到了")
	p.velocity.y = maxf(p.velocity.y, ARRIVE_POP)


func _let_go(p: Player, hop: bool, why := "放開勾索") -> void:
	state = State.IDLE
	busy = false
	reeling = false
	Deploy.fx(user, "rope_off", {})
	if p == null:
		return
	p.burst(0.7)
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
	tapped = false
	var p := user as Player
	if p != null and p.move == Player.Move.GRAPPLE:
		p._set_move(Player.Move.AIR, "勾索取消")


## Where the line goes now, for drawing it (INF when there is none).
func line_end() -> Vector3:
	return hook if state != State.IDLE else Vector3.INF
