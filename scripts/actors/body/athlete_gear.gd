class_name AthleteGear
## The athlete's kit (character overhaul, Phase 2), layered over the skinned body as more
## surfaces of the same mesh. Every piece is bound to one bone (or two across a bend) at
## full weight, so it moves with that bone as a rigid piece and costs no extra nodes:
##
##   head    a rounded shell helmet with side rails, an NVG shroud and a short fin; goggles
##           with a team signal slit; comm cups over the ears; a boom mic to the mouth
##   torso   a plate carrier (cordura over the suit) with front and back plates, shoulder
##           straps, three mag pouches and an admin pouch; a small back pack, a radio and
##           its antenna
##   waist   a belt with a steel buckle, a hip pouch and a dump pouch
##   limbs   a right thigh panel on two straps, knee pads, elbow pads, a painted left
##           shoulder plate, the team arm band on the left arm, knuckle guards, a wrist
##           unit on the left forearm, boot soles
##
##   AthleteGear.build(mesh, AthleteGear.materials(look))   # adds the gear surfaces to the body's mesh
##
## look: {shell, cordura, webbing, rubber, metal, accent, info} colours.

const LAYERS := ["shell", "cordura", "webbing", "rubber", "metal", "lens", "accent", "signal"]


## The gear materials in surface order (LAYERS), for a look.
static func materials(look: Dictionary) -> Array[Material]:
	return [CharMaterials.shell(look.shell), CharMaterials.cordura(look.cordura, false), CharMaterials.webbing(look.webbing),
		CharMaterials.rubber(look.rubber, false), CharMaterials.metal(look.metal), CharMaterials.lens(Color("#1A2226")),
		CharMaterials.shell(look.accent), CharMaterials.signal_color(look.info)]


static func build(mesh: ArrayMesh, mats: Array[Material]) -> ArrayMesh:
	var st := {}
	for k in LAYERS:
		st[k] = Loft.begin()
	_helmet(st)
	_face_kit(st)
	_carrier(st)
	_belt(st)
	for s in ["l", "r"]:
		_legs(st, s)
		_arms(st, s)
	_boots(st)
	for i in LAYERS.size():
		mesh = Loft.commit(st[LAYERS[i]], mesh, mats[i])
	return mesh


static func b(name: String) -> int:
	return AthleteBones.index(name)


static func one(name: String) -> Dictionary:
	return {b(name): 1.0}


## The torso's surface at height y: [centre z, side, front, back radius, exponent, weights].
static func torso_at(y: float) -> Array:
	var rows: Array = AthleteBody.TORSO
	for i in rows.size() - 1:
		var lo: Array = rows[i]
		var hi: Array = rows[i + 1]
		if y <= float(hi[0]) or i == rows.size() - 2:
			var t := clampf((y - float(lo[0])) / (float(hi[0]) - float(lo[0])), 0.0, 1.0)
			var wt := {}
			for p in lo[6]:
				var k := b(p[0])
				wt[k] = float(wt.get(k, 0.0)) + float(p[1]) * (1.0 - t)
			for p in hi[6]:
				var k := b(p[0])
				wt[k] = float(wt.get(k, 0.0)) + float(p[1]) * t
			return [lerpf(lo[1], hi[1], t), lerpf(lo[2], hi[2], t), lerpf(lo[3], hi[3], t), lerpf(lo[4], hi[4], t), lerpf(lo[5], hi[5], t), wt]
	return [0.0, 0.1, 0.1, 0.1, 2.0, one("chest")]


# --- Head ---------------------------------------------------------------------------------

## y, centre z, front tilt (the brim rises at the front over the goggles), side, front, back.
const HELMET := [
	[1.672, 0.0, 0.45, 0.1, 0.122, 0.125],
	[1.7, 0.0, 0.33, 0.104, 0.125, 0.129],
	[1.735, 0.0, 0.18, 0.104, 0.124, 0.129],
	[1.77, 0.0, 0.06, 0.098, 0.115, 0.121],
	[1.8, 0.004, 0.0, 0.085, 0.099, 0.105],
	[1.825, 0.006, 0.0, 0.063, 0.073, 0.077],
	[1.842, 0.006, 0.0, 0.03, 0.034, 0.036],
]


