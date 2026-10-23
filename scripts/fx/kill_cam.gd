class_name KillCam
extends Node
## The kill replay (C4). Always recording: where every combatant was (RATE apart, the
## last KEEP seconds) and every tracer. When you die, clip() cuts the last LENGTH seconds
## and play() replays them in a SubViewport: ghosts of everyone at their recorded spots,
## the shots flying again, the camera over the killer's shoulder looking at you, the last
## moment slowed down. It plays in the live world (same map, same light): the live
## actors are moved onto LIVE_LAYER, which the replay camera doesn't draw, and the ghosts
## sit on GHOST_LAYER, which the game camera doesn't draw.
##
## What you see is what this machine saw (its view of the others), which is also what the
## kill looked like to you.

const RATE := 1.0 / 30.0
const KEEP := 6.0
const LENGTH := 4.0
## The last SLOW seconds play at SLOW_SPEED.
const SLOW := 0.7
const SLOW_SPEED := 0.3
const HOLD := 1.2
const GHOST_LAYER := 1 << 10
const LIVE_LAYER := 1 << 11

static var current: KillCam

var frames: Array = []   # [t, {key: [pos, yaw, team]}]
var shots: Array = []    # [t, from, to, klass]
var replaying := 0
var _t := 0.0


func _init() -> void:
	name = "KillCam"


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = RATE
	var snap := {}
	for c in get_tree().get_nodes_in_group("combatants"):
		if c is Node3D and c.get("alive") and c.get("team") != null:
			snap[c.get_instance_id()] = [(c as Node3D).global_position, (c as Node3D).rotation.y, int(c.team)]
	var t := now()
	frames.append([t, snap])
	while not frames.is_empty() and t - float(frames[0][0]) > KEEP:
		frames.pop_front()
	while not shots.is_empty() and t - float(shots[0][0]) > KEEP:
		shots.pop_front()


## A tracer was drawn somewhere (PrintFx.tracer calls this).
func note_tracer(from: Vector3, to: Vector3, klass: String) -> void:
	if replaying == 0:
		shots.append([now(), from, to, klass])


## The last LENGTH seconds, for a replay of `victim` killed by `killer` (with `gun`).
## Empty when there's nothing to show (no killer, or it never was on record).
func clip(victim: Node, killer: Variant, gun: Dictionary) -> Dictionary:
	if victim == null or not (killer is Node3D) or not is_instance_valid(killer) or killer == victim:
		return {}
	var t1 := now()
	var t0 := t1 - LENGTH
	var fs := frames.filter(func(f: Array) -> bool: return float(f[0]) >= t0)
	var kk: int = (killer as Node).get_instance_id()
	var seen := false
	for f in fs:
		seen = seen or (f[1] as Dictionary).has(kk)
	if fs.size() < 4 or not seen:
		return {}
	var builds := {}
	for c in get_tree().get_nodes_in_group("combatants"):
		var b: Variant = c.get("build") if c is Avatar else (c.weapon.build if c.get("weapon") != null else null)
		if b is Dictionary:
			builds[c.get_instance_id()] = b
	if not gun.is_empty():
		builds[kk] = gun
	return {"frames": fs, "shots": shots.filter(func(s: Array) -> bool: return float(s[0]) >= t0),
		"t0": float(fs[0][0]), "t1": t1, "killer": kk, "victim": victim.get_instance_id(), "builds": builds,
		"my_team": int(victim.get("team")) if victim.get("team") != null else 0}


## A viewport playing `c` (from clip()); `finished` fires on the replay node after each pass.
func play(c: Dictionary, size: Vector2i) -> SubViewport:
	_tag_live()
	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 300.0
	cam.cull_mask = 0xFFFFF & ~LIVE_LAYER
	vp.add_child(cam)
	var r := Replay.new()
	r.cam = cam
	r.data = c
	r.kill_cam = self
	vp.add_child(r)
	return vp


## Every live actor's meshes onto LIVE_LAYER (respawns rebuild models, so each time).
func _tag_live() -> void:
	for c in get_tree().get_nodes_in_group("combatants"):
		_set_layers(c, LIVE_LAYER)


static func _set_layers(n: Node, mask: int) -> void:
	if n is ViewModel:
		return   # the first-person gun keeps its own layer
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = mask
	for child in n.get_children():
		_set_layers(child, mask)


