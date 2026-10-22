class_name GunFrames
## The Counterform frame models (art direction §6): real-feeling, precise, modular guns.
## Each builder draws one frame's own body on a GunModels.Rig and sets the anchors its
## parts bolt onto (see GunModels.Rig); parts are drawn afterwards by GunModels.
## Shapes are side silhouettes (GunKit.slab) and turned parts (GunKit.turned) with real
## split lines, pins and serrations, so receivers, barrels, sights and grips read apart.



static func f(name: String, glow := Color.BLACK) -> Material:
	return GunModels.fin(name, glow)


# --- Handguns ------------------------------------------------------------------------

## A striker or hammer pistol: slide over a frame with a railed dust cover, a moulded
## grip, a guard, sights. `spec` keys: y (slide centre), h, w, back, front, slide, frame,
## grip, rake, hammer (bool), cuts (lightening cuts), comp (compensator length).
static func _pistol(r: GunModels.Rig, spec: Dictionary) -> void:
	var y: float = spec.get("y", 0.075)
	var h: float = spec.get("h", 0.028)
	var w: float = spec.get("w", 0.026)
	var back: float = spec.get("back", 0.036)
	var front: float = spec.get("front", -0.152)
	var slide: Material = spec.get("slide", f("black"))
	var frame_m: Material = spec.get("frame", f("polymer"))
	var bottom := y - h / 2.0
	var top := y + h / 2.0
	# Slide: chamfered top edges, a bevelled nose.
	GunModels._slab(r.root, [Vector2(back, bottom), Vector2(back, top - 0.003), Vector2(back - 0.003, top), Vector2(front + 0.008, top),
			Vector2(front, top - 0.006), Vector2(front, bottom + 0.003), Vector2(front + 0.003, bottom)], w, slide, 0.0, 0.0024)
	# Rear and front cocking serrations; the ejection port with a case in it.
	GunModels._grooves(r, back - 0.004, back - 0.026, y - 0.001, h * 0.7, w / 2.0, 7)
	GunModels._grooves(r, front + 0.032, front + 0.014, y - 0.001, h * 0.7, w / 2.0, 4)
	var port := Vector3(w * 0.22, top + 0.0003, back - 0.07)
	GunModels._box(r.root, Vector3(w * 0.5, 0.0016, 0.032), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._box(r.root, Vector3(0.0016, h * 0.38, 0.032), Vector3(w / 2.0 + 0.0002, top - h * 0.19, port.z), f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.0042, 0.016, Vector3(w * 0.22, top - 0.003, port.z), f("brass"), 10))
	if spec.get("cuts", false):
		for i in 3:
			GunModels._box(r.root, Vector3(w * 0.45, 0.0016, 0.012), Vector3(0, top + 0.0003, front + 0.03 + i * 0.018), f("bore"), Vector3.ZERO, 0.0)
	# The slide/frame split line and the takedown lever.
	GunModels._seam(r, Vector2(back, bottom), Vector2(front, bottom), w / 2.0)
	# Sights: a notched rear blade and a front post with a sulfur dot.
	for sx: float in [-1.0, 1.0]:
		GunModels._box(r.root, Vector3(w * 0.32, 0.006, 0.008), Vector3(sx * w * 0.27, top + 0.003, back - 0.01), slide, Vector3.ZERO, 0.0012)
	GunModels._box(r.root, Vector3(0.0035, 0.006, 0.006), Vector3(0, top + 0.003, front + 0.009), slide, Vector3.ZERO, 0.001)
	GunModels._box(r.root, Vector3(0.0025, 0.0025, 0.001), Vector3(0, top + 0.0045, front + 0.0058), f("sulfur", Color(0.35, 0.3, 0.05)), Vector3.ZERO, 0.0)
	# Frame: a dust cover with rail slots under the slide, down to the grip.
	var fy := bottom
	var dust := fy - 0.016
	GunModels._slab(r.root, [Vector2(back - 0.006, fy), Vector2(front + 0.006, fy), Vector2(front + 0.004, dust + 0.003),
			Vector2(front + 0.01, dust), Vector2(-0.046, dust), Vector2(-0.038, dust - 0.004), Vector2(0.004, dust - 0.004),
			Vector2(0.02, fy - 0.01), Vector2(0.046, fy - 0.012), Vector2(back + 0.012, fy - 0.006), Vector2(back + 0.014, fy - 0.001)],
			w - 0.003, frame_m, 0.0, 0.002)
	for i in 3:
		GunModels._box(r.root, Vector3(w - 0.002, 0.003, 0.004), Vector3(0, dust + 0.0005, front + 0.03 + i * 0.012), f("bore"), Vector3.ZERO, 0.0)
	GunModels._slab(r.root, [Vector2(-0.01, fy - 0.003), Vector2(-0.024, fy - 0.003), Vector2(-0.024, fy - 0.009), Vector2(-0.01, fy - 0.009)],
			w - 0.001, f("black"), 0.0, 0.0008)
	GunModels._pins(r, [Vector2(-0.03, fy - 0.008), Vector2(0.03, fy - 0.006)], (w - 0.003) / 2.0, 0.0018)
	# Slide stop lever on the left.
	GunModels._box(r.root, Vector3(0.002, 0.004, 0.022), Vector3(-(w - 0.003) / 2.0 - 0.001, fy - 0.004, -0.012), f("black"), Vector3.ZERO, 0.0006)
	var rake: float = spec.get("rake", -18.0)
	GunModels._grip(r, Vector3(0, fy - 0.012, 0.022), spec.get("grip", frame_m), Vector3(w + 0.003, 0.092, 0.044), rake)
	GunModels._blade_at(r, -0.016, fy - 0.012, f("black"))
	r.trig = Vector3(0, fy - 0.024, -0.016)
	GunModels._guard(r, -0.046, 0.0, fy - 0.014, 0.034, frame_m, 0.01)
	if spec.get("hammer", false):
		GunModels._slab(r.root, [Vector2(back - 0.002, top - 0.012), Vector2(back + 0.012, top + 0.002), Vector2(back + 0.016, top - 0.002),
				Vector2(back + 0.004, top - 0.016)], 0.008, f("steel"), 0.0, 0.0008)
	# Barrel hood showing in the port, the barrel's crown at the nose.
	GunModels._barrel(r, Vector3(0, y + 0.002, front + 0.03), 0.032, 0.0072, f("bore"), false)
	var comp: float = spec.get("comp", 0.0)
	if comp > 0.0 and not r.parts.has("muzzle") and not r.parts.has("barrel"):
		var m0 := Vector3(0, y, front)
		GunModels._slab(r.root, [Vector2(front + 0.002, top), Vector2(front - comp, top), Vector2(front - comp - 0.004, top - 0.006),
				Vector2(front - comp, bottom + 0.004), Vector2(front + 0.002, bottom + 0.004)], w, slide, 0.0, 0.002)
		for i in 3:
			GunModels._box(r.root, Vector3(w * 0.5, 0.0016, 0.005), Vector3(0, top + 0.0003, front - 0.006 - i * comp / 3.5), f("bore"), Vector3.ZERO, 0.0)
		r.muzzle = m0 + Vector3(0, 0.002, -comp - 0.004)
	r.bolt = Vector3(w / 2.0 + 0.002, top - 0.006, port.z)
	r.recv = Vector3(0, y, (back + front) / 2.0)
	r.top = Vector3(0, top, back - 0.03)
	r.mount = Vector3(0, top, front + 0.03)
	r.body_w = w / 2.0
	r.rail_l = Vector3(0, dust, front + 0.04)
	r.stock = Vector3(0, fy - 0.004, back + 0.006)
	r.side = Vector3((w - 0.003) / 2.0, fy - 0.008, -0.07)
	r.charging = Vector3(0, top - 0.004, back)
	GunModels._pistol_mag(r, spec.get("stick", 0.0), f("polymer"))


static func service_pistol(r: GunModels.Rig) -> void:
	_pistol(r, {"y": 0.075, "slide": f("black"), "frame": f("poly_tan")})


static func heavy_pistol(r: GunModels.Rig) -> void:
	# Steel frame, a hammer, an oxide-orange cerakote slide and laminate grips.
	_pistol(r, {"y": 0.077, "h": 0.027, "w": 0.024, "front": -0.168, "slide": f("steel"), "frame": f("steel"),
			"grip": f("laminate"), "hammer": true, "rake": -14.0})


static func machine_pistol(r: GunModels.Rig) -> void:
	_pistol(r, {"y": 0.076, "slide": f("black"), "frame": f("polymer"), "cuts": true, "comp": 0.026, "stick": 0.075})
	# The selector on the slide's back plate, in oxide orange so it reads from behind.
	GunModels._box(r.root, Vector3(0.006, 0.008, 0.004), Vector3(-0.008, 0.07, 0.038), f("oxide"), Vector3.ZERO, 0.001)


static func revolver(r: GunModels.Rig) -> void:
	var y := 0.07
	var frame := f("steel")
	var recv: String = r.parts.get("receiver", "")
	var chambers := 8 if recv == "cylinder_8" else 6
	var cyl_r := 0.0285 if recv == "cylinder_8" else 0.025
	if recv in ["cylinder_8", "cylinder_45"]:
		r.done["receiver"] = true
	# The frame: top strap over the cylinder window, the recoil shield, the grip frame.
	GunModels._slab(r.root, [Vector2(0.032, y + 0.008), Vector2(0.03, y + 0.022), Vector2(0.012, y + 0.028), Vector2(-0.07, y + 0.028),
			Vector2(-0.072, y + 0.012), Vector2(-0.072, y - 0.03), Vector2(-0.062, y - 0.036), Vector2(-0.02, y - 0.036),
			Vector2(-0.008, y - 0.046), Vector2(0.012, y - 0.046), Vector2(0.03, y - 0.032)], 0.026, frame, 0.0, 0.0022)
	# The window the cylinder sits in (dark), and the cylinder: fluted, chambers showing.
	GunModels._box(r.root, Vector3(0.0275, 0.05, 0.056), Vector3(0, y - 0.006, -0.038), f("bore"), Vector3.ZERO, 0.0)
	var cyl_c := Vector3(0, y - 0.006, -0.038)
	var cyl_m := f("chrome") if recv == "cylinder_8" else f("black")
	GunModels._turn(r.root, [Vector2(-0.026, cyl_r - 0.003), Vector2(-0.024, cyl_r), Vector2(0.024, cyl_r), Vector2(0.026, cyl_r - 0.003)],
			cyl_c, cyl_m, 24)
	for i in chambers:
		var a := TAU * i / chambers
		var flute := Vector3(cos(a) * cyl_r, sin(a) * cyl_r, 0.0)
		GunModels._box(r.root, Vector3(0.0035, 0.0035, 0.03), cyl_c + flute * 0.98 + Vector3(0, 0, 0.004), f("bore"),
				Vector3(0, 0, rad_to_deg(a) + 45.0), 0.0)
		var b := a + PI / chambers
		var pos := cyl_c + Vector3(cos(b), sin(b), 0) * (cyl_r - 0.0095) + Vector3(0, 0, 0.0255)
		GunModels._round(r, GunModels._cyl(r.root, 0.0052 if recv != "cylinder_45" else 0.006, 0.002, pos, f("brass"), 10))
	if recv == "cylinder_45":
		GunModels._cyl(r.root, cyl_r * 0.96, 0.002, cyl_c + Vector3(0, 0, 0.027), f("black"), 20)
	# Barrel with a full underlug and a ramp front sight; ejector rod in the lug.
	var len := GunModels._barrel(r, Vector3(0, y + 0.002, -0.07), 0.14, 0.0105, frame, false)
	GunModels._slab(r.root, [Vector2(-0.07, y - 0.004), Vector2(-0.07 - len + 0.004, y - 0.004), Vector2(-0.07 - len, y - 0.012),
			Vector2(-0.07 - len + 0.01, y - 0.022), Vector2(-0.07, y - 0.022)], 0.016, frame, 0.0, 0.0018)
	GunModels._slab(r.root, [Vector2(-0.07 - len + 0.004, y + 0.012), Vector2(-0.07 - len + 0.004, y + 0.022), Vector2(-0.07 - len + 0.012, y + 0.022),
			Vector2(-0.07 - len + 0.03, y + 0.012)], 0.004, f("black"), 0.0, 0.0005)
	GunModels._box(r.root, Vector3(0.0045, 0.003, 0.01), Vector3(0, y + 0.02, -0.07 - len + 0.009), f("oxide"), Vector3.ZERO, 0.0)
	# The rear sight channel in the top strap; the hammer; the cylinder release.
	GunModels._box(r.root, Vector3(0.006, 0.0016, 0.07), Vector3(0, y + 0.0283, -0.03), f("bore"), Vector3.ZERO, 0.0)
	GunModels._slab(r.root, [Vector2(0.028, y + 0.012), Vector2(0.044, y + 0.03), Vector2(0.05, y + 0.027), Vector2(0.038, y + 0.008)],
			0.008, f("black"), 0.0, 0.0008)
	GunModels._box(r.root, Vector3(0.003, 0.007, 0.012), Vector3(-0.0145, y - 0.008, 0.012), f("black"), Vector3.ZERO, 0.001)
	GunModels._pins(r, [Vector2(0.005, y - 0.03), Vector2(0.022, y - 0.02)], 0.013, 0.0016)
	GunModels._grip(r, Vector3(0, y - 0.034, 0.018), f("laminate"), Vector3(0.03, 0.1, 0.044), -20.0)
	GunModels._blade_at(r, -0.004, y - 0.036, f("black"))
	r.trig = Vector3(0, y - 0.05, -0.004)
	GunModels._guard(r, -0.032, 0.012, y - 0.036, 0.032, frame, 0.009)
	# A lanyard ring at the butt.
	var heel := GunModels._grip_bottom(r)
	GunModels._turn(r.root, [Vector2(-0.003, 0.0055), Vector2(0.003, 0.0055)], heel + Vector3(0, -0.004, 0.012), f("bare"), 12)
	r.top = Vector3(0, y + 0.028, -0.03)
	r.under = Vector3(0, y - 0.024, r.muzzle.z + 0.06)
	r.gadget = heel + Vector3(0, -0.006, 0.012)
	r.side = Vector3(0.014, y - 0.03, 0.01)
	r.stock = Vector3(0, y - 0.03, 0.05)
	r.rail_l = Vector3(-0.009, y - 0.013, -0.07 - len * 0.6)
	r.recv = cyl_c
	r.body_w = 0.013
	r.mount = r.top + Vector3(0, 0, -0.05)
	r.bolt = Vector3(0, y + 0.03, 0.044)
	r.mag = Vector3(0, y - 0.04, -0.05)


# --- AR family -----------------------------------------------------------------------

## An AR receiver set around bore height `y`, scaled by `s`: a flat-top upper with its
## port, forward assist and deflector; a lower with a flared magwell, pins and controls;
## the charging handle. Upper parts recolour or reshape it.
static func _ar(r: GunModels.Rig, y: float, s: float, upper_m: Material, lower_m: Material) -> void:
	var recv: String = r.parts.get("receiver", "")
	var upper := upper_m
	match recv:
		"upper_billet": upper = f("oxide")
		"upper_light": upper = f("steel")
	if recv in ["upper_300", "upper_pcc", "upper_light", "upper_billet"]:
		r.done["receiver"] = true
	var b := 0.075 * s           # back of the receivers
	var fr := -0.105 * s         # front of the upper
	var uw := 0.028 * s
	var top := y + 0.017 * s
	var split := y - 0.012 * s
	# Upper: flat top, a squared nose where the barrel nut sits, a ridge over the port.
	GunModels._slab(r.root, [Vector2(b, split), Vector2(b, top - 0.004), Vector2(b - 0.004, top), Vector2(fr + 0.003, top),
			Vector2(fr, top - 0.003), Vector2(fr, split + 0.002), Vector2(fr + 0.002, split)], uw, upper, 0.0, 0.0022 if recv != "upper_billet" else 0.0008)
	# Forward assist housing and the brass deflector on the right.
	GunModels._turn(r.root, [Vector2(-0.016, 0.0), Vector2(-0.012, 0.007), Vector2(0.02, 0.0075), Vector2(0.024, 0.0)],
			Vector3(uw / 2.0 + 0.003, y + 0.004 * s, b - 0.02), upper, 12)
	GunModels._cyl(r.root, 0.0055, 0.006, Vector3(uw / 2.0 + 0.003, y + 0.004 * s, b - 0.039), f("black"), 12)
	GunModels._slab(r.root, [Vector2(b - 0.045, top - 0.004), Vector2(b - 0.032, top - 0.004), Vector2(b - 0.032, y - 0.004),
			Vector2(b - 0.04, y - 0.004)], uw + 0.008, upper, 0.0, 0.0015)
	# Ejection port, open, a round on the bolt face; the dust cover swung down under it.
	var port := Vector3(uw / 2.0 + 0.0002, y + 0.002 * s, b - 0.085 * s)
	GunModels._box(r.root, Vector3(0.0016, 0.013 * s, 0.034 * s), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.0044, 0.018, port + Vector3(-0.003, 0, 0), f("brass"), 10))
	GunModels._box(r.root, Vector3(0.0012, 0.01 * s, 0.036 * s), port + Vector3(0.0018, -0.013 * s, 0), upper, Vector3(0, 0, -25), 0.0004)
	match recv:
		"upper_light":
			for sx: float in [-1.0, 1.0]:
				for i in 3:
					GunModels._box(r.root, Vector3(0.0014, 0.01, 0.018), Vector3(sx * (uw / 2.0 + 0.0002), y + 0.008, fr + 0.02 + i * 0.026),
							f("bore"), Vector3.ZERO, 0.0)
		"upper_300":
			GunModels._box(r.root, Vector3(uw + 0.0008, 0.005, 0.016), Vector3(0, y + 0.004, fr + 0.012), f("sulfur"), Vector3.ZERO, 0.0)
	GunModels._pic(r, Vector3(0, top, (b + fr) / 2.0), (b - fr) - 0.006)
	# Lower: takedown tabs at the back, a flared magwell, the trigger housing and grip boss.
	var lw := 0.026 * s
	var mag_back := -0.04 * s
	var mag_front := -0.098 * s
	var well_bot := y - 0.062 * s
	var housing := y - 0.04 * s
	GunModels._slab(r.root, [Vector2(b - 0.002, split), Vector2(mag_front + 0.004, split), Vector2(mag_front, split - 0.012),
			Vector2(mag_front - 0.004, well_bot + 0.006), Vector2(mag_front + 0.002, well_bot), Vector2(mag_back + 0.004, well_bot),
			Vector2(mag_back, well_bot + 0.008), Vector2(mag_back + 0.006, housing), Vector2(0.045 * s, housing),
			Vector2(0.06 * s, housing - 0.008), Vector2(b + 0.004, split - 0.016), Vector2(b + 0.006, split - 0.004)],
			lw, lower_m, 0.0, 0.002 if recv != "upper_billet" else 0.0008)
	GunModels._slab(r.root, [Vector2(mag_front - 0.004, well_bot + 0.006), Vector2(mag_front + 0.002, well_bot),
			Vector2(mag_back + 0.004, well_bot), Vector2(mag_back + 0.002, well_bot + 0.012), Vector2(mag_front + 0.002, well_bot + 0.012)],
			lw + 0.004, lower_m, 0.0, 0.0012)
	GunModels._seam(r, Vector2(b, split), Vector2(fr, split), lw / 2.0)
	GunModels._pins(r, [Vector2(b - 0.012, split - 0.006), Vector2(mag_front + 0.008, split - 0.006),
			Vector2(-0.012 * s, housing + 0.008), Vector2(0.012 * s, housing + 0.01)], lw / 2.0, 0.0022)
	# Controls: mag release (right), bolt catch (left), selector (left), oxide-orange accents.
	GunModels._box(r.root, Vector3(0.003, 0.008, 0.008), Vector3(lw / 2.0 + 0.0015, split - 0.022 * s, mag_back + 0.006), f("black"), Vector3.ZERO, 0.001)
	GunModels._box(r.root, Vector3(0.0025, 0.016, 0.006), Vector3(-lw / 2.0 - 0.0012, split - 0.012 * s, mag_back + 0.004), f("black"), Vector3(-10, 0, 0), 0.0008)
	GunModels._slab(r.root, [Vector2(0.03 * s, split - 0.01), Vector2(0.046 * s, split - 0.008), Vector2(0.048 * s, split - 0.013),
			Vector2(0.032 * s, split - 0.016)], 0.002, f("oxide"), -lw / 2.0 - 0.001, 0.0004)
	# Charging handle: a T at the back of the upper.
	r.charging = Vector3(0, top - 0.004, b + 0.008)
	if not r.parts.has("charging"):
		GunModels._slab(r.root, [Vector2(b - 0.004, top - 0.002), Vector2(b + 0.012, top - 0.002), Vector2(b + 0.014, top - 0.008),
				Vector2(b - 0.004, top - 0.008)], 0.03 * s, f("black"), 0.0, 0.0012)
	GunModels._grip(r, Vector3(0, housing - 0.002, 0.042 * s), f("polymer"), Vector3(0.029, 0.09, 0.04) * Vector3(1, s, 1), -20.0)
	GunModels._blade_at(r, -0.006 * s, housing, f("black"))
	r.trig = Vector3(0, housing - 0.012, -0.006 * s)
	GunModels._guard(r, mag_back + 0.004, 0.032 * s, housing, 0.024 * s, lower_m, lw * 0.6)
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y + 0.004 * s, (b + fr) / 2.0)
	r.body_w = uw / 2.0
	r.top = Vector3(0, top + 0.007, -0.01 * s)
	r.mount = Vector3(0, top + 0.007, -0.08 * s)
	r.mag = Vector3(0, well_bot, (mag_back + mag_front) / 2.0)
	r.mag_len = 0.13 * s
	r.mag_w = 0.022 * s
	r.mag_d = 0.055 * s
	r.mag_tilt = 4.0
	r.mag_curve = 10.0
	if recv == "upper_pcc":
		# A magwell block in oxide orange: a skinny 9mm stick in the big rifle well.
		GunModels._box(r.root, Vector3(lw + 0.002, 0.014, 0.052 * s), r.mag + Vector3(0, -0.004, 0), f("oxide"), Vector3.ZERO, 0.002)
		r.mag_d = 0.03
		r.mag_len = 0.15
		r.mag_curve = 0.0
		r.mag_tilt = 2.0