static func _helmet(st: Dictionary) -> void:
	var hw := one("head")
	var rings := []
	# An inner lip first, so the brim has a thickness.
	var first: Array = HELMET[0]
	var tz := Vector3(0, sin(first[2]), -cos(first[2]))
	rings.append(Loft.ring(Vector3(0, first[0] + 0.004, first[1]), Vector3.RIGHT, tz, first[3] - 0.012, first[4] - 0.012, first[5] - 0.012, hw, 2.2))
	for r in HELMET:
		var z := Vector3(0, sin(r[2]), -cos(r[2]))
		rings.append(Loft.ring(Vector3(0, r[0], r[1]), Vector3.RIGHT, z, r[3], r[4], r[5], hw, 2.2))
	Loft.tube(st.shell, rings, 26, false, true)
	# Side rails, the NVG shroud at the front, a short fin along the top.
	for sx: float in [-1.0, 1.0]:
		Loft.box(st.rubber, Vector3(sx * 0.108, 1.722, 0.004), Vector3.UP, Vector3.BACK, Vector3.RIGHT * sx, 0.011, 0.062, 0.006, hw, 6.0)
		for zz: float in [-0.04, 0.0, 0.04]:
			Loft.box(st.metal, Vector3(sx * 0.115, 1.722, zz), Vector3.UP, Vector3.BACK, Vector3.RIGHT * sx, 0.004, 0.004, 0.002, hw, 4.0)
	var n := Vector3(0, 0.5, -0.866)
	var up := Vector3(0, 0.866, 0.5)
	Loft.box(st.rubber, Vector3(0, 1.79, -0.107), Vector3.RIGHT, up, n, 0.026, 0.018, 0.008, hw, 6.0)
	Loft.box(st.metal, Vector3(0, 1.79, -0.116), Vector3.RIGHT, up, n, 0.012, 0.01, 0.003, hw, 4.0)
	Loft.box(st.shell, Vector3(0, 1.84, 0.025), Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.005, 0.05, 0.009, hw, 4.0, 0.6)


static func _face_kit(st: Dictionary) -> void:
	var hw := one("head")
	# Goggles: a curved lens round the front of the face at eye level, a rubber frame
	# behind it, and the team's signal slit across the lens.
	var lens := PackedVector3Array()
	var frame := PackedVector3Array()
	var slit := PackedVector3Array()
	var count := 9
	for i in count:
		var x := lerpf(-0.074, 0.074, float(i) / (count - 1))
		var f := pow(maxf(1.0 - pow(absf(x) / 0.084, 2.3), 0.0), 1.0 / 2.3)
		var z := -0.1 * f - 0.016
		lens.append(Vector3(x, 1.69, z))
		frame.append(Vector3(x, 1.69, z + 0.006))
		if absf(x) < 0.056:
			slit.append(Vector3(x, 1.688, z - 0.009))
	_band(st.rubber, frame, 0.027, 0.011, hw)
	_band(st.lens, lens, 0.022, 0.008, hw)
	_band(st.signal, slit, 0.0035, 0.002, hw)
	# Comm cups over the ears, outside the helmet.
	for sx: float in [-1.0, 1.0]:
		var cup := []
		for r in [[0.098, 0.03], [0.108, 0.037], [0.124, 0.038], [0.134, 0.032], [0.138, 0.016]]:
			cup.append(Loft.ring(Vector3(sx * r[0], 1.664, 0.01), Vector3.UP, Vector3.FORWARD, r[1], r[1], r[1], hw, 2.4))
		Loft.tube(st.rubber, cup, 18, true, true)
		Loft.tube(st.metal, [Loft.ring(Vector3(sx * 0.125, 1.664, 0.01), Vector3.UP, Vector3.FORWARD, 0.04, 0.04, 0.04, hw),
			Loft.ring(Vector3(sx * 0.129, 1.664, 0.01), Vector3.UP, Vector3.FORWARD, 0.04, 0.04, 0.04, hw)], 18, false, false)
	# Boom mic from the right cup round to the mouth, a foam tip on the end.
	var mic := PackedVector3Array()
	var radii := PackedFloat32Array()
	var p0 := Vector3(0.122, 1.648, -0.02)
	var p1 := Vector3(0.11, 1.615, -0.085)
	var p2 := Vector3(0.05, 1.6, -0.112)
	for i in 7:
		var t := float(i) / 6.0
		mic.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
		radii.append(0.0042)
	Loft.path(st.rubber, mic, radii, Vector3.UP, hw)
	Loft.tube(st.rubber, [Loft.ring(p2 + Vector3(0.006, 0, 0), Vector3.UP, Vector3.FORWARD, 0.006, 0.006, 0.006, hw),
		Loft.ring(p2 - Vector3(0.008, 0, 0), Vector3.UP, Vector3.FORWARD, 0.01, 0.01, 0.01, hw),
		Loft.ring(p2 - Vector3(0.02, 0, 0), Vector3.UP, Vector3.FORWARD, 0.007, 0.007, 0.007, hw)], 10)


