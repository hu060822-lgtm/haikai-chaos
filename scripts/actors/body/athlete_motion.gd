class_name AthleteMotion
extends RefCounted
## The athlete's motion states (character overhaul, Phase 3): what the body should be
## doing, worked out from the game state alone, as one blended pose description for
## AthleteRig to solve onto the bones. It never moves anything itself.
##
## One state per Player.Move (ground, air, slide, wall run, climb, mantle, dash, stomp,
## grapple, charge). Each frame every state with any weight describes its pose (where
## the pelvis is and how it turns, how the spine leans, where each foot goes, where the
## gun sits, whether the left hand leaves it), and the states cross-fade at their own
## rates, so a slide into a jump or a wall run into a wall jump never pops. On top:
##
##   landing   the pelvis drops by how fast it came down, then settles back on a spring
##   push      leaving a wall (wall jump, wall kick), the wall-side foot stays on the wall
##             for a moment and the leg straightens: the push is visible
##   turning   the hips lag a turn and the body leans into it at speed
##   accel     the body leans into speeding up and back when braking
##   heft      heavy guns sit lower and pull the shoulders back
##
##   var m := AthleteMotion.new()
##   var d := m.update(delta, state)   # state: see AthleteRig.animate

enum { GROUND, AIR, SLIDE, WALLRUN, CLIMB, MANTLE, DASH, SLAM, GRAPPLE, CHARGE }
const NAMES := ["ground", "air", "slide", "wallrun", "climb", "mantle", "dash", "slam", "grapple", "charge"]
## How fast each state fades in (per second).
const FADE := [12.0, 10.0, 14.0, 12.0, 10.0, 14.0, 14.0, 14.0, 10.0, 10.0]
const HIP_Y := 0.935
const ANKLE_Y := 0.088
## How far a wall-running body's centre is from the wall (the player capsule's radius).
const WALL_GAP := 0.38


## A pose description. Everything is in model space (the body faces -Z, feet at y = 0).
class Desc:
	var hip := Vector3.ZERO          # pelvis offset from rest
	var hip_rot := Vector3.ZERO      # x: lean back (+), y: turn left (+), z: roll top to the left (+)
	var spine := Vector3.ZERO        # the same, shared up the spine
	var neck := Vector3.ZERO
	var foot_l := Vector3.ZERO       # ankle targets
	var foot_r := Vector3.ZERO
	var toe_l := 0.0                 # + lifts the toes
	var toe_r := 0.0
	var pole_l := Vector3.ZERO       # which way each knee points
	var pole_r := Vector3.ZERO
	var gun := Vector3.ZERO          # gun offset from its mount
	var gun_rot := Vector3.ZERO      # extra gun turn: x up (+), y left (+), z roll
	var port := 0.0                  # 1: the gun pulled up to the chest (climbing)
	var free_l := 0.0                # 1: the left hand off the gun, at free_at
	var free_at := Vector3.ZERO
	var blade := 1.0                 # how much of the bladed rifle stance

	func mix(o: Desc, w: float) -> void:
		hip += o.hip * w
		hip_rot += o.hip_rot * w
		spine += o.spine * w
		neck += o.neck * w
		foot_l += o.foot_l * w
		foot_r += o.foot_r * w
		toe_l += o.toe_l * w
		toe_r += o.toe_r * w
		pole_l += o.pole_l * w
		pole_r += o.pole_r * w
		gun += o.gun * w
		gun_rot += o.gun_rot * w
		port += o.port * w
		free_l += o.free_l * w
		free_at += o.free_at * w
		blade += o.blade * w

	func feet_from_hip(left: Vector3, right: Vector3) -> void:
		foot_l = Vector3(-0.1, HIP_Y, 0) + hip + left
		foot_r = Vector3(0.1, HIP_Y, 0) + hip + right


var move := GROUND
var move_t := 0.0
var weights: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var phase := 0.0
## Seconds left of a wall push, and which foot (0 left, 1 right). push_new is true on the
## frame one starts (the rig pins the foot where it is).
var push_left := 0.0
var push_foot := 1
var push_new := false
## The landing spring: 0..1 squash and its speed.
var land := 0.0
var _land_v := 0.0
var _vel := Vector3.ZERO          # model-space velocity (smoothed)
var _acc := Vector3.ZERO          # model-space acceleration (smoothed)
var _vy_prev := 0.0
var _floor := true
var _yaw_rate := 0.0
var _dash_dir := Vector3.FORWARD
var _wall := Vector3.ZERO         # model-space wall normal (points away from the wall)
var _crouch := 0.0
var _heft := 0.0
var _climb_phase := 0.0
var _stride := Vector3.ZERO       # the ground stride: heading * reach, eased


