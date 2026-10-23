class_name AthleteRig
extends CompetitorRig
## The skinned athlete (character overhaul): a 24-bone Skeleton3D under one mesh (the
## body and every piece of gear), posed in code every frame. It keeps CompetitorRig's
## whole API (pose, flinch, die, ragdoll, leave_corpse, GunHand, Marker), so bots,
## avatars, decoys and kill replays drive it the same way.
##
## The pose is solved, not keyed: the game state (velocity, floor, crouch, slide, wall,
## look pitch) sets where the pelvis, the feet and the gun are, and two-bone IK puts the
## legs under the pelvis and both hands on the gun's own grip and handguard points (the
## gun's "slots"), so any gun, of any length, is held where it is really gripped. The
## animation only reads the game state: it never moves the body, its collision or its
## velocity, and it adds no input delay.
##
##   var rig := AthleteRig.create(look)       # look: see CompetitorModel._look
##   rig.hold(gun)                            # or add the gun to GunHand yourself
##   rig.pose(delta, velocity, on_floor, crouch, slide, wall, pitch)

## Where the stock sits (the right shoulder pocket), in the upper chest's rest space.
const POCKET := Vector3(0.118, 1.452, -0.098)
## A pistol's grip at arm's length, from the shoulders' centre (rotated by the pitch).
const PISTOL_REACH := Vector3(0.04, -0.06, -0.6)
## A long gun turns the chest this far to the right (a bladed stance), so the left hand
## reaches the handguard; the head turns back to the front.
const BLADE := 0.42
const FINGER_CURL := 1.45

var skel: Skeleton3D
var body: MeshInstance3D
var gun_hand: Node3D

var _local: Array[Transform3D] = []
var _glob: Array[Transform3D] = []
var _gun: Node3D
var _slots := {}
var _pistol := false
var _debug := {}
var _ragdolled := false
var _driven := {}
var _limp_from: Array[Transform3D] = []

static var _mesh: ArrayMesh
static var _skin: Skin


static func create(look: Dictionary) -> AthleteRig:
	var r := AthleteRig.new()
	r.name = "Competitor"
	r.skel = AthleteBones.build()
	r.add_child(r.skel)
	if _mesh == null:
		_mesh = AthleteBody.build(AthleteBody.materials(look))
		_mesh = AthleteGear.build(_mesh, AthleteGear.materials(look))
		_skin = r.skel.create_skin_from_rest_transforms()
	r.body = MeshInstance3D.new()
	r.body.name = "Body"
	r.body.mesh = _mesh
	r.body.skin = _skin
	r.skel.add_child(r.body)
	r.body.skeleton = NodePath("..")
	var mats: Array[Material] = AthleteBody.materials(look)
	mats.append_array(AthleteGear.materials(look))
	for i in mats.size():
		r.body.set_surface_override_material(i, mats[i])
	r.gun_hand = Node3D.new()
	r.gun_hand.name = "GunHand"
	r.add_child(r.gun_hand)
	for i in AthleteBones.count():
		r._local.append(AthleteBones.rest_local(i))
		r._glob.append(AthleteBones.rest_global(i))
	# Something to stand on before the first pose (a gun in the hands, legs at rest).
	r.hips = r.skel
	r.pose(0.0, Vector3.ZERO, true)
	return r


## Puts a gun in the hands.
func hold(gun: Node3D) -> void:
	for c in gun_hand.get_children():
		c.queue_free()
	gun_hand.add_child(gun)
	_find_gun()
	pose(0.0, Vector3.ZERO, true)


## A fixed test pose (joint sheet): {elbow_l: flex, shoulder_l: Vector3 (x, y, z turns),
## hip_l: flex, knee_l: flex (negative bends), spine: Vector3}. The gun is hidden.
func debug_pose(p: Dictionary) -> void:
	_debug = p
	gun_hand.visible = false
	_rest()
	for s in ["l", "r"]:
		_turn("forearm_" + s, Vector3.RIGHT, float(p.get("elbow_" + s, 0.0)))
		var sh: Vector3 = p.get("shoulder_" + s, Vector3.ZERO)
		_euler("upper_arm_" + s, sh)
		_turn("thigh_" + s, Vector3.RIGHT, float(p.get("hip_" + s, 0.0)))
		_turn("shin_" + s, Vector3.RIGHT, float(p.get("knee_" + s, 0.0)))
	var sp: Vector3 = p.get("spine", Vector3.ZERO)
	_euler("spine", sp * 0.5)
	_euler("chest", sp * 0.5)
	_fk()
	_write()


