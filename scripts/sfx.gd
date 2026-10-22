class_name Sfx
## Placeholder sounds, synthesised at startup (no audio files yet): short noise bursts for
## shots, thumps for landings, whooshes for movement. Each weapon class has its own shot
## so you can hear what's shooting at you. Swap for real recordings later.

const RATE := 22050
static var _cache := {}


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## A sound: noise and a falling tone mixed, with an exponential decay.
static func _make(seconds: float, noise: float, tone_hz: float, tone_end: float, decay: float, crunch := 0.0) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tone_hz * 13 + seconds * 1000)
	var phase := 0.0
	var held := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay) * minf(t * 900.0, 1.0)
		phase += TAU * lerpf(tone_hz, tone_end, t / seconds) / RATE
		if i % int(1 + crunch * 6) == 0:
			held = rng.randf_range(-1.0, 1.0)
		s[i] = (held * noise + sin(phase) * (1.0 - noise)) * env * 0.8
	return _wav(s)


static func _stream(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var w: AudioStreamWAV
	match id:
		"shot_rapid": w = _make(0.12, 0.8, 220.0, 90.0, 38.0, 0.3)
		"shot_heavy": w = _make(0.35, 0.75, 120.0, 40.0, 12.0, 0.6)
		"shot_precise": w = _make(0.3, 0.7, 520.0, 120.0, 16.0, 0.1)
		"shot_odd": w = _make(0.25, 0.4, 900.0, 300.0, 14.0, 0.0)
		"shot_quiet": w = _make(0.1, 0.9, 400.0, 200.0, 45.0, 0.0)
		"jump": w = _make(0.12, 0.5, 260.0, 380.0, 30.0)
		"land": w = _make(0.15, 0.6, 90.0, 50.0, 26.0, 0.4)
		"slide": w = _make(0.5, 0.95, 200.0, 150.0, 5.0, 0.0)
		"wallrun": w = _make(0.35, 0.9, 300.0, 300.0, 7.0, 0.1)
		"kick": w = _make(0.12, 0.5, 180.0, 340.0, 28.0, 0.2)
		"climb": w = _make(0.2, 0.7, 200.0, 260.0, 16.0, 0.3)
		"mantle": w = _make(0.18, 0.6, 140.0, 220.0, 20.0, 0.3)
		"dash": w = _make(0.22, 0.95, 500.0, 200.0, 12.0, 0.0)
		"slam": w = _make(0.5, 0.7, 70.0, 30.0, 8.0, 0.8)
		"hit": w = _make(0.06, 0.1, 1800.0, 1600.0, 60.0)
		"head": w = _make(0.1, 0.05, 2600.0, 2400.0, 34.0)
		"kill": w = _make(0.25, 0.1, 900.0, 1500.0, 12.0)
		_: w = _make(0.1, 0.5, 300.0, 200.0, 30.0)
	_cache[id] = w
	return w


## Rushing air for speed: two seconds of soft, low-passed noise that loops.
static func wind() -> AudioStreamWAV:
	if _cache.has("wind"):
		return _cache.wind
	var n := RATE * 2
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.08)
		lp2 = lerpf(lp2, lp, 0.2)
		# Fade the ends together so the loop has no click.
		var edge := minf(minf(float(i), float(n - i)) / 2000.0, 1.0)
		s[i] = lp2 * 2.4 * edge + lp2 * 2.4 * (1.0 - edge) * 0.5
	var w := _wav(s)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_cache.wind = w
	return w


static func play(at: Node3D, id: String, volume_db := -8.0) -> void:
	if not at.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(id)
	p.volume_db = volume_db
	p.max_distance = 80.0
	at.get_tree().current_scene.add_child(p)
	p.global_position = at.global_position
	p.play()
	p.finished.connect(p.queue_free)


static func shot(at: Node3D, klass: String, quiet := false) -> void:
	play(at, "shot_quiet" if quiet else "shot_" + klass, -4.0)


## Flat (non-positional) UI sounds: hit and kill confirms.
static func ui(tree: SceneTree, id: String, volume_db := -6.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(id)
	p.volume_db = volume_db
	tree.current_scene.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