## The buffer tube with its castle nut; with no stock part, a collapsible stock on it.
static func _buffer(r: GunModels.Rig, y: float, s: float, default_stock := true) -> void:
	var b := 0.075 * s
	r.stock = Vector3(0, y, b)
	r.has_buffer = true
	GunModels._turn(r.root, [Vector2(b, 0.0), Vector2(b, 0.0145 * s), Vector2(b + 0.2 * s, 0.0145 * s), Vector2(b + 0.205 * s, 0.012 * s),
			Vector2(b + 0.205 * s, 0.0)], Vector3(0, y, 0), f("black"), 14)
	GunModels._turn(r.root, [Vector2(b + 0.004, 0.0185 * s), Vector2(b + 0.012, 0.0185 * s)], Vector3(0, y, 0), f("black"), 8)
	if r.parts.has("stock") or not default_stock:
		return
	var m := f("polymer")
	GunModels._slab(r.root, [Vector2(b + 0.07, y + 0.022), Vector2(b + 0.235, y + 0.024), Vector2(b + 0.242, y + 0.016),
			Vector2(b + 0.244, y - 0.072), Vector2(b + 0.23, y - 0.078), Vector2(b + 0.2, y - 0.07), Vector2(b + 0.14, y - 0.03),
			Vector2(b + 0.1, y - 0.022), Vector2(b + 0.07, y - 0.02)], 0.034, m, 0.0, 0.003)
	# A lightening window through the stock, and the adjustment lever under the tube.
	GunModels._slab(r.root, [Vector2(b + 0.15, y - 0.022), Vector2(b + 0.215, y - 0.018), Vector2(b + 0.218, y - 0.052),
			Vector2(b + 0.2, y - 0.052)], 0.0352, f("bore"), 0.0, 0.0)
	GunModels._box(r.root, Vector3(0.008, 0.006, 0.04), Vector3(0, y - 0.024, b + 0.11), f("black"), Vector3(-6, 0, 0), 0.0015)
	GunModels._slab(r.root, [Vector2(b + 0.244, y + 0.02), Vector2(b + 0.256, y + 0.02), Vector2(b + 0.256, y - 0.076),
			Vector2(b + 0.244, y - 0.078)], 0.036, f("rubber"), 0.0, 0.002)
	r.butt = Vector3(0, y - 0.028, b + 0.256)
	r.butt_h = 0.096
	r.comb = Vector3(0, y + 0.024, b + 0.17)


## A free-float M-LOK handguard from `from` to `to` (z) round the bore at `y`: an octagon
## with slots on the sides and bottom and the top rail running on from the receiver.
static func _mlok_tube(r: GunModels.Rig, y: float, from: float, to: float, radius: float, m: Material, rail := true) -> void:
	var len := from - to
	var oct := GunKit.turned(PackedVector2Array([Vector2(-len / 2.0, radius * 0.9), Vector2(-len / 2.0 + 0.003, radius),
			Vector2(len / 2.0, radius), Vector2(len / 2.0, radius * 0.92)]), 8)
	GunModels._put(r.root, oct, Vector3(0, y, (from + to) / 2.0), m, Vector3(0, 0, 22.5))
	var slots := int(len / 0.03)
	for i in slots:
		var z := from - 0.02 - i * (len - 0.03) / maxf(slots - 1, 1)
		for a: float in [0.0, 180.0, 270.0]:
			var dir := Vector3(cos(deg_to_rad(a)), sin(deg_to_rad(a)), 0)
			GunModels._box(r.root, Vector3(0.0016, 0.006, 0.02), Vector3(0, y, z) + dir * radius * 0.93, f("bore"), Vector3(0, 0, a), 0.0)
	if rail:
		GunModels._pic(r, Vector3(0, y + radius * 0.93, (from + to) / 2.0), len - 0.004)


static func carbine(r: GunModels.Rig) -> void:
	var y := 0.085
	_ar(r, y, 1.0, f("black"), f("black"))
	GunModels._barrel(r, Vector3(0, y, -0.105), 0.4, 0.0085, f("black"), false)
	r.hg_start = -0.108
	r.hg_end = -0.3
	r.hg_y = y
	r.hg_r = 0.021
	r.gas = Vector3(0, y, -0.32)
	if not r.parts.has("handguard"):
		_mlok_tube(r, y, -0.106, -0.3, 0.021, f("black"))
		# A folding front sight on the end of the rail.
		GunModels._slab(r.root, [Vector2(-0.29, y + 0.026), Vector2(-0.3, y + 0.026), Vector2(-0.3, y + 0.05), Vector2(-0.295, y + 0.05),
				Vector2(-0.29, y + 0.034)], 0.012, f("black"), 0.0, 0.0012)
		GunModels._box(r.root, Vector3(0.0022, 0.008, 0.0022), Vector3(0, y + 0.054, -0.297), f("black"), Vector3.ZERO, 0.0)
	elif not r.parts.has("gas"):
		GunModels._cyl(r.root, 0.012, 0.02, r.gas, f("black"), 12)
	_buffer(r, y, 1.0)
	if not r.parts.has("magazine"):
		GunModels._std_mag(r, f("polymer"))
	_birdcage(r)
	r.under = Vector3(0, y - 0.021, -0.28)
	r.gadget = Vector3(0, y - 0.016, 0.1)
	r.side = Vector3(0.019, y - 0.02, 0.2)


## A birdcage flash hider on a bare muzzle (only when no muzzle part goes there).
static func _birdcage(r: GunModels.Rig) -> void:
	if r.parts.has("muzzle") or r.parts.get("barrel", "") == "integral_suppressor":
		return
	var m := r.muzzle
	var rad := r.barrel_r * 1.35
	GunModels._turn(r.root, [Vector2(-0.044, rad * 0.95), Vector2(-0.042, rad), Vector2(-0.002, rad), Vector2(0.0, rad * 0.8)],
			m, f("black"), 14)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		GunModels._box(r.root, Vector3(0.0018, 0.0035, 0.026), m + Vector3(cos(a), sin(a), 0) * rad + Vector3(0, 0, -0.022), f("bore"),
				Vector3(0, 0, rad_to_deg(a) + 90.0), 0.0)
	GunModels._cyl(r.root, rad * 0.55, 0.0016, m + Vector3(0, 0, -0.0442), f("bore"), 10)
	r.muzzle = m + Vector3(0, 0, -0.044)


static func dmr(r: GunModels.Rig) -> void:
	var y := 0.09
	var s := 1.12
	_ar(r, y, s, f("poly_tan"), f("poly_tan"))
	GunModels._barrel(r, Vector3(0, y, -0.118), 0.52, 0.0105, f("black"), false)
	r.hg_start = -0.12
	r.hg_end = -0.4
	r.hg_y = y
	r.hg_r = 0.025
	r.gas = Vector3(0, y, -0.42)
	if not r.parts.has("handguard"):
		_mlok_tube(r, y, -0.118, -0.4, 0.025, f("poly_tan"))
	elif not r.parts.has("gas"):
		GunModels._cyl(r.root, 0.014, 0.022, r.gas, f("black"), 12)
	_buffer(r, y, s, false)
	if not r.parts.has("stock"):
		# A fixed precision stock with an adjustable comb and a monopod knob.
		var b := 0.075 * s
		GunModels._slab(r.root, [Vector2(b, y + 0.022), Vector2(b + 0.11, y + 0.022), Vector2(b + 0.13, y + 0.034),
				Vector2(b + 0.3, y + 0.034), Vector2(b + 0.31, y + 0.022), Vector2(b + 0.33, y + 0.02), Vector2(b + 0.335, y - 0.086),
				Vector2(b + 0.29, y - 0.09), Vector2(b + 0.24, y - 0.06), Vector2(b + 0.14, y - 0.045), Vector2(b + 0.05, y - 0.03),
				Vector2(b, y - 0.025)], 0.036, f("polymer"), 0.0, 0.003)
		GunModels._slab(r.root, [Vector2(b + 0.13, y + 0.034), Vector2(b + 0.3, y + 0.034), Vector2(b + 0.3, y + 0.04),
				Vector2(b + 0.135, y + 0.04)], 0.03, f("poly_tan"), 0.0, 0.0015)
		GunModels._slab(r.root, [Vector2(b + 0.335, y + 0.022), Vector2(b + 0.35, y + 0.022), Vector2(b + 0.35, y - 0.086),
				Vector2(b + 0.335, y - 0.088)], 0.038, f("rubber"), 0.0, 0.002)
		GunModels._cyl_y(r.root, 0.006, 0.03, Vector3(0, y - 0.085, b + 0.25), f("black"), 10)
		r.butt = Vector3(0, y - 0.033, b + 0.35)
		r.butt_h = 0.11
		r.comb = Vector3(0, y + 0.04, b + 0.22)
	r.mag_len = 0.075
	r.mag_d = 0.065
	r.mag_w = 0.026
	r.mag_tilt = 2.0
	r.mag_curve = 0.0
	if not r.parts.has("magazine"):
		GunModels._std_mag(r, f("polymer"))
	_birdcage(r)
	r.top = Vector3(0, r.top.y, -0.03)
	r.under = Vector3(0, y - 0.025, -0.38)
	r.gadget = Vector3(0, y - 0.035, 0.12)
	r.side = Vector3(0.02, y - 0.02, 0.32)


# --- Kalashnikov, battle rifle, bullpup --------------------------------------------------

static func ak(r: GunModels.Rig) -> void:
	var y := 0.08
	var recv: String = r.parts.get("receiver", "")
	var modern := recv == "ak_modern"
	if recv in ["ak_cover", "ak_modern"]:
		r.done["receiver"] = true
	var steel := f("black")
	var wood := f("polymer") if modern else f("laminate")
	# Stamped receiver: the long box with its dimples, a rounded dust cover with a rib.
	GunModels._slab(r.root, [Vector2(0.1, y + 0.012), Vector2(-0.13, y + 0.012), Vector2(-0.13, y - 0.028), Vector2(-0.112, y - 0.036),
			Vector2(-0.058, y - 0.036), Vector2(-0.052, y - 0.03), Vector2(0.04, y - 0.03), Vector2(0.07, y - 0.024), Vector2(0.1, y - 0.016)],
			0.03, steel, 0.0, 0.0012)
	GunModels._slab(r.root, [Vector2(0.104, y + 0.004), Vector2(0.104, y + 0.016), Vector2(0.09, y + 0.026), Vector2(-0.07, y + 0.026),
			Vector2(-0.08, y + 0.012)], 0.029, f("steel"), 0.0, 0.004)
	for i in 3:
		GunModels._box(r.root, Vector3(0.026, 0.0016, 0.004), Vector3(0, y + 0.0265, 0.06 - i * 0.02), f("bore"), Vector3.ZERO, 0.0)
	for sx: float in [-1.0, 1.0]:
		GunModels._cyl_x(r.root, 0.005, 0.0012, Vector3(sx * 0.0152, y - 0.018, -0.045), f("bore"), 10)
	GunModels._pins(r, [Vector2(-0.12, y - 0.02), Vector2(-0.1, y - 0.005), Vector2(0.03, y - 0.02), Vector2(0.06, y - 0.018)], 0.015, 0.002)
	# Rear sight block and leaf in front of the dust cover.
	GunModels._slab(r.root, [Vector2(-0.08, y + 0.012), Vector2(-0.14, y + 0.012), Vector2(-0.142, y + 0.026), Vector2(-0.085, y + 0.03)],
			0.024, steel, 0.0, 0.0015)
	GunModels._box(r.root, Vector3(0.018, 0.003, 0.05), Vector3(0, y + 0.032, -0.105), steel, Vector3(-2, 0, 0), 0.0008)
	r.top = Vector3(0, y + 0.026, 0.0)
	if recv in ["ak_cover", "ak_modern"]:
		GunModels._pic(r, Vector3(0, y + 0.026, 0.01), 0.17, 0.0, 0.02, f("poly_tan") if modern else f("black"))
		r.top = Vector3(0, y + 0.033, 0.0)
	r.mount = Vector3(0, r.top.y, -0.07)
	# Charging handle on the right, the long selector lever over the port.
	r.charging = Vector3(0.03, y + 0.004, -0.06)
	GunModels._rod_between(r.root, Vector3(0.015, y + 0.004, -0.06), r.charging, 0.0035, f("steel"))
	GunModels._ball(r.root, 0.0075 if modern else 0.006, r.charging, f("polymer") if modern else f("steel"))
	GunModels._slab(r.root, [Vector2(0.06, y - 0.004), Vector2(0.075, y - 0.012), Vector2(-0.02, y - 0.016), Vector2(-0.02, y - 0.008)],
			0.002, f("oxide") if modern else f("steel"), 0.0162, 0.0004)
	var port := Vector3(0.0152, y + 0.004, -0.035)
	GunModels._box(r.root, Vector3(0.0016, 0.011, 0.05), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.0045, 0.02, port + Vector3(-0.003, 0, 0), f("brass"), 10))
	GunModels._grip(r, Vector3(0, y - 0.03, 0.03), f("polymer"), Vector3(0.028, 0.092, 0.04), -22.0)
	GunModels._blade_at(r, -0.015, y - 0.03, f("black"))
	r.trig = Vector3(0, y - 0.042, -0.015)
	GunModels._guard(r, -0.05, 0.01, y - 0.03, 0.028, steel, 0.008)
	GunModels._barrel(r, Vector3(0, y, -0.13), 0.4, 0.0085, steel, false)
	# Gas tube with its handguard over the barrel, the gas block, the front sight base.
	var tube_from := -0.145
	GunModels._turn(r.root, [Vector2(-0.205, 0.0075), Vector2(0.0, 0.0075)], Vector3(0, y + 0.024, tube_from), steel, 12)
	r.gas = Vector3(0, y + 0.014, -0.35)
	if not r.parts.has("gas"):
		GunModels._slab(r.root, [Vector2(-0.335, y + 0.03), Vector2(-0.365, y + 0.03), Vector2(-0.365, y - 0.012), Vector2(-0.335, y - 0.012)],
				0.02, steel, 0.0, 0.002)
	var fs := r.muzzle.z + 0.03
	GunModels._slab(r.root, [Vector2(fs + 0.016, y - 0.012), Vector2(fs - 0.014, y - 0.012), Vector2(fs - 0.014, y + 0.014),
			Vector2(fs + 0.016, y + 0.01)], 0.018, steel, 0.0, 0.0015)
	GunModels._slab(r.root, [Vector2(fs + 0.005, y + 0.012), Vector2(fs - 0.005, y + 0.012), Vector2(fs - 0.005, y + 0.034),
			Vector2(fs + 0.005, y + 0.034)], 0.016, steel, 0.0, 0.001)
	GunModels._box(r.root, Vector3(0.012, 0.024, 0.008), Vector3(0, y + 0.024, fs), f("bore"), Vector3.ZERO, 0.0)
	GunModels._box(r.root, Vector3(0.0022, 0.014, 0.0022), Vector3(0, y + 0.024, fs), steel, Vector3.ZERO, 0.0)
	r.hg_start = -0.145
	r.hg_end = -0.315
	r.hg_y = y + 0.006
	r.hg_r = 0.022
	if not r.parts.has("handguard"):
		GunModels._slab(r.root, [Vector2(-0.145, y + 0.012), Vector2(-0.31, y + 0.012), Vector2(-0.315, y - 0.004), Vector2(-0.308, y - 0.026),
				Vector2(-0.152, y - 0.026), Vector2(-0.145, y - 0.016)], 0.038, wood, 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(-0.15, y + 0.016), Vector2(-0.28, y + 0.016), Vector2(-0.285, y + 0.024), Vector2(-0.275, y + 0.036),
				Vector2(-0.155, y + 0.036), Vector2(-0.148, y + 0.024)], 0.028, wood, 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(-0.31, y + 0.02), Vector2(-0.32, y + 0.02), Vector2(-0.32, y - 0.028), Vector2(-0.31, y - 0.028)],
				0.041, steel, 0.0, 0.0012)
	r.stock = Vector3(0, y, 0.1)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.098, y + 0.012), Vector2(0.16, y + 0.006), Vector2(0.34, y - 0.002), Vector2(0.345, y - 0.088),
				Vector2(0.32, y - 0.092), Vector2(0.22, y - 0.06), Vector2(0.14, y - 0.04), Vector2(0.098, y - 0.03)], 0.034, wood, 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(0.343, y), Vector2(0.351, y), Vector2(0.351, y - 0.088), Vector2(0.343, y - 0.09)],
				0.036, steel, 0.0, 0.0015)
		r.butt = Vector3(0, y - 0.046, 0.352)
		r.butt_h = 0.09
		r.comb = Vector3(0, y + 0.005, 0.24)
	r.mag = Vector3(0, y - 0.036, -0.085)
	r.mag_len = 0.19
	r.mag_w = 0.024
	r.mag_d = 0.05
	r.mag_tilt = 8.0
	r.mag_curve = 32.0
	if not r.parts.has("magazine"):
		GunModels._std_mag(r, f("oxide"))
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y - 0.01, -0.02)
	r.body_w = 0.015
	r.under = Vector3(0, y - 0.025, -0.36)
	r.gadget = Vector3(0, y - 0.03, 0.12)
	r.side = Vector3(0.018, y - 0.02, 0.24)


static func battle_rifle(r: GunModels.Rig) -> void:
	var y := 0.085
	var steel := f("steel")
	# Tall milled receiver, a top cover with the carry handle folded, a cocking handle left.
	GunModels._slab(r.root, [Vector2(0.105, y + 0.014), Vector2(-0.14, y + 0.014), Vector2(-0.145, y + 0.004), Vector2(-0.145, y - 0.04),
			Vector2(-0.11, y - 0.045), Vector2(-0.06, y - 0.045), Vector2(-0.05, y - 0.036), Vector2(0.06, y - 0.036), Vector2(0.105, y - 0.02)],
			0.034, steel, 0.0, 0.002)
	GunModels._slab(r.root, [Vector2(0.1, y + 0.014), Vector2(0.1, y + 0.026), Vector2(0.09, y + 0.033), Vector2(-0.1, y + 0.033),
			Vector2(-0.11, y + 0.014)], 0.03, f("black"), 0.0, 0.003)
	GunModels._seam(r, Vector2(0.105, y + 0.014), Vector2(-0.14, y + 0.014), 0.017)
	GunModels._tube(r.root, [Vector3(-0.0175, y + 0.0, -0.1), Vector3(-0.026, y + 0.006, -0.09), Vector3(-0.026, y + 0.006, -0.03),
			Vector3(-0.0175, y, -0.02)], 0.003, f("black"), 6)
	r.charging = Vector3(-0.03, y + 0.008, -0.125)
	if not r.parts.has("charging"):
		GunModels._rod_between(r.root, Vector3(-0.017, y + 0.008, -0.125), r.charging, 0.0035, steel)
		GunModels._slab(r.root, [Vector2(-0.12, y + 0.004), Vector2(-0.132, y + 0.004), Vector2(-0.134, y + 0.014), Vector2(-0.12, y + 0.014)],
				0.006, f("black"), -0.03, 0.001)
	GunModels._slab(r.root, [Vector2(0.09, y + 0.033), Vector2(0.07, y + 0.033), Vector2(0.072, y + 0.05), Vector2(0.088, y + 0.05)],
			0.016, f("black"), 0.0, 0.0015)
	GunModels._cyl_x(r.root, 0.0035, 0.017, Vector3(0, y + 0.045, 0.08), f("bore"), 10)
	var port := Vector3(0.0172, y + 0.004, -0.03)
	GunModels._box(r.root, Vector3(0.0016, 0.012, 0.04), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.0048, 0.022, port + Vector3(-0.003, 0, 0), f("brass"), 10))
	GunModels._pins(r, [Vector2(0.09, y - 0.02), Vector2(-0.13, y - 0.02), Vector2(0.0, y - 0.03)], 0.017, 0.0022)
	GunModels._slab(r.root, [Vector2(0.04, y - 0.01), Vector2(0.055, y - 0.006), Vector2(0.056, y - 0.012), Vector2(0.04, y - 0.016)],
			0.002, f("oxide"), -0.018, 0.0004)
	GunModels._grip(r, Vector3(0, y - 0.036, 0.034), f("polymer"), Vector3(0.03, 0.098, 0.042), -20.0)
	GunModels._blade_at(r, -0.012, y - 0.036, f("black"))
	r.trig = Vector3(0, y - 0.048, -0.012)
	GunModels._guard(r, -0.05, 0.016, y - 0.036, 0.03, steel, 0.009)
	GunModels._barrel(r, Vector3(0, y, -0.145), 0.48, 0.0095, f("black"), true)
	r.hg_start = -0.15
	r.hg_end = -0.35
	r.hg_y = y - 0.002
	r.hg_r = 0.023
	if not r.parts.has("handguard"):
		# Two-piece vented handguard in grey-green polymer.
		GunModels._slab(r.root, [Vector2(-0.148, y + 0.024), Vector2(-0.345, y + 0.024), Vector2(-0.352, y + 0.01), Vector2(-0.345, y - 0.028),
				Vector2(-0.155, y - 0.03), Vector2(-0.148, y - 0.018)], 0.044, f("poly_green"), 0.0, 0.005)
		for i in 6:
			GunModels._box(r.root, Vector3(0.0452, 0.0035, 0.018), Vector3(0, y + 0.012, -0.175 - i * 0.028), f("bore"), Vector3.ZERO, 0.0)
		GunModels._seam(r, Vector2(-0.15, y - 0.004), Vector2(-0.348, y - 0.004), 0.022)
	r.gas = Vector3(0, y + 0.02, -0.37)
	GunModels._turn(r.root, [Vector2(-0.21, 0.0055), Vector2(0.0, 0.0055)], Vector3(0, y + 0.02, -0.15), steel, 10)
	if not r.parts.has("gas"):
		GunModels._slab(r.root, [Vector2(-0.355, y + 0.03), Vector2(-0.39, y + 0.03), Vector2(-0.39, y - 0.014), Vector2(-0.355, y - 0.014)],
				0.024, steel, 0.0, 0.002)
		GunModels._turn(r.root, [Vector2(-0.008, 0.0), Vector2(-0.006, 0.005), Vector2(0.008, 0.005)], r.gas + Vector3(0, 0.002, -0.026), f("bare"), 10)
		GunModels._slab(r.root, [Vector2(-0.37, y + 0.03), Vector2(-0.385, y + 0.03), Vector2(-0.38, y + 0.05), Vector2(-0.374, y + 0.05)],
				0.012, f("black"), 0.0, 0.001)
	r.stock = Vector3(0, y, 0.105)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.103, y + 0.016), Vector2(0.4, y + 0.012), Vector2(0.41, y + 0.004), Vector2(0.412, y - 0.09),
				Vector2(0.39, y - 0.096), Vector2(0.3, y - 0.07), Vector2(0.18, y - 0.045), Vector2(0.103, y - 0.035)], 0.036, f("polymer"), 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(0.41, y + 0.012), Vector2(0.424, y + 0.012), Vector2(0.424, y - 0.094), Vector2(0.412, y - 0.096)],
				0.038, f("rubber"), 0.0, 0.002)
		r.butt = Vector3(0, y - 0.04, 0.424)
		r.butt_h = 0.105
		r.comb = Vector3(0, y + 0.016, 0.3)
	r.mag = Vector3(0, y - 0.044, -0.085)
	r.mag_len = 0.11
	r.mag_w = 0.027
	r.mag_d = 0.07
	r.mag_tilt = 6.0
	r.mag_curve = 4.0
	if not r.parts.has("magazine"):
		GunModels._std_mag(r, f("steel"))
	r.top = Vector3(0, y + 0.033, 0.0)
	r.mount = Vector3(0, y + 0.033, -0.08)
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y - 0.01, -0.02)
	r.body_w = 0.017
	r.under = Vector3(0, y - 0.03, -0.42)
	r.gadget = Vector3(0, y - 0.04, 0.16)
	r.side = Vector3(0.019, y - 0.025, 0.3)