## One frame. s: {vel (model space), floor, move, crouch, pitch, wall (model-space normal
## or ZERO), yaw_rate, heft (0..1, how heavy the gun), event ("" or "wall_kick")}.
func update(delta: float, s: Dictionary) -> Desc:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var on_floor: bool = s.get("floor", true)
	var m: int = s.get("move", GROUND)
	var k := 1.0 - exp(-12.0 * delta)
	if delta > 0.0:
		_acc = _acc.lerp((vel - _vel) / delta, 1.0 - exp(-8.0 * delta))
	_vel = vel
	_yaw_rate = lerpf(_yaw_rate, float(s.get("yaw_rate", 0.0)), k)
	_crouch = lerpf(_crouch, float(s.get("crouch", 0.0)), k) if delta > 0.0 else float(s.get("crouch", 0.0))
	_heft = float(s.get("heft", 0.0))
	var wall: Vector3 = s.get("wall", Vector3.ZERO)
	if wall != Vector3.ZERO:
		_wall = wall
	push_new = false
	# Transitions and their one-off events.
	if m != move:
		_enter(m, move, on_floor)
	elif str(s.get("event", "")) == "wall_kick":
		_push()
	if on_floor and not _floor:
		# Touchdown on the lead (right) foot: the stride starts from that contact.
		phase = PI
		if m != SLAM:
			_landed(_vy_prev)
	_floor = on_floor
	_vy_prev = vel.y
	move_t += delta
	push_left = maxf(push_left - delta, 0.0)
	# The landing spring (critically damped, ~0.3 s).
	if delta > 0.0:
		var sub := maxi(ceili(delta / 0.005), 1)
		for i in sub:
			var h := delta / sub
			_land_v += (-160.0 * land - 24.0 * _land_v) * h
			land += _land_v * h
	# Cross-fade: linear in time, eased in and out where the poses meet.
	var eased: Array[float] = []
	var total := 0.0
	for i in weights.size():
		var target := 1.0 if i == move else 0.0
		weights[i] = move_toward(weights[i], target, FADE[move] * delta) if delta > 0.0 else target
		eased.append(smoothstep(0.0, 1.0, weights[i]))
		total += eased[i]
	var out := Desc.new()
	out.blade = 0.0
	for i in weights.size():
		if eased[i] < 0.001:
			continue
		out.mix(_state(i, delta, s), eased[i] / total)
	# Overlays: the landing squash, turning, acceleration, heft.
	var sq := clampf(land, -0.2, 1.2)
	out.hip.y -= 0.24 * sq
	out.hip.z += 0.05 * sq
	out.spine.x -= 0.32 * sq
	out.hip_rot.x -= 0.12 * sq
	out.gun.y -= 0.05 * sq
	var flat := Vector2(_vel.x, _vel.z).length()
	out.hip_rot.y += clampf(-_yaw_rate * 0.07, -0.45, 0.45)
	out.spine.y += clampf(_yaw_rate * 0.05, -0.3, 0.3)
	out.hip_rot.z += clampf(_yaw_rate * flat * 0.012, -0.28, 0.28) * weights[GROUND]
	out.spine.x += clampf(_acc.z * 0.012, -0.22, 0.22) * (weights[GROUND] + weights[CHARGE])
	out.spine.x += 0.06 * _heft
	out.gun.y -= 0.03 * _heft
	return out


func _enter(to: int, from: int, on_floor: bool) -> void:
	if from == WALLRUN and to != CLIMB:
		_push()
	if to == DASH:
		var d := Vector3(_vel.x, 0, _vel.z)
		_dash_dir = d.normalized() if d.length() > 0.5 else Vector3.FORWARD
	if to == SLAM:
		pass
	if from == SLAM and on_floor:
		# The stomp lands: the deepest squash there is.
		_landed(-26.0)
	move = to
	move_t = 0.0


func _push() -> void:
	push_left = 0.2
	push_new = true
	push_foot = 1 if _wall.x < 0.0 else 0


func _landed(vy: float) -> void:
	var hit := clampf((-vy - 2.5) / 14.0, 0.0, 1.0)
	if hit <= 0.0:
		return
	_land_v += 16.0 * (0.35 + hit)


func _state(i: int, delta: float, s: Dictionary) -> Desc:
	match i:
		GROUND: return _ground(delta, s, false)
		AIR: return _air(s)
		SLIDE: return _slide(s)
		WALLRUN: return _wallrun(delta)
		CLIMB: return _climb(delta)
		MANTLE: return _mantle()
		DASH: return _dash()
		SLAM: return _slam()
		GRAPPLE: return _grapple()
		CHARGE: return _ground(delta, s, true)
	return Desc.new()