## A band across the face along `points` (goggles): rings stand up (x = up), thickness
## out from the face.
static func _band(st: SurfaceTool, points: PackedVector3Array, height: float, thick: float, w: Dictionary) -> void:
	var rings := []
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var out := along.cross(Vector3.UP).normalized()
		if out.z > 0.0:
			out = -out
		var k := 1.0 if i > 0 and i < points.size() - 1 else 0.7
		rings.append(Loft.ring(points[i], Vector3.UP, out, height * k, thick, thick, w, 5.0))
	Loft.tube(st, rings, 16)


# --- Torso ----------------------------------------------------------------------------------

static func _carrier(st: Dictionary) -> void:
	# The carrier: cordura over the suit from the waist to the chest, open at the arms.
	var rings := []
	for y: float in [1.095, 1.12, 1.18, 1.25, 1.31, 1.36, 1.405, 1.425]:
		var t := torso_at(y)
		var grow := 0.02 if y < 1.415 else 0.012
		rings.append(Loft.ring(Vector3(0, y, t[0]), Vector3.RIGHT, Vector3.FORWARD, t[1] + grow, t[2] + grow, t[3] + grow, t[5], t[4] + 0.4))
	Loft.tube(st.cordura, rings, 26, false, false)
	# Front and back plates, following the chest's profile a little.
	for back: bool in [false, true]:
		var plate := []
		var span: Array = [[1.13, 0.118], [1.17, 0.122], [1.25, 0.124], [1.32, 0.122], [1.37, 0.108], [1.395, 0.09]]
		for r in span:
			var t := torso_at(r[0])
			var z: float = t[0] + (float(t[3]) + 0.034 if back else -float(t[2]) - 0.034)
			plate.append(Loft.ring(Vector3(0, r[0], z), Vector3.RIGHT, Vector3.FORWARD, r[1], 0.012, 0.012, t[5], 8.0))
		Loft.tube(st.shell, plate, 20)
	# Three mag pouches low on the front, an admin pouch high, a strip of the accent paint.
	for i in 3:
		var x := (i - 1) * 0.074
		var t := torso_at(1.17)
		var z: float = t[0] - float(t[2]) - 0.068
		Loft.box(st.cordura, Vector3(x, 1.165, z), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.031, 0.058, 0.021, t[5], 5.0)
		Loft.box(st.webbing, Vector3(x, 1.222, z - 0.003), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.033, 0.012, 0.024, t[5], 5.0)
	var ta := torso_at(1.32)
	Loft.box(st.cordura, Vector3(0, 1.32, float(ta[0]) - float(ta[2]) - 0.056), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.075, 0.034, 0.011, ta[5], 6.0)
	Loft.box(st.accent, Vector3(0.088, 1.36, float(ta[0]) - float(ta[2]) - 0.049), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.018, 0.006, 0.003, ta[5], 6.0)
	# Shoulder straps from the front plate over the trapezius to the back plate.
	for sx: float in [-1.0, 1.0]:
		var pts := PackedVector3Array([Vector3(sx * 0.098, 1.39, -0.13), Vector3(sx * 0.1, 1.44, -0.088), Vector3(sx * 0.103, 1.497, -0.03),
			Vector3(sx * 0.104, 1.5, 0.035), Vector3(sx * 0.1, 1.455, 0.095), Vector3(sx * 0.098, 1.4, 0.13)])
		var radii := PackedFloat32Array([0.032, 0.032, 0.032, 0.032, 0.032, 0.032])
		var w := torso_at(1.44)[5] as Dictionary
		Loft.path(st.webbing, pts, radii, Vector3.RIGHT, w, 0.22, 12)
	# Back pack with a shell lid, a radio on the left with its antenna.
	var tb := torso_at(1.27)
	var bz: float = float(tb[0]) + float(tb[3]) + 0.046 + 0.046
	Loft.box(st.cordura, Vector3(0, 1.26, bz), Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.105, 0.115, 0.044, tb[5], 5.0, 0.9)
	Loft.box(st.shell, Vector3(0, 1.36, bz + 0.004), Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.098, 0.022, 0.046, tb[5], 6.0, 0.95)
	Loft.box(st.accent, Vector3(0.06, 1.3, bz + 0.046), Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.03, 0.006, 0.003, tb[5], 6.0)
	var tr := torso_at(1.36)
	var rz: float = float(tr[0]) + float(tr[3]) + 0.06
	Loft.box(st.rubber, Vector3(-0.128, 1.35, rz), Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.026, 0.05, 0.02, tr[5], 6.0)
	Loft.path(st.rubber, PackedVector3Array([Vector3(-0.14, 1.4, rz), Vector3(-0.145, 1.48, rz + 0.01), Vector3(-0.15, 1.56, rz + 0.025)]),
		PackedFloat32Array([0.006, 0.004, 0.003]), Vector3.RIGHT, tr[5], 1.0, 6)


