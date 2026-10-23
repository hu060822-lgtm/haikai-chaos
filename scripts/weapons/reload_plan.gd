class_name ReloadPlan
extends RefCounted
## How a gun is reloaded and worked, as one timeline both views play (character overhaul,
## Phase 4): the first-person arms (ViewModel) and the third-person athlete (AthleteRig)
## sample the same keys at the same progress, so the hands touch the same parts of the
## gun at the same moments and both end the instant the weapon's reload ends.
##
## Everything is in gun space (the gun points -Z, the grip near its origin): where the
## support hand's palm is, how it is turned (a named grip), how far the magazine has
## moved, how the gun itself is tipped, and what the hand carries.
##
##   var plan := ReloadPlan.for_gun(gun, seconds, empty)
##   var s := plan.sample(t, rest)   # t 0..1 through the reload; rest: the hand's home
##   s.at, s.grip_a, s.grip_b, s.grip_k, s.mag, s.tilt, s.prop, s.right, s.hum
##
## Templates (`kind`), chosen from the gun's own frame, tags and magazine:
##   mag        a detachable magazine (box, pistol, top, blades): out, a fresh one in, rack if dry
##   coil       a side-loaded coil or pack with no magazine node: the same, the pack in hand
##   stripper   bolt action with a fixed magazine: bolt open, a clip pressed in, bolt home
##   revolver   cylinder out, muzzle up to dump the empties, speedloader in, cylinder shut
##   tube       rounds one at a time up into the loading port; pump / lever / rack if dry
##   break      break open, empties out, a shell per barrel into the breech, snap shut
##   belt       feed cover up, box swapped, belt laid across the tray, cover slapped down
##   cell       energy cell ejected, a fresh one slapped in, the gun hums as it charges
##   hopper     rounds dropped one by one into a hopper on top
##   crossbow   the string drawn back, a bolt laid on the rail
##   muzzle     a harpoon / anchor pushed down the barrel from the front
## and after a shot (`cycle`): bolt, pump or lever, or nothing.

const GRIPS := ["rest", "cup", "pinch", "rack", "slap", "carry"]

var kind := "mag"
var cycle := ""
var rounds := 1
var empty := false
## Keys: {t, at (Vector3 or null = the hand's home), grip, mag, tilt, prop, right, hum}.
## A key leaves out what doesn't change from the key before it.
var keys: Array[Dictionary] = []
## When a magazine, round or cell seats (0..1), for the little knock it gives the gun.
var seats: Array[float] = []
var _slots: Dictionary = {}


## The plan for this gun (a GunModels build), a reload of `seconds`, run dry or not.
static func for_gun(gun: Node3D, seconds: float, dry: bool) -> ReloadPlan:
	var p := ReloadPlan.new()
	p.empty = dry
	p._slots = gun.get_meta("slots", {}) if gun != null else {}
	p.kind = template(gun)
	p.cycle = action(gun)
	p.rounds = clampi(roundi(seconds / 0.42), 2, 6)
	p._build()
	return p


## Which reload template a gun uses.
static func template(gun: Node3D) -> String:
	if gun == null:
		return "mag"
	var frame: String = gun.get_meta("frame", "")
	var tags: Array = Arsenal.FRAMES.get(frame, {}).get("tags", [])
	var style: String = gun.get_meta("mag_style", "box")
	var has_mag := gun.get_node_or_null("Magazine") != null
	if "revolver" in tags:
		return "revolver"
	if "bolt" in tags:
		return "crossbow" if frame == "crossbow" else "muzzle"
	if style == "none":
		return "break"
	if style == "tube":
		return "tube"
	if "bolt_action" in tags and not has_mag:
		return "stripper"
	if style == "belt":
		return "belt"
	if style in ["cell", "tank"]:
		return "cell"
	if style == "hopper":
		return "hopper"
	return "mag" if has_mag else "coil"


