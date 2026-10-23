class_name AthleteBody
## The athlete's skinned body (character overhaul, Phase 2): one mesh over the 24-bone
## AthleteBones skeleton, in six surfaces (jacket, trousers, neck gaiter, face, gloves, boots). Built
## from lofts with real anatomy under the suit: a pelvis wider than the waist, a ribcage
## and chest, trapezius sloping into the neck, deltoids, a forearm wider than deep, a calf
## that bulges at the back, a heel, an instep, the ball of the foot. Joints blend their
## weights across a few centimetres, so a bent elbow or knee stays round.
##
##   var mesh := AthleteBody.build(AthleteBody.materials(look))   # look: {suit, pants, gaiter, skin, glove, boot}
##
## The face is a real face under the helmet and goggles: jaw, chin, mouth, nose, cheeks.

const SIDES := 18


## The six materials in surface order, for a look.
static func materials(look: Dictionary) -> Array[Material]:
	return [CharMaterials.fabric(look.suit), CharMaterials.fabric(look.pants), CharMaterials.fabric(look.gaiter), CharMaterials.skin(look.skin),
		CharMaterials.leather(look.glove), CharMaterials.leather(look.boot)]


static func build(mats: Array[Material]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := Loft.begin()
	_torso(st)
	for s in ["l", "r"]:
		_arm(st, s)
	mesh = Loft.commit(st, mesh, mats[0])
	st = Loft.begin()
	_seat(st)
	for s in ["l", "r"]:
		_leg(st, s)
	mesh = Loft.commit(st, mesh, mats[1])
	st = Loft.begin()
	_neck(st)
	mesh = Loft.commit(st, mesh, mats[2])
	st = Loft.begin()
	_head(st)
	mesh = Loft.commit(st, mesh, mats[3])
	st = Loft.begin()
	for s in ["l", "r"]:
		_hand(st, s)
	mesh = Loft.commit(st, mesh, mats[4])
	st = Loft.begin()
	for s in ["l", "r"]:
		_boot(st, s)
	mesh = Loft.commit(st, mesh, mats[5])
	return mesh


static func b(name: String) -> int:
	return AthleteBones.index(name)


## Weights from a list of [bone name, weight] pairs.
static func w(pairs: Array) -> Dictionary:
	var out := {}
	for p in pairs:
		var i := b(p[0])
		out[i] = float(out.get(i, 0.0)) + float(p[1])
	return out


# --- Torso ---------------------------------------------------------------------------

## y, centre z, side radius, front, back, exponent, weights.
const TORSO := [
	[0.855, 0.012, 0.118, 0.07, 0.085, 2.2, [["hips", 1.0]]],
	[0.9, 0.012, 0.158, 0.092, 0.112, 2.3, [["hips", 1.0]]],
	[0.96, 0.008, 0.168, 0.098, 0.118, 2.4, [["hips", 1.0]]],
	[1.02, 0.004, 0.16, 0.094, 0.104, 2.4, [["hips", 0.6], ["spine", 0.4]]],
	[1.08, 0.0, 0.146, 0.09, 0.09, 2.3, [["spine", 1.0]]],
	[1.14, -0.004, 0.148, 0.096, 0.09, 2.3, [["spine", 0.65], ["chest", 0.35]]],
	[1.21, -0.006, 0.16, 0.108, 0.094, 2.4, [["chest", 0.85], ["spine", 0.15]]],
	[1.28, -0.004, 0.172, 0.118, 0.1, 2.5, [["chest", 1.0]]],
	[1.34, 0.0, 0.182, 0.122, 0.106, 2.6, [["chest", 0.45], ["upper_chest", 0.55]]],
	[1.395, 0.008, 0.188, 0.112, 0.11, 2.8, [["upper_chest", 1.0]]],
	[1.435, 0.014, 0.17, 0.094, 0.104, 2.6, [["upper_chest", 1.0]]],
	[1.468, 0.02, 0.128, 0.074, 0.088, 2.3, [["upper_chest", 0.9], ["neck", 0.1]]],
	[1.495, 0.022, 0.088, 0.062, 0.072, 2.1, [["upper_chest", 0.6], ["neck", 0.4]]],
	[1.512, 0.022, 0.066, 0.056, 0.064, 2.0, [["upper_chest", 0.4], ["neck", 0.6]]],
]


## The trousers' seat up to the belt, then the jacket from under the belt (the belt
## hides the seam; the jacket's hem sits a touch proud of the trousers).
static func _seat(st: SurfaceTool) -> void:
	var rings := []
	for r in TORSO:
		if r[0] <= 1.025:
			rings.append(Loft.ring(Vector3(0, r[0], r[1]), Vector3.RIGHT, Vector3.FORWARD, r[2], r[3], r[4], w(r[6]), r[5]))
	Loft.tube(st, rings, 24, true, false)


static func _torso(st: SurfaceTool) -> void:
	var rings := []
	var hem: Array = TORSO[2]
	rings.append(Loft.ring(Vector3(0, 0.972, hem[1]), Vector3.RIGHT, Vector3.FORWARD, hem[2] + 0.002, hem[3] + 0.002, hem[4] + 0.002, w(hem[6]), hem[5]))
	rings.append(Loft.ring(Vector3(0, 0.975, hem[1]), Vector3.RIGHT, Vector3.FORWARD, hem[2] + 0.007, hem[3] + 0.007, hem[4] + 0.007, w(hem[6]), hem[5]))
	for r in TORSO:
		if r[0] > 1.0:
			rings.append(Loft.ring(Vector3(0, r[0], r[1]), Vector3.RIGHT, Vector3.FORWARD, r[2], r[3], r[4], w(r[6]), r[5]))
	Loft.tube(st, rings, 24, false, false)
	# A stand-up collar round the base of the neck.
	var collar := []
	for r in [[1.47, 0.086, 0.08, 0.09, [["upper_chest", 1.0]]], [1.505, 0.082, 0.078, 0.086, [["upper_chest", 0.6], ["neck", 0.4]]],
			[1.552, 0.078, 0.075, 0.082, [["upper_chest", 0.2], ["neck", 0.8]]], [1.556, 0.07, 0.068, 0.075, [["upper_chest", 0.2], ["neck", 0.8]]]]:
		collar.append(Loft.ring(Vector3(0, r[0], 0.012), Vector3.RIGHT, Vector3.FORWARD, r[1], r[2], r[3], w(r[4]), 2.3))
	Loft.tube(st, collar, 22, false, false)


static func _neck(st: SurfaceTool) -> void:
	var rings := []
	for r in [[1.43, 0.066, 0.07, 0.076, [["upper_chest", 1.0]]], [1.48, 0.065, 0.068, 0.072, [["upper_chest", 0.5], ["neck", 0.5]]],
			[1.53, 0.062, 0.064, 0.066, [["neck", 1.0]]], [1.58, 0.06, 0.064, 0.064, [["neck", 0.5], ["head", 0.5]]],
			[1.605, 0.06, 0.066, 0.064, [["head", 1.0]]]]:
		rings.append(Loft.ring(Vector3(0, r[0], 0.006), Vector3.RIGHT, Vector3.FORWARD, r[1], r[2], r[3], w(r[4]), 2.2))
	Loft.tube(st, rings, SIDES, false, false)
	# The gaiter's rolled top edge.
	var top := []
	for r in [[1.598, 0.064, 0.07, 0.068], [1.612, 0.066, 0.072, 0.07], [1.622, 0.06, 0.066, 0.064]]:
		top.append(Loft.ring(Vector3(0, r[0], 0.006), Vector3.RIGHT, Vector3.FORWARD, r[1], r[2], r[3], w([["head", 1.0]]), 2.2))
	Loft.tube(st, top, SIDES, false, false)


# --- Head ------------------------------------------------------------------------------

## The skull and face, round the vertical: y, side, front, back. The front radius makes the
## profile: chin, mouth, the nose bridge under the goggles, the brow.
const HEAD := [
	[1.585, 0.036, 0.04, 0.03],
	[1.598, 0.052, 0.074, 0.052],
	[1.615, 0.062, 0.086, 0.07],
	[1.635, 0.068, 0.092, 0.084],
	[1.66, 0.074, 0.098, 0.094],
	[1.69, 0.078, 0.1, 0.1],
	[1.72, 0.079, 0.098, 0.104],
	[1.75, 0.074, 0.09, 0.1],
	[1.775, 0.062, 0.074, 0.088],
	[1.795, 0.04, 0.048, 0.06],
	[1.805, 0.012, 0.014, 0.018],
]


static func _head(st: SurfaceTool) -> void:
	var hw := w([["head", 1.0]])
	var rings := []
	for r in HEAD:
		rings.append(Loft.ring(Vector3(0, r[0], 0.0), Vector3.RIGHT, Vector3.FORWARD, r[1], r[2], r[3], hw, 2.3))
	Loft.tube(st, rings, 22)
	# Jaw line: the lower face is narrower at the chin than at the angle of the jaw.
	var jaw := []
	for r in [[1.588, 0.0, 0.028, 0.012, 0.026], [1.6, -0.036, 0.042, 0.02, 0.03], [1.618, -0.046, 0.05, 0.02, 0.026]]:
		jaw.append(Loft.ring(Vector3(0, r[0], r[1]), Vector3.RIGHT, Vector3.FORWARD, r[2], r[3], r[4], hw, 2.4))
	Loft.tube(st, jaw, 16)
	# Nose: a wedge from the bridge (under the goggles) down to the tip.
	var nose := []
	for r in [[1.67, -0.096, 0.01, 0.006], [1.648, -0.105, 0.012, 0.01], [1.632, -0.106, 0.015, 0.012], [1.624, -0.098, 0.011, 0.01]]:
		nose.append(Loft.ring(Vector3(0, r[0], r[1]), Vector3.RIGHT, Vector3.BACK, r[2], r[3], r[3], hw, 2.0))
	Loft.tube(st, nose, 10)
	# Lips: a slight fullness over the mouth line.
	var lips := []
	for x in [-0.024, -0.012, 0.0, 0.012, 0.024]:
		var fx: float = 1.0 - absf(x) / 0.03
		lips.append(Loft.ring(Vector3(x, 1.607, -0.092 - 0.004 * fx), Vector3.UP, Vector3.FORWARD, 0.006 * fx + 0.002,
				0.004 * fx + 0.001, 0.004, hw, 2.0))
	Loft.tube(st, lips, 8)
	# Ears (under the headset cups): flattened discs.
	for sx: float in [-1.0, 1.0]:
		var ear := []
		for r in [[0.0, 0.004], [0.01, 0.018], [0.017, 0.016], [0.02, 0.004]]:
			ear.append(Loft.ring(Vector3(sx * (0.072 + r[0]), 1.69, 0.014), Vector3.UP, Vector3.FORWARD, r[1] * 1.4, r[1], r[1], hw, 2.0))
		Loft.tube(st, ear, 12)


# --- Arms ------------------------------------------------------------------------------

## Along the upper arm (t of its length): radius side, front, back.
const UPPER_ARM := [
	[-0.1, 0.05, 0.05, 0.05],
	[0.0, 0.062, 0.06, 0.058],
	[0.14, 0.064, 0.058, 0.056],
	[0.32, 0.056, 0.052, 0.052],
	[0.55, 0.05, 0.048, 0.05],
	[0.8, 0.047, 0.046, 0.048],
]
const FOREARM := [
	[0.0, 0.045, 0.044, 0.047],
	[0.14, 0.05, 0.046, 0.044],
	[0.35, 0.051, 0.042, 0.04],
	[0.62, 0.043, 0.035, 0.034],
	[0.86, 0.035, 0.029, 0.028],
]


static func _arm(st: SurfaceTool, s: String) -> void:
	var clav := b("clavicle_" + s)
	var upper := b("upper_arm_" + s)
	var fore := b("forearm_" + s)
	var rings := []
	var gu := AthleteBones.rest_global(upper)
	var gf := AthleteBones.rest_global(fore)
	var lu := AthleteBones.length(upper)
	var lf := AthleteBones.length(fore)
	# The shoulder starts inside the torso, under the trapezius.
	for r in UPPER_ARM:
		var t: float = r[0]
		var wt := Loft.blend(clav, upper, (t + 0.1) / 0.24)
		if t > 0.7:
			wt = Loft.blend(upper, fore, (t - 0.82) / 0.36)
		rings.append(Loft.ring(gu.origin + gu.basis.y * lu * t, gu.basis.x, gu.basis.z, r[1], r[2], r[3], wt, 2.2))
	# The elbow: a blend across it, the point of the elbow at the back.
	rings.append(Loft.ring(gu.origin + gu.basis.y * lu * 0.96, gu.basis.x, gu.basis.z, 0.046, 0.044, 0.05, {upper: 0.55, fore: 0.45}, 2.2))
	for r in FOREARM:
		var t: float = r[0]
		var wt := Loft.blend(upper, fore, (t + 0.1) / 0.22)
		rings.append(Loft.ring(gf.origin + gf.basis.y * lf * t, gf.basis.x, gf.basis.z, r[1], r[2], r[3], wt, 2.3))
	Loft.tube(st, rings, SIDES, true, true)


## The gloved hand: a palm, four fingers in one curl, a thumb, a cuff over the wrist.
static func _hand(st: SurfaceTool, s: String) -> void:
	var fore := b("forearm_" + s)
	var hand := b("hand_" + s)
	var fing := b("fingers_" + s)
	var gf := AthleteBones.rest_global(fore)
	var gh := AthleteBones.rest_global(hand)
	var gg := AthleteBones.rest_global(fing)
	var lf := AthleteBones.length(fore)
	var lh := AthleteBones.length(hand)
	# Gauntlet cuff from the lower forearm over the wrist.
	var cuff := []
	for r in [[0.8, 0.04, 0.036, 0.035, {fore: 1.0}], [0.9, 0.039, 0.035, 0.034, {fore: 0.9, hand: 0.1}],
			[1.0, 0.036, 0.031, 0.031, {fore: 0.5, hand: 0.5}]]:
		cuff.append(Loft.ring(gf.origin + gf.basis.y * lf * r[0], gf.basis.x, gf.basis.z, r[1], r[2], r[3], r[4], 2.6))
	Loft.tube(st, cuff, SIDES)
	# Palm: thin across the hinge (x), wide front to back.
	var palm := []
	for r in [[-0.05, 0.022, 0.03, 0.028, {fore: 0.4, hand: 0.6}], [0.2, 0.021, 0.038, 0.034, {hand: 1.0}],
			[0.6, 0.019, 0.044, 0.04, {hand: 1.0}], [0.95, 0.017, 0.044, 0.042, {hand: 0.8, fing: 0.2}],
			[1.05, 0.013, 0.04, 0.038, {hand: 0.5, fing: 0.5}]]:
		palm.append(Loft.ring(gh.origin + gh.basis.y * lh * r[0], gh.basis.x, gh.basis.z, r[1], r[2], r[3], r[4], 2.8))
	Loft.tube(st, palm, SIDES)
	# Four fingers side by side across z (index at the front), one curl bone.
	for f in 4:
		var off := (0.028 - f * 0.0185) + 0.002
		var length := 0.074 - absf(f - 1.2) * 0.008
		var base := gg.origin + gg.basis.z * off - gg.basis.y * 0.004
		var finger := []
		for r in [[0.0, 0.0098, {hand: 0.5, fing: 0.5}], [0.35, 0.0094, {fing: 1.0}], [0.7, 0.0086, {fing: 1.0}], [1.0, 0.007, {fing: 1.0}]]:
			finger.append(Loft.ring(base + gg.basis.y * length * r[0], gg.basis.x, gg.basis.z, r[1] * 0.92, r[1], r[1], r[2], 2.0))
		Loft.tube(st, finger, 8)
	# Thumb: from the front of the palm, angled forward and down, on the hand bone.
	var tb := gh.origin + gh.basis.y * lh * 0.15 + gh.basis.z * 0.035
	var td := (gh.basis.y * 0.55 + gh.basis.z * 0.8).normalized()
	var thumb := []
	for r in [[0.0, 0.013], [0.4, 0.011], [0.75, 0.0098], [1.0, 0.008]]:
		thumb.append(Loft.ring(tb + td * 0.055 * r[0], gh.basis.x, gh.basis.y, r[1], r[1], r[1], {hand: 1.0}, 2.0))
	Loft.tube(st, thumb, 8)


# --- Legs and boots --------------------------------------------------------------------

const THIGH := [
	[-0.1, 0.088, 0.086, 0.092],
	[0.04, 0.1, 0.098, 0.102],
	[0.22, 0.097, 0.098, 0.094],
	[0.45, 0.086, 0.088, 0.082],
	[0.7, 0.073, 0.076, 0.07],
	[0.88, 0.064, 0.066, 0.064],
]
const SHIN := [
	[0.06, 0.06, 0.06, 0.064],
	[0.2, 0.064, 0.058, 0.074],
	[0.36, 0.062, 0.056, 0.072],
	[0.56, 0.055, 0.052, 0.058],
	[0.76, 0.05, 0.05, 0.05],
]


static func _leg(st: SurfaceTool, s: String) -> void:
	var thigh := b("thigh_" + s)
	var shin := b("shin_" + s)
	var gt := AthleteBones.rest_global(thigh)
	var gs := AthleteBones.rest_global(shin)
	var lt := AthleteBones.length(thigh)
	var ls := AthleteBones.length(shin)
	var hips := b("hips")
	var rings := []
	for r in THIGH:
		var t: float = r[0]
		var wt := Loft.blend(hips, thigh, (t + 0.12) / 0.24)
		if t > 0.8:
			wt = Loft.blend(thigh, shin, (t - 0.9) / 0.2)
		rings.append(Loft.ring(gt.origin + gt.basis.y * lt * t, gt.basis.x, gt.basis.z, r[1], r[2], r[3], wt, 2.2))
	rings.append(Loft.ring(gt.origin + gt.basis.y * lt * 0.99, gt.basis.x, gt.basis.z, 0.062, 0.066, 0.06, {thigh: 0.5, shin: 0.5}, 2.2))
	for r in SHIN:
		var t: float = r[0]
		rings.append(Loft.ring(gs.origin + gs.basis.y * ls * t, gs.basis.x, gs.basis.z, r[1], r[2], r[3], Loft.blend(thigh, shin, (t + 0.06) / 0.14), 2.2))
	Loft.tube(st, rings, SIDES, true, true)


## A boot: a padded shaft over the ankle, then the foot along the foot bone with a flat
## sole, a heel behind the ankle and a toe box that bends with the toe bone.
static func _boot(st: SurfaceTool, s: String) -> void:
	var shin := b("shin_" + s)
	var foot := b("foot_" + s)
	var toe := b("toe_" + s)
	var gs := AthleteBones.rest_global(shin)
	var ls := AthleteBones.length(shin)
	var shaft := []
	for r in [[0.7, 0.047, 0.046, 0.048, {shin: 1.0}], [0.82, 0.049, 0.047, 0.05, {shin: 1.0}],
			[0.94, 0.05, 0.048, 0.052, {shin: 0.8, foot: 0.2}], [1.04, 0.05, 0.05, 0.054, {shin: 0.4, foot: 0.6}]]:
		shaft.append(Loft.ring(gs.origin + gs.basis.y * ls * r[0], gs.basis.x, gs.basis.z, r[1], r[2], r[3], r[4], 2.4))
	Loft.tube(st, shaft, SIDES, false, true)
	# The foot along the ground (so the sole sits flat at rest): rings across x, up and
	# down from a centre line; the heel and instep on the foot bone, the toe box on the toe.
	var x := gs.origin.x + 0.004 * signf(gs.origin.x)
	var body := []
	for r in [[0.078, 0.064, 0.03, 0.026, 0.03, 0.0], [0.06, 0.072, 0.04, 0.042, 0.042, 0.0], [0.02, 0.078, 0.046, 0.05, 0.048, 0.0],
			[-0.03, 0.07, 0.049, 0.042, 0.04, 0.0], [-0.08, 0.056, 0.051, 0.03, 0.026, 0.1], [-0.115, 0.05, 0.051, 0.024, 0.02, 0.45],
			[-0.15, 0.046, 0.048, 0.02, 0.016, 0.85], [-0.182, 0.044, 0.04, 0.017, 0.014, 1.0], [-0.2, 0.043, 0.024, 0.01, 0.01, 1.0]]:
		var wt := Loft.blend(foot, toe, r[5])
		body.append(Loft.ring(Vector3(x, r[1], r[0]), Vector3.RIGHT, Vector3.UP, r[2], r[3], r[4], wt, 3.0))
	Loft.tube(st, body, SIDES)
