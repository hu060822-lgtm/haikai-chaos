class_name CameraFx
extends RefCounted
## The camera's feel effects, each on its own spring or smoother with its own strength and
## recovery, so several at once add up predictably instead of stacking into a shake:
##   fov      a few degrees wider at high speed (smoothed)
##   roll     tilt away from the wall on a wall run, a little on slides (smoothed)
##   pitch    short dips from landing, jumps and wall kicks (spring)
##   height   eye drop on landings (spring)
##   shake    hard landings and slams only, and only at full strength
## Recoil is not here: it moves your aim, so the player owns it.
## `intensity` is the player's setting (F5): 1 full, 0.4 reduced (no shake), 0 off.

const LEVELS := [[1.0, "完整"], [0.4, "減少"], [0.0, "關閉"]]
const SETTINGS := "user://settings.cfg"

static var level := 0

var fov := 0.0
var roll := 0.0
var pitch := 0.0
var height := 0.0
var shake := Vector2.ZERO
var _pitch := Spring.new(170.0, 22.0)
var _height := Spring.new(140.0, 20.0)
var _roll := Spring.new(120.0, 18.0)
var _roll_smooth := 0.0
var _shake_left := 0.0
var _shake_amount := 0.0


static func intensity() -> float:
	return LEVELS[level][0]


static func level_name() -> String:
	return LEVELS[level][1]


static func cycle() -> void:
	level = (level + 1) % LEVELS.size()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("camera", "fx_level", level)
	cfg.save(SETTINGS)


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		level = clampi(int(cfg.get_value("camera", "fx_level", 0)), 0, LEVELS.size() - 1)


## Landing: `strength` 0..1 from fall speed.
func land(strength: float) -> void:
	_pitch.kick(-0.9 * strength)
	_height.kick(-1.6 * strength)
	if strength > 0.75:
		_shake_left = 0.18
		_shake_amount = 0.006 * strength


func jump() -> void:
	_pitch.kick(0.25)


## Kick off a wall; `side` is +1 when the wall was on your right.
func wall_kick(side: float) -> void:
	_pitch.kick(0.35)
	_roll.kick(0.6 * side)


## Getting hit: a small knock away from where it came from (`side` +1 = from the right).
func hurt(side: float) -> void:
	_pitch.kick(0.3)
	_roll.kick(-0.35 * side)


func slam() -> void:
	_height.kick(-3.0)
	_shake_left = 0.3
	_shake_amount = 0.012


## Every frame. `roll_target` and `fov_target` come from the movement state; `aim` (0..1)
## calms everything so aiming stays precise.
func update(delta: float, roll_target: float, fov_target: float, aim: float) -> void:
	var k := intensity() * lerpf(1.0, 0.35, aim)
	_roll_smooth = lerpf(_roll_smooth, roll_target, 1.0 - exp(-7.0 * delta))
	roll = (_roll_smooth + _roll.step(delta)) * k
	fov = lerpf(fov, fov_target * k, 1.0 - exp(-6.0 * delta))
	pitch = _pitch.step(delta) * k
	height = _height.step(delta) * k
	_shake_left = maxf(_shake_left - delta, 0.0)
	if _shake_left > 0.0 and level == 0 and aim < 0.5:
		var a := _shake_amount * _shake_left / 0.3
		shake = Vector2(randf_range(-a, a), randf_range(-a, a))
	else:
		shake = Vector2.ZERO


## A damped spring around 0 (radians or metres). Sub-steps keep it the same at any tick rate.
class Spring:
	var stiffness: float
	var damping: float
	var value := 0.0
	var speed := 0.0

	func _init(k: float, c: float) -> void:
		stiffness = k
		damping = c

	func kick(v: float) -> void:
		speed += v

	func step(delta: float) -> float:
		var steps := maxi(ceili(delta / 0.0042), 1)
		var h := delta / steps
		for i in steps:
			speed += (-stiffness * value - damping * speed) * h
			value += speed * h
		return value
