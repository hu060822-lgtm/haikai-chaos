class_name GunPartsC7
## Models for the C7 slot types (Arsenal: tactical, spring, magwell, cheek, sling). Since
## C7 every part fits every frame, so these only lean on anchors every Rig has (top,
## stock, mag, comb/butt) and size themselves from the frame's body width.


static func f(name: String, glow := Color.BLACK) -> Material:
	return GunModels.fin(name, glow)


## Where a top tactical device sits: on the top rail, ahead of the sight.
static func tactical_point(r: GunModels.Rig) -> Vector3:
	var z := lerpf(r.top.z, r.muzzle.z, 0.3)
	return Vector3(0, maxf(r.top.y, r.hg_y + r.hg_r) + 0.004, minf(z, r.top.z - 0.05))


static func cheek_point(r: GunModels.Rig) -> Vector3:
	return r.comb if r.comb != Vector3.INF else r.stock + Vector3(0, 0.022, 0.07)


static func sling_point(r: GunModels.Rig) -> Vector3:
	var butt := r.butt if r.butt != Vector3.INF else r.stock + Vector3(0, -0.02, 0.1)
	return butt + Vector3(0, -0.02, -0.03)


static func draw(r: GunModels.Rig, slot: String, id: String) -> void:
	match slot:
		"tactical": _tactical(r, id)
		"spring": _spring(r, id)
		"magwell": _magwell(r, id)
		"cheek": _cheek(r, id)
		"sling": _sling(r, id)


static func _tactical(r: GunModels.Rig, id: String) -> void:
	var at := tactical_point(r)
	var black := f("black")
	# A rail clamp with a riser down to whatever is under it.
	GunModels._box(r.root, Vector3(0.018, 0.008, 0.024), at + Vector3(0, 0.004, 0), black, Vector3.ZERO, 0.0015)
	var c := at + Vector3(0, 0.018, 0)
	match id:
		"top_light":
			GunModels._turn(r.root, [Vector2(-0.034, 0.012), Vector2(-0.03, 0.012), Vector2(-0.02, 0.009), Vector2(0.03, 0.009)], c, black, 20)
			GunModels._cyl(r.root, 0.0105, 0.002, c + Vector3(0, 0, -0.0345), f("dust", Color(1.0, 0.95, 0.75) * 1.2), 20)
		"top_laser":
			GunModels._box(r.root, Vector3(0.02, 0.016, 0.044), c, f("poly_tan"), Vector3.ZERO, 0.003)
			GunModels._cyl(r.root, 0.003, 0.002, c + Vector3(0.004, 0.002, -0.0225), f("bore", Color(1.0, 0.05, 0.05) * 1.4), 10)
		"rangefinder":
			GunModels._box(r.root, Vector3(0.026, 0.02, 0.05), c, black, Vector3.ZERO, 0.004)
			for sx: float in [-0.006, 0.006]:
				GunModels._cyl(r.root, 0.0055, 0.003, c + Vector3(sx, 0.002, -0.0255), f("lens", Color(0.05, 0.12, 0.2)), 14)
			GunModels._box(r.root, Vector3(0.012, 0.004, 0.012), c + Vector3(0, 0.012, 0.01), f("rubber"), Vector3.ZERO, 0.001)
		"thermal_clip":
			GunModels._box(r.root, Vector3(0.036, 0.034, 0.06), c + Vector3(0, 0.006, 0), f("poly_grey"), Vector3.ZERO, 0.005)
			GunModels._cyl(r.root, 0.013, 0.008, c + Vector3(0, 0.006, -0.034), f("lens", Color(0.25, 0.05, 0.0)), 18)
			GunModels._box(r.root, Vector3(0.012, 0.008, 0.01), c + Vector3(0.012, 0.026, 0.016), f("oxide"), Vector3.ZERO, 0.001)
		"ballistic_pc":
			GunModels._box(r.root, Vector3(0.03, 0.022, 0.034), c, black, Vector3.ZERO, 0.003)
			GunModels._box(r.root, Vector3(0.024, 0.016, 0.002), c + Vector3(0, 0.002, 0.0175), f("bore", Color(0.2, 0.9, 0.35)), Vector3(-12, 0, 0), 0.0)
		_:
			GunModels._generic(r, c, id)


## Buffers and springs live inside: a coloured band on the back of the receiver and, on a
## tuned buffer, a knob, so you can still see which one you have.
static func _spring(r: GunModels.Rig, id: String) -> void:
	var at := r.stock + Vector3(0, 0.002, -0.004)
	var w := maxf(r.body_w, 0.012)
	var tint: Material = {"buffer_heavy": f("steel"), "spring_light": f("sulfur"), "tuned_buffer": f("oxide"),
		"hydraulic_buffer": f("copper"), "runaway_spring": f("shell_red")}.get(id, f("dust"))
	GunModels._box(r.root, Vector3(w * 2.0 + 0.003, 0.012, 0.006), at, tint, Vector3.ZERO, 0.0012)
	match id:
		"tuned_buffer":
			GunModels._cyl_x(r.root, 0.006, 0.006, at + Vector3(w + 0.004, 0, 0), f("oxide"), 12)
		"hydraulic_buffer":
			GunModels._cyl(r.root, 0.007, 0.03, at + Vector3(0, -0.014, 0.014), f("copper"), 12)
		"runaway_spring":
			# A coil poking out of the back, like it escaped.
			var pts := []
			for i in 13:
				var a := i * 0.9
				pts.append(at + Vector3(cos(a) * 0.008, 0.012 + sin(a) * 0.008, 0.004 + i * 0.0035))
			GunModels._tube(r.root, pts, 0.0012, f("chrome"))