static func _belt(st: Dictionary) -> void:
	var rings := []
	for y: float in [0.958, 0.966, 0.994, 1.002]:
		var t := torso_at(y)
		var grow := 0.013 if y > 0.96 and y < 1.0 else 0.006
		rings.append(Loft.ring(Vector3(0, y, t[0]), Vector3.RIGHT, Vector3.FORWARD, t[1] + grow, t[2] + grow, t[3] + grow, one("hips"), t[4]))
	Loft.tube(st.webbing, rings, 26, false, false)
	var t := torso_at(0.98)
	var hw := one("hips")
	Loft.box(st.metal, Vector3(0, 0.98, float(t[0]) - float(t[2]) - 0.017), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.03, 0.021, 0.005, hw, 6.0)
	Loft.box(st.cordura, Vector3(0.172, 0.945, 0.03), Vector3.BACK, Vector3.UP, Vector3.RIGHT, 0.045, 0.05, 0.026, hw, 5.0)
	Loft.box(st.cordura, Vector3(-0.115, 0.935, 0.118), Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.06, 0.06, 0.03, hw, 4.0, 1.1)


# --- Limbs ---------------------------------------------------------------------------------

static func _legs(st: Dictionary, s: String) -> void:
	var thigh := b("thigh_" + s)
	var shin := b("shin_" + s)
	var gt := AthleteBones.rest_global(thigh)
	var gs := AthleteBones.rest_global(shin)
	var lt := AthleteBones.length(thigh)
	var ls := AthleteBones.length(shin)
	if s == "r":
		# Thigh panel on the outside of the right leg, on two straps.
		var c := gt.origin + gt.basis.y * lt * 0.36 + gt.basis.x * 0.098
		Loft.box(st.cordura, c, gt.basis.z, gt.basis.y, gt.basis.x, 0.058, 0.085, 0.016, {thigh: 1.0}, 5.0, 0.9)
		Loft.box(st.webbing, c + gt.basis.x * 0.018, gt.basis.z, gt.basis.y, gt.basis.x, 0.035, 0.03, 0.006, {thigh: 1.0}, 5.0)
		for t: float in [0.22, 0.5]:
			var r := 0.092 - t * 0.04
			var band := []
			for dy: float in [-0.012, 0.012]:
				band.append(Loft.ring(gt.origin + gt.basis.y * (lt * t + dy), gt.basis.x, gt.basis.z, r, r, r, {thigh: 1.0}, 2.2))
			Loft.tube(st.webbing, band, 18, false, false)
	# Knee pad over the kneecap, its strap round the top of the shin.
	var kc := gs.origin + gs.basis.y * 0.03 + gs.basis.z * 0.064
	Loft.box(st.shell, kc, gs.basis.x, gs.basis.y, gs.basis.z, 0.05, 0.062, 0.018, {shin: 0.85, thigh: 0.15}, 3.0)
	Loft.box(st.rubber, kc + gs.basis.z * 0.012, gs.basis.x, gs.basis.y, gs.basis.z, 0.03, 0.034, 0.01, {shin: 0.85, thigh: 0.15}, 4.0)
	var strap := []
	for dy: float in [0.08, 0.1]:
		strap.append(Loft.ring(gs.origin + gs.basis.y * (ls * 0.0 + dy), gs.basis.x, gs.basis.z, 0.056, 0.056, 0.066, {shin: 1.0}, 2.2))
	Loft.tube(st.webbing, strap, 18, false, false)


