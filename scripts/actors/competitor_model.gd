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



# --- Counterform: the skinned athlete (character overhaul) ---------------------------------

## Stylised realism (art direction §7): a real human build under a fitted suit, a plate
## carrier, a shell helmet with goggles and comms, pads, pouches and parkour boots
## (AthleteBody, AthleteGear on the AthleteBones skeleton, posed by AthleteRig). Each
## competitor draws its own low-saturation palette; the team's info colour is on the arm
## band, the goggles' slit and the marker over the head.
static func _athlete(info: Color, enemy: bool, rng: RandomNumberGenerator) -> CompetitorRig:
	# The look draws from its own generator, seeded from the caller's, which takes exactly
	# the three draws the old model took, so a bot's own random choices after this (its
	# strafes, its aim) stay the same as before.
	var own := RandomNumberGenerator.new()
	own.seed = rng.randi()
	rng.randf()
	rng.randf()
	var root := AthleteRig.create(look(info, own))
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	if enemy:
		marker.mesh = LowPoly.extrude(PackedVector2Array([Vector2(-0.14, 0.1), Vector2(0, -0.06), Vector2(0.14, 0.1), Vector2(0, 0.03)]), 0.02)
	else:
		marker.mesh = PrintFx._ring_mesh(0.07, 0.11, 12)
	marker.material_override = Faultprint.flat(info, true)
	marker.position = Vector3(0, 2.12, 0)
	root.add_child(marker)
	return root


## One competitor's colours: suit, gaiter, carrier, shell, gloves, boots, skin, an accent.
static func look(info: Color, rng: RandomNumberGenerator) -> Dictionary:
	var suits := [Color("#4E5450"), Color("#5E5A52"), Color("#3E4245"), Color("#55594F")]
	var carriers := [Color("#3A3D38"), Color("#5E5848"), Color("#2E3134"), Color("#4A4F45")]
	var shells := [Counterform.DUST_WHITE.darkened(0.12), Counterform.GREEN_GREY, Color("#7D827C"), Color("#A39E92")]
	var gloves := [Color("#2C2F31"), Color("#4A4238"), Color("#3B3A36")]
	var boots := [Color("#3B3631"), Color("#2A2B2C"), Color("#4A453C")]
	var pants := [Color("#3F433F"), Color("#56524A"), Color("#34383B"), Color("#4B4F46")]
	var suit: Color = suits[rng.randi() % suits.size()]
	return {
		"suit": suit, "pants": pants[rng.randi() % pants.size()], "gaiter": suit.darkened(0.35), "carrier": carriers[rng.randi() % carriers.size()],
		"cordura": carriers[rng.randi() % carriers.size()], "shell": shells[rng.randi() % shells.size()],
		"webbing": Color("#2C2F2E"), "rubber": Counterform.GRAPHITE_DEEP, "metal": Color("#8C8F8E"),
		"glove": gloves[rng.randi() % gloves.size()], "boot": boots[rng.randi() % boots.size()],
		"skin": CharMaterials.SKIN_TONES[rng.randi() % CharMaterials.SKIN_TONES.size()],
		"accent": Counterform.SULFUR if rng.randf() < 0.5 else Counterform.OXIDE_ORANGE, "info": info,
	}