static func bullpup(r: GunModels.Rig) -> void:
	var y := 0.085
	var body := f("poly_green")
	# One moulded shell from the butt to the nose, the action behind the grip.
	GunModels._slab(r.root, [Vector2(0.3, 0.118), Vector2(0.3, 0.03), Vector2(0.29, 0.024), Vector2(0.16, 0.03), Vector2(0.15, 0.04),
			Vector2(0.085, 0.042), Vector2(0.06, 0.052), Vector2(-0.03, 0.056), Vector2(-0.11, 0.06), Vector2(-0.172, 0.066),
			Vector2(-0.18, 0.08), Vector2(-0.178, 0.1), Vector2(-0.12, 0.112), Vector2(0.24, 0.118)], 0.054, body, 0.0, 0.006)
	GunModels._seam(r, Vector2(0.28, 0.06), Vector2(-0.02, 0.07), 0.027)
	GunModels._seam(r, Vector2(0.06, 0.1), Vector2(0.06, 0.052), 0.027)
	# A smoked-glass window over the magazine well shows the rounds.
	GunModels._slab(r.root, [Vector2(0.15, 0.09), Vector2(0.08, 0.09), Vector2(0.08, 0.06), Vector2(0.15, 0.06)], 0.0552, f("glass"), 0.0, 0.0)
	GunModels._slab(r.root, [Vector2(0.3, 0.116), Vector2(0.312, 0.116), Vector2(0.312, 0.03), Vector2(0.3, 0.03)], 0.056, f("rubber"), 0.0, 0.003)
	GunModels._pic(r, Vector3(0, 0.118, -0.02), 0.22)
	GunModels._grip(r, Vector3(0, 0.058, 0.0), f("polymer"), Vector3(0.03, 0.095, 0.042), -12.0)
	GunModels._blade_at(r, -0.035, 0.06, f("black"))
	r.trig = Vector3(0, 0.048, -0.035)
	# A full-hand guard moulded down from the nose to the grip.
	GunModels._slab(r.root, [Vector2(-0.11, 0.062), Vector2(-0.122, 0.0), Vector2(-0.1, -0.05), Vector2(-0.03, -0.062), Vector2(-0.02, -0.05),
			Vector2(-0.03, -0.044), Vector2(-0.09, -0.036), Vector2(-0.106, 0.0), Vector2(-0.096, 0.058)], 0.03, body, 0.0, 0.003)
	GunModels._barrel(r, Vector3(0, y, -0.175), 0.23, 0.0085, f("black"))
	GunModels._cyl(r.root, 0.013, 0.012, Vector3(0, y, -0.182), f("black"), 12)
	r.gas = Vector3(0, y, -0.2)
	r.charging = Vector3(-0.034, 0.1, -0.06)
	if not r.parts.has("charging"):
		GunModels._rod_between(r.root, Vector3(-0.026, 0.1, -0.06), r.charging, 0.0035, f("black"))
		GunModels._ball(r.root, 0.006, r.charging, f("oxide"))
	var port := Vector3(0.0275, 0.095, 0.17)
	GunModels._box(r.root, Vector3(0.0016, 0.014, 0.04), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.0045, 0.022, port + Vector3(-0.003, 0, 0), f("brass"), 10))
	r.bolt = port + Vector3(0.002, 0, 0)
	r.mag = Vector3(0, 0.035, 0.12)
	r.mag_len = 0.11
	r.mag_w = 0.022
	r.mag_d = 0.055
	r.mag_tilt = -4.0
	r.mag_curve = 10.0
	if not r.parts.has("magazine"):
		GunModels._std_mag(r, f("glass"))
		# Rounds stacked inside the clear magazine.
		for i in 5:
			GunModels._round(r, GunModels._cyl(r.root, 0.0045, 0.04, r.mag + Vector3(0, -0.012 - i * 0.016, -0.0015 * i), f("brass"), 8))
	r.top = Vector3(0, 0.125, 0.0)
	r.mount = Vector3(0, 0.125, -0.1)
	r.hg_start = -0.05
	r.hg_end = -0.175
	r.hg_y = 0.085
	r.hg_r = 0.027
	r.rail_l = Vector3(-0.028, 0.085, -0.13)
	r.rail_r = Vector3(0.028, 0.085, -0.13)
	r.foregrip = Vector3(0, 0.06, -0.135)
	r.under = Vector3(0, y - 0.012, -0.26)
	r.stock = Vector3(0, 0.085, 0.3)
	r.butt = Vector3(0, 0.073, 0.312)
	r.gadget = Vector3(0, 0.028, 0.24)
	r.side = Vector3(0.028, 0.06, 0.24)
	r.recv = Vector3(0, 0.085, 0.12)
	r.body_w = 0.027


# --- SMG, PDW -----------------------------------------------------------------------

static func smg(r: GunModels.Rig) -> void:
	var y := 0.075
	var steel := f("black")
	# Stamped receiver with a rounded top, the cocking tube over the barrel, end cap.
	GunModels._slab(r.root, [Vector2(0.1, y + 0.016), Vector2(0.094, y + 0.024), Vector2(-0.17, y + 0.024), Vector2(-0.176, y + 0.016),
			Vector2(-0.176, y - 0.018), Vector2(-0.11, y - 0.022), Vector2(-0.04, y - 0.022), Vector2(0.03, y - 0.026), Vector2(0.1, y - 0.016)],
			0.032, steel, 0.0, 0.006)
	GunModels._seam(r, Vector2(0.1, y - 0.012), Vector2(-0.176, y - 0.012), 0.016)
	GunModels._turn(r.root, [Vector2(-0.12, 0.0), Vector2(-0.118, 0.008), Vector2(0.0, 0.008)], Vector3(0, y + 0.026, -0.09), steel, 12)
	GunModels._cyl(r.root, 0.02, 0.01, Vector3(0, y, 0.105), f("polymer"), 16)
	r.charging = Vector3(-0.022, y + 0.026, -0.17)
	if not r.parts.has("charging"):
		GunModels._rod_between(r.root, Vector3(-0.004, y + 0.026, -0.17), r.charging, 0.0035, f("black"))
		GunModels._ball(r.root, 0.005, r.charging, f("oxide"))
	# Drum rear sight on top, a front sight ring at the nose.
	GunModels._cyl_x(r.root, 0.009, 0.014, Vector3(0, y + 0.034, 0.06), f("black"), 12)
	GunModels._turn(r.root, [Vector2(-0.006, 0.011), Vector2(0.006, 0.011)], Vector3(0, y + 0.03, -0.165), f("black"), 14)
	GunModels._box(r.root, Vector3(0.0022, 0.016, 0.0022), Vector3(0, y + 0.03, -0.165), f("black"), Vector3.ZERO, 0.0)
	GunModels._pins(r, [Vector2(0.08, y - 0.008), Vector2(-0.03, y - 0.012)], 0.016, 0.0022)
	var port := Vector3(0.0162, y + 0.006, -0.03)
	GunModels._box(r.root, Vector3(0.0016, 0.01, 0.03), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.0042, 0.016, port + Vector3(-0.003, 0, 0), f("brass"), 10))
	# Trigger housing in polymer, the selector in oxide.
	GunModels._slab(r.root, [Vector2(0.09, y - 0.02), Vector2(-0.02, y - 0.022), Vector2(-0.024, y - 0.03), Vector2(0.06, y - 0.034),
			Vector2(0.09, y - 0.03)], 0.03, f("polymer"), 0.0, 0.003)
	GunModels._slab(r.root, [Vector2(0.06, y - 0.024), Vector2(0.074, y - 0.02), Vector2(0.075, y - 0.026), Vector2(0.06, y - 0.03)],
			0.002, f("oxide"), -0.0155, 0.0004)
	GunModels._grip(r, Vector3(0, y - 0.03, 0.035), f("polymer"), Vector3(0.03, 0.09, 0.04), -14.0)
	GunModels._blade_at(r, -0.004, y - 0.032, f("black"))
	r.trig = Vector3(0, y - 0.044, -0.004)
	GunModels._guard(r, -0.034, 0.022, y - 0.032, 0.028, f("polymer"), 0.01)
	var start := Vector3(0, y, -0.176)
	GunModels._barrel(r, start, 0.11, 0.009, f("black"))
	if not r.parts.has("handguard"):
		# A slim polymer handguard round the barrel's root.
		GunModels._turn(r.root, [Vector2(-0.075, 0.017), Vector2(-0.07, 0.02), Vector2(0.0, 0.02)], start, f("polymer"), 10)
		for i in 4:
			GunModels._box(r.root, Vector3(0.042, 0.0035, 0.004), start + Vector3(0, -0.012, -0.014 - i * 0.015), f("bore"), Vector3.ZERO, 0.0)
	if not r.parts.has("magazine"):
		r.mag = Vector3(0, y - 0.022, -0.075)
		r.mag_len = 0.12
		r.mag_w = 0.022
		r.mag_d = 0.03
		r.mag_tilt = 6.0
		r.mag_curve = 14.0
		GunModels._std_mag(r, f("black"))
		GunModels._slab(r.root, [Vector2(-0.058, y - 0.022), Vector2(-0.094, y - 0.022), Vector2(-0.094, y - 0.04), Vector2(-0.058, y - 0.04)],
				0.03, steel, 0.0, 0.002)
	r.mag = Vector3(0, y - 0.022, -0.075)
	r.top = Vector3(0, y + 0.028, -0.04)
	r.stock = Vector3(0, y - 0.005, 0.105)
	r.under = Vector3(0, y - 0.025, start.z - 0.08)
	r.gadget = Vector3(0, y - 0.03, 0.07)
	r.side = Vector3(0.017, y, -0.13)
	r.rail_l = Vector3(-0.021, y, -0.23)
	r.rail_r = Vector3(0.021, y, -0.23)
	r.foregrip = Vector3(0, y - 0.02, -0.21)
	r.hg_start = -0.18
	r.hg_end = -0.28
	r.hg_y = y
	r.hg_r = 0.02
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y, -0.04)
	r.body_w = 0.016
	r.mount = Vector3(0, y + 0.028, -0.12)


static func pdw(r: GunModels.Rig) -> void:
	var body := f("poly_grey")
	# One moulded body: butt, thumbhole grip, finger loop and the nose, in one silhouette.
	var outline := [Vector2(-0.215, 0.065), Vector2(0.17, 0.065), Vector2(0.25, 0.052), Vector2(0.262, 0.03),
			Vector2(0.24, 0.012), Vector2(0.125, 0.012), Vector2(0.1, -0.03), Vector2(0.088, -0.066), Vector2(0.05, -0.07),
			Vector2(0.046, -0.03), Vector2(0.042, 0.004), Vector2(0.008, 0.004), Vector2(-0.008, -0.075),
			Vector2(-0.055, -0.08), Vector2(-0.06, -0.035), Vector2(-0.2, -0.05), Vector2(-0.218, -0.04)]
	var pts := []
	for v: Vector2 in outline:
		pts.append(Vector2(-v.x, v.y + 0.035))
	GunModels._slab(r.root, pts, 0.05, body, 0.0, 0.006)
	GunModels._seam(r, Vector2(-0.24, 0.07), Vector2(0.2, 0.07), 0.025)
	GunModels._slab(r.root, [Vector2(0.205, 0.1), Vector2(0.222, 0.1), Vector2(0.222, -0.01), Vector2(0.205, -0.012)],
			0.052, f("rubber"), 0.0, 0.003)
	# The 50-round magazine lies along the top in smoked glass: the rounds show through.
	r.mag = Vector3(0, 0.1, 0.0)
	r.mag_style = "top"
	r.mag_len = 0.3
	if not r.parts.has("magazine"):
		GunModels._top_mag(r, 0.3, f("glass"))
	for z: float in [0.13, -0.14]:
		GunModels._slab(r.root, [Vector2(z + 0.008, 0.1), Vector2(z - 0.008, 0.1), Vector2(z - 0.006, 0.136), Vector2(z + 0.006, 0.136)],
				0.014, f("black"), 0.0, 0.0015)
	GunModels._pic(r, Vector3(0, 0.136, -0.005), 0.29)
	GunModels._barrel(r, Vector3(0, 0.062, -0.25), 0.045, 0.0075, f("black"), false)
	for sx: float in [-1.0, 1.0]:
		GunModels._cyl_x(r.root, 0.006, 0.006, Vector3(sx * 0.028, 0.075, -0.2), f("oxide"), 10)
	GunModels._blade_at(r, -0.028, 0.04, f("black"))
	r.trig = Vector3(0, 0.03, -0.03)
	r.grip_top = Vector3(0, 0.04, 0.03)
	r.grip_rake = -12.0
	r.top = Vector3(0, 0.143, 0.03)
	r.mount = Vector3(0, 0.143, -0.1)
	r.rail_l = Vector3(-0.026, 0.06, -0.19)
	r.rail_r = Vector3(0.026, 0.06, -0.19)
	r.foregrip = Vector3(0, 0.047, -0.2)
	r.hg_start = -0.13
	r.hg_end = -0.245
	r.hg_y = 0.06
	r.hg_r = 0.025
	r.stock = Vector3(0, 0.07, 0.215)
	r.butt = Vector3(0, 0.044, 0.222)
	r.gadget = Vector3(0, -0.012, 0.15)
	r.side = Vector3(0.026, 0.06, 0.12)
	r.bolt = Vector3(0.026, 0.07, -0.08)
	r.body_w = 0.025
	r.recv = Vector3(0, 0.07, 0.0)


# --- Support and precision -------------------------------------------------------------

static func lmg(r: GunModels.Rig) -> void:
	var y := 0.09
	var steel := f("black")
	GunModels._slab(r.root, [Vector2(0.1, y + 0.02), Vector2(-0.16, y + 0.02), Vector2(-0.165, y + 0.01), Vector2(-0.165, y - 0.044),
			Vector2(-0.14, y - 0.052), Vector2(0.02, y - 0.052), Vector2(0.06, y - 0.045), Vector2(0.1, y - 0.03)], 0.05, steel, 0.0, 0.003)
	# Feed tray cover with its latch and rail; the belt feed port on the left.
	GunModels._slab(r.root, [Vector2(0.065, y + 0.02), Vector2(0.065, y + 0.032), Vector2(0.055, y + 0.04), Vector2(-0.1, y + 0.04),
			Vector2(-0.105, y + 0.02)], 0.052, f("steel"), 0.0, 0.004)
	GunModels._seam(r, Vector2(0.065, y + 0.02), Vector2(-0.105, y + 0.02), 0.026)
	GunModels._slab(r.root, [Vector2(0.075, y + 0.03), Vector2(0.065, y + 0.04), Vector2(0.06, y + 0.032), Vector2(0.068, y + 0.022)],
			0.02, f("oxide"), 0.0, 0.0012)
	GunModels._pic(r, Vector3(0, y + 0.04, -0.02), 0.13)
	GunModels._box(r.root, Vector3(0.006, 0.03, 0.05), Vector3(-0.027, y + 0.004, -0.05), f("bore"), Vector3.ZERO, 0.0015)
	GunModels._pins(r, [Vector2(0.085, y - 0.02), Vector2(-0.15, y - 0.03), Vector2(0.02, y - 0.04)], 0.025, 0.0026)
	r.charging = Vector3(0.034, y, -0.11)
	if not r.parts.has("charging"):
		GunModels._rod_between(r.root, Vector3(0.025, y, -0.11), r.charging, 0.0035, f("steel"))
		GunModels._slab(r.root, [Vector2(-0.104, y - 0.006), Vector2(-0.116, y - 0.006), Vector2(-0.116, y + 0.008), Vector2(-0.104, y + 0.008)],
				0.006, f("black"), 0.034, 0.001)
	GunModels._grip(r, Vector3(0, y - 0.048, 0.04), f("polymer"), Vector3(0.032, 0.098, 0.044), -18.0)
	GunModels._blade_at(r, -0.004, y - 0.048, f("black"))
	r.trig = Vector3(0, y - 0.06, -0.004)
	GunModels._guard(r, -0.04, 0.024, y - 0.048, 0.03, steel, 0.012)
	GunModels._barrel(r, Vector3(0, y, -0.165), 0.48, 0.0105, f("steel"))
	# Carry handle over the barrel; the gas cylinder under it; a heat shield on top.
	GunModels._tube(r.root, [Vector3(0, y + 0.012, -0.19), Vector3(0, y + 0.05, -0.2), Vector3(0, y + 0.05, -0.27), Vector3(0, y + 0.012, -0.28)],
			0.0045, f("polymer"), 8)
	GunModels._turn(r.root, [Vector2(-0.25, 0.008), Vector2(0.0, 0.008)], Vector3(0, y - 0.024, -0.165), f("black"), 12)
	r.gas = Vector3(0, y - 0.018, -0.42)
	if not r.parts.has("gas"):
		GunModels._slab(r.root, [Vector2(-0.405, y + 0.012), Vector2(-0.435, y + 0.012), Vector2(-0.435, y - 0.036), Vector2(-0.405, y - 0.036)],
				0.022, steel, 0.0, 0.002)
	r.hg_start = -0.16
	r.hg_end = -0.32
	r.hg_y = y - 0.01
	r.hg_r = 0.028
	if not r.parts.has("handguard"):
		GunModels._slab(r.root, [Vector2(-0.165, y - 0.012), Vector2(-0.32, y - 0.012), Vector2(-0.325, y - 0.03), Vector2(-0.31, y - 0.048),
				Vector2(-0.17, y - 0.048), Vector2(-0.165, y - 0.036)], 0.05, f("polymer"), 0.0, 0.005)
		GunModels._slab(r.root, [Vector2(-0.18, y + 0.012), Vector2(-0.3, y + 0.012), Vector2(-0.3, y + 0.02), Vector2(-0.18, y + 0.02)],
				0.03, f("steel"), 0.0, 0.002)
		for i in 5:
			GunModels._box(r.root, Vector3(0.0304, 0.0028, 0.012), Vector3(0, y + 0.017, -0.195 - i * 0.022), f("bore"), Vector3.ZERO, 0.0)
	r.stock = Vector3(0, y - 0.005, 0.1)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.098, y + 0.02), Vector2(0.37, y + 0.02), Vector2(0.39, y + 0.01), Vector2(0.392, y - 0.082),
				Vector2(0.37, y - 0.088), Vector2(0.2, y - 0.05), Vector2(0.098, y - 0.036)], 0.04, f("polymer"), 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(0.2, y - 0.004), Vector2(0.32, y - 0.002), Vector2(0.33, y - 0.04), Vector2(0.24, y - 0.04)],
				0.0405, f("bore"), 0.0, 0.0)
		GunModels._slab(r.root, [Vector2(0.39, y + 0.014), Vector2(0.404, y + 0.014), Vector2(0.404, y - 0.086), Vector2(0.392, y - 0.088)],
				0.042, f("rubber"), 0.0, 0.002)
		r.butt = Vector3(0, y - 0.035, 0.404)
		r.butt_h = 0.1
		r.comb = Vector3(0, y + 0.028, 0.28)
	r.mag = Vector3(-0.005, y - 0.0525, -0.06)
	r.mag_style = "belt"
	if not r.parts.has("magazine"):
		GunModels._belt_box(r, Vector3(0.05, 0.075, 0.1), f("poly_green"))
	r.top = Vector3(0, y + 0.047, -0.01)
	r.mount = Vector3(0, y + 0.047, -0.07)
	r.bolt = Vector3(0.026, y - 0.02, 0.01)
	r.recv = Vector3(0, y - 0.015, -0.03)
	r.body_w = 0.025
	r.under = Vector3(0, y - 0.04, -0.4)
	r.gadget = Vector3(0, y - 0.045, 0.16)
	r.side = Vector3(0.022, y - 0.02, 0.3)