## What a gun works between shots: "bolt", "pump", "lever" or "".
static func action(gun: Node3D) -> String:
	if gun == null:
		return ""
	var frame: String = gun.get_meta("frame", "")
	var tags: Array = Arsenal.FRAMES.get(frame, {}).get("tags", [])
	if "bolt_action" in tags:
		return "bolt"
	if "lever" in tags:
		return "lever"
	if frame == "shotgun":
		return "pump"
	return ""


## How long working the action takes after a shot, given the gun's shots a second.
static func cycle_time(rate: float) -> float:
	return clampf(0.75 / maxf(rate, 0.1), 0.25, 0.6)


func _pt(slot: String, fallback: Vector3) -> Vector3:
	return _slots.get(slot, fallback)


func _key(t: float, d: Dictionary) -> void:
	d["t"] = t
	keys.append(d)


func _build() -> void:
	var grip := _pt("grip", Vector3.ZERO)
	var well := _pt("magwell", _pt("magazine", Vector3(0, -0.02, -0.07)))
	var rack := _pt("charging", Vector3(0, 0.1, 0.06)) + Vector3(-0.025, 0.01, 0.0)
	var receiver := _pt("receiver", Vector3(0, 0.08, -0.02))
	var pouch := well + Vector3(-0.08, -0.3, 0.14)
	var cup_under := well + Vector3(-0.012, -0.03, 0.006)
	_key(0.0, {"at": null, "grip": "rest", "mag": Vector3.ZERO, "tilt": Vector3.ZERO, "prop": "", "right": Vector3.ZERO, "hum": 0.0})
	match kind:
		"mag", "coil":
			var carry := "mag" if kind == "coil" else ""
			var tip := Vector3(0, 0, -0.35) if kind == "mag" else Vector3(0, 0, -0.5)
			_key(0.14, {"at": cup_under, "grip": "cup", "tilt": tip})
			_key(0.32, {"at": pouch, "mag": pouch - cup_under, "prop": carry})
			_key(0.4, {"prop": carry})
			_key(0.62, {"at": cup_under, "mag": Vector3.ZERO, "prop": ""})
			seats.append(0.62)
			if empty:
				_key(0.76, {"at": rack, "grip": "rack", "tilt": Vector3(0.1, 0, -0.2)})
				_key(0.82, {"at": rack + Vector3(0, 0.004, 0.06)})
				_key(0.86, {"at": rack})
		"stripper":
			# The right hand works the bolt; the left presses a clip down through the top.
			var bolt := _pt("bolt", receiver) - grip
			var top := receiver + Vector3(-0.02, 0.06, 0.02)
			_key(0.08, {"right": bolt + Vector3(0, 0.03, 0)})
			_key(0.16, {"right": bolt + Vector3(0, 0.03, 0.08), "tilt": Vector3(0, 0, -0.3)})
			_key(0.3, {"at": pouch, "grip": "pinch"})
			_key(0.5, {"at": top, "prop": "clip"})
			_key(0.6, {"at": top + Vector3(0, -0.04, 0), "prop": "clip"})
			seats.append(0.6)
			_key(0.68, {"at": top + Vector3(-0.05, 0.03, 0), "prop": ""})
			_key(0.8, {"right": bolt + Vector3(0, 0.03, 0)})
			_key(0.88, {"right": Vector3.ZERO, "tilt": Vector3.ZERO})
		"revolver":
			# Cylinder out to the left, muzzle up, the empties fall; muzzle down for the
			# speedloader; a flick shuts it.
			var cyl := _pt("magazine", Vector3(0, 0.03, -0.05)) + Vector3(-0.045, 0.0, 0.0)
			_key(0.12, {"at": cyl, "grip": "pinch", "tilt": Vector3(0, 0, 0.7)})
			_key(0.22, {"at": cyl + Vector3(-0.02, 0, 0), "tilt": Vector3(1.0, 0, 0.5)})
			_key(0.3, {"tilt": Vector3(1.1, 0, 0.4)})
			_key(0.46, {"at": pouch, "grip": "carry", "tilt": Vector3(-0.5, 0, 0.6)})
			_key(0.64, {"at": cyl + Vector3(0, 0.0, 0.04), "prop": "loader"})
			_key(0.72, {"at": cyl + Vector3(0, 0.0, 0.015), "prop": "loader"})
			seats.append(0.72)
			_key(0.8, {"at": cyl + Vector3(-0.03, 0, 0.0), "grip": "slap", "prop": ""})
			_key(0.86, {"at": cyl + Vector3(0.01, 0, 0.0), "tilt": Vector3(0, 0, 0)})
		"tube":
			# The gun rolls its port toward the hand; shells come up from the belt one by
			# one and are thumbed in.
			var port := Vector3(0, receiver.y - 0.07, well.z + 0.02)
			var roll := Vector3(0, 0, -0.55)
			_key(0.1, {"at": pouch, "grip": "pinch", "tilt": roll})
			var span := 0.72 / rounds
			for i in rounds:
				var t0 := 0.1 + span * i
				_key(t0 + span * 0.45, {"at": port + Vector3(-0.01, -0.02, 0.01), "prop": "shell"})
				_key(t0 + span * 0.62, {"at": port + Vector3(0, 0.005, -0.03), "prop": "shell"})
				seats.append(t0 + span * 0.62)
				_key(t0 + span, {"at": pouch, "prop": ""})
			if empty:
				var fore := _pt("foregrip", Vector3(0, 0.02, -0.2))
				_key(0.86, {"at": null, "grip": "rest", "tilt": Vector3.ZERO})
				if cycle == "pump":
					_key(0.92, {"at": fore + Vector3(0, -0.01, 0.08)})
					_key(0.97, {"at": null})
				elif cycle == "lever":
					_key(0.92, {"right": Vector3(0, -0.07, 0.04)})
					_key(0.97, {"right": Vector3.ZERO})
				else:
					_key(0.92, {"at": rack, "grip": "rack"})
					_key(0.95, {"at": rack + Vector3(0, 0.004, 0.06)})
		"break":
			# The barrels drop (the gun pitches down), the empties fly, a shell per barrel.
			var breech := Vector3(0, receiver.y + 0.02, receiver.z - 0.03)
			var fore := _pt("foregrip", Vector3(0, 0.02, -0.2))
			_key(0.12, {"at": fore + Vector3(0, -0.04, 0), "tilt": Vector3(-0.4, 0, 0)})
			_key(0.2, {"tilt": Vector3(-0.22, 0, 0)})
			_key(0.26, {"tilt": Vector3(-0.42, 0, 0)})
			var loads := clampi(rounds, 1, 2)
			var span := 0.48 / loads
			for i in loads:
				var t0 := 0.28 + span * i
				_key(t0 + span * 0.35, {"at": pouch, "grip": "pinch", "prop": ""})
				_key(t0 + span * 0.75, {"at": breech + Vector3(0, 0.04, 0), "prop": "shells"})
				_key(t0 + span, {"at": breech, "prop": "shells"})
				seats.append(t0 + span)
			_key(0.84, {"at": fore + Vector3(0, -0.02, 0), "grip": "slap", "prop": ""})
			_key(0.9, {"tilt": Vector3(0.12, 0, 0)})
			seats.append(0.9)
		"belt":
			var cover := Vector3(-0.02, receiver.y + 0.06, receiver.z)
			_key(0.1, {"at": cover, "grip": "rack"})
			_key(0.16, {"at": cover + Vector3(0, 0.07, 0.02), "tilt": Vector3(0, 0, -0.3)})
			_key(0.28, {"at": cup_under, "grip": "cup"})
			_key(0.42, {"at": pouch, "mag": pouch - cup_under, "prop": "box"})
			_key(0.5, {"prop": "box"})
			_key(0.62, {"at": cup_under, "mag": Vector3.ZERO, "prop": ""})
			seats.append(0.62)
			_key(0.72, {"at": cover + Vector3(0.0, 0.02, -0.03), "grip": "pinch", "prop": "belt"})
			_key(0.8, {"at": cover + Vector3(0, 0.07, 0.02), "grip": "slap", "prop": ""})
			_key(0.86, {"at": cover + Vector3(0, 0.005, 0)})
			seats.append(0.86)
			if empty:
				_key(0.92, {"at": rack, "grip": "rack", "tilt": Vector3.ZERO})
				_key(0.95, {"at": rack + Vector3(0, 0.004, 0.06)})
		"cell":
			var side := cup_under + Vector3(-0.02, 0.0, 0.0)
			_key(0.12, {"at": side, "grip": "cup", "tilt": Vector3(0, 0, 0.35)})
			_key(0.2, {"mag": Vector3(-0.03, -0.05, 0.0)})
			_key(0.36, {"at": pouch, "mag": pouch - side, "prop": "cell"})
			_key(0.42, {"prop": "cell"})
			_key(0.58, {"at": side, "mag": Vector3.ZERO, "prop": ""})
			_key(0.64, {"at": side + Vector3(0, -0.03, 0), "grip": "slap"})
			seats.append(0.64)
			_key(0.72, {"at": null, "grip": "rest", "tilt": Vector3.ZERO, "hum": 1.0})
			_key(0.95, {"hum": 1.0})
			_key(1.0, {"hum": 0.0})
		"hopper":
			var hop := _pt("magwell", receiver) + Vector3(0, 0.06, 0)
			var drops := clampi(rounds, 2, 4)
			var span := 0.74 / drops
			_key(0.08, {"tilt": Vector3(-0.15, 0, 0.2)})
			for i in drops:
				var t0 := 0.1 + span * i
				_key(t0 + span * 0.45, {"at": pouch, "grip": "carry", "prop": ""})
				_key(t0 + span * 0.85, {"at": hop + Vector3(0, 0.08, 0), "prop": "round"})
				_key(t0 + span, {"at": hop + Vector3(0, 0.1, 0), "prop": ""})
				seats.append(t0 + span)
		"crossbow":
			var string := _pt("charging", Vector3(0, 0.08, 0.1)) + Vector3(0, 0.02, -0.06)
			var rail := _pt("bolt", Vector3(0, 0.07, -0.1)) + Vector3(-0.02, 0.03, -0.06)
			_key(0.12, {"at": string, "grip": "rack", "tilt": Vector3(0.25, 0, 0)})
			_key(0.32, {"at": string + Vector3(0, 0.01, 0.12)})
			seats.append(0.32)
			_key(0.5, {"at": pouch + Vector3(0, 0.1, 0.1), "grip": "carry", "tilt": Vector3.ZERO})
			_key(0.7, {"at": rail, "prop": "bolt"})
			_key(0.8, {"at": rail + Vector3(0, -0.012, 0.06), "prop": "bolt"})
			seats.append(0.8)
		"muzzle":
			var mouth := Vector3(0, receiver.y, _slots.get("muzzle", Vector3(0, 0, -0.4)).z) + Vector3(-0.03, 0.04, 0)
			_key(0.14, {"tilt": Vector3(0.75, 0, 0.15)})
			_key(0.36, {"at": pouch + Vector3(0, 0.1, 0.1), "grip": "carry"})
			_key(0.58, {"at": mouth + Vector3(0, 0.12, -0.08), "prop": "harpoon"})
			_key(0.74, {"at": mouth + Vector3(0, 0.02, 0.02), "prop": "harpoon"})
			seats.append(0.74)
			_key(0.84, {"at": mouth + Vector3(0, 0.03, 0.0), "grip": "slap", "prop": ""})
	_key(1.0, {"at": null, "grip": "rest", "mag": Vector3.ZERO, "tilt": Vector3.ZERO, "prop": "", "right": Vector3.ZERO, "hum": 0.0})
	# Fill what each key left out from the key before it.
	for i in range(1, keys.size()):
		for f in ["at", "grip", "mag", "tilt", "prop", "right", "hum"]:
			if not keys[i].has(f):
				keys[i][f] = keys[i - 1][f]
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))


