class_name AthleteBones
## The athlete's skeleton (character overhaul, Phase 2): 24 bones in a standing A-pose,
## 1.80 m to the top of the helmet, facing -Z, feet on y = 0.
##
## Every bone's local +Y runs along the bone to its tail. For the limbs (arms, legs, hands,
## fingers) local +X is the hinge: turning a bone by a positive angle about X swings its
## tail toward the front (-Z) — an elbow or a hip flexing, a knee extending backward is
## negative. For the spine, neck and head +X is the body's right, and a positive angle
## leans the top backward. Feet: a positive angle lifts the toes.
##
##   var skel := AthleteBones.build()     # a Skeleton3D with the rest pose set
##   AthleteBones.index("forearm_r")       # bone index by name

## name, parent, head (model space), tail, axis hint ("limb", "spine", "foot", "clav")
const BONES := [
	["hips", "", Vector3(0, 0.95, 0.0), Vector3(0, 1.06, 0.0), "spine"],
	["spine", "hips", Vector3(0, 1.06, 0.0), Vector3(0, 1.19, -0.008), "spine"],
	["chest", "spine", Vector3(0, 1.19, -0.008), Vector3(0, 1.33, -0.004), "spine"],
	["upper_chest", "chest", Vector3(0, 1.33, -0.004), Vector3(0, 1.455, 0.012), "spine"],
	["neck", "upper_chest", Vector3(0, 1.455, 0.012), Vector3(0, 1.56, -0.006), "spine"],
	["head", "neck", Vector3(0, 1.56, -0.006), Vector3(0, 1.76, -0.006), "spine"],
	["clavicle_l", "upper_chest", Vector3(-0.025, 1.425, -0.03), Vector3(-0.175, 1.44, 0.012), "clav"],
	["upper_arm_l", "clavicle_l", Vector3(-0.185, 1.43, 0.012), Vector3(-0.385, 1.22, 0.022), "limb"],
	["forearm_l", "upper_arm_l", Vector3(-0.385, 1.22, 0.022), Vector3(-0.565, 1.033, 0.0), "limb"],
	["hand_l", "forearm_l", Vector3(-0.565, 1.033, 0.0), Vector3(-0.625, 0.97, -0.004), "limb"],
	["fingers_l", "hand_l", Vector3(-0.625, 0.97, -0.004), Vector3(-0.68, 0.913, -0.008), "limb"],
	["clavicle_r", "upper_chest", Vector3(0.025, 1.425, -0.03), Vector3(0.175, 1.44, 0.012), "clav"],
	["upper_arm_r", "clavicle_r", Vector3(0.185, 1.43, 0.012), Vector3(0.385, 1.22, 0.022), "limb"],
	["forearm_r", "upper_arm_r", Vector3(0.385, 1.22, 0.022), Vector3(0.565, 1.033, 0.0), "limb"],
	["hand_r", "forearm_r", Vector3(0.565, 1.033, 0.0), Vector3(0.625, 0.97, -0.004), "limb"],
	["fingers_r", "hand_r", Vector3(0.625, 0.97, -0.004), Vector3(0.68, 0.913, -0.008), "limb"],
	["thigh_l", "hips", Vector3(-0.095, 0.935, 0.005), Vector3(-0.108, 0.5, -0.008), "limb"],
	["shin_l", "thigh_l", Vector3(-0.108, 0.5, -0.008), Vector3(-0.112, 0.088, 0.018), "limb"],
	["foot_l", "shin_l", Vector3(-0.112, 0.088, 0.018), Vector3(-0.118, 0.026, -0.112), "foot"],
	["toe_l", "foot_l", Vector3(-0.118, 0.026, -0.112), Vector3(-0.12, 0.022, -0.185), "foot"],
	["thigh_r", "hips", Vector3(0.095, 0.935, 0.005), Vector3(0.108, 0.5, -0.008), "limb"],
	["shin_r", "thigh_r", Vector3(0.108, 0.5, -0.008), Vector3(0.112, 0.088, 0.018), "limb"],
	["foot_r", "shin_r", Vector3(0.112, 0.088, 0.018), Vector3(0.118, 0.026, -0.112), "foot"],
	["toe_r", "foot_r", Vector3(0.118, 0.026, -0.112), Vector3(0.12, 0.022, -0.185), "foot"],
]

static var _index := {}
static var _rest_global: Array[Transform3D] = []
static var _rest_local: Array[Transform3D] = []
static var _parent: PackedInt32Array = PackedInt32Array()


static func count() -> int:
	return BONES.size()


static func index(bone: String) -> int:
	_ensure()
	return int(_index.get(bone, -1))


static func parent(i: int) -> int:
	_ensure()
	return _parent[i]


static func head(i: int) -> Vector3:
	return BONES[i][2]


static func tail(i: int) -> Vector3:
	return BONES[i][3]


static func length(i: int) -> float:
	return (BONES[i][3] as Vector3).distance_to(BONES[i][2])


## A bone's rest transform in model space (origin at its head, Y along it).
static func rest_global(i: int) -> Transform3D:
	_ensure()
	return _rest_global[i]


## Every bone's rest transform relative to its parent, in bone order (do not modify).
static func rest_locals() -> Array[Transform3D]:
	_ensure()
	return _rest_local


## Every bone's parent (-1 for the root), in bone order; parents come before children.
static func parents() -> PackedInt32Array:
	_ensure()
	return _parent


## A bone's rest transform relative to its parent.
static func rest_local(i: int) -> Transform3D:
	_ensure()
	return _rest_local[i]


static func _ensure() -> void:
	if not _rest_global.is_empty():
		return
	for i in BONES.size():
		_index[BONES[i][0]] = i
	_parent.resize(BONES.size())
	for i in BONES.size():
		var b: Array = BONES[i]
		_parent[i] = int(_index.get(b[1], -1))
		var y: Vector3 = ((b[3] as Vector3) - (b[2] as Vector3)).normalized()
		var hint := Vector3.RIGHT
		match b[4]:
			"limb":
				# X = Y × forward, so a positive turn about X swings the tail forward.
				hint = y.cross(Vector3.FORWARD)
				if hint.length() < 0.01:
					hint = Vector3.RIGHT
			"clav":
				hint = Vector3.UP.cross(y) if (b[0] as String).ends_with("_r") else y.cross(Vector3.UP)
			"foot", "spine":
				hint = Vector3.RIGHT
		var x := (hint - y * hint.dot(y)).normalized()
		var z := x.cross(y).normalized()
		_rest_global.append(Transform3D(Basis(x, y, z), b[2]))
	for i in BONES.size():
		var p := _parent[i]
		_rest_local.append(_rest_global[i] if p < 0 else _rest_global[p].affine_inverse() * _rest_global[i])


## A Skeleton3D with every bone and its rest pose, posed at rest.
static func build() -> Skeleton3D:
	_ensure()
	var s := Skeleton3D.new()
	s.name = "Skeleton"
	for i in BONES.size():
		s.add_bone(BONES[i][0])
	for i in BONES.size():
		s.set_bone_parent(i, _parent[i])
		s.set_bone_rest(i, _rest_local[i])
	s.reset_bone_poses()
	return s