static func anti_materiel(r: GunModels.Rig) -> void:
	var y := 0.1
	var sand := f("sand")
	var black := f("black")
	# Upper receiver: a long sand-painted slab with lightening cuts; the lower in black.
	GunModels._slab(r.root, [Vector2(0.2, y + 0.034), Vector2(-0.3, y + 0.034), Vector2(-0.31, y + 0.02), Vector2(-0.31, y - 0.012),
			Vector2(0.2, y - 0.012)], 0.06, sand, 0.0, 0.004)
	for i in 4:
		GunModels._slab(r.root, [Vector2(-0.27 + i * 0.05, y + 0.024), Vector2(-0.235 + i * 0.05, y + 0.024), Vector2(-0.235 + i * 0.05, y - 0.002),
				Vector2(-0.27 + i * 0.05, y - 0.002)], 0.0604, f("bore"), 0.0, 0.0)
	GunModels._slab(r.root, [Vector2(0.2, y - 0.012), Vector2(-0.2, y - 0.012), Vector2(-0.2, y - 0.04), Vector2(-0.14, y - 0.052),
			Vector2(0.02, y - 0.052), Vector2(0.08, y - 0.04), Vector2(0.2, y - 0.04)], 0.056, black, 0.0, 0.004)
	GunModels._seam(r, Vector2(0.2, y - 0.012), Vector2(-0.31, y - 0.012), 0.03)
	GunModels._pins(r, [Vector2(0.18, y - 0.026), Vector2(-0.18, y - 0.026)], 0.028, 0.003)
	GunModels._pic(r, Vector3(0, y + 0.034, -0.06), 0.42, 0.0, 0.024)
	GunModels._grip(r, Vector3(0, y - 0.05, 0.035), f("polymer"), Vector3(0.036, 0.11, 0.05), -18.0)
	GunModels._blade_at(r, -0.01, y - 0.05, f("black"))
	r.trig = Vector3(0, y - 0.062, -0.01)
	GunModels._guard(r, -0.05, 0.02, y - 0.05, 0.034, black, 0.012)
	# A big bolt handle on the right.
	r.bolt = Vector3(0.068, y - 0.004, 0.13)
	GunModels._rod_between(r.root, Vector3(0.03, y + 0.012, 0.11), r.bolt, 0.0055, f("steel"))
	if r.parts.get("bolt", "") != "bolt_knob":
		GunModels._turn(r.root, [Vector2(-0.012, 0.0), Vector2(-0.01, 0.008), Vector2(0.01, 0.012), Vector2(0.014, 0.0)], r.bolt, f("polymer"), 14)
	# Fat fluted barrel.
	GunModels._barrel(r, Vector3(0, y + 0.004, -0.3), 0.58, 0.016, f("black"), false)
	for i in 6:
		var a := TAU * i / 6.0
		GunModels._box(r.root, Vector3(0.0035, 0.004, 0.3), Vector3(0, y + 0.004, -0.5) + Vector3(cos(a), sin(a), 0) * 0.0158,
				f("bore"), Vector3(0, 0, rad_to_deg(a) + 90.0), 0.0)
	if not r.parts.has("muzzle"):
		# The double-chamber brake: two baffles with side ports and a chamfered nose.
		var m := r.muzzle
		GunModels._slab(r.root, [Vector2(m.z, m.y + 0.022), Vector2(m.z - 0.075, m.y + 0.022), Vector2(m.z - 0.085, m.y + 0.012),
				Vector2(m.z - 0.085, m.y - 0.012), Vector2(m.z - 0.075, m.y - 0.022), Vector2(m.z, m.y - 0.022)], 0.06, black, 0.0, 0.004)
		for i in 2:
			GunModels._box(r.root, Vector3(0.0612, 0.028, 0.018), Vector3(0, m.y, m.z - 0.022 - i * 0.034), f("bore"), Vector3.ZERO, 0.0)
		GunModels._cyl(r.root, 0.012, 0.0016, m + Vector3(0, 0, -0.0852), f("bore"), 12)
		r.muzzle = m + Vector3(0, 0, -0.086)
	# The bipod yoke clamped round the barrel at the front of the receiver.
	GunModels._turn(r.root, [Vector2(-0.02, 0.026), Vector2(0.02, 0.026)], Vector3(0, y + 0.004, -0.33), black, 12)
	r.foregrip = Vector3(0, y - 0.03, -0.335)
	r.stock = Vector3(0, y, 0.2)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.2, y + 0.03), Vector2(0.45, y + 0.03), Vector2(0.46, y + 0.02), Vector2(0.46, y - 0.06),
				Vector2(0.44, y - 0.07), Vector2(0.3, y - 0.05), Vector2(0.2, y - 0.04)], 0.05, sand, 0.0, 0.005)
		GunModels._slab(r.root, [Vector2(0.27, y + 0.03), Vector2(0.4, y + 0.03), Vector2(0.4, y + 0.052), Vector2(0.28, y + 0.052)],
				0.036, f("polymer"), 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(0.46, y + 0.04), Vector2(0.485, y + 0.04), Vector2(0.485, y - 0.072), Vector2(0.46, y - 0.074)],
				0.056, f("rubber"), 0.0, 0.005)
		GunModels._rod_between(r.root, Vector3(0, y - 0.05, 0.4), Vector3(0, y - 0.13, 0.405), 0.005, f("steel"))
		GunModels._box(r.root, Vector3(0.03, 0.006, 0.03), Vector3(0, y - 0.133, 0.405), f("rubber"), Vector3.ZERO, 0.002)
		r.butt = Vector3(0, y - 0.016, 0.485)
		r.butt_h = 0.11
		r.comb = Vector3(0, y + 0.052, 0.33)
	r.mag = Vector3(0, y - 0.052, -0.02)
	r.mag_len = 0.08
	r.mag_w = 0.042
	r.mag_d = 0.13
	r.mag_tilt = 0.0
	r.mag_curve = 0.0
	if not r.parts.has("magazine"):
		GunModels._std_mag(r, f("black"))
	r.top = Vector3(0, y + 0.041, 0.02)
	r.mount = Vector3(0, y + 0.041, -0.2)
	r.rail_l = Vector3(-0.03, y + 0.012, -0.25)
	r.hg_start = -0.3
	r.hg_end = -0.33
	r.hg_y = y
	r.hg_r = 0.03
	r.recv = Vector3(0, y, -0.05)
	r.body_w = 0.03
	r.gadget = Vector3(0, y - 0.05, 0.22)
	r.side = Vector3(0.026, y - 0.01, 0.33)


## Bolt-action rifle: a round receiver with its bolt, in a polymer stock (or the aluminium
## precision chassis receiver part).
static func rifle(r: GunModels.Rig) -> void:
	var y := 0.08
	var chassis: bool = r.parts.get("receiver", "") == "precision_chassis"
	var furniture := f("poly_green")
	if chassis:
		r.done["receiver"] = true
		var alu := f("steel")
		GunModels._slab(r.root, [Vector2(0.06, 0.07), Vector2(-0.36, 0.07), Vector2(-0.365, 0.062), Vector2(-0.365, 0.034),
				Vector2(-0.355, 0.028), Vector2(-0.04, 0.028), Vector2(0.0, 0.034), Vector2(0.06, 0.04)], 0.036, alu, 0.0, 0.003)
		for i in 5:
			GunModels._slab(r.root, [Vector2(-0.07 - i * 0.055, 0.062), Vector2(-0.105 - i * 0.055, 0.062), Vector2(-0.105 - i * 0.055, 0.04),
					Vector2(-0.07 - i * 0.055, 0.04)], 0.0364, f("bore"), 0.0, 0.0)
		GunModels._pic(r, Vector3(0, 0.028, -0.24), 0.22, 180.0)
		for sx: float in [-1.0, 1.0]:
			GunModels._pic(r, Vector3(sx * 0.018, 0.05, -0.29), 0.1, -sx * 90.0, 0.016)
		GunModels._grip(r, Vector3(0, 0.04, 0.03), f("polymer"), Vector3(0.03, 0.095, 0.045), -18.0)
		r.stock = Vector3(0, y - 0.012, 0.075)
		if not r.parts.has("stock"):
			# A folding skeleton butt.
			GunModels._slab(r.root, [Vector2(0.075, 0.075), Vector2(0.33, 0.075), Vector2(0.335, 0.065), Vector2(0.335, -0.02),
					Vector2(0.32, -0.025), Vector2(0.3, -0.01), Vector2(0.3, 0.06), Vector2(0.11, 0.06), Vector2(0.09, 0.03), Vector2(0.075, 0.03)],
					0.026, alu, 0.0, 0.002)
			GunModels._slab(r.root, [Vector2(0.18, 0.075), Vector2(0.29, 0.075), Vector2(0.29, 0.09), Vector2(0.19, 0.09)], 0.03, f("polymer"), 0.0, 0.003)
			GunModels._slab(r.root, [Vector2(0.335, 0.08), Vector2(0.348, 0.08), Vector2(0.348, -0.024), Vector2(0.335, -0.026)],
					0.036, f("rubber"), 0.0, 0.002)
			r.butt = Vector3(0, 0.027, 0.348)
			r.butt_h = 0.1
			r.comb = Vector3(0, 0.09, 0.24)
		r.rail_r = Vector3(0.026, 0.05, -0.29)
		r.rail_l = Vector3(-0.026, 0.05, -0.29)
		r.foregrip = Vector3(0, 0.023, -0.2)
	else:
		# Fore-end and wrist moulded in one piece, a pistol grip swept into it.
		GunModels._slab(r.root, [Vector2(0.065, 0.066), Vector2(-0.37, 0.066), Vector2(-0.378, 0.05), Vector2(-0.37, 0.024),
				Vector2(-0.06, 0.02), Vector2(-0.045, 0.026), Vector2(0.0, 0.04), Vector2(0.065, 0.045)], 0.038, furniture, 0.0, 0.005)
		GunModels._grip(r, Vector3(0, 0.044, 0.035), furniture, Vector3(0.034, 0.09, 0.05), -24.0)
		r.stock = Vector3(0, y - 0.012, 0.075)
		if not r.parts.has("stock"):
			GunModels._slab(r.root, [Vector2(0.06, 0.066), Vector2(0.15, 0.072), Vector2(0.35, 0.068), Vector2(0.362, 0.058), Vector2(0.362, -0.038),
					Vector2(0.34, -0.045), Vector2(0.2, -0.01), Vector2(0.09, 0.02), Vector2(0.06, 0.04)], 0.036, furniture, 0.0, 0.005)
			GunModels._slab(r.root, [Vector2(0.362, 0.064), Vector2(0.374, 0.064), Vector2(0.374, -0.04), Vector2(0.362, -0.042)],
					0.038, f("rubber"), 0.0, 0.002)
			r.butt = Vector3(0, 0.012, 0.374)
			r.butt_h = 0.1
			r.comb = Vector3(0, 0.07, 0.25)
		r.rail_l = Vector3(-0.0195, 0.045, -0.26)
		r.rail_r = Vector3(0.0195, 0.045, -0.26)
		r.foregrip = Vector3(0, 0.022, -0.22)
	# Round receiver with its bolt, the bolt handle with a knob, scope bases on top.
	GunModels._turn(r.root, [Vector2(-0.1, 0.012), Vector2(-0.096, 0.016), Vector2(0.06, 0.016), Vector2(0.066, 0.012)], Vector3(0, y + 0.002, 0),
			f("black"), 16)
	GunModels._box(r.root, Vector3(0.0016, 0.012, 0.05), Vector3(0.016, y + 0.006, -0.03), f("bore"), Vector3.ZERO, 0.0)
	GunModels._turn(r.root, [Vector2(0.06, 0.0), Vector2(0.062, 0.01), Vector2(0.09, 0.011), Vector2(0.094, 0.0)], Vector3(0, y + 0.002, 0), f("bare"), 14)
	r.bolt = Vector3(0.052, y - 0.014, 0.042)
	GunModels._rod_between(r.root, Vector3(0.012, y + 0.004, 0.03), Vector3(0.05, y - 0.012, 0.04), 0.0035, f("bare"))
	if r.parts.get("bolt", "") != "bolt_knob":
		GunModels._ball(r.root, 0.0095, r.bolt, f("polymer"))
	for z: float in [0.04, -0.07]:
		GunModels._box(r.root, Vector3(0.018, 0.005, 0.016), Vector3(0, y + 0.02, z), f("black"), Vector3.ZERO, 0.001)
	GunModels._blade_at(r, -0.004, 0.032, f("bare"))
	r.trig = Vector3(0, 0.02, -0.004)
	GunModels._guard(r, -0.034, 0.014, 0.03, 0.03, f("black"), 0.012)
	GunModels._barrel(r, Vector3(0, y + 0.002, -0.1), 0.42, 0.009, f("black"))
	r.mag = Vector3(0, 0.025 if not chassis else 0.03, -0.05)
	r.mag_len = 0.035
	r.mag_w = 0.02
	r.mag_d = 0.05
	r.mag_tilt = 0.0
	if not r.parts.has("magazine"):
		GunModels._slab(r.root, [Vector2(-0.025, r.mag.y + 0.004), Vector2(-0.08, r.mag.y + 0.004), Vector2(-0.08, r.mag.y - 0.012),
				Vector2(-0.025, r.mag.y - 0.012)], 0.03, f("black"), 0.0, 0.002)
	r.top = Vector3(0, y + 0.023, -0.02)
	r.mount = Vector3(0, y + 0.023, -0.075)
	r.under = Vector3(0, 0.035, -0.4)
	r.gadget = Vector3(0, 0.022, 0.06)
	r.side = Vector3(0.019, 0.05, -0.18) if not chassis else Vector3(0.019, 0.06, 0.05)
	r.hg_start = -0.1
	r.hg_end = -0.37
	r.hg_y = 0.05
	r.hg_r = 0.02
	r.recv = Vector3(0, y + 0.002, -0.02)
	r.body_w = 0.016


static func lever_action(r: GunModels.Rig) -> void:
	var y := 0.08
	var wood := f("laminate")
	# Receiver with a loading gate (a round in it), the hammer at the back.
	GunModels._slab(r.root, [Vector2(0.03, 0.09), Vector2(-0.098, 0.09), Vector2(-0.105, 0.082), Vector2(-0.105, 0.046),
			Vector2(-0.09, 0.038), Vector2(0.01, 0.038), Vector2(0.03, 0.046)], 0.03, f("steel"), 0.0, 0.003)
	GunModels._slab(r.root, [Vector2(-0.045, 0.06), Vector2(-0.08, 0.06), Vector2(-0.08, 0.046), Vector2(-0.045, 0.046)], 0.0304, f("bore"), 0.0, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.0055, 0.02, Vector3(0.0125, 0.053, -0.062), f("brass"), 10))
	GunModels._pins(r, [Vector2(0.015, 0.05), Vector2(-0.02, 0.08), Vector2(-0.09, 0.05)], 0.015, 0.0022)
	GunModels._slab(r.root, [Vector2(0.025, 0.084), Vector2(0.04, 0.104), Vector2(0.046, 0.101), Vector2(0.034, 0.08)], 0.008, f("black"), 0.0, 0.001)
	r.stock = Vector3(0, 0.07, 0.025)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.028, 0.09), Vector2(0.1, 0.078), Vector2(0.37, 0.07), Vector2(0.38, 0.06), Vector2(0.38, -0.045),
				Vector2(0.36, -0.05), Vector2(0.1, 0.03), Vector2(0.028, 0.04)], 0.034, wood, 0.0, 0.005)
		GunModels._slab(r.root, [Vector2(0.38, 0.07), Vector2(0.39, 0.07), Vector2(0.39, -0.048), Vector2(0.38, -0.05)], 0.036, f("black"), 0.0, 0.0015)
		r.butt = Vector3(0, 0.012, 0.39)
		r.butt_h = 0.12
		r.comb = Vector3(0, 0.074, 0.25)
	if r.parts.get("bolt", "") != "lever_loop":
		GunModels._lever(r, 1.0)
	GunModels._blade_at(r, -0.008, 0.038, f("bare"))
	r.trig = Vector3(0, 0.03, -0.012)
	r.grip_top = Vector3(0, 0.045, 0.04)
	r.grip_rake = -5.0
	GunModels._barrel(r, Vector3(0, y + 0.006, -0.105), 0.48, 0.0105, f("black"))
	GunModels._slab(r.root, [Vector2(-0.165, y + 0.016), Vector2(-0.175, y + 0.016), Vector2(-0.175, y + 0.026), Vector2(-0.17, y + 0.026),
			Vector2(-0.168, y + 0.022), Vector2(-0.165, y + 0.026)], 0.014, f("black"), 0.0, 0.0006)
	r.tube_r = 0.0085
	var tube_len := 0.3
	r.tube_end = Vector3(0, 0.063, -0.105 - tube_len)
	GunModels._turn(r.root, [Vector2(-tube_len, 0.0075), Vector2(-tube_len + 0.002, r.tube_r), Vector2(0.0, r.tube_r)],
			Vector3(0, 0.063, -0.105), f("black"), 12)
	GunModels._turn(r.root, [Vector2(-0.006, r.tube_r * 1.15), Vector2(0.006, r.tube_r * 1.15)], r.tube_end + Vector3(0, 0, 0.006), f("bare"), 12)
	GunModels._slab(r.root, [Vector2(r.tube_end.z + 0.006, 0.096), Vector2(r.tube_end.z + 0.018, 0.096), Vector2(r.tube_end.z + 0.018, 0.054),
			Vector2(r.tube_end.z + 0.006, 0.054)], 0.024, f("black"), 0.0, 0.0015)
	GunModels._slab(r.root, [Vector2(-0.105, 0.086), Vector2(-0.29, 0.086), Vector2(-0.296, 0.074), Vector2(-0.29, 0.054),
			Vector2(-0.105, 0.052)], 0.03, wood, 0.0, 0.004)
	r.mag = Vector3(0, 0.038, -0.07)
	r.mag_style = "tube"
	r.top = Vector3(0, 0.091, -0.04)
	r.mount = Vector3(0, 0.091, -0.08)
	r.rail_l = Vector3(-0.0155, 0.068, -0.2)
	r.under = Vector3(0, 0.054, -0.44)
	r.gadget = Vector3(-0.0155, 0.06, 0.0)
	r.side = Vector3(0.018, 0.04, 0.25)
	r.bolt = Vector3(0, -0.03, 0.02)
	r.recv = Vector3(0, 0.064, -0.04)
	r.body_w = 0.015
	r.hg_start = -0.105
	r.hg_end = -0.29
	r.hg_y = 0.07
	r.hg_r = 0.018


# --- Shotguns ----------------------------------------------------------------------

static func shotgun(r: GunModels.Rig) -> void:
	var y := 0.08
	var furniture := f("polymer")
	GunModels._slab(r.root, [Vector2(0.04, y + 0.024), Vector2(0.03, y + 0.03), Vector2(-0.12, y + 0.03), Vector2(-0.125, y + 0.02),
			Vector2(-0.125, y - 0.036), Vector2(-0.11, y - 0.04), Vector2(0.0, y - 0.04), Vector2(0.04, y - 0.03)], 0.042, f("black"), 0.0, 0.003)
	GunModels._pins(r, [Vector2(-0.02, y - 0.028), Vector2(0.02, y - 0.026)], 0.021, 0.0024)
	var len := GunModels._barrel(r, Vector3(0, y + 0.012, -0.125), 0.34, 0.013, f("black"))
	# A ventilated rib along the barrel with a sulfur bead.
	GunModels._box(r.root, Vector3(0.008, 0.004, len - 0.01), Vector3(0, y + 0.03, -0.125 - len / 2.0), f("black"), Vector3.ZERO, 0.0008)
	GunModels._ball(r.root, 0.0025, Vector3(0, y + 0.034, -0.125 - len + 0.008), f("sulfur"))
	var tube := minf(len - 0.03, 0.27)
	r.tube_end = Vector3(0, y - 0.016, -0.125 - tube)
	r.tube_r = 0.011
	GunModels._turn(r.root, [Vector2(-tube, 0.009), Vector2(-tube + 0.003, 0.011), Vector2(0.0, 0.011)], Vector3(0, y - 0.016, -0.125), f("black"), 14)
	GunModels._turn(r.root, [Vector2(-0.012, 0.009), Vector2(-0.01, 0.0125), Vector2(0.0, 0.0125)], r.tube_end, f("steel"), 14)
	GunModels._box(r.root, Vector3(0.012, 0.03, 0.012), Vector3(0, y - 0.0, r.tube_end.z + 0.02), f("black"), Vector3.ZERO, 0.002)
	if not r.parts.has("handguard"):
		# The pump: a ribbed polymer forend on the tube.
		GunModels._turn(r.root, [Vector2(-0.065, 0.018), Vector2(-0.06, 0.021), Vector2(0.06, 0.021), Vector2(0.065, 0.018)],
				Vector3(0, y - 0.014, -0.22), furniture, 12)
		for i in 7:
			GunModels._turn(r.root, [Vector2(-0.002, 0.0225), Vector2(0.002, 0.0225)], Vector3(0, y - 0.014, -0.18 - i * 0.013), furniture, 12)
	# Ejection port with a red shell in it, the loading gate underneath.
	var port := Vector3(0.0212, y + 0.004, -0.05)
	GunModels._box(r.root, Vector3(0.0016, 0.022, 0.05), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.009, 0.034, port + Vector3(-0.004, 0, 0), f("shell_red"), 12))
	GunModels._box(r.root, Vector3(0.024, 0.0016, 0.05), Vector3(0, y - 0.0402, -0.06), f("bore"), Vector3.ZERO, 0.0)
	GunModels._blade_at(r, -0.012, y - 0.04, f("black"))
	r.trig = Vector3(0, y - 0.052, -0.012)
	GunModels._guard(r, -0.046, 0.016, y - 0.04, 0.03, f("black"), 0.012)
	GunModels._grip(r, Vector3(0, y - 0.034, 0.03), furniture, Vector3(0.034, 0.095, 0.045), -20.0)
	r.stock = Vector3(0, y - 0.01, 0.045)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.04, y + 0.024), Vector2(0.35, y + 0.012), Vector2(0.36, y + 0.002), Vector2(0.362, y - 0.1),
				Vector2(0.34, y - 0.106), Vector2(0.1, y - 0.05), Vector2(0.04, y - 0.036)], 0.036, furniture, 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(0.36, y + 0.006), Vector2(0.374, y + 0.006), Vector2(0.374, y - 0.104), Vector2(0.362, y - 0.106)],
				0.038, f("rubber"), 0.0, 0.002)
		r.butt = Vector3(0, y - 0.05, 0.374)
		r.butt_h = 0.112
		r.comb = Vector3(0, y + 0.012, 0.25)
	r.mag = Vector3(0, y - 0.036, -0.07)
	r.mag_style = "tube"
	r.mag_w = 0.03
	r.mag_d = 0.06
	r.mag_len = 0.1
	r.mag_tilt = 4.0
	r.hg_start = -0.16
	r.hg_end = -0.28
	r.hg_y = y - 0.012
	r.hg_r = 0.021
	r.recv = Vector3(0, y - 0.004, -0.04)
	r.body_w = 0.021
	r.mount = Vector3(0, y + 0.03, -0.1)
	r.bolt = port + Vector3(0.002, 0, 0)
	r.top = Vector3(0, y + 0.03, -0.05)
	r.under = Vector3(0, y - 0.04, -0.33 if tube > 0.2 else r.muzzle.z + 0.05)
	r.gadget = Vector3(0, y - 0.035, 0.04)
	r.side = Vector3(0.022, y, -0.06)


