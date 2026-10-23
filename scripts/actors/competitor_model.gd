class_name CompetitorModel
## A FAULTPRINT competitor: an industrial athlete, not a soldier. Geometric hard plates
## over a big cloth body, an asymmetric shoulder (the left one carries a heavy plate), a
## helmet with a slit visor and a tall fin, a waist pack. The team's info colour sits on
## the arm band, the visor and a marker over the head; the shape of that marker (a down
## chevron for enemies, a ring for allies) says the same thing without colour.
## Carbon outline so the silhouette reads at speed.
##
##   var model := CompetitorModel.build(info_color, is_enemy, rng)
##   model.find_child("GunHand", true, false)   # Node3D where the held gun goes (gun points -Z)

const CLOTH_COLORS := [Faultprint.CONCRETE, Faultprint.DUST, Faultprint.SLATE, Faultprint.KRAFT]


static func build(info: Color, enemy: bool, rng: RandomNumberGenerator) -> CompetitorRig:
	if Settings.look == Faultprint.COUNTERFORM:
		return _athlete(info, enemy, rng)
	var root := CompetitorRig.new()
	root.name = "Competitor"
	var cloth := Faultprint.surface(CLOTH_COLORS[rng.randi() % CLOTH_COLORS.size()], {"slip": null, "pattern": 1, "dot_density": 22.0})
	var plate := Faultprint.surface(Faultprint.BONE if rng.randf() < 0.6 else Faultprint.TEAL, {"slip": null, "dot_density": 20.0})
	var dark := Faultprint.surface(Faultprint.GRAPHITE, {"slip": null, "dot_density": 24.0})
	if Settings.look == Faultprint.COUNTERFORM:
		# Fabric in graphite / grey-green, painted armour plates, rubber boots.
		var fabric := [Color("#4E5450"), Color("#5E5A52"), Color("#3E4245")]
		cloth = Counterform.material("polymer", fabric[rng.randi() % fabric.size()], false)
		plate = Counterform.material("paint", Counterform.DUST_WHITE if rng.randf() < 0.6 else Counterform.GREEN_GREY, false)
		dark = Counterform.material("rubber", Counterform.GRAPHITE_DEEP, false)
	var mark := Faultprint.flat(info)
	var parts := [
		# legs
		[Vector3(0.17, 0.82, 0.2), Vector3(-0.12, 0.41, 0), cloth, Vector3.ZERO],
		[Vector3(0.17, 0.82, 0.2), Vector3(0.12, 0.41, 0), cloth, Vector3.ZERO],
		[Vector3(0.2, 0.16, 0.26), Vector3(-0.12, 0.08, -0.03), dark, Vector3.ZERO],
		[Vector3(0.2, 0.16, 0.26), Vector3(0.12, 0.08, -0.03), dark, Vector3.ZERO],
		[Vector3(0.19, 0.22, 0.06), Vector3(-0.12, 0.55, -0.12), plate, Vector3(8, 0, 0)],
		# torso: cloth core, a wedge chest plate, a waist pack
		[Vector3(0.46, 0.6, 0.27), Vector3(0, 1.12, 0), cloth, Vector3.ZERO],
		[Vector3(0.5, 0.34, 0.08), Vector3(0.0, 1.25, -0.16), plate, Vector3(-6, 0, 4)],
		[Vector3(0.34, 0.14, 0.2), Vector3(0.05, 0.84, 0.13), dark, Vector3.ZERO],
		# asymmetric shoulders
		[Vector3(0.26, 0.12, 0.34), Vector3(-0.3, 1.43, 0), plate, Vector3(0, 0, 18)],
		[Vector3(0.14, 0.1, 0.2), Vector3(0.28, 1.42, 0), dark, Vector3(0, 0, -10)],
		# arms (reaching forward to the gun)
		[Vector3(0.12, 0.42, 0.12), Vector3(-0.3, 1.18, -0.12), cloth, Vector3(-38, 0, 8)],
		[Vector3(0.12, 0.42, 0.12), Vector3(0.28, 1.18, -0.1), cloth, Vector3(-50, 0, -6)],
		# helmet with fin
		[Vector3(0.26, 0.26, 0.28), Vector3(0, 1.63, 0), plate, Vector3.ZERO],
		[Vector3(0.04, 0.12, 0.3), Vector3(0.0, 1.8, 0.02), dark, Vector3(-10, 0, 0)],
		[Vector3(0.28, 0.08, 0.04), Vector3(0, 1.63, -0.15), dark, Vector3.ZERO],
	]
	for p in parts:
		var m := MeshInstance3D.new()
		m.mesh = LowPoly.chamfer_box(p[0], minf(0.03, p[0][p[0].min_axis_index()] * 0.25))
		m.position = p[1]
		m.rotation_degrees = p[3]
		m.material_override = p[2]
		root.add_child(m)
	Faultprint.outline(root, 0.022)
	# Info colour: arm band, visor slit, head marker (no outline: they're flat signals).
	var band := MeshInstance3D.new()
	band.mesh = LowPoly.chamfer_box(Vector3(0.14, 0.07, 0.14), 0.01)
	band.position = Vector3(-0.3, 1.3, -0.05)
	band.material_override = mark
	root.add_child(band)
	var visor := MeshInstance3D.new()
	visor.mesh = LowPoly.chamfer_box(Vector3(0.2, 0.03, 0.02), 0.005)
	visor.position = Vector3(0, 1.64, -0.175)
	visor.material_override = mark
	root.add_child(visor)
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	if enemy:
		marker.mesh = LowPoly.extrude(PackedVector2Array([Vector2(-0.14, 0.1), Vector2(0, -0.06), Vector2(0.14, 0.1), Vector2(0, 0.03)]), 0.02)
	else:
		marker.mesh = PrintFx._ring_mesh(0.07, 0.11, 12)
	marker.material_override = Faultprint.flat(info, true)
	marker.position = Vector3(0, 2.12, 0)
	root.add_child(marker)
	var hand := Node3D.new()
	hand.name = "GunHand"
	hand.position = Vector3(0.18, 1.22, -0.32)
	root.add_child(hand)
	root.rig()
	return root