func _find_gun() -> void:
	var g: Node3D = null
	for c in gun_hand.get_children():
		if c is Node3D and not c.is_queued_for_deletion():
			g = c
	if g == _gun:
		return
	_gun = g
	_slots = {}
	_pistol = false
	if g != null and g.has_meta("slots"):
		_slots = g.get_meta("slots")
		var muzzle: Vector3 = g.get_meta("muzzle", Vector3(0, 0, -0.5))
		_pistol = muzzle.z > -0.25


# --- The pose ------------------------------------------------------------------------------

func pose(delta: float, vel: Vector3, on_floor: bool, crouch := 0.0, slide := false, wall := 0, pitch := 0.0) -> void:
	if dead or skel == null or not _debug.is_empty():
		return
	_find_gun()
	var local := global_basis.inverse() * vel if is_inside_tree() else vel
	var flat := Vector2(local.x, local.z)
	var k := 1.0 - exp(-10.0 * delta)
	_speed = lerpf(_speed, flat.length(), k)
	_side = lerpf(_side, clampf(local.x / maxf(flat.length(), 1.0), -1.0, 1.0), k)
	var forward := -local.z
	_air = lerpf(_air, 0.0 if on_floor else 1.0, 1.0 - exp(-12.0 * delta))
	_crouch = lerpf(_crouch, maxf(crouch, 1.0 if slide else 0.0), 1.0 - exp(-12.0 * delta))
	_tilt = lerpf(_tilt, float(wall) * 0.32, 1.0 - exp(-8.0 * delta))
	_pitch = lerpf(_pitch, pitch, 1.0 - exp(-14.0 * delta)) if delta > 0.0 else pitch
	_breath += delta * 1.6
	var run := clampf(_speed / 7.0, 0.0, 1.6)
	if on_floor and not slide:
		_phase += delta * (_speed / (1.1 + 0.35 * run)) * PI
		var n := int(_phase / PI)
		if n != _step_n:
			_step_n = n
			if steps and _speed > 2.5:
				Sfx.step(self, _speed)
	var sub := maxi(ceili(delta / 0.005), 1)
	for i in sub:
		var h := delta / sub
		_flinch_v += (-220.0 * _flinch - 20.0 * _flinch_v) * h
		_flinch += _flinch_v * h
	_rest()
	# Pelvis: height from the crouch and the stride's bob, a sway with the stride, the
	# wall run's tilt.
	var bob := absf(sin(_phase)) * 0.04 * minf(run, 1.2) * (1.0 - _air)
	var drop := _crouch * (0.55 if slide else 0.36)
	var hip := b("hips")
	_local[hip].origin = AthleteBones.rest_local(hip).origin + Vector3(0, bob - drop - 0.02 * run, 0.06 * _crouch * (0.0 if slide else 1.0))
	_local[hip].basis = Basis(Vector3.BACK, _tilt) * Basis(Vector3.UP, sin(_phase) * 0.08 * minf(run, 1.0)) \
		* Basis(Vector3.RIGHT, (-0.25 * _crouch if not slide else 0.0)) * _local[hip].basis
	# Spine: lean into the run, back in a slide, with the look pitch; breathing; a hit.
	var lean := 0.22 * clampf(forward / 7.0, -0.6, 1.4) - (0.45 if slide else 0.0)
	_lean = lerpf(_lean, lean, k) if delta > 0.0 else lean
	var breath := sin(_breath) * 0.012 * (1.0 - minf(run, 1.0))
	var twist := -sin(_phase) * 0.12 * minf(run, 1.0)
	var blade := -BLADE if _gun != null and not _pistol else 0.0
	_euler("spine", Vector3(-_lean * 0.5 + _pitch * 0.1 + 0.18 * _crouch * (0.0 if slide else 1.0), twist * 0.5 + blade * 0.3, -_side * 0.04 * run))
	_euler("chest", Vector3(-_lean * 0.5 + _pitch * 0.1 + breath + _flinch.x, twist * 0.5 + blade * 0.35 + _flinch.y, -_side * 0.04 * run + _flinch.z))
	_euler("upper_chest", Vector3(_pitch * 0.1 - breath * 0.5, blade * 0.35, 0.0))
	_fk()
	_legs(slide, run, flat)
	_arms()
	_write()