static func double_barrel(r: GunModels.Rig) -> void:
	var y := 0.085
	var wood := f("laminate")
	# Box-lock action in bare steel, two hammers, two triggers.
	GunModels._slab(r.root, [Vector2(0.0, 0.098), Vector2(-0.085, 0.098), Vector2(-0.09, 0.09), Vector2(-0.09, 0.05), Vector2(-0.07, 0.04),
			Vector2(-0.01, 0.04), Vector2(0.0, 0.05)], 0.05, f("chrome"), 0.0, 0.004)
	GunModels._seam(r, Vector2(-0.01, 0.07), Vector2(-0.08, 0.07), 0.025)
	GunModels._pins(r, [Vector2(-0.075, 0.055), Vector2(-0.03, 0.06)], 0.025, 0.003)
	for sx: float in [-1.0, 1.0]:
		GunModels._slab(r.root, [Vector2(-0.004, 0.09), Vector2(0.01, 0.112), Vector2(0.016, 0.109), Vector2(0.006, 0.088)], 0.006,
				f("black"), sx * 0.012, 0.0008)
	GunModels._blade_at(r, -0.03, 0.04, f("bare"))
	GunModels._blade_at(r, -0.016, 0.04, f("bare"))
	GunModels._guard(r, -0.055, 0.0, 0.042, 0.03, f("black"), 0.01)
	r.trig = Vector3(0, 0.032, -0.012)
	r.grip_top = Vector3(0, 0.045, 0.035)
	r.grip_rake = -5.0
	r.stock = Vector3(0, 0.072, 0.005)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.0, 0.094), Vector2(0.1, 0.08), Vector2(0.37, 0.075), Vector2(0.378, 0.066), Vector2(0.38, -0.045),
				Vector2(0.355, -0.05), Vector2(0.1, 0.03), Vector2(0.0, 0.045)], 0.036, wood, 0.0, 0.005)
		GunModels._slab(r.root, [Vector2(0.38, 0.072), Vector2(0.39, 0.072), Vector2(0.39, -0.048), Vector2(0.38, -0.05)], 0.038, f("black"), 0.0, 0.0015)
		r.butt = Vector3(0, 0.015, 0.39)
		r.butt_h = 0.125
		r.comb = Vector3(0, 0.08, 0.25)
	GunModels._twin_barrels(r, Vector3(0, y, -0.088), 0.56, 0.0125, f("black"))
	GunModels._slab(r.root, [Vector2(-0.09, y - 0.008), Vector2(-0.25, y - 0.008), Vector2(-0.256, y - 0.018), Vector2(-0.245, y - 0.03),
			Vector2(-0.1, y - 0.032), Vector2(-0.09, y - 0.024)], 0.04, wood, 0.0, 0.004)
	if r.rounds.is_empty():
		GunModels._round(r, GunModels._cyl(r.root, 0.008, 0.004, Vector3(0.0137, y, -0.086), f("brass"), 12))
	r.top = Vector3(0, y + 0.017, -0.06)
	r.mount = Vector3(0, y + 0.017, -0.12)
	r.rail_l = Vector3(-0.021, y - 0.019, -0.17)
	r.mag_style = "none"
	r.recv = Vector3(0, 0.07, -0.04)
	r.body_w = 0.025
	r.gadget = Vector3(0, 0.045, 0.1)
	r.side = Vector3(0.019, 0.05, 0.24)
	r.under = Vector3(0, y - 0.03, -0.4)
	r.bolt = Vector3(0.025, 0.07, -0.04)


static func auto_shotgun(r: GunModels.Rig) -> void:
	var y := 0.085
	var black := f("black")
	GunModels._slab(r.root, [Vector2(0.07, y + 0.02), Vector2(-0.13, y + 0.02), Vector2(-0.135, y + 0.01), Vector2(-0.135, y - 0.04),
			Vector2(-0.12, y - 0.045), Vector2(-0.03, y - 0.045), Vector2(0.0, y - 0.04), Vector2(0.07, y - 0.04)], 0.044, f("poly_grey"), 0.0, 0.004)
	GunModels._seam(r, Vector2(0.07, y - 0.004), Vector2(-0.135, y - 0.004), 0.022)
	GunModels._pic(r, Vector3(0, y + 0.02, -0.03), 0.17)
	GunModels._turn(r.root, [Vector2(-0.003, 0.009), Vector2(0.003, 0.009)], Vector3(0, y + 0.044, 0.055), black, 14)
	GunModels._cyl(r.root, 0.005, 0.0064, Vector3(0, y + 0.044, 0.055), f("bore"), 10)
	GunModels._box(r.root, Vector3(0.006, 0.016, 0.01), Vector3(0, y + 0.032, 0.055), black, Vector3.ZERO, 0.001)
	r.charging = Vector3(0.036, y - 0.004, -0.07)
	if not r.parts.has("charging"):
		GunModels._rod_between(r.root, Vector3(0.02, y - 0.004, -0.07), r.charging, 0.004, f("steel"))
		GunModels._slab(r.root, [Vector2(-0.064, y - 0.012), Vector2(-0.078, y - 0.012), Vector2(-0.078, y + 0.006), Vector2(-0.064, y + 0.006)],
				0.01, f("oxide"), 0.036, 0.0015)
	var port := Vector3(0.0222, y, -0.02)
	GunModels._box(r.root, Vector3(0.0016, 0.02, 0.05), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.009, 0.03, port + Vector3(-0.004, 0, 0), f("shell_red"), 12))
	GunModels._grip(r, Vector3(0, y - 0.042, 0.03), f("polymer"), Vector3(0.032, 0.1, 0.044), -18.0)
	GunModels._blade_at(r, -0.008, y - 0.044, black)
	r.trig = Vector3(0, y - 0.056, -0.008)
	GunModels._guard(r, -0.044, 0.016, y - 0.044, 0.03, black, 0.012)
	GunModels._barrel(r, Vector3(0, y + 0.01, -0.135), 0.42, 0.012, black, true)
	r.tube_r = 0.012
	var tube := minf(0.32, r.barrel_start.distance_to(r.muzzle) - 0.05)
	r.tube_end = Vector3(0, y - 0.018, -0.13 - tube)
	GunModels._turn(r.root, [Vector2(-tube, 0.01), Vector2(-tube + 0.003, r.tube_r), Vector2(0.0, r.tube_r)], Vector3(0, y - 0.018, -0.13), black, 14)
	r.gas = Vector3(0, y - 0.004, -0.315)
	if not r.parts.has("gas"):
		for sx: float in [-1.0, 1.0]:
			GunModels._cyl(r.root, 0.005, 0.05, r.gas + Vector3(sx * 0.016, 0, 0.02), f("bare"), 10)
	r.hg_start = -0.13
	r.hg_end = -0.29
	r.hg_y = y - 0.004
	r.hg_r = 0.024
	if not r.parts.has("handguard"):
		GunModels._slab(r.root, [Vector2(-0.135, y + 0.018), Vector2(-0.285, y + 0.018), Vector2(-0.292, y + 0.004), Vector2(-0.285, y - 0.036),
				Vector2(-0.14, y - 0.036), Vector2(-0.135, y - 0.026)], 0.048, f("poly_grey"), 0.0, 0.005)
		for i in 5:
			GunModels._box(r.root, Vector3(0.0484, 0.004, 0.012), Vector3(0, y - 0.022, -0.16 - i * 0.025), f("bore"), Vector3.ZERO, 0.0)
	r.stock = Vector3(0, y - 0.005, 0.07)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.068, y + 0.02), Vector2(0.38, y + 0.012), Vector2(0.39, y + 0.002), Vector2(0.392, y - 0.085),
				Vector2(0.37, y - 0.09), Vector2(0.12, y - 0.044), Vector2(0.068, y - 0.04)], 0.038, f("polymer"), 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(0.39, y + 0.008), Vector2(0.404, y + 0.008), Vector2(0.404, y - 0.088), Vector2(0.392, y - 0.09)],
				0.04, f("rubber"), 0.0, 0.002)
		r.butt = Vector3(0, y - 0.04, 0.404)
		r.butt_h = 0.1
		r.comb = Vector3(0, y + 0.016, 0.26)
	r.mag = Vector3(0, y - 0.045, -0.07)
	r.mag_style = "tube"
	r.mag_len = 0.1
	r.mag_w = 0.03
	r.mag_d = 0.06
	r.mag_tilt = 4.0
	r.top = Vector3(0, y + 0.027, -0.02)
	r.mount = Vector3(0, y + 0.027, -0.08)
	r.bolt = port + Vector3(0.002, 0, 0)
	r.recv = Vector3(0, y - 0.01, -0.03)
	r.body_w = 0.022
	r.under = Vector3(0, y - 0.034, -0.36)
	r.gadget = Vector3(0, y - 0.04, 0.12)
	r.side = Vector3(0.02, y - 0.02, 0.28)


static func sawed_off(r: GunModels.Rig) -> void:
	var y := 0.085
	GunModels._slab(r.root, [Vector2(0.008, 0.098), Vector2(-0.075, 0.098), Vector2(-0.08, 0.09), Vector2(-0.08, 0.05), Vector2(-0.065, 0.044),
			Vector2(-0.01, 0.044), Vector2(0.008, 0.052)], 0.05, f("steel"), 0.0, 0.004)
	GunModels._pins(r, [Vector2(-0.068, 0.056)], 0.025, 0.003)
	for sx: float in [-1.0, 1.0]:
		GunModels._slab(r.root, [Vector2(0.004, 0.09), Vector2(0.018, 0.112), Vector2(0.024, 0.109), Vector2(0.014, 0.088)], 0.006,
				f("black"), sx * 0.012, 0.0008)
	# What is left of the stock: a cut-down pistol grip.
	GunModels._grip(r, Vector3(0, 0.062, 0.03), f("laminate"), Vector3(0.034, 0.095, 0.05), -32.0)
	if not r.parts.has("grip"):
		var cut := r.grip_top + GunModels._grip_down(-32.0) * 0.095
		GunModels._box(r.root, Vector3(0.036, 0.008, 0.052), cut, f("black"), Vector3(-32, 0, 0), 0.002)
	GunModels._blade_at(r, -0.018, 0.046, f("bare"))
	GunModels._guard(r, -0.052, 0.006, 0.046, 0.028, f("black"), 0.01)
	r.trig = Vector3(0, 0.036, -0.018)
	GunModels._twin_barrels(r, Vector3(0, y, -0.078), 0.25, 0.0125, f("black"))
	GunModels._slab(r.root, [Vector2(-0.08, y - 0.008), Vector2(-0.17, y - 0.008), Vector2(-0.176, y - 0.018), Vector2(-0.17, y - 0.03),
			Vector2(-0.085, y - 0.032), Vector2(-0.08, y - 0.024)], 0.04, f("laminate"), 0.0, 0.004)
	# Two spare shells in an elastic band on the left side.
	for i in 2:
		GunModels._round(r, GunModels._cyl(r.root, 0.0075, 0.04, Vector3(-0.031, 0.07, -0.05 + i * 0.016) + Vector3(0, 0, 0), f("shell_red"), 12))
	GunModels._box(r.root, Vector3(0.006, 0.012, 0.04), Vector3(-0.03, 0.07, -0.042), f("rubber"), Vector3.ZERO, 0.002)
	r.top = Vector3(0, y + 0.017, -0.06)
	r.mount = Vector3(0, y + 0.017, -0.12)
	r.rail_l = Vector3(-0.026, y - 0.004, -0.2)
	r.mag_style = "none"
	r.stock = Vector3(0, 0.07, 0.05)
	r.recv = Vector3(0, 0.072, -0.035)
	r.body_w = 0.025
	r.gadget = GunModels._grip_bottom(r) + Vector3(0, 0, 0.02)
	r.side = Vector3(0.026, 0.07, -0.04)
	r.bolt = Vector3(0.025, 0.072, -0.035)
	r.under = Vector3(0, y - 0.03, -0.25)


# --- Odd frames: industrial tools and prototypes ----------------------------------------

## A pneumatic framing nailer: a cast housing in oxide orange, a magnesium nose, the
## coil canister under it and a battery pack in the heel.
static func nail_gun(r: GunModels.Rig) -> void:
	var y := 0.075
	var body := f("oxide")
	GunModels._slab(r.root, [Vector2(0.08, y + 0.044), Vector2(-0.1, y + 0.044), Vector2(-0.12, y + 0.03), Vector2(-0.12, y - 0.02),
			Vector2(-0.1, y - 0.036), Vector2(0.02, y - 0.036), Vector2(0.06, y - 0.03), Vector2(0.09, y - 0.01), Vector2(0.095, y + 0.02)],
			0.054, body, 0.0, 0.008)
	GunModels._seam(r, Vector2(0.09, y + 0.004), Vector2(-0.12, y + 0.004), 0.027)
	GunModels._slab(r.root, [Vector2(0.06, y + 0.044), Vector2(-0.08, y + 0.044), Vector2(-0.075, y + 0.056), Vector2(0.05, y + 0.056)],
			0.04, f("black"), 0.0, 0.004)
	# The cylinder cap with cooling fins at the back.
	GunModels._turn(r.root, [Vector2(-0.025, 0.036), Vector2(0.02, 0.036), Vector2(0.028, 0.026), Vector2(0.03, 0.0)],
			Vector3(0, y + 0.005, 0.085), f("steel"), 18)
	for i in 4:
		GunModels._turn(r.root, [Vector2(-0.002, 0.039), Vector2(0.002, 0.039)], Vector3(0, y + 0.005, 0.068 + i * 0.01), f("steel"), 18)
	GunModels._grip(r, Vector3(0, y - 0.036, 0.03), f("rubber"), Vector3(0.036, 0.1, 0.046), -10.0)
	GunModels._slab(r.root, [Vector2(0.075, -0.07), Vector2(-0.01, -0.07), Vector2(-0.01, -0.105), Vector2(0.075, -0.105)],
			0.05, f("black"), 0.0, 0.004)
	GunModels._box(r.root, Vector3(0.052, 0.006, 0.012), Vector3(0, -0.075, -0.004), f("black", Color(0.25, 0.9, 0.4)), Vector3.ZERO, 0.0)
	var start := Vector3(0, y - 0.01, -0.12)
	var len := GunModels._barrel(r, start, 0.08, 0.012, f("bare"), false)
	GunModels._turn(r.root, [Vector2(-0.04, 0.013), Vector2(-0.036, 0.018), Vector2(0.0, 0.024)], start, f("steel"), 12)
	GunModels._slab(r.root, [Vector2(r.muzzle.z + 0.02, start.y - 0.012), Vector2(r.muzzle.z - 0.004, start.y - 0.012),
			Vector2(r.muzzle.z - 0.004, start.y - 0.022), Vector2(r.muzzle.z + 0.02, start.y - 0.022)], 0.028, f("sulfur"), 0.0, 0.002)
	GunModels._blade_at(r, -0.012, y - 0.036, f("black"))
	r.trig = Vector3(0, y - 0.048, -0.012)
	if not r.parts.has("magazine"):
		GunModels._turn(r.root, [Vector2(-0.018, 0.04), Vector2(0.018, 0.04)], Vector3.ZERO, f("black"), 20).transform = \
				LowPoly.at(Vector3(0, 0.0, -0.09), Vector3(0, 90, 0))
		GunModels._round(r, GunModels._cyl_x(r.root, 0.032, 0.038, Vector3(0, 0.0, -0.09), f("bare"), 18))
		GunModels._slab(r.root, [Vector2(-0.085, 0.04), Vector2(-0.11, 0.04), Vector2(-0.11, 0.03), Vector2(-0.085, 0.03)], 0.02, f("black"), 0.0, 0.002)
	r.mag = Vector3(0, 0.032, -0.09)
	r.top = Vector3(0, y + 0.056, -0.03)
	r.under = Vector3(0, y - 0.04, r.muzzle.z + 0.04 + len * 0.3)
	r.gadget = Vector3(0, -0.106, 0.06)
	r.side = Vector3(0.027, y - 0.005, -0.05)
	r.stock = Vector3(0, y, 0.115)
	r.rail_l = Vector3(-0.028, 0.07, -0.06)
	r.rail_r = Vector3(0.028, 0.07, -0.06)
	r.recv = Vector3(0, 0.075, -0.03)
	r.body_w = 0.027
	r.mount = Vector3(0, 0.131, -0.06)
	r.bolt = Vector3(0.028, 0.08, 0.0)
	r.mag_style = "coil"


## A compound crossbow: a machined rail stock, split limbs with cams, a cocked string.
static func crossbow(r: GunModels.Rig) -> void:
	var y := 0.085
	var alu := f("black")
	GunModels._slab(r.root, [Vector2(0.11, y - 0.01), Vector2(-0.3, y - 0.01), Vector2(-0.305, y - 0.02), Vector2(-0.3, y - 0.042),
			Vector2(-0.05, y - 0.046), Vector2(0.11, y - 0.042)], 0.034, alu, 0.0, 0.003)
	for i in 4:
		GunModels._slab(r.root, [Vector2(-0.1 - i * 0.045, y - 0.016), Vector2(-0.13 - i * 0.045, y - 0.016), Vector2(-0.13 - i * 0.045, y - 0.036),
				Vector2(-0.1 - i * 0.045, y - 0.036)], 0.0344, f("bore"), 0.0, 0.0)
	GunModels._box(r.root, Vector3(0.012, 0.006, 0.36), Vector3(0, y - 0.007, -0.12), f("bare"), Vector3.ZERO, 0.001)
	GunModels._grip(r, Vector3(0, y - 0.045, 0.03), f("polymer"), Vector3(0.032, 0.09, 0.045), -22.0)
	GunModels._blade_at(r, -0.014, y - 0.045, f("black"))
	r.trig = Vector3(0, y - 0.057, -0.014)
	GunModels._guard(r, -0.05, 0.014, y - 0.045, 0.028, alu, 0.01)
	var front := -0.29
	GunModels._slab(r.root, [Vector2(front + 0.03, y + 0.004), Vector2(front - 0.02, y + 0.004), Vector2(front - 0.02, y - 0.036),
			Vector2(front + 0.03, y - 0.036)], 0.05, f("steel"), 0.0, 0.004)
	for sx: float in [-1.0, 1.0]:
		var tip := Vector3(sx * 0.2, y - 0.012, front + 0.07)
		for k: float in [-0.007, 0.007]:
			var packed := PackedVector3Array([Vector3(sx * 0.02, y - 0.012 + k, front), Vector3(sx * 0.1, y - 0.012 + k, front + 0.012),
					tip + Vector3(0, k, 0)])
			GunModels._put(r.root, LowPoly.tube(packed, PackedFloat32Array([0.006, 0.005, 0.004]), 6), Vector3.ZERO, f("green"))
		GunModels._cyl_y(r.root, 0.012, 0.008, tip, f("bare"), 14)
		GunModels._rod_between(r.root, tip + Vector3(-sx * 0.006, 0.005, 0.004), Vector3(0, y + 0.002, -0.02), 0.0014, f("polymer"), 4)
	# The loaded bolt; its head is the round.
	GunModels._cyl(r.root, 0.004, 0.27, Vector3(0, y + 0.002, -0.15), f("dust"), 8)
	GunModels._round(r, GunModels._turn(r.root, [Vector2(-0.016, 0.0), Vector2(0.012, 0.007), Vector2(0.014, 0.004)], Vector3(0, y + 0.002, -0.3), f("bare"), 10))
	for sx: float in [-1.0, 1.0]:
		GunModels._box(r.root, Vector3(0.0015, 0.012, 0.03), Vector3(sx * 0.005, y + 0.008, -0.03), f("oxide"), Vector3(0, 0, sx * 30.0), 0.0)
	# A foot stirrup at the front.
	GunModels._tube(r.root, [Vector3(-0.02, y - 0.02, front - 0.02), Vector3(-0.025, y - 0.035, front - 0.06),
			Vector3(0.025, y - 0.035, front - 0.06), Vector3(0.02, y - 0.02, front - 0.02)], 0.004, f("black"), 6)
	r.muzzle = Vector3(0, y + 0.002, -0.315)
	r.top = Vector3(0, y + 0.004, 0.05)
	r.stock = Vector3(0, y - 0.025, 0.11)
	r.under = Vector3(0, y - 0.05, -0.22)
	r.gadget = Vector3(0, y - 0.046, 0.06)
	r.side = Vector3(0.018, y - 0.025, -0.13)
	r.mag_style = "none"
	r.rail_l = Vector3(-0.018, 0.06, -0.15)
	r.rail_r = Vector3(0.018, 0.06, -0.15)
	r.foregrip = Vector3(0, 0.041, -0.17)
	r.mount = Vector3(0, 0.089, 0.0)
	r.recv = Vector3(0, 0.06, -0.05)
	r.body_w = 0.017
	r.hg_start = -0.05
	r.hg_end = -0.25
	r.hg_y = 0.06
	r.hg_r = 0.019


