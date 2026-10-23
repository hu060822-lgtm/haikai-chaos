class_name CompetitorRig
extends Node3D
## The competitor's moving parts (C5): CompetitorModel builds the body as one piece, then
## rig() sorts its meshes onto joints (hips, torso, head, each thigh and shin) and pose()
## moves them every frame from how the body is moving:
##
##   idle      breathing, a slow weight shift
##   run       legs swing and knees fold with the stride (faster and longer with speed),
##             the torso leans into it and the hips bob; strafing swings the legs sideways
##   air       knees tucked, legs a little forward; falling straightens them for the landing
##   crouch    hips down, knees bent; a slide leans back with the front leg out
##   wall run  the whole body tilts off the wall
##   aim       the torso, head and arms follow the look pitch (the gun goes with the arms)
##   flinch()  a hit knocks the torso back a little on a spring
##   die()     goes limp: knees buckle, the hips drop, the torso folds over and the body
##             settles on the floor with a small bounce, head and arms loose (kill replays)
##   ragdoll() C7: a real physics body instead: every joint becomes a rigid piece linked
##             to its parent by a loose cone joint, thrown by the killing hit and the
##             speed it died at. Explosions, knock-backs, shoulder charges and shotgun
##             blasts throw it much harder (kill_force), so bodies fly.
##
## Everything is procedural (no animation data), the same at any frame rate.

const KNEE_Y := 0.5
const HIP_Y := 0.94
const WAIST_Y := 0.98
const NECK_Y := 1.52
const SHOULDER_Y := 1.43
const FALL_TIME := 0.75

var hips: Node3D
var torso: Node3D
var head: Node3D
## The arms and the gun in their hands, hung from the shoulders.
var arms: Node3D
var thighs: Array[Node3D] = []
var shins: Array[Node3D] = []
var dead := false
## Footsteps (C6): every stride makes a sound, so a decoy's steps are worth believing.
## Kill-replay ghosts turn them off.
var steps := true

var _phase := 0.0
var _breath := 0.0
var _speed := 0.0
var _side := 0.0
var _lean := 0.0
var _crouch := 0.0
var _air := 0.0
var _tilt := 0.0
var _pitch := 0.0
var _flinch := Vector3.ZERO
var _flinch_v := Vector3.ZERO
var _die_t := 0.0
var _fall_back := true
var _fall_twist := 0.0
var _step_n := 0


## Sorts the meshes built straight onto this node onto joints, by where each one sits.
func rig() -> void:
	hips = _joint(self, "Hips", Vector3(0, HIP_Y, 0))
	torso = _joint(hips, "Torso", Vector3(0, WAIST_Y - HIP_Y, 0))
	head = _joint(torso, "Head", Vector3(0, NECK_Y - WAIST_Y, 0))
	arms = _joint(torso, "Arms", Vector3(0, SHOULDER_Y - WAIST_Y, 0))
	for sx in [-1.0, 1.0]:
		var thigh := _joint(hips, "Thigh", Vector3(sx * 0.115, 0, 0))
		thighs.append(thigh)
		shins.append(_joint(thigh, "Shin", Vector3(0, KNEE_Y - HIP_Y, -0.02)))
	for child in get_children():
		if child == hips or not (child is Node3D) or child.name in ["Marker"]:
			continue
		var n := child as Node3D
		var c := _centre(n)
		var dest: Node3D = hips
		if child.name == "GunHand" or (c.y > WAIST_Y and c.y < NECK_Y - 0.02
				and (absf(c.x) > 0.2 or c.z < -0.2 or (absf(c.x) > 0.13 and c.z < -0.05))):
			dest = arms
		elif c.y > NECK_Y - 0.02 and absf(c.x) < 0.17 and c.z > -0.25:
			dest = head
		elif c.y >= WAIST_Y - 0.03:
			dest = torso
		elif c.y < HIP_Y - 0.06 and absf(c.x) > 0.04:
			var i := 0 if c.x < 0.0 else 1
			dest = shins[i] if c.y <= KNEE_Y + 0.03 else thighs[i]
		_move_to(n, dest)