# --- States ------------------------------------------------------------------------------------

## Stride: the stance foot moves straight back under the body at its speed (no sliding),
## the swing foot lifts and comes forward. Returns [offset along the move, lift, toe].
static func stride(ph: float, amp: float, lift_h: float) -> Array:
	var p := fposmod(ph, TAU)
	if p < PI:
		var u := p / PI
		var toe := -0.55 * clampf((u - 0.7) / 0.3, 0.0, 1.0) * clampf(lift_h / 0.12, 0.0, 1.0)
		return [amp * (1.0 - 2.0 * u), 0.0, toe]
	var w := (p - PI) / PI
	var e := w * w * (3.0 - 2.0 * w)
	return [amp * (-1.0 + 2.0 * e), lift_h * sin(w * PI), lerpf(-0.35, 0.2, clampf(w * 2.0, 0.0, 1.0)) * clampf(lift_h / 0.12, 0.0, 1.0)]


func _ground(delta: float, s: Dictionary, charge: bool) -> Desc:
	var d := Desc.new()
	var flat := Vector3(_vel.x, 0, _vel.z)
	var v := flat.length()
	# Turning on the spot steps the feet round too.
	var drive := maxf(v, absf(_yaw_rate) * 0.35)
	var dir := flat.normalized() if v > 0.3 else Vector3.FORWARD
	var amp := clampf(drive * 0.075, 0.0, 0.52) * (1.0 - _crouch * 0.35)
	if amp > 0.001 and delta > 0.0 and (move == GROUND or move == CHARGE):
		phase += delta * PI * drive / (2.0 * maxf(amp, 0.05))
	# The stride's reach and heading ease to a new direction or a stop (a hard strafe or a
	# dash never snaps the feet across).
	if delta > 0.0 and (move == GROUND or move == CHARGE):
		_stride = _stride.lerp(dir * amp, 1.0 - exp(-14.0 * delta))
	var reach := _stride.length()
	if reach > 0.001:
		dir = _stride / reach
	amp = reach
	var run := clampf(v / 7.0, 0.0, 1.6)
	var sprint := clampf((v - 8.0) / 3.0, 0.0, 1.0)
	var lift_h := 0.14 * clampf(drive / 3.0, 0.0, 1.0) + 0.06 * sprint
	var stance := 0.11 + 0.05 * _crouch + 0.025 * _heft
	var feet: Array[Vector3] = []
	var toes: Array[float] = []
	for leg in 2:
		var sx := -1.0 if leg == 0 else 1.0
		var st := stride(phase + PI * leg, amp, lift_h)
		feet.append(Vector3(sx * stance, ANKLE_Y + float(st[1]), 0.02) + dir * float(st[0]))
		toes.append(float(st[2]))
	d.foot_l = feet[0]
	d.foot_r = feet[1]
	d.toe_l = toes[0]
	d.toe_r = toes[1]
	d.pole_l = Vector3(-0.25, 0, -1)
	d.pole_r = Vector3(0.25, 0, -1)
	var bob := -0.04 * minf(run, 1.2) * (0.5 - 0.5 * cos(2.0 * phase))
	# Soft knees even standing (an athlete, not a mannequin); lower still at a run.
	d.hip = Vector3(0, bob - 0.035 - 0.36 * _crouch - 0.03 * run, 0.06 * _crouch)
	d.hip_rot = Vector3(-0.25 * _crouch, sin(phase) * 0.09 * minf(run, 1.0), 0)
	var lean := 0.07 * minf(v / 7.0, 1.5) + 0.08 * sprint
	d.spine = Vector3(-lean + 0.18 * _crouch, -sin(phase) * 0.1 * minf(run, 1.0), 0)
	# Sprinting lowers the gun across the body; charging drops a shoulder into it.
	d.gun_rot = Vector3(-0.45 * sprint, 0.35 * sprint, 0)
	d.gun = Vector3(-0.03 * sprint, -0.06 * sprint, 0.04 * sprint)
	if charge:
		d.spine.x -= 0.3
		d.hip.y -= 0.06
		d.gun_rot = Vector3(-0.6, 0.4, 0)
		d.gun = Vector3(-0.04, -0.1, 0.06)
		d.blade = 1.4
	return d


