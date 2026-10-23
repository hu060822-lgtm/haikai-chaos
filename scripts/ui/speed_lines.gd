class_name SpeedLines
extends Control
## Speed lines in print style: short ink dashes streaming out from the screen's edges when
## you're faster than a sprint, thicker and longer the faster you go. They stay out of the
## middle third so they never cover what you're aiming at. Off when camera effects are off.

const COUNT := 46

var player: Player
var _seeds: Array[Vector3] = []   # angle, distance phase, speed
var _t := 0.0


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in COUNT:
		_seeds.append(Vector3(rng.randf() * TAU, rng.randf(), rng.randf_range(0.7, 1.3)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if player == null or CameraFx.intensity() <= 0.0:
		return
	var v := player.velocity.length()
	# C7: they start at a run, not past a sprint, and grow faster.
	var k := clampf((v - player.tune.run_speed * 1.15) / 11.0, 0.0, 1.0) * CameraFx.intensity() * lerpf(1.0, 0.3, player._aim)
	if k <= 0.01:
		return
	_vignette(k)
	var c := size / 2.0
	# Lines stream from where you're heading: shift the centre toward the velocity on screen.
	var local := player.camera.global_basis.inverse() * player.velocity
	if local.z < -0.5:
		c += Vector2(local.x / -local.z, -local.y / -local.z) * size.y * 0.5
	var r_max := size.length() * 0.6
	for s in _seeds:
		var phase := fmod(s.y + _t * s.z * (0.8 + k * 1.6), 1.0)
		var r0 := lerpf(r_max * 0.42, r_max, phase)
		var length := (30.0 + 120.0 * k) * s.z
		var dir := Vector2(cos(s.x), sin(s.x))
		var a := c + dir * r0
		var col := Color(Faultprint.ui_ink, 0.55 * k * sin(phase * PI))
		draw_line(a, a + dir * length, col, 1.5 + 2.5 * k)


## The edges of the view close in a little at speed (C7): a soft dark band all round.
func _vignette(k: float) -> void:
	var w := size.x
	var h := size.y
	var band := minf(w, h) * (0.08 + 0.1 * k)
	var dark := Color(0, 0, 0, 0.34 * k)
	var clear := Color(0, 0, 0, 0.0)
	var outer := [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	var inner := [Vector2(band, band), Vector2(w - band, band), Vector2(w - band, h - band), Vector2(band, h - band)]
	for i in 4:
		var j := (i + 1) % 4
		draw_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), PackedColorArray([dark, dark, clear, clear]))