## The reload at progress `t` (0..1). `rest` is where the hand sits on the gun when not
## reloading (gun space), what the keys' home means.
func sample(t: float, rest: Vector3) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	var i := 0
	while i < keys.size() - 2 and float(keys[i + 1].t) <= t:
		i += 1
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[i + 1]
	var span := maxf(float(b.t) - float(a.t), 0.0001)
	var k := smoothstep(0.0, 1.0, (t - float(a.t)) / span)
	var pa: Vector3 = rest if a.at == null else a.at
	var pb: Vector3 = rest if b.at == null else b.at
	return {
		"at": pa.lerp(pb, k), "grip_a": a.grip, "grip_b": b.grip, "grip_k": k,
		"mag": (a.mag as Vector3).lerp(b.mag, k), "tilt": (a.tilt as Vector3).lerp(b.tilt, k),
		"prop": a.prop if k < 0.5 or a.prop == b.prop else b.prop,
		"right": (a.right as Vector3).lerp(b.right, k), "hum": lerpf(a.hum, b.hum, k),
	}


## How many seats fall between progress t0 and t1 (the gun knocks once for each).
func seats_between(t0: float, t1: float) -> int:
	var n := 0
	for s in seats:
		if s > t0 and s <= t1:
			n += 1
	return n


## Working the action after a shot, at `t` 0..1: offsets (gun space) for the right hand
## and the support hand, and a tilt of the gun.
static func cycle_pose(kind: String, t: float, slots: Dictionary) -> Dictionary:
	var right := Vector3.ZERO
	var support := Vector3.ZERO
	var tilt := Vector3.ZERO
	var e := sin(clampf(t, 0.0, 1.0) * PI)
	match kind:
		"bolt":
			# Up, back, forward, down: the right hand leaves the grip for the bolt handle.
			var bolt: Vector3 = slots.get("bolt", Vector3(0.04, 0.07, 0.03)) - slots.get("grip", Vector3.ZERO)
			var reach := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.75, 1.0, t))
			var pull := smoothstep(0.25, 0.45, t) * (1.0 - smoothstep(0.55, 0.75, t))
			right = (bolt + Vector3(0.01, 0.03 * pull, 0.08 * pull)) * reach
			tilt = Vector3(0.05, 0, -0.12) * reach
		"pump":
			support = Vector3(0, -0.005, 0.08) * e
			tilt = Vector3(0.04, 0, 0) * e
		"lever":
			right = Vector3(0, -0.07, 0.035) * e
			tilt = Vector3(0.06, 0, 0) * e
	return {"right": right, "support": support, "tilt": tilt}