## A fuel wand: a steel lance with a heat-shielded nozzle and a pilot light, the tank under.
static func flamethrower(r: GunModels.Rig) -> void:
	var y := 0.06
	GunModels._grip(r, Vector3(0, y - 0.016, 0.02), f("rubber"), Vector3(0.03, 0.095, 0.04), -12.0)
	GunModels._slab(r.root, [Vector2(0.09, y + 0.02), Vector2(-0.06, y + 0.02), Vector2(-0.06, y - 0.016), Vector2(0.09, y - 0.016)],
			0.034, f("black"), 0.0, 0.004)
	GunModels._blade_at(r, -0.016, y - 0.016, f("bare"))
	r.trig = Vector3(0, y - 0.028, -0.016)
	GunModels._guard(r, -0.05, 0.01, y - 0.016, 0.028, f("black"), 0.01)
	GunModels._turn(r.root, [Vector2(-0.3, 0.012), Vector2(0.0, 0.012)], Vector3(0, y, -0.06), f("bare"), 14)
	# A perforated heat shield over the lance.
	GunModels._turn(r.root, [Vector2(-0.12, 0.022), Vector2(-0.115, 0.024), Vector2(0.0, 0.024)], Vector3(0, y, -0.2), f("steel"), 14)
	for i in 6:
		for a: float in [30.0, 90.0, 150.0]:
			var dir := Vector3(cos(deg_to_rad(a)), sin(deg_to_rad(a)), 0)
			GunModels._cyl_x(r.root, 0.004, 0.0015, Vector3(0, y, -0.215 - i * 0.017) + dir * 0.0242, f("bore"), 8).rotation_degrees = Vector3(0, 90, a)
	GunModels._turn(r.root, [Vector2(-0.03, 0.017), Vector2(-0.025, 0.02), Vector2(0.0, 0.014)], Vector3(0, y, -0.32), f("black"), 14)
	GunModels._cyl(r.root, 0.009, 0.0016, Vector3(0, y, -0.3502), f("bore"), 10)
	GunModels._rod_between(r.root, Vector3(0, y - 0.016, -0.3), Vector3(0, y - 0.03, -0.34), 0.0025, f("brass"))
	GunModels._ball(r.root, 0.005, Vector3(0, y - 0.032, -0.343), f("bore", Color(1.0, 0.45, 0.1) * 1.4), Vector3(1, 1.6, 1))
	r.muzzle = Vector3(0, y, -0.355)
	GunModels._tube(r.root, [Vector3(0, y + 0.012, -0.08), Vector3(0, y + 0.05, -0.1), Vector3(0, y + 0.05, -0.17), Vector3(0, y + 0.012, -0.19)],
			0.0055, f("polymer"), 8)
	if not r.parts.has("magazine"):
		GunModels._tank(r, Vector3(0, -0.005, -0.17), 0.045, 0.2, f("green"))
	r.mag = Vector3(0, -0.005, -0.17)
	r.gadget = Vector3(0, y - 0.02, 0.09)
	r.side = Vector3(0.017, y, -0.03)
	r.under = Vector3(0, y - 0.03, -0.25)
	r.top = Vector3(0, y + 0.02, -0.02)
	r.stock = Vector3(0, y, 0.095)
	r.mag_style = "tank"
	r.rail_l = Vector3(-0.015, 0.06, -0.24)
	r.rail_r = Vector3(0.015, 0.06, -0.24)
	r.recv = Vector3(0, 0.06, -0.02)
	r.body_w = 0.017
	r.hg_start = -0.1
	r.hg_end = -0.3
	r.hg_y = 0.06
	r.hg_r = 0.014


## An arc projector: a graphite housing, a copper coil stack on ceramic insulators and a
## glass discharge bulb.
static func tesla(r: GunModels.Rig) -> void:
	var y := 0.075
	GunModels._grip(r, Vector3(0, y - 0.03, 0.02), f("polymer"), Vector3(0.032, 0.1, 0.044), -16.0)
	GunModels._slab(r.root, [Vector2(0.07, y + 0.03), Vector2(-0.08, y + 0.03), Vector2(-0.095, y + 0.015), Vector2(-0.095, y - 0.02),
			Vector2(-0.08, y - 0.03), Vector2(0.07, y - 0.03), Vector2(0.08, y - 0.015), Vector2(0.08, y + 0.02)], 0.05, f("black"), 0.0, 0.006)
	GunModels._seam(r, Vector2(0.08, y), Vector2(-0.095, y), 0.025)
	GunModels._blade_at(r, -0.012, y - 0.03, f("bare"))
	r.trig = Vector3(0, y - 0.042, -0.012)
	GunModels._guard(r, -0.05, 0.01, y - 0.03, 0.028, f("black"), 0.01)
	GunModels._turn(r.root, [Vector2(-0.16, 0.009), Vector2(0.0, 0.009)], Vector3(0, y, -0.095), f("bore", Color(0.35, 0.75, 0.8) * 0.8), 10)
	for i in 5:
		GunModels._turn(r.root, [Vector2(-0.008, 0.03 - i * 0.003), Vector2(-0.006, 0.034 - i * 0.003), Vector2(0.006, 0.034 - i * 0.003),
				Vector2(0.008, 0.03 - i * 0.003)], Vector3(0, y, -0.11 - i * 0.026), f("copper"), 20)
		GunModels._turn(r.root, [Vector2(-0.005, 0.016), Vector2(0.005, 0.016)], Vector3(0, y, -0.123 - i * 0.026), f("dust"), 12)
	for a: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var off := Vector3(cos(a), sin(a), 0) * 0.026
		GunModels._rod_between(r.root, Vector3(0, y, -0.22) + off, Vector3(0, y, -0.255) + off * 0.25, 0.0025, f("bare"))
	GunModels._ball(r.root, 0.011, Vector3(0, y, -0.26), f("chrome", Color(0.3, 0.75, 0.85) * 0.9))
	GunModels._turn(r.root, [Vector2(-0.008, 0.013), Vector2(0.008, 0.013)], Vector3.ZERO, f("copper"), 14).transform = LowPoly.at(Vector3(0, y + 0.036, 0.0), Vector3(90, 0, 0))
	GunModels._ball(r.root, 0.018, Vector3(0, y + 0.058, 0.0), f("glass"), Vector3(1, 1.25, 1))
	GunModels._ball(r.root, 0.006, Vector3(0, y + 0.056, 0.0), f("bore", Color(0.35, 0.8, 0.9) * 1.2))
	if not r.parts.has("magazine"):
		GunModels._slab(r.root, [Vector2(-0.03, y - 0.032), Vector2(-0.1, y - 0.032), Vector2(-0.1, y - 0.075), Vector2(-0.03, y - 0.075)],
				0.05, f("green"), 0.0, 0.004)
		GunModels._box(r.root, Vector3(0.012, 0.008, 0.012), Vector3(0.014, y - 0.03, -0.085), f("oxide"), Vector3.ZERO, 0.001)
	GunModels._tube(r.root, [Vector3(0.026, y - 0.02, -0.06), Vector3(0.034, y - 0.01, -0.1), Vector3(0.03, y, -0.13)], 0.0028, f("rubber"), 6)
	r.barrel_start = Vector3(0, y, -0.1)
	r.barrel_r = 0.034
	r.muzzle = Vector3(0, y, -0.27)
	r.mag = Vector3(0, y - 0.03, -0.065)
	r.stock = Vector3(0, y - 0.005, 0.08)
	r.gadget = Vector3(0, y - 0.03, 0.05)
	r.side = Vector3(0.025, y, -0.03)
	r.top = Vector3(0, y + 0.03, -0.05)
	r.under = Vector3(0, y - 0.04, -0.2)
	r.mag_style = "cell"
	r.rail_l = Vector3(-0.026, 0.075, -0.03)
	r.recv = Vector3(0, 0.075, -0.02)
	r.body_w = 0.025


## A pneumatic harpoon: a green-grey pressure tube, an air bottle under it, a rope reel.
static func harpoon(r: GunModels.Rig) -> void:
	var y := 0.07
	GunModels._grip(r, Vector3(0, y - 0.025, 0.02), f("rubber"), Vector3(0.032, 0.1, 0.045), -16.0)
	GunModels._turn(r.root, [Vector2(-0.465, 0.019), Vector2(-0.46, 0.021), Vector2(0.0, 0.021), Vector2(0.004, 0.017)],
			Vector3(0, y, 0.08), f("green"), 18)
	for z: float in [0.08, -0.375]:
		GunModels._turn(r.root, [Vector2(-0.012, 0.024), Vector2(0.012, 0.024)], Vector3(0, y, z), f("black"), 18)
	GunModels._slab(r.root, [Vector2(0.05, y - 0.018), Vector2(-0.06, y - 0.018), Vector2(-0.06, y - 0.03), Vector2(0.05, y - 0.03)],
			0.026, f("black"), 0.0, 0.003)
	GunModels._blade_at(r, -0.016, y - 0.025, f("bare"))
	r.trig = Vector3(0, y - 0.037, -0.016)
	GunModels._guard(r, -0.05, 0.008, y - 0.026, 0.028, f("black"), 0.01)
	GunModels._turn(r.root, [Vector2(-0.075, 0.0), Vector2(-0.07, 0.012), Vector2(-0.055, 0.018), Vector2(0.06, 0.018), Vector2(0.07, 0.01),
			Vector2(0.075, 0.0)], Vector3(0, y - 0.042, -0.16), f("sulfur"), 16)
	GunModels._cyl_y(r.root, 0.006, 0.02, Vector3(0, y - 0.024, -0.1), f("bare"), 10)
	GunModels._cyl(r.root, 0.005, 0.14, Vector3(0, y, -0.43), f("bare"), 8)
	GunModels._round(r, GunModels._turn(r.root, [Vector2(-0.025, 0.0), Vector2(0.025, 0.013), Vector2(0.026, 0.005)], Vector3(0, y, -0.52), f("bare"), 4))
	for sx: float in [-1.0, 1.0]:
		GunModels._box(r.root, Vector3(0.0025, 0.003, 0.03), Vector3(sx * 0.012, y, -0.495), f("bare"), Vector3(0, -sx * 30.0, 0), 0.0)
	GunModels._cyl_x(r.root, 0.03, 0.006, Vector3(0.022, y - 0.01, -0.03), f("black"), 20)
	GunModels._cyl_x(r.root, 0.03, 0.006, Vector3(0.05, y - 0.01, -0.03), f("black"), 20)
	GunModels._cyl_x(r.root, 0.024, 0.024, Vector3(0.036, y - 0.01, -0.03), f("dust"), 18)
	GunModels._tube(r.root, [Vector3(0.036, y + 0.014, -0.04), Vector3(0.03, y + 0.02, -0.2), Vector3(0.02, y + 0.012, -0.38),
			Vector3(0.006, y + 0.004, -0.44)], 0.0018, f("dust"), 4)
	r.muzzle = Vector3(0, y, -0.385)
	r.top = Vector3(0, y + 0.022, -0.05)
	r.stock = Vector3(0, y - 0.005, 0.095)
	r.gadget = Vector3(0, y - 0.022, 0.06)
	r.side = Vector3(-0.022, y, -0.2)
	r.under = Vector3(0, y - 0.03, -0.3)
	r.mag_style = "none"
	r.rail_l = Vector3(-0.022, 0.07, -0.25)
	r.mount = Vector3(0, 0.092, -0.12)
	r.recv = Vector3(0, 0.07, -0.05)
	r.body_w = 0.021


## Two copper rails on insulating clamps, the capacitor housing, fat cables.
static func railgun(r: GunModels.Rig) -> void:
	var y := 0.08
	var housing := f("steel")
	GunModels._grip(r, Vector3(0, y - 0.045, 0.02), f("polymer"), Vector3(0.034, 0.1, 0.045), -14.0)
	GunModels._slab(r.root, [Vector2(0.135, y + 0.035), Vector2(0.12, y + 0.045), Vector2(-0.12, y + 0.045), Vector2(-0.135, y + 0.03),
			Vector2(-0.135, y - 0.035), Vector2(-0.12, y - 0.045), Vector2(0.12, y - 0.045), Vector2(0.135, y - 0.03)], 0.07, housing, 0.0, 0.008)
	GunModels._seam(r, Vector2(0.135, y + 0.01), Vector2(-0.135, y + 0.01), 0.035)
	GunModels._box(r.root, Vector3(0.0712, 0.016, 0.04), Vector3(0, y + 0.024, -0.08), f("sulfur"), Vector3.ZERO, 0.0)
	for i in 6:
		GunModels._box(r.root, Vector3(0.05, 0.0016, 0.006), Vector3(0, y + 0.0452, 0.02 + i * 0.014), f("bore"), Vector3.ZERO, 0.0)
	GunModels._blade_at(r, -0.012, y - 0.045, f("bare"))
	r.trig = Vector3(0, y - 0.057, -0.012)
	GunModels._guard(r, -0.05, 0.01, y - 0.045, 0.028, f("black"), 0.012)
	var front := -0.6
	var len := absf(front + 0.13)
	for sy: float in [-1.0, 1.0]:
		GunModels._slab(r.root, [Vector2(-0.13, y + sy * 0.014), Vector2(front, y + sy * 0.014), Vector2(front, y + sy * 0.03),
				Vector2(-0.13, y + sy * 0.03)], 0.016, f("copper"), 0.0, 0.002)
	GunModels._box(r.root, Vector3(0.004, 0.02, len - 0.02), Vector3(0, y, -0.13 - len / 2.0), f("bore", Color(0.3, 0.75, 0.85) * 0.8), Vector3.ZERO, 0.0)
	for i in 4:
		GunModels._slab(r.root, [Vector2(-0.165 - i * 0.12, y + 0.04), Vector2(-0.18 - i * 0.12, y + 0.04), Vector2(-0.18 - i * 0.12, y - 0.04),
				Vector2(-0.165 - i * 0.12, y - 0.04)], 0.034, f("dust"), 0.0, 0.003)
	GunModels._grip(r, Vector3(0, y - 0.04, -0.18), f("polymer"), Vector3(0.026, 0.07, 0.03), -6.0)
	r.grip_top = Vector3(0, y - 0.045, 0.02)
	r.grip_size = Vector3(0.034, 0.1, 0.045)
	r.grip_rake = -14.0
	for sx: float in [-1.0, 1.0]:
		GunModels._tube(r.root, [Vector3(sx * 0.035, y + 0.01, -0.1), Vector3(sx * 0.05, y + 0.0, -0.22),
				Vector3(sx * 0.03, y + 0.0, -0.36), Vector3(sx * 0.016, y, -0.42)], 0.0055, f("rubber"), 8)
	if not r.parts.has("magazine"):
		GunModels._cells(r, Vector3(0, y - 0.045, -0.03), 2, 0.018, 0.1, f("green"))
	r.barrel_start = Vector3(0, y, -0.13)
	r.barrel_r = 0.034
	r.muzzle = Vector3(0, y, front)
	r.top = Vector3(0, y + 0.045, -0.02)
	r.mag = Vector3(0, y - 0.045, -0.03)
	r.stock = Vector3(0, y, 0.135)
	r.gadget = Vector3(0, y - 0.045, 0.1)
	r.side = Vector3(0.035, y, -0.05)
	r.under = Vector3(0, y - 0.05, -0.4)
	r.mag_style = "cell"
	r.foregrip = Vector3(0, 0.049, -0.36)
	r.mount = Vector3(0, 0.125, -0.08)
	r.recv = Vector3(0, 0.08, 0.0)
	r.body_w = 0.035


## A launcher tube in sulfur-painted steel with a flared blast cone; ducks for rounds.
static func duck_launcher(r: GunModels.Rig) -> void:
	var y := 0.08
	GunModels._grip(r, Vector3(0, y - 0.046, 0.02), f("polymer"), Vector3(0.032, 0.1, 0.042), -14.0)
	GunModels._turn(r.root, [Vector2(-0.34, 0.058), Vector2(-0.32, 0.058), Vector2(-0.3, 0.046), Vector2(0.12, 0.046), Vector2(0.125, 0.03),
			Vector2(0.126, 0.0)], Vector3(0, y, 0), f("green"), 20)
	GunModels._turn(r.root, [Vector2(-0.3, 0.0), Vector2(-0.299, 0.043), Vector2(-0.2, 0.043), Vector2(-0.199, 0.0)], Vector3(0, y, 0), f("bore"), 18)
	for z: float in [-0.22, 0.0]:
		GunModels._turn(r.root, [Vector2(-0.012, 0.049), Vector2(0.012, 0.049)], Vector3(0, y, z), f("sulfur"), 20)
	GunModels._duck(r.root, Vector3(0, y - 0.012, -0.335), 1.0)
	GunModels._slab(r.root, [Vector2(0.06, y - 0.044), Vector2(-0.05, y - 0.044), Vector2(-0.05, y - 0.05), Vector2(0.06, y - 0.05)],
			0.028, f("black"), 0.0, 0.002)
	GunModels._blade_at(r, -0.012, y - 0.05, f("bare"))
	r.trig = Vector3(0, y - 0.062, -0.012)
	GunModels._guard(r, -0.05, 0.01, y - 0.05, 0.028, f("black"), 0.01)
	GunModels._grip(r, Vector3(0, y - 0.046, -0.16), f("polymer"), Vector3(0.026, 0.07, 0.03), -10.0)
	r.grip_top = Vector3(0, y - 0.046, 0.02)
	r.grip_size = Vector3(0.032, 0.1, 0.042)
	r.grip_rake = -14.0
	r.muzzle = Vector3(0, y, -0.34)
	r.top = Vector3(0, y + 0.046, 0.0)
	r.mag = Vector3(-0.046, y, -0.07)
	r.stock = Vector3(0, y - 0.01, 0.125)
	r.gadget = Vector3(0, y - 0.046, 0.08)
	r.side = Vector3(0.046, y, -0.1)
	r.under = Vector3(0, y - 0.05, -0.26)
	r.mag_style = "hopper"
	r.rail_l = Vector3(-0.047, 0.08, -0.2)
	r.mount = Vector3(0, 0.126, -0.12)
	r.recv = Vector3(0, 0.08, 0.0)
	r.body_w = 0.046


## A blade thrower: a motor housing, a launch deck with the blade half under a guard.
static func saw_launcher(r: GunModels.Rig) -> void:
	var y := 0.07
	GunModels._grip(r, Vector3(0, y - 0.04, 0.022), f("rubber"), Vector3(0.034, 0.1, 0.044), -12.0)
	GunModels._slab(r.root, [Vector2(0.07, y + 0.026), Vector2(-0.1, y + 0.026), Vector2(-0.115, y + 0.012), Vector2(-0.115, y - 0.03),
			Vector2(-0.1, y - 0.04), Vector2(0.07, y - 0.04), Vector2(0.08, y - 0.02)], 0.05, f("green"), 0.0, 0.007)
	GunModels._turn(r.root, [Vector2(-0.03, 0.034), Vector2(0.028, 0.034), Vector2(0.032, 0.0)], Vector3(0, y + 0.005, 0.1), f("black"), 20)
	for i in 3:
		GunModels._turn(r.root, [Vector2(-0.002, 0.036), Vector2(0.002, 0.036)], Vector3(0, y + 0.005, 0.085 + i * 0.012), f("steel"), 20)
	GunModels._box(r.root, Vector3(0.09, 0.006, 0.12), Vector3(0, y + 0.03, -0.14), f("steel"), Vector3.ZERO, 0.002)
	GunModels._blade(r.root, Vector3(0, y + 0.042, -0.15), 0.072)
	var arc := []
	for i in 9:
		var a := PI * i / 8.0
		arc.append(Vector3(cos(a) * 0.074, y + 0.046, -0.15 + sin(a) * 0.074))
	GunModels._tube(r.root, arc, 0.006, f("oxide"), 6)
	GunModels._box(r.root, Vector3(0.012, 0.026, 0.012), Vector3(0, y + 0.05, -0.15), f("black"), Vector3.ZERO, 0.002)
	for sx: float in [-1.0, 1.0]:
		GunModels._rod_between(r.root, Vector3(sx * 0.04, y + 0.035, -0.06), Vector3(sx * 0.055, y + 0.035, -0.2), 0.0035, f("bare"))
	GunModels._blade_at(r, -0.012, y - 0.04, f("bare"))
	r.trig = Vector3(0, y - 0.052, -0.012)
	GunModels._guard(r, -0.05, 0.012, y - 0.04, 0.028, f("black"), 0.01)
	if not r.parts.has("magazine"):
		GunModels._blade_stack(r, Vector3(0, y - 0.04, -0.08), 3)
	r.muzzle = Vector3(0, y + 0.04, -0.22)
	r.top = Vector3(0, y + 0.028, 0.04)
	r.mag = Vector3(0, y - 0.04, -0.08)
	r.stock = Vector3(0, y - 0.005, 0.13)
	r.gadget = Vector3(0, y - 0.04, 0.05)
	r.side = Vector3(0.026, y - 0.01, 0.0)
	r.under = Vector3(0, y - 0.045, -0.15)
	r.mag_style = "blades"
	r.rail_l = Vector3(-0.026, 0.065, -0.03)
	r.recv = Vector3(0, 0.065, -0.02)
	r.body_w = 0.025