func _legs(slide: bool, run: float, flat: Vector2) -> void:
	var dir := Vector3(flat.x, 0.0, flat.y).normalized() if flat.length() > 0.3 else Vector3.FORWARD
	var stride := 0.34 * minf(run, 1.25) * (1.0 - _crouch * 0.4)
	for i in 2:
		var s := "l" if i == 0 else "r"
		var sx := -1.0 if i == 0 else 1.0
		var ph := _phase + PI * i
		var f := sin(ph) * stride
		var lift := maxf(0.0, cos(ph)) * 0.16 * minf(run, 1.0)
		var hip_at := _glob[b("thigh_" + s)].origin
		var ground := Vector3(sx * (0.118 + 0.05 * _crouch), 0.088 + lift, 0.02) + dir * f
		# In the air: knees tucked up under the hips, reaching down as it falls.
		var tuck := hip_at + Vector3(sx * 0.03, -0.62, -0.12 + 0.18 * i)
		var foot := ground.lerp(tuck, _air)
		var toe := 0.25 * lift / 0.16 - 0.3 * _air
		if slide:
			# Front (right) leg out along the floor, the back leg folded under.
			foot = Vector3(0.14, 0.1, -0.52) if i == 1 else Vector3(-0.17, 0.07, 0.16)
			toe = 0.45 if i == 1 else -0.4
		_ik("thigh_" + s, "shin_" + s, foot, Vector3(sx * 0.25, 0.0 if not slide or i == 1 else -0.9, -1.0), -1.0)
		_aim_bone("foot_" + s, Basis(Vector3.RIGHT, toe) * AthleteBones.rest_global(b("foot_" + s)).basis)
	_fk()