## A small mesh for what the support hand carries ("mag", "shell", "shells", "loader",
## "clip", "box", "belt", "cell", "round", "bolt", "harpoon").
static func prop_mesh(what: String) -> Mesh:
	match what:
		"shell":
			return GunKit.rod(0.0095, 0.065, 8)
		"shells":
			return LowPoly.chamfer_box(Vector3(0.042, 0.022, 0.065), 0.006)
		"loader":
			return GunKit.rod(0.022, 0.03, 10)
		"clip":
			return LowPoly.chamfer_box(Vector3(0.012, 0.045, 0.055), 0.003)
		"round":
			return LowPoly.chamfer_box(Vector3(0.05, 0.05, 0.06), 0.012)
		"bolt", "harpoon":
			return GunKit.rod(0.008 if what == "bolt" else 0.012, 0.32 if what == "bolt" else 0.42, 8)
		"belt":
			return LowPoly.chamfer_box(Vector3(0.05, 0.012, 0.09), 0.003)
		"cell":
			return LowPoly.chamfer_box(Vector3(0.04, 0.05, 0.07), 0.006)
		"box":
			return LowPoly.chamfer_box(Vector3(0.07, 0.09, 0.11), 0.008)
	return LowPoly.chamfer_box(Vector3(0.03, 0.1, 0.05), 0.005)
