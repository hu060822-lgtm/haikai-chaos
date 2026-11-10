class_name VeilTrail
extends Ability
## 霧行者 VEIL's ability (C13; it threw one big cloud before smoke went on everyone's belt).
## Press F and for TRAIL seconds you leave a wall of smoke behind you: a small cloud every
## SPACING metres along the way you actually move, wherever you are (on a wall run it hangs
## up on the wall, off a line it hangs in the air), and you move HASTE faster while it lasts.
## So the route is the smoke: a slide across an open lane cuts the lane in two, a wall run
## along a corridor fills its upper half. Press F again to stop early.
##
## Each puff is an ordinary SmokeCloud (blocks sight for everyone, blown thin by blasts) sent
## through Deploy, so every machine has the same wall.

const TRAIL := 3.5
const SPACING := 2.4
const HASTE := 1.15
const PUFF_RADIUS := 2.3
const PUFF_HEIGHT := 1.9
const PUFF_LIFE := 7.0
const MAX_PUFFS := 16

var left := 0.0
var dropped := 0
var _last := Vector3.INF


func press() -> void:
	if not alive():
		return
	if busy:
		_stop()
		return
	if charges < 1.0:
		say("霧行還在冷卻")
		return
	spend()
	busy = true
	left = TRAIL
	dropped = 0
	_last = Vector3.INF
	_drop()
	Sfx.play(user, "smoke_throw", -6.0)


func tick(delta: float) -> void:
	if not busy:
		super.tick(delta)
		return
	if not alive():
		_stop()
		return
	left -= delta
	var at := user.global_position
	if _last == Vector3.INF or at.distance_to(_last) >= SPACING:
		_drop()
	if left <= 0.0 or dropped >= MAX_PUFFS:
		_stop()


func cancel() -> void:
	_stop()


func _stop() -> void:
	busy = false
	left = 0.0


func _drop() -> void:
	var at := user.global_position
	_last = at
	dropped += 1
	Deploy.spawn("smoke", user, {"from": at, "to": at - Vector3(0, 0.3, 0), "flight": 0.02, "radius": PUFF_RADIUS,
		"height": PUFF_HEIGHT, "life": PUFF_LIFE, "puffs": 5, "canister": false})
	Sfx.play(user, "smoke_pop", -16.0, 30.0)


## 0..1 of the trail still to run (HUD).
func trail_left() -> float:
	return clampf(left / TRAIL, 0.0, 1.0) if busy else 0.0