static func _arms(st: Dictionary, s: String) -> void:
	var upper := b("upper_arm_" + s)
	var fore := b("forearm_" + s)
	var hand := b("hand_" + s)
	var gu := AthleteBones.rest_global(upper)
	var gf := AthleteBones.rest_global(fore)
	var gh := AthleteBones.rest_global(hand)
	var lu := AthleteBones.length(upper)
	var lf := AthleteBones.length(fore)
	var lh := AthleteBones.length(hand)
	var left := s == "l"
	# The back of the arm and hand: right side +x, left side -x (bone x is the hinge).
	var back := gh.basis.x * (1.0 if not left else -1.0)
	# Elbow pad behind the elbow (the elbow points back, -z in the arm's frame).
	Loft.box(st.rubber, gf.origin + gf.basis.y * 0.025 - gf.basis.z * 0.05, gf.basis.x, gf.basis.y, -gf.basis.z, 0.036, 0.042, 0.013, {fore: 1.0}, 3.0)
	# Knuckle guard on the back of the hand.
	Loft.box(st.rubber, gh.origin + gh.basis.y * lh * 0.78 + back * 0.021, gh.basis.z, gh.basis.y, back, 0.038, 0.017, 0.008, {hand: 1.0}, 4.0)
	var outward := (gu.origin - Vector3(0, gu.origin.y, 0)).normalized()
	var top := (outward + Vector3.UP * 0.9).normalized()
	top = (top - gu.basis.y * top.dot(gu.basis.y)).normalized()
	var front := gu.basis.y.cross(top).normalized()
	if front.z > 0.0:
		front = -front
	if left:
		# A heavy painted plate over the left shoulder, the team arm band below it.
		var cap := []
		for r in [[-0.06, 0.05, 0.018], [-0.03, 0.08, 0.032], [0.04, 0.084, 0.034], [0.1, 0.072, 0.03], [0.13, 0.05, 0.02]]:
			var c: Vector3 = gu.origin + gu.basis.y * float(r[0]) + top * 0.062
			cap.append(Loft.ring(c, front, top, r[1], r[2], r[2] * 0.4, {upper: 1.0}, 2.6))
		Loft.tube(st.shell, cap, 20)
		Loft.box(st.accent, gu.origin + gu.basis.y * 0.02 + top * 0.097, front, gu.basis.y, top, 0.04, 0.008, 0.003, {upper: 1.0}, 6.0)
		var band := []
		for t: float in [0.44, 0.47, 0.57, 0.6]:
			var r := 0.057 if t > 0.45 and t < 0.58 else 0.053
			band.append(Loft.ring(gu.origin + gu.basis.y * lu * t, gu.basis.x, gu.basis.z, r, r, r, {upper: 1.0}, 2.2))
		Loft.tube(st.signal, band, 18, false, false)
		# A wrist unit on the back of the left forearm.
		var wc := gf.origin + gf.basis.y * lf * 0.72 + back * 0.04
		Loft.box(st.rubber, wc, gf.basis.z, gf.basis.y, back, 0.024, 0.028, 0.009, {fore: 1.0}, 5.0)
		Loft.box(st.lens, wc + back * 0.009, gf.basis.z, gf.basis.y, back, 0.016, 0.019, 0.002, {fore: 1.0}, 6.0)
	else:
		# A small rubber cap on the right shoulder (the stock sits here).
		var cap := []
		for r in [[-0.04, 0.04, 0.012], [-0.01, 0.06, 0.02], [0.05, 0.058, 0.02], [0.08, 0.04, 0.012]]:
			var c: Vector3 = gu.origin + gu.basis.y * float(r[0]) + top * 0.058
			cap.append(Loft.ring(c, front, top, r[1], r[2], r[2] * 0.4, {upper: 1.0}, 2.4))
		Loft.tube(st.rubber, cap, 16)


## Boot soles: flat on the floor at rest (built along the ground, not the tilted foot
## bone), the heel on the foot bone, the front on the toe so it flexes at the ball.
static func _boots(st: Dictionary) -> void:
	for s in ["l", "r"]:
		var foot := b("foot_" + s)
		var toe := b("toe_" + s)
		var x := AthleteBones.head(foot).x
		var rings := []
		for r in [[0.078, 0.034, 0.0], [0.06, 0.046, 0.0], [0.0, 0.05, 0.0], [-0.06, 0.054, 0.0], [-0.1, 0.056, 0.3],
				[-0.14, 0.054, 0.75], [-0.18, 0.046, 1.0], [-0.205, 0.03, 1.0]]:
			var wt := Loft.blend(foot, toe, r[2])
			var lift := 0.0 if r[0] > -0.15 else (float(-r[0]) - 0.15) * 0.18
			rings.append(Loft.ring(Vector3(x, 0.0145 + lift, r[0]), Vector3.RIGHT, Vector3.UP, r[1], 0.0145, 0.0145, wt, 5.0))
		Loft.tube(st.rubber, rings, 20)