# --- Counterform: a sculpted industrial athlete -------------------------------------------

## Stylised realism (art direction §7): a real human build in a fitted grey-green or
## graphite suit, painted hard plates on the chest, knees and the left shoulder, a compact
## pack, rubber boots and gloves, a rounded helmet with a dark visor and a short fin.
## Limbs are tapered turned forms between real joints, posed holding a rifle at the ready.
static func _athlete(info: Color, enemy: bool, rng: RandomNumberGenerator) -> CompetitorRig:
	var root := CompetitorRig.new()
	root.name = "Competitor"
	var fabrics := [Color("#4E5450"), Color("#5E5A52"), Color("#3E4245"), Color("#55594F")]
	var suit := Counterform.material("polymer", fabrics[rng.randi() % fabrics.size()], false)
	var plate := Counterform.material("paint", Counterform.DUST_WHITE if rng.randf() < 0.55 else Counterform.GREEN_GREY, false)
	var rubber := Counterform.material("rubber", Counterform.GRAPHITE_DEEP, false)
	var gear := Counterform.material("polymer", Color("#2C2F31"), false)
	var lens := Counterform.material("lens", Color("#1E2A2E"), false)
	var accent := Counterform.material("paint", Counterform.SULFUR if rng.randf() < 0.5 else Counterform.OXIDE_ORANGE, false)
	# Legs: a slightly staggered stance, knees a little bent.
	for sx: float in [-1.0, 1.0]:
		var hip := Vector3(sx * 0.11, 0.94, 0.0)
		var knee := Vector3(sx * 0.125, 0.52, -0.05 if sx < 0.0 else 0.02)
		var ankle := Vector3(sx * 0.125, 0.1, 0.02 if sx < 0.0 else 0.06)
		_limb(root, hip, knee, 0.1, 0.07, suit)
		_limb(root, knee, ankle, 0.068, 0.05, suit)
		_ball(root, knee, 0.066, suit)
		# Knee pad, boot with a thick sole.
		_slab(root, [Vector2(knee.z - 0.07, knee.y + 0.07), Vector2(knee.z - 0.085, knee.y), Vector2(knee.z - 0.07, knee.y - 0.08),
				Vector2(knee.z - 0.03, knee.y - 0.08), Vector2(knee.z - 0.035, knee.y + 0.07)], 0.12, plate, knee.x, 0.012)
		var b := ankle
		_slab(root, [Vector2(b.z + 0.06, b.y + 0.07), Vector2(b.z + 0.07, b.y - 0.05), Vector2(b.z - 0.17, b.y - 0.05), Vector2(b.z - 0.19, b.y - 0.03),
				Vector2(b.z - 0.15, b.y + 0.01), Vector2(b.z - 0.05, b.y + 0.05), Vector2(b.z - 0.03, b.y + 0.1), Vector2(b.z + 0.05, b.y + 0.1)],
				0.115, rubber, b.x, 0.018)
		_slab(root, [Vector2(b.z + 0.075, b.y - 0.045), Vector2(b.z + 0.075, b.y - 0.1), Vector2(b.z - 0.195, b.y - 0.1), Vector2(b.z - 0.195, b.y - 0.045)],
				0.12, gear, b.x, 0.01)
	# Pelvis and belt.
	_slab(root, [Vector2(0.11, 1.02), Vector2(0.12, 0.9), Vector2(0.06, 0.84), Vector2(-0.08, 0.84), Vector2(-0.12, 0.9), Vector2(-0.11, 1.02)],
			0.34, suit, 0.0, 0.05)
	_slab(root, [Vector2(0.125, 1.04), Vector2(0.125, 0.98), Vector2(-0.125, 0.98), Vector2(-0.125, 1.04)], 0.36, gear, 0.0, 0.012)
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(0.08, 0.1, 0.07), Vector3(sx * 0.15, 0.96, -0.08), gear)
	# Torso: a turned, flattened form (broad chest, narrow waist), a painted chest plate on it.
	var torso := GunKit.turned(PackedVector2Array([Vector2(-0.27, 0.07), Vector2(-0.255, 0.15), Vector2(-0.21, 0.205), Vector2(-0.09, 0.21),
			Vector2(0.04, 0.175), Vector2(0.14, 0.155), Vector2(0.22, 0.17), Vector2(0.27, 0.16), Vector2(0.29, 0.0)]), 20)
	_put(root, torso, Vector3(0, 1.25, 0.0), suit, Vector3(90, 0, 0)).scale = Vector3(1.0, 0.64, 1.0)
	_slab(root, [Vector2(-0.1, 1.46), Vector2(-0.15, 1.38), Vector2(-0.158, 1.24), Vector2(-0.135, 1.14), Vector2(-0.08, 1.14), Vector2(-0.08, 1.46)],
			0.3, plate, 0.0, 0.025)
	_slab(root, [Vector2(-0.152, 1.3), Vector2(-0.162, 1.3), Vector2(-0.162, 1.26), Vector2(-0.152, 1.26)], 0.16, accent, 0.0, 0.003)
	# Webbing straps over the shoulders to the pack.
	for sx: float in [-1.0, 1.0]:
		_slab(root, [Vector2(-0.09, 1.46), Vector2(0.0, 1.53), Vector2(0.13, 1.44), Vector2(0.13, 1.4), Vector2(0.0, 1.49), Vector2(-0.09, 1.42)],
				0.05, gear, sx * 0.12, 0.006)
	# Pack on the back: a hard shell with a sulfur or oxide stripe.
	_slab(root, [Vector2(0.12, 1.12), Vector2(0.24, 1.14), Vector2(0.26, 1.2), Vector2(0.25, 1.4), Vector2(0.13, 1.44)], 0.3, gear, 0.0, 0.03)
	_slab(root, [Vector2(0.255, 1.36), Vector2(0.262, 1.36), Vector2(0.262, 1.32), Vector2(0.255, 1.32)], 0.302, accent, 0.0, 0.0)
	# Neck, helmet (turned), visor, fin.
	_limb(root, Vector3(0, 1.5, 0.0), Vector3(0, 1.62, -0.01), 0.066, 0.06, suit)
	_put(root, GunKit.turned(PackedVector2Array([Vector2(-0.03, 0.075), Vector2(0.0, 0.095), Vector2(0.025, 0.1)]), 16), Vector3(0, 1.52, 0.0),
			gear, Vector3(90, 0, 0))
	var head := Vector3(0, 1.69, -0.01)
	var helmet := GunKit.turned(PackedVector2Array([Vector2(-0.13, 0.0), Vector2(-0.125, 0.045), Vector2(-0.1, 0.095), Vector2(-0.05, 0.122),
			Vector2(0.02, 0.126), Vector2(0.06, 0.118), Vector2(0.075, 0.1), Vector2(0.075, 0.0)]), 20)
	_put(root, helmet, head, plate, Vector3(90, 0, 0)).scale = Vector3(1.0, 1.0, 1.12)
	_slab(root, [Vector2(-0.1, 1.73), Vector2(-0.145, 1.7), Vector2(-0.15, 1.64), Vector2(-0.13, 1.6), Vector2(-0.08, 1.6)], 0.2, lens, 0.0, 0.015)
	_slab(root, [Vector2(-0.06, 1.8), Vector2(0.1, 1.8), Vector2(0.13, 1.76), Vector2(-0.02, 1.78)], 0.02, gear, 0.0, 0.004)
	for sx: float in [-1.0, 1.0]:
		_cyl_x(root, Vector3(sx * 0.118, 1.67, 0.0), 0.035, 0.02, gear)
	# Arms: right hand on the grip (GunHand), left hand forward on the handguard.
	var hand_r := Vector3(0.18, 1.2, -0.3)
	var hand_l := Vector3(0.14, 1.24, -0.56)
	var sh_r := Vector3(0.23, 1.43, 0.0)
	var sh_l := Vector3(-0.23, 1.43, 0.0)
	var el_r := Vector3(0.3, 1.13, -0.1)
	var el_l := Vector3(-0.1, 1.12, -0.32)
	for arm in [[sh_r, el_r, hand_r], [sh_l, el_l, hand_l]]:
		_limb(root, arm[0], arm[1], 0.07, 0.056, suit)
		_limb(root, arm[1], arm[2], 0.056, 0.044, suit)
		_ball(root, arm[0], 0.078, suit)
		_ball(root, arm[1], 0.056, suit)
		_ball(root, arm[2], 0.045, rubber)
	# The left shoulder carries a heavy plate; the right a small cap.
	_put(root, GunKit.turned(PackedVector2Array([Vector2(-0.06, 0.0), Vector2(-0.05, 0.07), Vector2(-0.01, 0.1), Vector2(0.04, 0.1),
			Vector2(0.05, 0.0)]), 16), sh_l + Vector3(-0.03, 0.02, 0.0), plate, Vector3(90, 0, 30))
	_put(root, GunKit.turned(PackedVector2Array([Vector2(-0.04, 0.0), Vector2(-0.03, 0.06), Vector2(0.03, 0.07), Vector2(0.035, 0.0)]), 14),
			sh_r + Vector3(0.02, 0.02, 0.0), gear, Vector3(90, 0, -25))
	# Info colour: arm band, visor slit, head marker (flat signals, readable through light).
	var mark := Faultprint.flat(info)
	var band := _limb(root, sh_l.lerp(el_l, 0.5) + (el_l - sh_l).normalized() * 0.04, sh_l.lerp(el_l, 0.5) - (el_l - sh_l).normalized() * 0.04,
			0.066, 0.066, mark)
	band.name = "Band"
	var visor := MeshInstance3D.new()
	visor.mesh = LowPoly.chamfer_box(Vector3(0.17, 0.016, 0.01), 0.003)
	visor.position = Vector3(0, 1.665, -0.152)
	visor.material_override = mark
	root.add_child(visor)
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	if enemy:
		marker.mesh = LowPoly.extrude(PackedVector2Array([Vector2(-0.14, 0.1), Vector2(0, -0.06), Vector2(0.14, 0.1), Vector2(0, 0.03)]), 0.02)
	else:
		marker.mesh = PrintFx._ring_mesh(0.07, 0.11, 12)
	marker.material_override = Faultprint.flat(info, true)
	marker.position = Vector3(0, 2.12, 0)
	root.add_child(marker)
	var hand := Node3D.new()
	hand.name = "GunHand"
	hand.position = Vector3(0.18, 1.22, -0.32)
	root.add_child(hand)
	root.rig()
	return root