## The gun: on the right shoulder for long guns, at arm's length for pistols, turned by
## the look pitch; then both hands on it.
func _arms() -> void:
	var p := _pitch
	var aim := Basis(Vector3.RIGHT, p)
	var uc := b("upper_chest")
	var mount: Transform3D
	if _gun == null:
		_relaxed_arms()
		return
	if _pistol:
		var centre := (_glob[b("upper_arm_l")].origin + _glob[b("upper_arm_r")].origin) * 0.5
		var grip: Vector3 = _slots.get("grip", Vector3.ZERO)
		mount = Transform3D(aim, centre + aim * PISTOL_REACH) * Transform3D(Basis.IDENTITY, -grip)
	else:
		var pocket := _glob[uc] * (AthleteBones.rest_global(uc).affine_inverse() * POCKET)
		var butt: Vector3 = _slots.get("buttpad", Vector3(0, 0.03, 0.25))
		mount = Transform3D(aim, pocket) * Transform3D(Basis.IDENTITY, -butt)
	gun_hand.transform = mount
	var gb := mount.basis
	# Head: down onto the stock for a long gun, square behind a pistol; looking with the pitch.
	var back := BLADE if not _pistol else 0.0
	_euler("neck", Vector3(p * 0.12 - (0.06 if not _pistol else 0.03), back * 0.45, 0.0))
	_euler("head", Vector3(p * 0.3 - (0.05 if not _pistol else 0.02), back * 0.55, -0.08 if not _pistol else 0.0))
	# Shoulders a little forward into the gun.
	_turn_model("clavicle_r", Vector3.UP, 0.18)
	_turn_model("clavicle_l", Vector3.UP, -0.3 if not _pistol else -0.2)
	_fk()
	# Right hand round the grip: the back of the hand out to the right, the knuckles
	# forward across the grip, the index finger at the trigger.
	var grip_at: Vector3 = mount * (_slots.get("grip", Vector3.ZERO) as Vector3)
	var yr := (gb * Vector3(-0.28, -0.3, -0.91)).normalized()
	var xr := gb.x
	xr = (xr - yr * xr.dot(yr)).normalized()
	var hr := Basis(xr, yr, xr.cross(yr))
	var wrist_r := grip_at - hr.y * 0.064 + hr.x * 0.03 - hr.z * 0.006
	_ik("upper_arm_r", "forearm_r", wrist_r, Vector3(0.7, -1.0, 0.25) if not _pistol else Vector3(1.0, -0.5, 0.2), 1.0)
	_aim_bone("hand_r", hr)
	var hl: Basis
	var wrist_l: Vector3
	if _pistol:
		# The left hand wraps the right from the other side.
		var yl := (gb * Vector3(0.2, -0.45, -0.87)).normalized()
		var xl := gb.x
		xl = (xl - yl * xl.dot(yl)).normalized()
		hl = Basis(xl, yl, xl.cross(yl))
		wrist_l = grip_at - hl.y * 0.05 - hl.x * 0.045 - hl.z * 0.012
	else:
		# Left hand under the handguard, palm up, fingers round its right side.
		var fg: Vector3 = _slots.get("foregrip", Vector3(0, 0.0, -0.2))
		var under := mount * (fg + Vector3(0, 0.03, 0))
		var yl := (gb * Vector3(0.88, -0.05, -0.47)).normalized()
		var xl := (gb * Vector3(0.3, 0.95, 0.0)).normalized()
		xl = (xl - yl * xl.dot(yl)).normalized()
		hl = Basis(xl, yl, xl.cross(yl))
		wrist_l = under - hl.y * 0.05 - hl.x * 0.026
		# Too far out (a long handguard, a punt gun): the hand slides back along it.
		var shoulder := (_glob[b("clavicle_l")] * AthleteBones.rest_local(b("upper_arm_l"))).origin
		var reach := (AthleteBones.length(b("upper_arm_l")) + AthleteBones.length(b("forearm_l"))) * 0.96
		var room := 0
		while wrist_l.distance_to(shoulder) > reach and room < 12:
			wrist_l += gb.z * 0.025
			room += 1
	_ik("upper_arm_l", "forearm_l", wrist_l, Vector3(-0.5, -1.0, 0.1), 1.0)
	_aim_bone("hand_l", hl)
	_turn("fingers_r", Vector3.BACK, FINGER_CURL)
	_turn("fingers_l", Vector3.BACK, -FINGER_CURL * 1.1)
	_fk()


func _relaxed_arms() -> void:
	for s in ["l", "r"]:
		var sx := 1.0 if s == "r" else -1.0
		_turn("upper_arm_" + s, Vector3.BACK, 0.25 * sx)
		_turn("forearm_" + s, Vector3.RIGHT, 0.35)
		_turn("fingers_" + s, Vector3.BACK, 0.5 * sx)
	_fk()


# --- Bones -----------------------------------------------------------------------------------

static func b(name: String) -> int:
	return AthleteBones.index(name)


func _rest() -> void:
	for i in _local.size():
		_local[i] = AthleteBones.rest_local(i)


## Turns a bone about one of its own axes.
func _turn(bone: String, axis: Vector3, angle: float) -> void:
	var i := b(bone)
	_local[i].basis = _local[i].basis * Basis(axis, angle)


## Turns a bone by x, then y, then z about its own axes.
func _euler(bone: String, e: Vector3) -> void:
	var i := b(bone)
	_local[i].basis = _local[i].basis * Basis(Vector3.RIGHT, e.x) * Basis(Vector3.UP, e.y) * Basis(Vector3.BACK, e.z)


## Turns a bone about an axis in model space (its parent's global must be current).
func _turn_model(bone: String, axis: Vector3, angle: float) -> void:
	var i := b(bone)
	var p := AthleteBones.parent(i)
	var pb := _glob[p].basis if p >= 0 else Basis.IDENTITY
	_local[i].basis = Basis((pb.inverse() * axis).normalized(), angle) * _local[i].basis