## A foam projector: a white housing, a glass reservoir of soap, a ring nozzle.
static func bubble_gun(r: GunModels.Rig) -> void:
	var y := 0.07
	GunModels._grip(r, Vector3(0, y - 0.03, 0.015), f("polymer"), Vector3(0.032, 0.09, 0.04), -12.0)
	GunModels._slab(r.root, [Vector2(0.05, y + 0.028), Vector2(-0.07, y + 0.028), Vector2(-0.09, y + 0.012), Vector2(-0.09, y - 0.02),
			Vector2(-0.075, y - 0.03), Vector2(0.05, y - 0.03), Vector2(0.06, y - 0.01)], 0.05, f("dust"), 0.0, 0.01)
	GunModels._seam(r, Vector2(0.06, y), Vector2(-0.09, y), 0.025)
	GunModels._turn(r.root, [Vector2(-0.06, 0.026), Vector2(-0.055, 0.03), Vector2(0.0, 0.018)], Vector3(0, y, -0.09), f("green"), 18)
	GunModels._turn(r.root, [Vector2(-0.006, 0.03), Vector2(-0.004, 0.033), Vector2(0.004, 0.033), Vector2(0.006, 0.03)], Vector3(0, y, -0.155), f("chrome"), 22)
	GunModels._blade_at(r, -0.01, y - 0.03, f("black"))
	r.trig = Vector3(0, y - 0.042, -0.01)
	GunModels._guard(r, -0.045, 0.006, y - 0.03, 0.026, f("dust"), 0.01)
	# The soap: a glass reservoir standing on top with a pink core.
	GunModels._turn(r.root, [Vector2(-0.03, 0.0), Vector2(-0.028, 0.02), Vector2(0.025, 0.022), Vector2(0.03, 0.01), Vector2(0.035, 0.0)],
			Vector3.ZERO, f("glass"), 18).transform = LowPoly.at(Vector3(0, y + 0.06, 0.0), Vector3(90, 0, 0))
	GunModels._cyl_y(r.root, 0.016, 0.04, Vector3(0, y + 0.058, 0.0), f("oxide", Color(0.3, 0.1, 0.15)), 14)
	GunModels._cyl_y(r.root, 0.012, 0.01, Vector3(0, y + 0.032, 0.0), f("black"), 12)
	var bubble := f("glass")
	GunModels._ball(r.root, 0.012, Vector3(0.03, y + 0.03, -0.19), bubble)
	GunModels._ball(r.root, 0.008, Vector3(-0.025, y + 0.045, -0.17), bubble)
	if not r.parts.has("magazine"):
		GunModels._slab(r.root, [Vector2(-0.02, y - 0.03), Vector2(-0.07, y - 0.03), Vector2(-0.07, y - 0.05), Vector2(-0.02, y - 0.05)],
				0.03, f("polymer"), 0.0, 0.003)
	r.muzzle = Vector3(0, y, -0.16)
	r.mag = Vector3(0, y - 0.03, -0.06)
	r.gadget = Vector3(0, y - 0.03, 0.03)
	r.side = Vector3(0.025, y, -0.04)
	r.top = Vector3(0, y + 0.03, -0.06)
	r.stock = Vector3(0, y, 0.05)
	r.under = Vector3(0, y - 0.03, -0.12)
	r.mag_style = "cell"
	r.rail_l = Vector3(-0.026, 0.07, -0.04)
	r.recv = Vector3(0, 0.07, -0.02)
	r.body_w = 0.025


# --- CHAOS frames: guns that bend the rules -----------------------------------------------

## A short magazine-fed shotgun built to throw its user: a blast shroud with side vents
## over a fat barrel, a box magazine, a stub cheek pad. The vents are what push.
static func jump_shotgun(r: GunModels.Rig) -> void:
	var y := 0.08
	var body := f("black")
	GunModels._slab(r.root, [Vector2(0.06, y + 0.026), Vector2(0.05, y + 0.032), Vector2(-0.11, y + 0.032), Vector2(-0.12, y + 0.022),
			Vector2(-0.12, y - 0.036), Vector2(-0.1, y - 0.042), Vector2(0.0, y - 0.042), Vector2(0.06, y - 0.03)], 0.046, body, 0.0, 0.004)
	GunModels._seam(r, Vector2(0.06, y - 0.004), Vector2(-0.12, y - 0.004), 0.023)
	GunModels._pins(r, [Vector2(-0.02, y - 0.03), Vector2(0.03, y - 0.026)], 0.023, 0.0024)
	GunModels._pic(r, Vector3(0, y + 0.032, -0.03), 0.13)
	var len := GunModels._barrel(r, Vector3(0, y + 0.006, -0.12), 0.2, 0.015, f("steel"), false)
	if not r.parts.has("muzzle"):
		# The blast shroud: an oxide-painted can, open at the front, slotted down both sides.
		var c := Vector3(0, y + 0.006, -0.12 - len * 0.55)
		GunModels._turn(r.root, [Vector2(-len * 0.5, 0.022), Vector2(-len * 0.48, 0.026), Vector2(len * 0.42, 0.026), Vector2(len * 0.48, 0.02)],
				c, f("oxide"), 16)
		for i in 5:
			for sx: float in [-1.0, 1.0]:
				GunModels._box(r.root, Vector3(0.002, 0.03, 0.008), c + Vector3(sx * 0.025, 0, -len * 0.35 + i * len * 0.16), f("bore"),
						Vector3(0, 0, sx * 20.0), 0.0)
		GunModels._cyl(r.root, 0.018, 0.003, c + Vector3(0, 0, -len * 0.5 - 0.001), f("bore"), 16)
		r.muzzle = c + Vector3(0, 0, -len * 0.5)
	var port := Vector3(0.0232, y + 0.006, -0.045)
	GunModels._box(r.root, Vector3(0.0016, 0.022, 0.05), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.009, 0.032, port + Vector3(-0.004, 0, 0), f("shell_red"), 12))
	GunModels._grip(r, Vector3(0, y - 0.04, 0.03), f("polymer"), Vector3(0.034, 0.1, 0.046), -18.0)
	GunModels._blade_at(r, -0.01, y - 0.042, f("black"))
	r.trig = Vector3(0, y - 0.054, -0.01)
	GunModels._guard(r, -0.046, 0.016, y - 0.042, 0.03, body, 0.012)
	r.stock = Vector3(0, y - 0.004, 0.06)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.06, y + 0.024), Vector2(0.15, y + 0.02), Vector2(0.158, y + 0.01), Vector2(0.158, y - 0.03),
				Vector2(0.14, y - 0.034), Vector2(0.06, y - 0.03)], 0.04, f("polymer"), 0.0, 0.004)
		GunModels._slab(r.root, [Vector2(0.158, y + 0.016), Vector2(0.17, y + 0.016), Vector2(0.17, y - 0.032), Vector2(0.158, y - 0.032)],
				0.042, f("rubber"), 0.0, 0.002)
	r.mag = Vector3(0, y - 0.042, -0.075)
	r.mag_style = "box"
	r.mag_len = 0.1
	r.mag_w = 0.034
	r.mag_d = 0.07
	r.mag_tilt = 4.0
	if not r.parts.has("magazine"):
		GunModels._mag_body(r, r.mag, r.mag_len, r.mag_w, r.mag_d, r.mag_tilt, 0.0, f("polymer"))
	r.top = Vector3(0, y + 0.032, -0.02)
	r.mount = Vector3(0, y + 0.032, -0.08)
	r.rail_l = Vector3(-0.024, y - 0.01, -0.09)
	r.recv = Vector3(0, y, -0.03)
	r.body_w = 0.023
	r.bolt = port + Vector3(0.002, 0, 0)
	r.gadget = Vector3(0, y - 0.04, 0.05)
	r.side = Vector3(0.023, y - 0.01, -0.09)
	r.under = Vector3(0, y - 0.03, -0.25)


## A gyrojet pistol: a bright steel slide pierced by rocket vents, a long slim barrel
## with four exhaust ports, a rocket nose showing in the muzzle.
static func gyrojet(r: GunModels.Rig) -> void:
	_pistol(r, {"y": 0.076, "front": -0.178, "slide": f("chrome"), "frame": f("black"), "grip": f("laminate"), "rake": -22.0})
	var y := 0.076
	for i in 4:
		for sx: float in [-1.0, 1.0]:
			GunModels._cyl_x(r.root, 0.0032, 0.0012, Vector3(sx * 0.0131, y + 0.002, -0.12 - i * 0.014), f("bore"), 10)
	if not r.parts.has("barrel"):
		GunModels._round(r, GunModels._turn(r.root, [Vector2(-0.012, 0.0), Vector2(-0.006, 0.0045), Vector2(0.004, 0.005)],
				r.muzzle + Vector3(0, 0, 0.012), f("sulfur"), 12))
	# The fin cap of a spare rocket on the back of the slide.
	GunModels._box(r.root, Vector3(0.012, 0.002, 0.006), Vector3(0, y + 0.0155, 0.02), f("oxide"), Vector3.ZERO, 0.0)


## A hand-carried six-barrel rotary gun: barrel cluster on three clamps, a motor housing,
## a carry handle, a front spade grip and an ammo can feeding a belt in from the left.
static func minigun(r: GunModels.Rig) -> void:
	var y := 0.085
	var steel := f("steel")
	GunModels._slab(r.root, [Vector2(0.09, y + 0.05), Vector2(-0.09, y + 0.05), Vector2(-0.1, y + 0.04), Vector2(-0.1, y - 0.045),
			Vector2(-0.09, y - 0.055), Vector2(0.09, y - 0.055), Vector2(0.1, y - 0.04), Vector2(0.1, y + 0.04)], 0.09, f("black"), 0.0, 0.008)
	GunModels._seam(r, Vector2(0.1, y + 0.01), Vector2(-0.1, y + 0.01), 0.045)
	for i in 8:
		GunModels._box(r.root, Vector3(0.0912, 0.003, 0.006), Vector3(0, y - 0.03 + i * 0.008, 0.06), f("bore"), Vector3.ZERO, 0.0)
	GunModels._turn(r.root, [Vector2(-0.03, 0.03), Vector2(-0.025, 0.04), Vector2(0.03, 0.04), Vector2(0.035, 0.03)], Vector3(0, y, -0.12), steel, 18)
	var front := -0.66
	if r.parts.has("muzzle"):
		front = -0.6
	for i in 6:
		var a := TAU * i / 6.0
		var off := Vector3(cos(a), sin(a), 0) * 0.022
		GunModels._turn(r.root, [Vector2(front, 0.0065), Vector2(front + 0.004, 0.0075), Vector2(-0.15, 0.0075), Vector2(-0.148, 0.009),
				Vector2(-0.1, 0.009)], Vector3(0, y, 0) + off, f("black"), 12)
		GunModels._cyl(r.root, 0.0034, 0.002, Vector3(0, y, front - 0.0005) + off, f("bore"), 8)
	for z: float in [-0.25, -0.45, front + 0.03]:
		GunModels._turn(r.root, [Vector2(-0.008, 0.031), Vector2(-0.006, 0.034), Vector2(0.006, 0.034), Vector2(0.008, 0.031)], Vector3(0, y, z), steel, 18)
	GunModels._cyl(r.root, 0.006, 0.52, Vector3(0, y, -0.38), f("bore"), 10)
	# Carry handle over the housing, a spade grip at the front, the rear pistol grip.
	GunModels._tube(r.root, [Vector3(0, y + 0.05, 0.06), Vector3(0, y + 0.1, 0.03), Vector3(0, y + 0.1, -0.08), Vector3(0, y + 0.05, -0.1)],
			0.007, f("black"), 10)
	GunModels._grip(r, Vector3(0, y - 0.055, 0.04), f("rubber"), Vector3(0.036, 0.1, 0.046), -10.0)
	GunModels._grip_shape(r, Vector3(0, y - 0.03, -0.2), f("rubber"), Vector3(0.03, 0.09, 0.036), 8.0)
	GunModels._rod_between(r.root, Vector3(0, y - 0.03, -0.12), Vector3(0, y - 0.03, -0.2), 0.008, steel)
	GunModels._blade_at(r, 0.012, y - 0.055, f("bare"))
	r.trig = Vector3(0, y - 0.067, 0.012)
	GunModels._guard(r, -0.026, 0.03, y - 0.055, 0.028, f("black"), 0.012)
	r.mag = Vector3(-0.07, y - 0.055, -0.02)
	r.mag_style = "belt"
	if not r.parts.has("magazine"):
		var can := Vector3(-0.09, y - 0.1, -0.02)
		GunModels._box(r.root, Vector3(0.07, 0.1, 0.14), can, f("poly_green"), Vector3.ZERO, 0.006)
		GunModels._box(r.root, Vector3(0.074, 0.01, 0.144), can + Vector3(0, 0.05, 0), f("black"), Vector3.ZERO, 0.002)
		GunModels._box(r.root, Vector3(0.002, 0.03, 0.06), can + Vector3(-0.036, 0.01, 0), f("sulfur"), Vector3.ZERO, 0.0)
		for i in 6:
			var t := i / 5.0
			var p := (can + Vector3(0.02, 0.055, 0)).lerp(Vector3(-0.046, y - 0.02, -0.04), t) + Vector3(-sin(t * PI) * 0.02, sin(t * PI) * 0.02, 0)
			GunModels._round(r, GunModels._cyl_x(r.root, 0.004, 0.03, p, f("brass"), 8))
	r.barrel_start = Vector3(0, y, -0.12)
	r.barrel_r = 0.034
	r.muzzle = Vector3(0, y, front)
	r.top = Vector3(0, y + 0.1, -0.02)
	r.mount = Vector3(0, y + 0.05, -0.06)
	r.stock = Vector3(0, y, 0.1)
	r.gadget = Vector3(0, y - 0.055, 0.08)
	r.side = Vector3(0.045, y, 0.0)
	r.under = Vector3(0, y - 0.04, -0.4)
	r.rail_l = Vector3(-0.046, y + 0.02, -0.04)
	r.recv = Vector3(0, y, 0.0)
	r.body_w = 0.045
	r.bolt = Vector3(0.045, y + 0.02, 0.02)
	r.charging = Vector3(0.05, y + 0.03, 0.06)


## Four barrels in a square on a chrome box-lock, laminate furniture, four bead sights.
static func quad_barrel(r: GunModels.Rig) -> void:
	var y := 0.085
	var wood := f("laminate")
	GunModels._slab(r.root, [Vector2(0.0, 0.112), Vector2(-0.09, 0.112), Vector2(-0.095, 0.104), Vector2(-0.095, 0.05), Vector2(-0.075, 0.04),
			Vector2(-0.01, 0.04), Vector2(0.0, 0.05)], 0.062, f("chrome"), 0.0, 0.004)
	GunModels._seam(r, Vector2(-0.01, 0.075), Vector2(-0.085, 0.075), 0.031)
	GunModels._pins(r, [Vector2(-0.08, 0.055), Vector2(-0.03, 0.06), Vector2(-0.055, 0.1)], 0.031, 0.003)
	for sx: float in [-1.5, -0.5, 0.5, 1.5]:
		GunModels._slab(r.root, [Vector2(-0.004, 0.104), Vector2(0.01, 0.124), Vector2(0.015, 0.121), Vector2(0.006, 0.1)], 0.005,
				f("black"), sx * 0.012, 0.0006)
	GunModels._blade_at(r, -0.034, 0.04, f("bare"))
	GunModels._blade_at(r, -0.02, 0.04, f("bare"))
	GunModels._guard(r, -0.058, 0.0, 0.042, 0.03, f("black"), 0.01)
	r.trig = Vector3(0, 0.032, -0.014)
	r.grip_top = Vector3(0, 0.045, 0.035)
	r.grip_rake = -5.0
	r.stock = Vector3(0, 0.072, 0.005)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.0, 0.106), Vector2(0.1, 0.086), Vector2(0.36, 0.078), Vector2(0.368, 0.068), Vector2(0.37, -0.045),
				Vector2(0.345, -0.05), Vector2(0.1, 0.03), Vector2(0.0, 0.045)], 0.04, wood, 0.0, 0.005)
		GunModels._slab(r.root, [Vector2(0.37, 0.074), Vector2(0.382, 0.074), Vector2(0.382, -0.048), Vector2(0.37, -0.05)], 0.042, f("rubber"), 0.0, 0.0015)
		r.butt = Vector3(0, 0.015, 0.382)
		r.butt_h = 0.125
		r.comb = Vector3(0, 0.084, 0.25)
	var rad := 0.0115
	var gap := rad + 0.001
	var len := 0.0
	for sy: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			len = GunModels._barrel(r, Vector3(sx * gap, y + sy * gap, -0.094), 0.5, rad, f("black"), false)
			GunModels._ball(r.root, 0.002, Vector3(sx * gap, y + sy * gap + rad + 0.002, -0.094 - len + 0.008), f("brass"))
	for z: float in [-0.2, -0.094 - len + 0.03]:
		GunModels._box(r.root, Vector3(gap * 4.2, gap * 4.2, 0.012), Vector3(0, y, z), f("black"), Vector3.ZERO, 0.002)
	GunModels._slab(r.root, [Vector2(-0.095, y - 0.022), Vector2(-0.25, y - 0.022), Vector2(-0.256, y - 0.032), Vector2(-0.245, y - 0.044),
			Vector2(-0.1, y - 0.046), Vector2(-0.095, y - 0.038)], 0.05, wood, 0.0, 0.004)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		GunModels._round(r, GunModels._cyl(r.root, 0.007, 0.003, Vector3(cos(a), sin(a), 0) * gap * 1.41 + Vector3(0, y, -0.091), f("brass"), 12))
	r.twin = gap
	r.barrel_start = Vector3(0, y, -0.094)
	r.barrel_r = gap * 2.0
	r.muzzle = Vector3(0, y, -0.094 - len)
	r.top = Vector3(0, y + 2.0 * gap + 0.004, -0.06)
	r.mount = Vector3(0, y + 2.0 * gap + 0.004, -0.12)
	r.rail_l = Vector3(-0.026, y - 0.03, -0.17)
	r.mag_style = "none"
	r.recv = Vector3(0, 0.075, -0.045)
	r.body_w = 0.031
	r.gadget = Vector3(0, 0.045, 0.1)
	r.side = Vector3(0.02, 0.05, 0.24)
	r.under = Vector3(0, y - 0.05, -0.4)
	r.bolt = Vector3(0.031, 0.075, -0.045)


## A punt gun: a two-metre wildfowling barrel in rust and brass bands, a bell mouth, a
## tiny wooden stock that was never meant for a shoulder, rope breeching through a ring.
static func punt_gun(r: GunModels.Rig) -> void:
	var y := 0.09
	var wood := f("laminate")
	var front := -1.55
	GunModels._turn(r.root, [Vector2(front - 0.04, 0.046), Vector2(front - 0.035, 0.05), Vector2(front, 0.032), Vector2(front + 0.06, 0.026),
			Vector2(-0.3, 0.03), Vector2(-0.12, 0.036), Vector2(-0.1, 0.044), Vector2(0.0, 0.044), Vector2(0.01, 0.036)], Vector3(0, y, 0), f("rust"), 20)
	GunModels._cyl(r.root, 0.034, 0.003, Vector3(0, y, front - 0.04), f("bore"), 18)
	for z: float in [-0.12, -0.5, -0.9, -1.3]:
		GunModels._turn(r.root, [Vector2(-0.012, 0.035), Vector2(-0.01, 0.038), Vector2(0.01, 0.038), Vector2(0.012, 0.035)],
				Vector3(0, y, z - (0.0 if z > -0.2 else 0.0)), f("brass"), 20)
	# Breech block, a side hammer, the breeching ring with rope through it.
	GunModels._slab(r.root, [Vector2(0.01, y + 0.04), Vector2(0.06, y + 0.03), Vector2(0.06, y - 0.04), Vector2(0.01, y - 0.046)], 0.07, f("steel"), 0.0, 0.004)
	GunModels._slab(r.root, [Vector2(0.03, y + 0.03), Vector2(0.046, y + 0.058), Vector2(0.054, y + 0.054), Vector2(0.044, y + 0.026)], 0.008,
			f("black"), 0.03, 0.001)
	GunModels._turn(r.root, [Vector2(-0.004, 0.018), Vector2(0.004, 0.018)], Vector3.ZERO, f("steel"), 16).transform = LowPoly.at(Vector3(0, y - 0.06, -0.06), Vector3(0, 90, 0))
	GunModels._tube(r.root, [Vector3(0.0, y - 0.06, -0.08), Vector3(0.03, y - 0.09, -0.02), Vector3(0.05, y - 0.1, 0.08)], 0.006, f("sand"), 8)
	GunModels._tube(r.root, [Vector3(0.0, y - 0.06, -0.04), Vector3(-0.03, y - 0.09, 0.02), Vector3(-0.05, y - 0.1, 0.1)], 0.006, f("sand"), 8)
	r.stock = Vector3(0, y - 0.01, 0.06)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.06, y + 0.03), Vector2(0.24, y + 0.0), Vector2(0.25, y - 0.01), Vector2(0.25, y - 0.09),
				Vector2(0.23, y - 0.095), Vector2(0.06, y - 0.045)], 0.05, wood, 0.0, 0.005)
		r.butt = Vector3(0, y - 0.045, 0.25)
		r.butt_h = 0.09
		r.comb = Vector3(0, y + 0.01, 0.16)
	GunModels._grip(r, Vector3(0, y - 0.044, 0.08), wood, Vector3(0.034, 0.09, 0.044), -30.0)
	GunModels._blade_at(r, 0.04, y - 0.046, f("bare"))
	r.trig = Vector3(0, y - 0.058, 0.04)
	GunModels._guard(r, 0.01, 0.07, y - 0.046, 0.028, f("steel"), 0.012)
	# A wooden cradle block under the barrel to rest it on.
	GunModels._slab(r.root, [Vector2(-0.4, y - 0.03), Vector2(-0.56, y - 0.03), Vector2(-0.57, y - 0.06), Vector2(-0.39, y - 0.06)], 0.06, wood, 0.0, 0.004)
	GunModels._round(r, GunModels._cyl(r.root, 0.03, 0.004, Vector3(0, y, 0.012), f("shell_green"), 18))
	r.barrel_start = Vector3(0, y, -0.1)
	r.barrel_r = 0.03
	r.muzzle = Vector3(0, y, front - 0.04)
	r.top = Vector3(0, y + 0.044, -0.04)
	r.mount = Vector3(0, y + 0.036, -0.25)
	r.rail_l = Vector3(-0.036, y, -0.3)
	r.mag_style = "none"
	r.recv = Vector3(0, y, 0.03)
	r.body_w = 0.035
	r.gadget = Vector3(0, y - 0.046, 0.12)
	r.side = Vector3(0.035, y, 0.03)
	r.under = Vector3(0, y - 0.06, -0.48)
	r.bolt = Vector3(0.035, y + 0.01, 0.03)