func _joint(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = label
	j.position = at
	parent.add_child(j)
	return j


## Where a part is (its mesh's centre, in this node's space).
func _centre(n: Node3D) -> Vector3:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n.transform * (n as MeshInstance3D).mesh.get_aabb().get_center()
	return n.position


func _move_to(n: Node3D, dest: Node3D) -> void:
	var xf := dest.global_transform.affine_inverse() * global_transform * n.transform if is_inside_tree() \
		else _rest_of(dest).affine_inverse() * n.transform
	remove_child(n)
	dest.add_child(n)
	n.transform = xf


## A joint's transform in this node's space, at rest (before anything is in the tree).
func _rest_of(j: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = j
	while n != null and n != self:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## One frame of motion. `vel` is the body's velocity in world space, `floor` whether it
## stands on something, `crouch` 0..1, `slide` and `wall` (-1/0/1 side) for those moves,
## `pitch` the look pitch in radians.
func pose(delta: float, vel: Vector3, on_floor: bool, crouch := 0.0, slide := false, wall := 0, pitch := 0.0) -> void:
	if dead or hips == null:
		return
	var local := global_basis.inverse() * vel
	var flat := Vector2(local.x, local.z)
	var k := 1.0 - exp(-10.0 * delta)
	_speed = lerpf(_speed, flat.length(), k)
	_side = lerpf(_side, clampf(local.x / maxf(flat.length(), 1.0), -1.0, 1.0), k)
	var forward := -local.z
	_air = lerpf(_air, 0.0 if on_floor else 1.0, 1.0 - exp(-12.0 * delta))
	_crouch = lerpf(_crouch, maxf(crouch, 1.0 if slide else 0.0), 1.0 - exp(-12.0 * delta))
	_tilt = lerpf(_tilt, float(wall) * 0.32, 1.0 - exp(-8.0 * delta))
	_pitch = lerpf(_pitch, pitch, 1.0 - exp(-14.0 * delta))
	_breath += delta * 1.6
	# Stride: a cycle per ~1.5 m at a walk, longer strides when running.
	var run := clampf(_speed / 7.0, 0.0, 1.6)
	if on_floor and not slide:
		_phase += delta * (_speed / (1.1 + 0.35 * run)) * PI
		var n := int(_phase / PI)
		if n != _step_n:
			_step_n = n
			if steps and _speed > 2.5:
				Sfx.step(self, _speed)
	var swing := 0.62 * minf(run, 1.2) * (1.0 - _air) * (1.0 - _crouch * 0.5)
	var back := -1.0 if forward < -0.5 else 1.0      # backpedalling swings the other way
	for i in 2:
		var s := sin(_phase + PI * i)
		var lift := maxf(0.0, -cos(_phase + PI * i))
		var thigh := thighs[i]
		var shin := shins[i]
		var t_x := -s * swing * back * (1.0 - absf(_side) * 0.6)
		var t_z := s * swing * _side * 0.45
		var knee := lift * swing * 1.5 + 0.08
		# Air: tuck, then reach down for the floor as it falls.
		t_x += _air * (-0.55 + 0.25 * i)
		knee += _air * 0.9
		# Crouch: hips down, thighs forward, knees bent. Slide: front leg out, back leg folded.
		if slide:
			t_x += -1.25 if i == 1 else -0.35
			knee += 0.15 if i == 1 else 1.6
		else:
			t_x += -_crouch * 0.9
			knee += _crouch * 1.6
		thigh.rotation = Vector3(t_x, 0.0, t_z + (0.06 if i == 0 else -0.06) * run)
		shin.rotation = Vector3(knee, 0.0, 0.0)
	var bob := absf(sin(_phase)) * 0.045 * minf(run, 1.2) * (1.0 - _air)
	hips.position = Vector3(0, HIP_Y - _crouch * (0.55 if slide else 0.38) + bob - 0.02 * run, 0)
	# Flinch spring.
	var steps := maxi(ceili(delta / 0.005), 1)
	for n in steps:
		var h := delta / steps
		_flinch_v += (-220.0 * _flinch - 20.0 * _flinch_v) * h
		_flinch += _flinch_v * h
	var lean := 0.22 * clampf(forward / 7.0, -0.6, 1.4) - (0.45 if slide else 0.0)
	_lean = lerpf(_lean, lean, k)
	var breath := sin(_breath) * 0.012 * (1.0 - minf(run, 1.0))
	hips.rotation = Vector3(0.0, sin(_phase) * 0.08 * minf(run, 1.0), _tilt)
	torso.rotation = Vector3(-_lean - _pitch * 0.45 + breath + _flinch.x, -sin(_phase) * 0.12 * minf(run, 1.0) + _flinch.y,
		-_side * 0.08 * run + _flinch.z)
	head.rotation = Vector3(-_pitch * 0.4, 0.0, 0.0)
	arms.rotation = Vector3(-_pitch * 0.45, 0.0, 0.0)


## A hit from `dir` (world, the way the shot travelled): the torso gives a little.
func flinch(dir: Vector3, strength := 1.0) -> void:
	if dead or torso == null:
		return
	var local := global_basis.inverse() * dir
	_flinch_v += Vector3(-local.z * 3.2, local.x * 1.6, -local.x * 2.4) * strength
	_hit_flash()


## C7: a hit shows on the body: everything flashes white for a few frames.
static var _flash_mat: StandardMaterial3D
var _flash_left := 0.0

func _hit_flash() -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1, 1, 1, 0.55)
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if _flash_left <= 0.0:
		for m in find_children("*", "GeometryInstance3D", true, false):
			(m as GeometryInstance3D).material_overlay = _flash_mat
	_flash_left = 0.07
	set_process(true)


## Goes limp. `dir` is the way the killing shot travelled (it falls away from it).
func die(dir := Vector3.ZERO) -> void:
	if dead or hips == null:
		return
	dead = true
	_die_t = 0.0
	var local := global_basis.inverse() * dir
	_fall_back = local.z <= 0.15     # shot from the front: falls back; from behind: forward
	_fall_twist = clampf(local.x, -1.0, 1.0) * 0.5 + randf_range(-0.2, 0.2)


func _limp(delta: float) -> void:
	_die_t += delta
	var t := clampf(_die_t / FALL_TIME, 0.0, 1.0)
	# Knees go first, then the hips, then the torso folds; a small bounce at the floor.
	var knees := _ease(clampf(t * 2.2, 0.0, 1.0))
	var drop := _bounce(clampf((t - 0.08) / 0.92, 0.0, 1.0))
	var fold := _bounce(clampf((t - 0.15) / 0.85, 0.0, 1.0))
	var way := 1.0 if _fall_back else -1.0
	hips.position = Vector3(0, lerpf(HIP_Y, 0.16, drop), lerpf(0.0, 0.25 * way, drop))
	hips.rotation = Vector3(way * 1.45 * fold, _fall_twist * fold, _fall_twist * 0.6 * fold)
	torso.rotation = Vector3(way * 0.15 * fold, _fall_twist * 0.4 * fold, -_fall_twist * 0.3 * fold)
	head.rotation = Vector3(way * 0.5 * fold, _fall_twist * 0.8 * fold, 0.35 * fold * signf(_fall_twist + 0.01))
	# The arms let go and flop down along the body, the gun with them.
	arms.rotation = Vector3(-1.35 * _ease(clampf(t * 1.6, 0.0, 1.0)), _fall_twist * 0.5, 0.0)
	for i in 2:
		var splay := (0.12 if i == 0 else -0.12) + _fall_twist * 0.2
		# The knees fold as it drops, then the legs lie out loose (one a little bent).
		thighs[i].rotation = Vector3(-knees * 0.9 * (1.0 - fold) - way * 0.12 * fold * (1 + i), 0.0, splay * fold)
		shins[i].rotation = Vector3(knees * 1.5 * (1.0 - fold) + fold * (0.15 + 0.45 * i), 0.0, 0.0)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## 0..1 with gravity: speeds up, lands past 1 a touch and settles.
static func _bounce(x: float) -> float:
	if x < 0.7:
		var a := x / 0.7
		return a * a
	var b := (x - 0.7) / 0.3
	return 1.0 + sin(b * PI) * 0.06 * (1.0 - b)


## A corpse: the model taken off its owner (who is about to vanish or respawn), left
## lying in the world, sinking away after `keep` seconds.
static func leave_corpse(model: Node3D, dir: Vector3, keep := 6.0, force := 1.0, carry := Vector3.ZERO) -> void:
	if model == null or not model.is_inside_tree():
		return
	var world: Node = model.get_tree().current_scene
	if world == null:
		world = model.get_parent()
	var xf := model.global_transform
	model.get_parent().remove_child(model)
	world.add_child(model)
	model.global_transform = xf
	var marker := model.get_node_or_null("Marker")
	if marker != null:
		marker.visible = false
	if model is CompetitorRig and RAGDOLLS:
		(model as CompetitorRig).ragdoll(dir, force, carry, keep)
		return
	if model is CompetitorRig:
		(model as CompetitorRig).die(dir)
		model.set_process(true)
	var tw := model.create_tween()
	tw.tween_interval(keep)
	tw.tween_property(model, "position:y", model.position.y - 1.2, 1.5)
	tw.tween_callback(model.queue_free)


# --- Ragdoll (C7) ------------------------------------------------------------------------

## Physics bodies for corpses (off: the old procedural fall).
static var RAGDOLLS := true
## Corpses lying around at once; the oldest goes first.
const MAX_RAGDOLLS := 10
## Collision layer of ragdoll pieces: they hit the world and each other, never people or shots.
const RAG_LAYER := PhysicsFx.LAYER
static var _live: Array = []
var _pieces: Array[RigidBody3D] = []


## How hard a kill throws the body: 1 for a bullet, up to ~4 for a blast.
static func kill_force(info: Dictionary) -> float:
	var f := 1.0 + clampf(float(info.get("damage", 20.0)) / 60.0, 0.0, 1.0)
	var e: Dictionary = info.get("effects", {}) if info.get("effects") is Dictionary else {}
	if info.get("blast", false) or e.has("explode"):
		f += 2.6
	if e.has("knock"):
		f += clampf(absf(float(e.knock)) * 0.25, 0.4, 2.0)
	if int(info.get("pellets", 1)) > 3 or str(info.get("gun_name", "")) in ["重踩", "肩撞"]:
		f += 1.0
	if str(info.get("zone", "")) == "head":
		f += 0.4
	return clampf(f, 1.0, 4.5)


## Turns the rigged body into linked rigid pieces and throws it: `dir` the way the killing
## hit went, `force` from kill_force, `carry` the speed the body had.
func ragdoll(dir: Vector3, force := 1.0, carry := Vector3.ZERO, keep := 6.0) -> void:
	if dead or hips == null:
		return
	dead = true
	set_process(false)
	_live.append(self)
	while _live.size() > MAX_RAGDOLLS:
		var old = _live.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var world := get_parent()
	var joints: Array[Node3D] = [hips, torso, head, arms, thighs[0], thighs[1], shins[0], shins[1]]
	var parents := {torso: hips, head: torso, arms: torso, thighs[0]: hips, thighs[1]: hips, shins[0]: thighs[0], shins[1]: thighs[1]}
	var mass := {hips: 14.0, torso: 20.0, head: 5.0, arms: 9.0, thighs[0]: 8.0, thighs[1]: 8.0, shins[0]: 5.0, shins[1]: 5.0}
	var body_of := {}
	var pivots := {}
	for j in joints:
		pivots[j] = j.global_position
	# Each joint's meshes go onto a rigid body of their own, shaped by their bounds.
	for j in joints:
		var b := RigidBody3D.new()
		b.name = "Rag%s%d" % [j.name, _pieces.size()]
		b.collision_layer = RAG_LAYER
		b.collision_mask = PhysicsFx.MASK
		b.add_to_group("loose")
		b.mass = mass[j]
		b.linear_damp = 0.15
		b.angular_damp = 1.2
		b.continuous_cd = true
		var pm := PhysicsMaterial.new()
		pm.friction = 0.9
		pm.bounce = 0.15
		b.physics_material_override = pm
		world.add_child(b)
		b.global_transform = j.global_transform
		var box := AABB()
		var first := true
		for child in j.get_children():
			if not (child is MeshInstance3D) or (child as MeshInstance3D).mesh == null:
				continue
			var mi := child as MeshInstance3D
			var a := mi.transform * mi.mesh.get_aabb()
			box = a if first else box.merge(a)
			first = false
		if first:
			box = AABB(Vector3(-0.08, -0.08, -0.08), Vector3(0.16, 0.16, 0.16))
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = (box.size * 0.85).max(Vector3(0.08, 0.08, 0.08)).min(Vector3(0.6, 0.6, 0.6))
		shape.shape = bs
		shape.position = box.get_center()
		b.add_child(shape)
		for child in j.get_children():
			if child is Node3D and not (child in joints):
				var xf: Transform3D = (child as Node3D).global_transform
				j.remove_child(child)
				b.add_child(child)
				(child as Node3D).global_transform = xf
		body_of[j] = b
		_pieces.append(b)
	for j in parents:
		var joint := ConeTwistJoint3D.new()
		world.add_child(joint)
		# The twist axis (X) runs along the bone, from the parent's pivot out to this one.
		var bone: Vector3 = (pivots[j] - pivots[parents[j]])
		var x := bone.normalized() if bone.length() > 0.01 else Vector3.UP
		var y := x.cross(Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		joint.global_transform = Transform3D(Basis(x, y, x.cross(y)), pivots[j])
		joint.node_a = joint.get_path_to(body_of[parents[j]])
		joint.node_b = joint.get_path_to(body_of[j])
		var knee: bool = j == shins[0] or j == shins[1]
		joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(25.0 if knee else (50.0 if j == head else 70.0)))
		joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(10.0 if knee else 35.0))
		joint.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)
		joint.set_param(ConeTwistJoint3D.PARAM_RELAXATION, 0.9)
		_pieces.append(joint)
	# The throw: the body's own speed, plus the hit pushing the chest and head hardest.
	var push := dir.normalized() if dir.length() > 0.01 else -global_basis.z
	var throw := push * (2.2 + 3.0 * (force - 1.0)) + Vector3.UP * (0.6 + 1.6 * maxf(force - 1.5, 0.0))
	for j in joints:
		var b: RigidBody3D = body_of[j]
		var share := 1.0 if j in [torso, head, arms] else 0.65
		b.linear_velocity = carry * 0.9 + throw * share
		b.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)) * (0.6 + 0.4 * force)
	var tw := create_tween()
	tw.tween_interval(keep)
	tw.tween_callback(_settle)
	tw.tween_method(_sink, 0.0, 1.2, 1.5)
	tw.tween_callback(queue_free)


## The body stops being physical and sinks into the floor.
func _settle() -> void:
	for p in _pieces:
		if p is RigidBody3D and is_instance_valid(p):
			var b := p as RigidBody3D
			b.freeze = true
			b.collision_layer = 0
			b.set_meta("rest_y", b.global_position.y)


func _sink(depth: float) -> void:
	for p in _pieces:
		if p is RigidBody3D and is_instance_valid(p):
			var b := p as RigidBody3D
			b.global_position.y = float(b.get_meta("rest_y", b.global_position.y)) - depth


func _exit_tree() -> void:
	_live.erase(self)
	for p in _pieces:
		if is_instance_valid(p):
			p.queue_free()
	_pieces.clear()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			for m in find_children("*", "GeometryInstance3D", true, false):
				(m as GeometryInstance3D).material_overlay = null
	if dead:
		_limp(delta)