func _air(s: Dictionary) -> Desc:
	var d := Desc.new()
	var vy := _vel.y
	# Rising: the lead knee drives up, the other leg trails; falling: both reach down for
	# the floor, a little forward. Crouch tucks them up.
	# (Fading out after a touchdown it stays in its reaching-down shape.)
	var fall := 1.0 if _floor else clampf((1.5 - vy) / 7.0, 0.0, 1.0)
	var tuck := clampf(float(s.get("crouch", 0.0)), 0.0, 1.0)
	var drift := Vector3(_vel.x, 0, _vel.z) * -0.012
	var up_l := Vector3(0.0, -0.8, 0.14)
	var up_r := Vector3(0.02, -0.42, -0.22)
	var down_l := Vector3(-0.02, -0.72, -0.08)
	var down_r := Vector3(0.02, -0.69, -0.14)
	var l := up_l.lerp(down_l, fall).lerp(Vector3(-0.02, -0.45, -0.2), tuck) + drift
	var r := up_r.lerp(down_r, fall).lerp(Vector3(0.02, -0.42, -0.24), tuck) + drift
	d.hip = Vector3(0, 0.02, 0)
	d.feet_from_hip(l, r)
	d.toe_l = lerpf(-0.45, -0.1, fall)
	d.toe_r = lerpf(-0.2, -0.05, fall)
	d.pole_l = Vector3(-0.2, 0, -1)
	d.pole_r = Vector3(0.2, 0, -1)
	d.spine = Vector3(-0.08 + 0.06 * fall, 0, 0)
	d.hip_rot = Vector3(-0.08 * (1.0 - fall), 0, 0)
	return d


func _slide(_s: Dictionary) -> Desc:
	var d := Desc.new()
	d.hip = Vector3(0, -0.53, 0.04)
	d.hip_rot = Vector3(0.22, 0.12, -0.08)
	d.spine = Vector3(0.12, -0.15, 0.06)
	d.foot_r = Vector3(0.14, 0.09, -0.56)
	d.foot_l = Vector3(-0.17, 0.065, 0.14)
	d.toe_r = 0.5
	d.toe_l = -0.6
	d.pole_r = Vector3(0.2, 0.4, -1)
	d.pole_l = Vector3(-0.3, -1.0, -0.4)
	return d


func _wallrun(delta: float) -> Desc:
	var d := Desc.new()
	# The body tips with its feet toward the wall and runs along it.
	var side := -signf(_wall.x) if absf(_wall.x) > 0.1 else 1.0
	var roll := 0.38 * side
	var v := Vector3(_vel.x, 0, _vel.z).length()
	var amp := clampf(v * 0.06, 0.15, 0.48)
	if delta > 0.0 and move == WALLRUN:
		phase += delta * PI * v / (2.0 * amp)
	var tilt := Basis(Vector3.BACK, roll)
	var feet: Array[Vector3] = []
	var toes: Array[float] = []
	for leg in 2:
		var sx := -1.0 if leg == 0 else 1.0
		var st := stride(phase + PI * leg, amp, 0.14)
		var rel := Vector3(sx * 0.12, -0.8 + float(st[1]), -float(st[0]) - 0.05)
		feet.append(tilt * rel)
		toes.append(float(st[2]))
	d.hip = Vector3(0.06 * side, -0.04, 0)
	d.hip_rot = Vector3(-0.1, 0, roll)
	d.spine = Vector3(-0.12, 0, -roll * 0.45)
	d.neck = Vector3(0, 0, -roll * 0.3)
	d.feet_from_hip(feet[0], feet[1])
	# The soles land on the wall, not in it.
	var reach := WALL_GAP - 0.05
	d.foot_l.x = maxf(d.foot_l.x, -reach) if side < 0.0 else minf(d.foot_l.x, reach)
	d.foot_r.x = maxf(d.foot_r.x, -reach) if side < 0.0 else minf(d.foot_r.x, reach)
	d.toe_l = toes[0]
	d.toe_r = toes[1]
	d.pole_l = Vector3(-0.2, 0, -1)
	d.pole_r = Vector3(0.2, 0, -1)
	return d


func _climb(delta: float) -> Desc:
	var d := Desc.new()
	# Facing the wall: the feet run up it, the left hand reaches over the top, the gun is
	# pulled up against the chest in the right hand.
	if delta > 0.0 and move == CLIMB:
		_climb_phase += delta * 11.0
	var a := sin(_climb_phase)
	d.hip = Vector3(0, -0.06, -0.06)
	d.hip_rot = Vector3(-0.25, 0, 0)
	d.spine = Vector3(-0.18, 0, 0)
	d.neck = Vector3(0.35, 0, 0)
	d.feet_from_hip(Vector3(-0.02, -0.55 + 0.18 * a, -0.3), Vector3(0.02, -0.55 - 0.18 * a, -0.3))
	d.toe_l = 0.4
	d.toe_r = 0.4
	d.pole_l = Vector3(-0.3, 0.2, -1)
	d.pole_r = Vector3(0.3, 0.2, -1)
	d.port = 1.0
	d.free_l = 1.0
	d.free_at = Vector3(-0.2, 1.78 + 0.12 * a, -0.33)
	d.blade = 0.0
	return d