## Sets a bone's model-space orientation (its parent's global must be current).
func _aim_bone(bone: String, g: Basis) -> void:
	var i := b(bone)
	var p := AthleteBones.parent(i)
	_local[i].basis = (_glob[p].basis.inverse() * g).orthonormalized()
	_glob[i] = _glob[p] * _local[i]


## Two-bone IK: bends `upper` and `lower` so the end of `lower` reaches `target`, the
## joint between them pushed toward `pole`. `flex` is the way the joint bends in the
## bones' own frame (+1 elbows, -1 knees), which keeps their twist as it is at rest.
func _ik(upper: String, lower: String, target: Vector3, pole: Vector3, flex: float) -> void:
	var a := b(upper)
	var c := b(lower)
	var p := AthleteBones.parent(a)
	var pg := _glob[p]
	var root := (pg * AthleteBones.rest_local(a)).origin
	var l1 := AthleteBones.length(a)
	var l2 := AthleteBones.length(c)
	var d := target - root
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var pd := pole - dir * pole.dot(dir)
	pd = pd.normalized() if pd.length() > 0.0001 else Vector3.FORWARD
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var ang := acos(cos_a)
	var joint := root + (dir * cos(ang) + pd * sin(ang)) * l1
	var end := root + dir * dist
	var y1 := (joint - root).normalized()
	var y2 := (end - joint).normalized()
	var bend := y2 - y1 * y2.dot(y1)
	bend = bend.normalized() if bend.length() > 0.001 else -pd
	var z1 := bend * flex
	var x1 := y1.cross(z1).normalized()
	z1 = x1.cross(y1)
	var g1 := Transform3D(Basis(x1, y1, z1), root)
	_local[a] = Transform3D((pg.basis.inverse() * g1.basis).orthonormalized(), AthleteBones.rest_local(a).origin)
	_glob[a] = pg * _local[a]
	var z2 := x1.cross(y2).normalized()
	var g2 := Basis(x1, y2, z2)
	_local[c] = Transform3D((_glob[a].basis.inverse() * g2).orthonormalized(), AthleteBones.rest_local(c).origin)
	_glob[c] = _glob[a] * _local[c]


func _fk() -> void:
	for i in _local.size():
		var p := AthleteBones.parent(i)
		_glob[i] = _local[i] if p < 0 else _glob[p] * _local[i]


func _write() -> void:
	for i in _local.size():
		skel.set_bone_pose_position(i, _local[i].origin)
		skel.set_bone_pose_rotation(i, _local[i].basis.orthonormalized().get_rotation_quaternion())


# --- Hits, death, ragdoll -----------------------------------------------------------------------

func flinch(dir: Vector3, strength := 1.0) -> void:
	if dead:
		return
	var l := global_basis.inverse() * dir
	_flinch_v += Vector3(-l.z * 3.2, l.x * 1.6, -l.x * 2.4) * strength
	_hit_flash()