## A pneumatic lance: a green air bottle under a slotted guide tube, a chrome ram with a
## four-sided spike, a pressure gauge with a glass face.
static func pneumatic_lance(r: GunModels.Rig) -> void:
	var y := 0.08
	GunModels._grip(r, Vector3(0, y - 0.035, 0.03), f("rubber"), Vector3(0.034, 0.1, 0.044), -14.0)
	GunModels._slab(r.root, [Vector2(0.09, y + 0.026), Vector2(-0.08, y + 0.026), Vector2(-0.09, y + 0.016), Vector2(-0.09, y - 0.026),
			Vector2(-0.08, y - 0.036), Vector2(0.09, y - 0.036), Vector2(0.1, y - 0.02), Vector2(0.1, y + 0.016)], 0.05, f("steel"), 0.0, 0.005)
	GunModels._seam(r, Vector2(0.1, y), Vector2(-0.09, y), 0.025)
	GunModels._turn(r.root, [Vector2(-0.4, 0.016), Vector2(-0.396, 0.019), Vector2(-0.09, 0.019), Vector2(-0.086, 0.016)], Vector3(0, y + 0.004, 0), f("black"), 16)
	for i in 6:
		GunModels._box(r.root, Vector3(0.0392, 0.004, 0.03), Vector3(0, y + 0.004, -0.13 - i * 0.045), f("bore"), Vector3.ZERO, 0.0)
	# The ram: chrome rod sticking out past the tube, a hardened four-sided spike on it.
	GunModels._cyl(r.root, 0.007, 0.08, Vector3(0, y + 0.004, -0.43), f("chrome"), 14)
	GunModels._round(r, GunModels._turn(r.root, [Vector2(-0.06, 0.0), Vector2(0.0, 0.012), Vector2(0.006, 0.009)], Vector3(0, y + 0.004, -0.47), f("bare"), 4))
	GunModels._turn(r.root, [Vector2(-0.16, 0.0), Vector2(-0.15, 0.018), Vector2(-0.13, 0.026), Vector2(0.06, 0.026), Vector2(0.075, 0.016),
			Vector2(0.08, 0.0)], Vector3(0, y - 0.05, -0.12), f("green"), 18)
	GunModels._turn(r.root, [Vector2(-0.006, 0.027), Vector2(0.006, 0.027)], Vector3(0, y - 0.05, -0.2), f("sulfur"), 18)
	GunModels._cyl_y(r.root, 0.006, 0.02, Vector3(0, y - 0.03, -0.1), f("bare"), 10)
	var gauge := Vector3(0.03, y + 0.01, -0.03)
	GunModels._cyl_x(r.root, 0.016, 0.01, gauge, f("black"), 20)
	GunModels._cyl_x(r.root, 0.013, 0.002, gauge + Vector3(0.006, 0, 0), f("dust"), 18)
	GunModels._box(r.root, Vector3(0.0012, 0.01, 0.0016), gauge + Vector3(0.0075, 0.003, -0.002), f("oxide"), Vector3(-35, 0, 0), 0.0)
	GunModels._cyl_x(r.root, 0.0135, 0.002, gauge + Vector3(0.0085, 0, 0), f("glass"), 18)
	GunModels._blade_at(r, -0.01, y - 0.036, f("bare"))
	r.trig = Vector3(0, y - 0.048, -0.01)
	GunModels._guard(r, -0.048, 0.014, y - 0.036, 0.028, f("black"), 0.012)
	r.stock = Vector3(0, y - 0.005, 0.1)
	r.barrel_start = Vector3(0, y + 0.004, -0.09)
	r.barrel_r = 0.019
	r.muzzle = Vector3(0, y + 0.004, -0.53)
	r.mag = Vector3(0, y - 0.036, -0.03)
	r.mag_style = "cell"
	r.top = Vector3(0, y + 0.026, -0.02)
	r.mount = Vector3(0, y + 0.026, -0.06)
	r.rail_l = Vector3(-0.026, y, -0.05)
	r.recv = Vector3(0, y, 0.0)
	r.body_w = 0.025
	r.gadget = Vector3(0, y - 0.036, 0.07)
	r.side = Vector3(-0.025, y - 0.01, 0.03)
	r.under = Vector3(0, y - 0.08, -0.25)


## A compact SMG whose shroud is cut with a helix of slots, and two deflector vanes at
## the muzzle that set every bullet spinning off at an angle.
static func ricochet_smg(r: GunModels.Rig) -> void:
	var y := 0.08
	var body := f("poly_grey")
	GunModels._slab(r.root, [Vector2(0.07, y + 0.024), Vector2(0.06, y + 0.03), Vector2(-0.12, y + 0.03), Vector2(-0.13, y + 0.02),
			Vector2(-0.13, y - 0.028), Vector2(-0.11, y - 0.036), Vector2(0.0, y - 0.036), Vector2(0.07, y - 0.026)], 0.042, body, 0.0, 0.004)
	GunModels._seam(r, Vector2(0.07, y), Vector2(-0.13, y), 0.021)
	GunModels._pic(r, Vector3(0, y + 0.03, -0.03), 0.15)
	GunModels._barrel(r, Vector3(0, y + 0.004, -0.13), 0.17, 0.0085, f("bore"), false)
	var c := Vector3(0, y + 0.004, -0.13)
	GunModels._turn(r.root, [Vector2(-0.15, 0.016), Vector2(-0.146, 0.019), Vector2(0.0, 0.019)], c, f("black"), 18)
	for i in 14:
		var a := i * 0.9
		var z := c.z - 0.012 - i * 0.0095
		GunModels._box(r.root, Vector3(0.008, 0.0016, 0.006), Vector3(cos(a) * 0.0186, sin(a) * 0.0186 + c.y, z), f("bore"),
				Vector3(0, 30, rad_to_deg(a) + 90.0), 0.0)
	if not r.parts.has("muzzle"):
		for sx: float in [-1.0, 1.0]:
			GunModels._slab(r.root, [Vector2(c.z - 0.15, c.y + 0.004), Vector2(c.z - 0.18, c.y + 0.016), Vector2(c.z - 0.184, c.y + 0.012),
					Vector2(c.z - 0.158, c.y - 0.006)], 0.004, f("sulfur"), sx * 0.012, 0.0006)
	var port := Vector3(0.0212, y + 0.008, -0.05)
	GunModels._box(r.root, Vector3(0.0016, 0.014, 0.034), port, f("bore"), Vector3.ZERO, 0.0)
	GunModels._round(r, GunModels._cyl(r.root, 0.0042, 0.016, port + Vector3(-0.003, 0, 0), f("brass"), 10))
	GunModels._grip(r, Vector3(0, y - 0.036, 0.03), f("polymer"), Vector3(0.032, 0.098, 0.043), -16.0)
	GunModels._blade_at(r, -0.01, y - 0.036, f("black"))
	r.trig = Vector3(0, y - 0.048, -0.01)
	GunModels._guard(r, -0.046, 0.016, y - 0.036, 0.028, body, 0.011)
	r.mag = Vector3(0, y - 0.036, -0.075)
	r.mag_style = "box"
	r.mag_len = 0.13
	r.mag_w = 0.022
	r.mag_d = 0.03
	r.mag_tilt = 2.0
	if not r.parts.has("magazine"):
		GunModels._mag_body(r, r.mag, r.mag_len, r.mag_w, r.mag_d, r.mag_tilt, 0.0, f("black"))
	r.stock = Vector3(0, y - 0.004, 0.07)
	if not r.parts.has("stock"):
		GunModels._slab(r.root, [Vector2(0.07, y + 0.02), Vector2(0.075, y + 0.02), Vector2(0.075, y - 0.02), Vector2(0.07, y - 0.02)],
				0.03, f("black"), 0.0, 0.001)
	r.charging = Vector3(-0.024, y + 0.012, -0.08)
	if not r.parts.has("charging"):
		GunModels._box(r.root, Vector3(0.008, 0.008, 0.014), r.charging, f("oxide"), Vector3.ZERO, 0.0015)
	r.hg_start = -0.13
	r.hg_end = -0.27
	r.hg_y = c.y
	r.hg_r = 0.019
	r.top = Vector3(0, y + 0.03, -0.02)
	r.mount = Vector3(0, y + 0.03, -0.08)
	r.rail_l = Vector3(-0.02, y + 0.004, -0.2)
	r.foregrip = Vector3(0, c.y - 0.019, -0.18)
	r.recv = Vector3(0, y, -0.03)
	r.body_w = 0.021
	r.bolt = port + Vector3(0.002, 0, 0)
	r.gadget = Vector3(0, y - 0.036, 0.06)
	r.side = Vector3(0.021, y - 0.01, -0.09)
	r.under = Vector3(0, y - 0.02, -0.24)


## A revolver machined from tempered glass: you can see the steel liner, the cylinder
## and the rounds inside. The hammer, liner and grip are the only opaque parts.
static func glass_revolver(r: GunModels.Rig) -> void:
	var y := 0.07
	var glass := f("glass")
	GunModels._slab(r.root, [Vector2(0.032, y + 0.008), Vector2(0.03, y + 0.022), Vector2(0.012, y + 0.028), Vector2(-0.07, y + 0.028),
			Vector2(-0.072, y + 0.012), Vector2(-0.072, y - 0.03), Vector2(-0.062, y - 0.036), Vector2(-0.02, y - 0.036),
			Vector2(-0.008, y - 0.046), Vector2(0.012, y - 0.046), Vector2(0.03, y - 0.032)], 0.026, glass, 0.0, 0.0022)
	var cyl_c := Vector3(0, y - 0.006, -0.038)
	GunModels._turn(r.root, [Vector2(-0.026, 0.022), Vector2(-0.024, 0.025), Vector2(0.024, 0.025), Vector2(0.026, 0.022)], cyl_c, f("chrome"), 24)
	for i in 5:
		var a := TAU * i / 5.0
		GunModels._round(r, GunModels._cyl(r.root, 0.0055, 0.002, cyl_c + Vector3(cos(a), sin(a), 0) * 0.015 + Vector3(0, 0, 0.0255), f("brass"), 10))
	var len := GunModels._barrel(r, Vector3(0, y + 0.002, -0.07), 0.15, 0.006, f("steel"), false)
	GunModels._turn(r.root, [Vector2(-len, 0.011), Vector2(-len + 0.003, 0.0135), Vector2(0.0, 0.0135)], Vector3(0, y + 0.002, -0.07), glass, 18)
	GunModels._slab(r.root, [Vector2(-0.07, y - 0.008), Vector2(-0.07 - len + 0.004, y - 0.008), Vector2(-0.07 - len, y - 0.016),
			Vector2(-0.07 - len + 0.01, y - 0.024), Vector2(-0.07, y - 0.024)], 0.014, glass, 0.0, 0.0018)
	GunModels._box(r.root, Vector3(0.004, 0.008, 0.006), Vector3(0, y + 0.02, -0.07 - len + 0.008), f("oxide"), Vector3.ZERO, 0.0)
	GunModels._slab(r.root, [Vector2(0.028, y + 0.012), Vector2(0.044, y + 0.03), Vector2(0.05, y + 0.027), Vector2(0.038, y + 0.008)],
			0.008, f("black"), 0.0, 0.0008)
	GunModels._grip(r, Vector3(0, y - 0.034, 0.018), f("rubber"), Vector3(0.03, 0.1, 0.044), -20.0)
	GunModels._blade_at(r, -0.004, y - 0.036, f("chrome"))
	r.trig = Vector3(0, y - 0.05, -0.004)
	GunModels._guard(r, -0.032, 0.012, y - 0.036, 0.032, glass, 0.009)
	r.top = Vector3(0, y + 0.028, -0.03)
	r.under = Vector3(0, y - 0.024, r.muzzle.z + 0.06)
	r.gadget = GunModels._grip_bottom(r) + Vector3(0, -0.006, 0.012)
	r.side = Vector3(0.014, y - 0.03, 0.01)
	r.stock = Vector3(0, y - 0.03, 0.05)
	r.rail_l = Vector3(-0.009, y - 0.016, -0.07 - len * 0.6)
	r.recv = cyl_c
	r.body_w = 0.013
	r.mount = r.top + Vector3(0, 0, -0.05)
	r.bolt = Vector3(0, y + 0.03, 0.044)
	r.mag = Vector3(0, y - 0.04, -0.05)


## A tuning-fork resonator: two long chrome tines from a heavy steel stem, a striker
## hammer cocked over them, and a cell in the housing that keeps them ringing.
static func tuning_fork(r: GunModels.Rig) -> void:
	var y := 0.08
	GunModels._grip(r, Vector3(0, y - 0.035, 0.025), f("polymer"), Vector3(0.032, 0.1, 0.044), -16.0)
	GunModels._slab(r.root, [Vector2(0.08, y + 0.03), Vector2(-0.07, y + 0.03), Vector2(-0.085, y + 0.015), Vector2(-0.085, y - 0.025),
			Vector2(-0.07, y - 0.035), Vector2(0.08, y - 0.035), Vector2(0.09, y - 0.015), Vector2(0.09, y + 0.02)], 0.054, f("black"), 0.0, 0.006)
	GunModels._seam(r, Vector2(0.09, y + 0.004), Vector2(-0.085, y + 0.004), 0.027)
	GunModels._turn(r.root, [Vector2(-0.06, 0.012), Vector2(-0.05, 0.018), Vector2(0.0, 0.018)], Vector3(0, y, -0.085), f("steel"), 18)
	# The fork: a U at the stem, two tines running forward.
	var tine := f("chrome")
	GunModels._slab(r.root, [Vector2(-0.14, y + 0.03), Vector2(-0.12, y + 0.03), Vector2(-0.12, y - 0.03), Vector2(-0.14, y - 0.03)], 0.016, tine, 0.0, 0.003)
	for sy: float in [-1.0, 1.0]:
		GunModels._slab(r.root, [Vector2(-0.13, y + sy * 0.02), Vector2(-0.46, y + sy * 0.02), Vector2(-0.465, y + sy * 0.025),
				Vector2(-0.46, y + sy * 0.03), Vector2(-0.13, y + sy * 0.03)], 0.014, tine, 0.0, 0.002)
	GunModels._cyl(r.root, 0.012, 0.06, Vector3(0, y, -0.11), f("steel"), 16)
	# The striker: a rubber-tipped hammer on an arm over the stem.
	GunModels._slab(r.root, [Vector2(0.0, y + 0.03), Vector2(-0.09, y + 0.05), Vector2(-0.09, y + 0.042), Vector2(0.0, y + 0.024)], 0.008, f("steel"), 0.0, 0.001)
	GunModels._cyl_x(r.root, 0.012, 0.03, Vector3(0, y + 0.05, -0.1), f("rubber"), 16)
	GunModels._cyl_x(r.root, 0.006, 0.058, Vector3(0, y + 0.03, 0.0), f("bare"), 12)
	for i in 4:
		GunModels._box(r.root, Vector3(0.0552, 0.003, 0.006), Vector3(0, y - 0.02 + i * 0.009, 0.06), f("bore"), Vector3.ZERO, 0.0)
	GunModels._blade_at(r, -0.01, y - 0.035, f("bare"))
	r.trig = Vector3(0, y - 0.047, -0.01)
	GunModels._guard(r, -0.048, 0.014, y - 0.035, 0.028, f("black"), 0.012)
	if not r.parts.has("magazine"):
		GunModels._cells(r, Vector3(0, y - 0.035, -0.045), 2, 0.014, 0.08, f("green"))
	r.barrel_start = Vector3(0, y, -0.13)
	r.barrel_r = 0.03
	r.muzzle = Vector3(0, y, -0.465)
	r.mag = Vector3(0, y - 0.035, -0.045)
	r.mag_style = "cell"
	r.stock = Vector3(0, y - 0.005, 0.09)
	r.top = Vector3(0, y + 0.03, 0.03)
	r.mount = Vector3(0, y + 0.03, -0.03)
	r.rail_l = Vector3(-0.028, y, -0.03)
	r.recv = Vector3(0, y, 0.0)
	r.body_w = 0.027
	r.gadget = Vector3(0, y - 0.035, 0.07)
	r.side = Vector3(0.027, y - 0.01, 0.03)
	r.under = Vector3(0, y - 0.04, -0.3)


## An anchor gun: a sulfur-painted launch tube, a steel anchor with two flukes on the
## front, a rope drum on the right paying out to the anchor's ring.
static func anchor_gun(r: GunModels.Rig) -> void:
	var y := 0.075
	GunModels._grip(r, Vector3(0, y - 0.028, 0.02), f("rubber"), Vector3(0.033, 0.1, 0.045), -16.0)
	GunModels._turn(r.root, [Vector2(-0.38, 0.022), Vector2(-0.375, 0.026), Vector2(0.0, 0.026), Vector2(0.006, 0.02)], Vector3(0, y, 0.08), f("green"), 18)
	for z: float in [0.0, -0.2]:
		GunModels._turn(r.root, [Vector2(-0.008, 0.0265), Vector2(0.008, 0.0265)], Vector3(0, y, z), f("sulfur"), 18)
	for z: float in [0.08, -0.29]:
		GunModels._turn(r.root, [Vector2(-0.012, 0.029), Vector2(0.012, 0.029)], Vector3(0, y, z), f("black"), 18)
	GunModels._slab(r.root, [Vector2(0.05, y - 0.022), Vector2(-0.06, y - 0.022), Vector2(-0.06, y - 0.032), Vector2(0.05, y - 0.032)],
			0.028, f("black"), 0.0, 0.003)
	GunModels._blade_at(r, -0.016, y - 0.028, f("bare"))
	r.trig = Vector3(0, y - 0.04, -0.016)
	GunModels._guard(r, -0.05, 0.008, y - 0.028, 0.028, f("black"), 0.01)
	# The anchor: shank, crown, two curved flukes with spade tips, a ring at the back.
	var a := Vector3(0, y, -0.33)
	GunModels._cyl(r.root, 0.006, 0.14, a + Vector3(0, 0, -0.04), f("steel"), 10)
	var crown := a + Vector3(0, 0, -0.11)
	var fluke := []
	for i in 9:
		var t := PI * i / 8.0
		fluke.append(crown + Vector3(0, cos(t) * 0.055, 0.035 * (1.0 - sin(t))))
	GunModels._tube(r.root, fluke, 0.0065, f("steel"), 10)
	GunModels._ball(r.root, 0.011, crown, f("steel"))
	for sy: float in [-1.0, 1.0]:
		var tip := crown + Vector3(0, sy * 0.055, 0.035)
		GunModels._slab(r.root, [Vector2(tip.z + 0.012, tip.y), Vector2(tip.z - 0.016, tip.y + sy * 0.008), Vector2(tip.z - 0.006, tip.y - sy * 0.016)],
				0.008, f("steel"), 0.0, 0.001)
	GunModels._turn(r.root, [Vector2(-0.004, 0.012), Vector2(0.004, 0.012)], Vector3.ZERO, f("steel"), 16).transform = LowPoly.at(a + Vector3(0, 0, 0.035), Vector3(0, 90, 0))
	var drum := Vector3(0.05, y - 0.006, -0.03)
	GunModels._cyl_x(r.root, 0.032, 0.006, drum + Vector3(-0.014, 0, 0), f("black"), 22)
	GunModels._cyl_x(r.root, 0.032, 0.006, drum + Vector3(0.014, 0, 0), f("black"), 22)
	GunModels._cyl_x(r.root, 0.026, 0.024, drum, f("sand"), 20)
	GunModels._rod_between(r.root, Vector3(0.026, y - 0.006, -0.03), drum + Vector3(0.017, 0, 0), 0.004, f("steel"))
	GunModels._tube(r.root, [drum + Vector3(0, 0.024, -0.01), Vector3(0.03, y + 0.03, -0.15), Vector3(0.012, y + 0.016, -0.3), a + Vector3(0.004, 0, 0.035)],
			0.002, f("sand"), 6)
	r.muzzle = crown + Vector3(0, 0, -0.012)
	r.barrel_start = Vector3(0, y, -0.0)
	r.barrel_r = 0.026
	r.top = Vector3(0, y + 0.026, -0.05)
	r.stock = Vector3(0, y - 0.005, 0.095)
	r.gadget = Vector3(0, y - 0.026, 0.06)
	r.side = Vector3(-0.026, y, -0.15)
	r.under = Vector3(0, y - 0.03, -0.22)
	r.mag_style = "none"
	r.rail_l = Vector3(-0.026, y, -0.2)
	r.mount = Vector3(0, y + 0.026, -0.12)
	r.recv = Vector3(0, y, -0.05)
	r.body_w = 0.026