func _mantle() -> Desc:
	var d := Desc.new()
	# Over the top: the left hand planted on the ledge, the knees tucked up and through.
	var t := clampf(move_t / 0.3, 0.0, 1.0) if move == MANTLE else 1.0
	d.hip = Vector3(0, 0.05 * t, -0.05)
	d.hip_rot = Vector3(-0.45, 0.1, 0)
	d.spine = Vector3(-0.3, 0.1, 0)
	d.feet_from_hip(Vector3(-0.1, -0.38 + 0.05 * t, -0.18), Vector3(0.08, -0.5, -0.05))
	d.toe_l = 0.3
	d.toe_r = -0.2
	d.pole_l = Vector3(-0.2, 0.3, -1)
	d.pole_r = Vector3(0.2, 0, -1)
	d.port = 0.8
	d.free_l = 1.0
	d.free_at = Vector3(-0.16, 1.02 - 0.15 * t, -0.42)
	d.blade = 0.0
	return d


func _dash() -> Desc:
	var d := Desc.new()
	# A lunge: leaning hard the way it goes, the lead leg tucked, the trailing leg long.
	var dd := _dash_dir
	d.hip = Vector3(0, -0.05, 0) + dd * 0.04
	d.hip_rot = Vector3(dd.z * 0.25, 0, dd.x * 0.3)
	d.spine = Vector3(dd.z * 0.25, 0, dd.x * 0.2)
	var lead := dd * 0.3 + Vector3(0, -0.5, 0)
	var trail := -dd * 0.42 + Vector3(0, -0.78, 0)
	var right_leads := dd.x > 0.3 or (absf(dd.x) <= 0.3 and dd.z < 0.0)
	if right_leads:
		d.feet_from_hip(trail, lead)
	else:
		d.feet_from_hip(lead, trail)
	d.toe_l = -0.4
	d.toe_r = -0.4
	d.pole_l = Vector3(-0.2, 0, -1)
	d.pole_r = Vector3(0.2, 0, -1)
	return d


func _slam() -> Desc:
	var d := Desc.new()
	# Wind-up (knees to the chest, gun up), then straight down, legs together.
	var wind := clampf(1.0 - move_t / 0.14, 0.0, 1.0) if move == SLAM else 0.0
	var up_l := Vector3(-0.02, -0.34, -0.2)
	var up_r := Vector3(0.02, -0.34, -0.2)
	var down_l := Vector3(0.0, -0.84, 0.02)
	var down_r := Vector3(0.0, -0.84, 0.02)
	d.feet_from_hip(down_l.lerp(up_l, wind), down_r.lerp(up_r, wind))
	d.hip = Vector3(0, 0.04, 0)
	d.toe_l = lerpf(-0.6, 0.2, wind)
	d.toe_r = lerpf(-0.6, 0.2, wind)
	d.pole_l = Vector3(-0.15, 0, -1)
	d.pole_r = Vector3(0.15, 0, -1)
	d.spine = Vector3(lerpf(0.05, -0.35, wind), 0, 0)
	d.gun_rot = Vector3(lerpf(-0.25, 0.35, wind), 0, 0)
	d.gun = Vector3(0, lerpf(0.0, 0.06, wind), 0)
	return d


func _grapple() -> Desc:
	var d := Desc.new()
	# Pulled along the rope: the body stretches toward it, the left hand reaches the way it
	# goes, the legs trail.
	var vd := _vel.normalized() if _vel.length() > 1.0 else Vector3.FORWARD
	var trail := -vd * 0.35 + Vector3(0, -0.72, 0)
	d.feet_from_hip(trail + Vector3(-0.06, 0.05, 0), trail + Vector3(0.06, -0.05, 0.08))
	d.hip_rot = Vector3(vd.z * 0.2, 0, vd.x * 0.25)
	d.spine = Vector3(vd.z * 0.2 + vd.y * 0.15, 0, vd.x * 0.15)
	d.toe_l = -0.5
	d.toe_r = -0.5
	d.pole_l = Vector3(-0.2, 0, -1)
	d.pole_r = Vector3(0.2, 0, -1)
	d.free_l = 1.0
	d.free_at = Vector3(-0.19, 1.43, 0) + (vd + Vector3(0, 0.25, 0)).normalized() * 0.56
	d.blade = 0.5
	return d