## Plays one clip, over and over: ghosts, tracers, the camera.
class Replay:
	extends Node
	signal finished()
	var cam: Camera3D
	var data: Dictionary
	var kill_cam: KillCam
	var _ghosts := {}
	var _root: Node3D
	var _clock := 0.0
	var _shot_i := 0
	var _done := false

	func _ready() -> void:
		_root = Node3D.new()
		_root.name = "KillCamGhosts"
		get_tree().current_scene.add_child(_root)
		var rng := RandomNumberGenerator.new()
		var keys := {}
		for f in data.frames:
			for k in f[1]:
				keys[k] = f[1][k][2]
		for k in keys:
			rng.seed = int(k)
			var ally: bool = int(keys[k]) == int(data.my_team)
			var model := CompetitorModel.build(FpUi.ally_color() if ally else FpUi.enemy_color(), not ally, rng)
			var build: Variant = data.builds.get(k)
			if build is Dictionary and not (build as Dictionary).is_empty() and model.find_child("GunHand", true, false):
				model.find_child("GunHand", true, false).add_child(GunModels.build(build))
			KillCam._set_layers(model, KillCam.GHOST_LAYER)
			for m in model.find_children("*", "GeometryInstance3D", true, false):
				(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			model.visible = false
			model.set_meta("team", keys[k])
			_root.add_child(model)
			_ghosts[k] = model
		kill_cam.replaying += 1
		_place(0.0)

	## Ghosts back on their feet for the next pass.
	func _revive() -> void:
		for k in _ghosts:
			var g = _ghosts[k]
			if g is CompetitorRig and g.dead:
				var rng := RandomNumberGenerator.new()
				rng.seed = int(k)
				var ally: bool = int(g.get_meta("team", 0)) == int(data.my_team)
				var fresh := CompetitorModel.build(FpUi.ally_color() if ally else FpUi.enemy_color(), not ally, rng)
				var build: Variant = data.builds.get(k)
				if build is Dictionary and not (build as Dictionary).is_empty():
					fresh.find_child("GunHand", true, false).add_child(GunModels.build(build))
				KillCam._set_layers(fresh, KillCam.GHOST_LAYER)
				fresh.set_meta("team", g.get_meta("team", 0))
				_root.add_child(fresh)
				g.queue_free()
				_ghosts[k] = fresh

	func _exit_tree() -> void:
		if is_instance_valid(_root):
			_root.queue_free()
		if is_instance_valid(kill_cam):
			kill_cam.replaying -= 1

	## Seconds into the clip -> everything where it was (and moving its legs the way it went).
	func _place(at: float, delta := 0.0) -> void:
		var fs: Array = data.frames
		var t := float(data.t0) + at
		var i := 0
		while i < fs.size() - 2 and float(fs[i + 1][0]) < t:
			i += 1
		var a: Array = fs[i]
		var b: Array = fs[mini(i + 1, fs.size() - 1)]
		var w := clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
		for k in _ghosts:
			var g: Node3D = _ghosts[k]
			var sa = a[1].get(k)
			var sb = b[1].get(k, sa)
			if sa == null:
				g.visible = false
				continue
			g.visible = true
			var was := g.global_position
			g.global_position = (sa[0] as Vector3).lerp(sb[0], w)
			g.rotation.y = lerp_angle(float(sa[1]), float(sb[1]), w)
			if g is CompetitorRig and delta > 0.0:
				var v := (g.global_position - was) / delta if was.distance_to(g.global_position) < 3.0 else Vector3.ZERO
				g.pose(delta, v, absf(v.y) < 2.0)
		var killer: Node3D = _ghosts.get(data.killer)
		var victim: Node3D = _ghosts.get(data.victim)
		if killer == null or not killer.visible:
			return
		var target := (victim.global_position if victim != null and victim.visible else _last_victim()) + Vector3(0, 1.2, 0)
		var head := killer.global_position + Vector3(0, 1.75, 0)
		var to := target - head
		var flat := Vector3(to.x, 0, to.z).normalized() if Vector2(to.x, to.z).length() > 0.1 else -killer.global_basis.z
		var right := flat.cross(Vector3.UP)
		var want := head - flat * 1.9 + right * 0.55 + Vector3(0, 0.25, 0)
		cam.global_position = cam.global_position.lerp(want, 0.35) if at > 0.0 else want
		if cam.global_position.distance_to(target) > 0.2:
			cam.look_at(target, Vector3.UP)

	func _last_victim() -> Vector3:
		for j in range(data.frames.size() - 1, -1, -1):
			var s = data.frames[j][1].get(data.victim)
			if s != null:
				return s[0]
		return Vector3.ZERO

	func _process(delta: float) -> void:
		var span := float(data.t1) - float(data.t0)
		var speed := SLOW_SPEED if _clock > span - KillCam.SLOW and _clock < span else 1.0
		_clock += delta * speed
		# The victim goes limp where it was hit, at the end of the clip.
		var victim = _ghosts.get(data.victim)
		if _clock >= span - 0.02 and victim is CompetitorRig and not victim.dead:
			var killer: Node3D = _ghosts.get(data.killer)
			var dir: Vector3 = (victim.global_position - killer.global_position).normalized() if killer != null else Vector3.ZERO
			victim.visible = true
			victim.global_position = _last_victim()
			victim.die(dir)
		if _clock > span + KillCam.HOLD:
			_clock = 0.0
			_shot_i = 0
			_revive()
			if not _done:
				_done = true
				finished.emit()
		if _clock < span:
			_place(_clock, delta * speed)
		var t := float(data.t0) + _clock
		var s: Array = data.shots
		while _shot_i < s.size() and float(s[_shot_i][0]) <= t:
			PrintFx.tracer(get_tree().current_scene, s[_shot_i][1], s[_shot_i][2], s[_shot_i][3])
			_shot_i += 1