## A tapered limb from joint a (radius ra) to joint b (radius rb), rounded at both ends.
static func _limb(root: Node3D, a: Vector3, b: Vector3, ra: float, rb: float, m: Material) -> MeshInstance3D:
	var l := a.distance_to(b)
	var h := l / 2.0
	var mesh := GunKit.turned(PackedVector2Array([Vector2(-h - rb * 0.3, rb * 0.55), Vector2(-h, rb), Vector2(-h * 0.2, lerpf(rb, ra, 0.45) * 1.06),
			Vector2(h, ra), Vector2(h + ra * 0.3, ra * 0.55)]), 14)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = m
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
	node.transform = Transform3D(Basis.looking_at(dir, up), (a + b) / 2.0)
	root.add_child(node)
	return node


static func _ball(root: Node3D, at: Vector3, r: float, m: Material) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	_put(root, sphere, at, m, Vector3.ZERO)


static func _slab(root: Node3D, outline: Array, width: float, m: Material, x: float, bevel: float) -> void:
	_put(root, GunKit.slab(PackedVector2Array(outline), width, bevel), Vector3(x, 0, 0), m, Vector3.ZERO)


static func _box(root: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	_put(root, LowPoly.chamfer_box(size, 0.012), at, m, Vector3.ZERO)


static func _cyl_x(root: Node3D, at: Vector3, r: float, length: float, m: Material) -> void:
	_put(root, GunKit.rod(r, length, 16), at, m, Vector3(0, 90, 0))


static func _put(root: Node3D, mesh: Mesh, at: Vector3, m: Material, rot: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = m
	node.transform = LowPoly.at(at, rot)
	root.add_child(node)
	return node