func die(dir := Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	_die_t = 0.0
	var l := global_basis.inverse() * dir
	_fall_back = l.z <= 0.15
	_fall_twist = clampf(l.x, -1.0, 1.0) * 0.5 + randf_range(-0.2, 0.2)
	_limp_from = _local.duplicate()
	set_process(true)


## The procedural fall (kill replays, ragdolls off): knees go, the hips drop, the torso
## folds over, a small bounce at the floor; the gun stays in the right hand.
func _limp(delta: float) -> void:
	_die_t += delta
	var t := clampf(_die_t / FALL_TIME, 0.0, 1.0)
	var knees := _ease(clampf(t * 2.2, 0.0, 1.0))
	var drop := _bounce(clampf((t - 0.08) / 0.92, 0.0, 1.0))
	var fold := _bounce(clampf((t - 0.15) / 0.85, 0.0, 1.0))
	var way := 1.0 if _fall_back else -1.0
	var limp := _ease(clampf(t * 1.6, 0.0, 1.0))
	var grip_off := Transform3D.IDENTITY
	if _gun != null:
		grip_off = _glob[b("hand_r")].affine_inverse() * gun_hand.transform
	_rest()
	for i in _local.size():
		var from: Transform3D = _limp_from[i] if i < _limp_from.size() else _local[i]
		_local[i].basis = from.basis.slerp(_local[i].basis, limp) if i > 0 else from.basis
	var hip := b("hips")
	_local[hip].origin = Vector3(0, lerpf(0.95, 0.17, drop), lerpf(0.0, 0.3 * way, drop))
	_local[hip].basis = Basis(Vector3.UP, _fall_twist * fold) * Basis(Vector3.RIGHT, way * 1.45 * fold) * Basis(Vector3.BACK, _fall_twist * 0.6 * fold)
	_euler("chest", Vector3(way * 0.15 * fold, _fall_twist * 0.4 * fold, -_fall_twist * 0.3 * fold))
	_euler("head", Vector3(way * 0.45 * fold, _fall_twist * 0.8 * fold, 0.35 * fold * signf(_fall_twist + 0.01)))
	for i in 2:
		var s := "l" if i == 0 else "r"
		var sx := -1.0 if i == 0 else 1.0
		_turn("thigh_" + s, Vector3.RIGHT, knees * 0.9 * (1.0 - fold) + way * 0.12 * fold * (1 + i))
		_turn("thigh_" + s, Vector3.BACK, -sx * (0.12 + _fall_twist * 0.2) * fold)
		_turn("shin_" + s, Vector3.RIGHT, -(knees * 1.5 * (1.0 - fold) + fold * (0.15 + 0.45 * i)))
		_turn("upper_arm_" + s, Vector3.BACK, sx * 0.5 * fold)
		_turn("forearm_" + s, Vector3.RIGHT, 0.4 * fold)
	_fk()
	_write()
	if _gun != null:
		gun_hand.transform = _glob[b("hand_r")] * grip_off


func ragdoll(dir: Vector3, force := 1.0, carry := Vector3.ZERO, keep := 6.0) -> void:
	if dead and _ragdolled:
		return
	dead = true
	_ragdolled = true
	set_process(true)
	_live.append(self)
	while _live.size() > MAX_RAGDOLLS:
		var old = _live.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var world := get_parent()
	var sxf := skel.global_transform
	# One rigid body per segment: [bone, parent segment bone, shape size (radius, length) or box, mass].
	var segs := [
		["hips", "", Vector3(0.32, 0.2, 0.22), 14.0], ["spine", "hips", Vector3(0.34, 0.4, 0.22), 20.0],
		["neck", "spine", Vector2(0.1, 0.32), 5.0],
		["upper_arm_l", "spine", Vector2(0.05, 0.3), 3.0], ["upper_arm_r", "spine", Vector2(0.05, 0.3), 3.0],
		["forearm_l", "upper_arm_l", Vector2(0.042, 0.36), 2.0], ["forearm_r", "upper_arm_r", Vector2(0.042, 0.36), 2.0],
		["thigh_l", "hips", Vector2(0.075, 0.44), 8.0], ["thigh_r", "hips", Vector2(0.075, 0.44), 8.0],
		["shin_l", "thigh_l", Vector2(0.055, 0.46), 5.0], ["shin_r", "thigh_r", Vector2(0.055, 0.46), 5.0],
	]
	var bodies := {}
	for sg in segs:
		var i := b(sg[0])
		var rb := RigidBody3D.new()
		rb.name = "Rag_%s" % sg[0]
		rb.collision_layer = RAG_LAYER
		rb.collision_mask = PhysicsFx.MASK
		rb.add_to_group("loose")
		rb.mass = sg[3]
		rb.linear_damp = 0.15
		rb.angular_damp = 1.4
		rb.continuous_cd = true
		var pm := PhysicsMaterial.new()
		pm.friction = 0.9
		pm.bounce = 0.1
		rb.physics_material_override = pm
		var shape := CollisionShape3D.new()
		if sg[2] is Vector3:
			var bs := BoxShape3D.new()
			bs.size = sg[2]
			shape.shape = bs
			shape.position = Vector3(0, (sg[2] as Vector3).y * 0.5 - (0.05 if sg[0] == "hips" else 0.0), 0)
		else:
			var cs := CapsuleShape3D.new()
			cs.radius = (sg[2] as Vector2).x
			cs.height = maxf((sg[2] as Vector2).y, cs.radius * 2.0 + 0.01)
			shape.shape = cs
			shape.position = Vector3(0, (sg[2] as Vector2).y * 0.5 - cs.radius * 0.5, 0)
		rb.add_child(shape)
		world.add_child(rb)
		rb.global_transform = sxf * _glob[i]
		for other in bodies.values():
			rb.add_collision_exception_with(other)
		bodies[sg[0]] = rb
		_driven[i] = rb
		_pieces.append(rb)
	for sg in segs:
		if sg[1] == "":
			continue
		var j := ConeTwistJoint3D.new()
		world.add_child(j)
		var child: RigidBody3D = bodies[sg[0]]
		var x := child.global_basis.y.normalized()
		var y := x.cross(Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		j.global_transform = Transform3D(Basis(x, y, x.cross(y)), child.global_position)
		j.node_a = j.get_path_to(bodies[sg[1]])
		j.node_b = j.get_path_to(child)
		var knee: bool = (sg[0] as String).begins_with("shin") or (sg[0] as String).begins_with("forearm")
		j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(30.0 if knee else (45.0 if sg[0] == "neck" else 70.0)))
		j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(10.0 if knee else 30.0))
		j.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)
		j.set_param(ConeTwistJoint3D.PARAM_RELAXATION, 0.9)
		_pieces.append(j)
	# The gun flies loose.
	if _gun != null:
		var gb := RigidBody3D.new()
		gb.collision_layer = RAG_LAYER
		gb.collision_mask = PhysicsFx.MASK
		gb.add_to_group("loose")
		gb.mass = 3.0
		var box := AABB(Vector3(-0.03, -0.05, -0.4), Vector3(0.06, 0.12, 0.6))
		var gs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size.max(Vector3(0.04, 0.04, 0.1))
		gs.shape = bs
		gs.position = box.get_center()
		gb.add_child(gs)
		world.add_child(gb)
		gb.global_transform = gun_hand.global_transform
		var gun := _gun
		var gxf := gun.global_transform
		gun_hand.remove_child(gun)
		gb.add_child(gun)
		gun.global_transform = gxf
		for other in bodies.values():
			gb.add_collision_exception_with(other)
		gb.linear_velocity = carry * 0.9 + Vector3.UP * 1.5
		gb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		_pieces.append(gb)
		_gun = null
	var push := dir.normalized() if dir.length() > 0.01 else -global_basis.z
	var throw := push * (2.2 + 3.0 * (force - 1.0)) + Vector3.UP * (0.6 + 1.6 * maxf(force - 1.5, 0.0))
	for seg: String in bodies:
		var rb: RigidBody3D = bodies[seg]
		var share := 1.0 if seg in ["spine", "neck", "upper_arm_l", "upper_arm_r"] else 0.65
		rb.linear_velocity = carry * 0.9 + throw * share
		rb.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)) * (0.6 + 0.4 * force)
	var tw := create_tween()
	tw.tween_interval(keep)
	tw.tween_callback(_settle)
	tw.tween_method(_sink, 0.0, 1.2, 1.5)
	tw.tween_callback(queue_free)


## Ragdolled: every segment's bone follows its rigid body; the bones between (the
## chest, the head, the hands, the feet) keep their last pose relative to them.
func _drive() -> void:
	var inv := skel.global_transform.affine_inverse()
	for i in _local.size():
		var p := AthleteBones.parent(i)
		if _driven.has(i) and is_instance_valid(_driven[i]):
			var g: Transform3D = inv * (_driven[i] as Node3D).global_transform
			_local[i] = g if p < 0 else _glob[p].affine_inverse() * g
			_local[i].basis = _local[i].basis.orthonormalized()
		_glob[i] = _local[i] if p < 0 else _glob[p] * _local[i]
	_write()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			for m in find_children("*", "GeometryInstance3D", true, false):
				(m as GeometryInstance3D).material_overlay = null
	if _ragdolled:
		_drive()
	elif dead:
		_limp(delta)