## The magwell flare: a lip around the bottom of the well the magazine goes in.
static func _magwell(r: GunModels.Rig, id: String) -> void:
	var at := r.mag + Vector3(0, -0.004, 0)
	var w := r.mag_w + 0.008
	var d := r.mag_d + 0.012
	var m := f("black")
	match id:
		"flared_magwell":
			GunModels._box(r.root, Vector3(w + 0.006, 0.012, d + 0.006), at, m, Vector3(r.mag_tilt, 0, 0), 0.002)
		"funnel_magwell":
			GunModels._box(r.root, Vector3(w + 0.016, 0.02, d + 0.018), at + Vector3(0, -0.006, 0), f("oxide"), Vector3(r.mag_tilt, 0, 0), 0.003)
			GunModels._box(r.root, Vector3(w + 0.004, 0.022, d + 0.004), at + Vector3(0, -0.007, 0), f("bore"), Vector3(r.mag_tilt, 0, 0), 0.0)
		"ambi_release":
			for sx: float in [-1.0, 1.0]:
				GunModels._box(r.root, Vector3(0.004, 0.008, 0.01), at + Vector3(sx * (w / 2.0 + 0.002), 0.012, -d * 0.4), f("oxide"), Vector3.ZERO, 0.001)
		"mag_coupler":
			# A clamp on the magazine and a second magazine beside it, upside down.
			GunModels._box(r.root, Vector3(w * 2.2, 0.012, d * 0.6), at + Vector3(w * 0.55, -0.05, 0), f("poly_tan"), Vector3.ZERO, 0.002)
			GunModels._box(r.root, Vector3(r.mag_w, r.mag_len * 0.8, r.mag_d), at + Vector3(w * 1.1, -0.05 - r.mag_len * 0.3, 0), f("polymer"),
					Vector3(-r.mag_tilt, 0, 180), 0.003)
		_:
			GunModels._generic(r, at, id)


static func _cheek(r: GunModels.Rig, id: String) -> void:
	var at := cheek_point(r)
	var w := maxf(r.body_w * 2.0, 0.026)
	match id:
		"cheek_raised":
			GunModels._box(r.root, Vector3(w, 0.014, 0.07), at + Vector3(0, 0.007, 0), f("polymer"), Vector3.ZERO, 0.003)
		"cheek_leather":
			GunModels._box(r.root, Vector3(w + 0.006, 0.018, 0.08), at + Vector3(0, 0.004, 0), f("laminate"), Vector3.ZERO, 0.005)
			for i in 4:
				GunModels._box(r.root, Vector3(w + 0.008, 0.002, 0.002), at + Vector3(0, 0.004, -0.03 + i * 0.02), f("dust"), Vector3.ZERO, 0.0)
		"cheek_gel":
			GunModels._box(r.root, Vector3(w, 0.016, 0.065), at + Vector3(0, 0.008, 0), f("poly_green"), Vector3.ZERO, 0.007)
		"cheek_adjust":
			for z: float in [-0.022, 0.022]:
				GunModels._cyl_y(r.root, 0.003, 0.02, at + Vector3(0, 0.006, z), f("chrome"), 10)
			var lift := 0.006 + 0.008 * float(r.tune.get("cheek", 0.0))
			GunModels._box(r.root, Vector3(w, 0.01, 0.075), at + Vector3(0, 0.012 + lift, 0), f("black"), Vector3.ZERO, 0.003)
			GunModels._cyl_x(r.root, 0.005, 0.006, at + Vector3(w / 2.0 + 0.003, 0.006, 0), f("oxide"), 12)
		_:
			GunModels._generic(r, at, id)


## A swivel at the back, and a strap hanging in a loose curve under the gun.
static func _sling(r: GunModels.Rig, id: String) -> void:
	var at := sling_point(r)
	var colour: Material = {"single_point": f("black"), "two_point": f("poly_green"), "bungee_sling": f("poly_tan"),
		"tow_strap": f("sulfur")}.get(id, f("dust"))
	GunModels._box(r.root, Vector3(0.012, 0.012, 0.006), at, f("steel"), Vector3.ZERO, 0.0015)
	var front := Vector3(0, r.under.y - 0.01, lerpf(r.under.z, at.z, 0.35)) if id == "two_point" or id == "tow_strap" else at + Vector3(0, -0.12, 0.02)
	var pts := []
	for i in 9:
		var t := i / 8.0
		var p := at.lerp(front, t)
		p.y -= sin(t * PI) * (0.07 if id != "bungee_sling" else 0.045)
		p.x = -0.004
		pts.append(p)
	GunModels._tube(r.root, pts, 0.0035 if id != "tow_strap" else 0.005, colour)
