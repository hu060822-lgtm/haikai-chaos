class_name TestamentDetail
## 最後的遺訓's Phase 5 (C10): light, sound, the words on the walls and the six easter eggs.
## All of it is static scenery built once with the map: nothing here syncs over the net,
## gives anyone an edge or changes a rule. Every egg that you could touch has a collider
## the size of what you see.
##
## Words are carved or stencilled (Label3D, alpha-cut so there's no transparency sorting),
## never floating UI.

const CARVE := Color("#3A3936")       # letters cut into stone
const STENCIL := Color("#D9D2C0")     # military stencil paint
const NOTICE := Color("#C2352B")      # the institution's red
const PLATE := Color("#2A2C2E")       # notice plates


static func build(map: LastTestament) -> void:
	var root := TestamentArt.group(map, "EasterEggs")
	_lights(map)
	_hum(map)
	_area_signs(map)
	_slogans(map)
	_altar_words(map)
	_lost_wall(map, root)
	_weapon_list(map, root)
	_checkpoint(map, root)
	_thirteenth_seat(map, root)
	_perfect_build(map, root)
	_wrong_icon(map, root)


# --- Helpers -------------------------------------------------------------------------------

## Text on a surface: `yaw` turns it to face its reader (0 = readable from +z), `height` is
## the letters' height in metres.
static func words(parent: Node3D, text: String, pos: Vector3, yaw: float, height: float, color: Color,
		lit := true, pitch := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FpUi.body()
	l.font_size = 64
	l.pixel_size = height / 64.0
	l.outline_size = 0
	l.modulate = color
	l.shaded = lit
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.position = pos
	l.rotation_degrees = Vector3(pitch, yaw, 0)
	parent.add_child(l)
	return l


## Whether the wall behind a sign at `pos`, facing `yaw`, is solid rock for `half` metres
## each side (so a sign never hangs in a doorway, a window or a breach).
static func solid_behind(map: LastTestament, pos: Vector3, yaw: float, half: float) -> bool:
	var back := Vector3(-sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw)))
	var side := Vector3(back.z, 0, -back.x)
	for k in [-1.0, 0.0, 1.0]:
		if map.layout.kind_at(pos + back * 1.0 + side * half * k) != "#":
			return false
	return true


## An invisible collider round a piece of art.
static func collider(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Geo.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	parent.add_child(body)
	body.position = pos
	return body


# --- Light ----------------------------------------------------------------------------------

## The stained glass's colour on the stone (red and amber under the Saint, blue and purple
## in the aisles), amber lamps in the crypt, red tell-tales at the organ. No shadows, few
## lights: GL Compatibility.
static func _lights(map: LastTestament) -> void:
	Faultprint.zone_light(map, Vector3(68, 10.0, 0), TestamentArt.GLASS_RED.lightened(0.3), 16.0, 0.7)
	Faultprint.zone_light(map, Vector3(64, 4.0, 0), TestamentArt.GLASS_AMBER, 10.0, 0.5)
	for s in [1.0, -1.0]:
		Faultprint.zone_light(map, Vector3(-14, 10.0, 17.5 * s), TestamentArt.GLASS_PURPLE.lightened(0.35), 12.0, 0.55)
		Faultprint.zone_light(map, Vector3(14, 10.0, 17.5 * s), TestamentArt.GLASS_BLUE.lightened(0.4), 12.0, 0.55)
		Faultprint.zone_light(map, Vector3(-62, LastTestament.CRYPT_Y + 3.0, 13.0 * s), TestamentArt.AMBER, 10.0, 0.7)
	Faultprint.zone_light(map, Vector3(-71, 9.0, 0), TestamentArt.WARN_RED, 8.0, 0.4)


# --- Sound ----------------------------------------------------------------------------------

## The organ's hum: a very low mechanical drone, everywhere and nowhere near the organ, quieter
## in the crypt. All of it under 100 Hz and well under a footstep, so it never hides one.
static func _hum(map: LastTestament) -> void:
	var stream := drone()
	for spec in [[Vector3(-62, 8.0, 0), -24.0, "OrganHum"], [Vector3(-63, LastTestament.CRYPT_Y + 2.0, 0), -28.0, "OrganHumCrypt"]]:
		var p := AudioStreamPlayer3D.new()
		p.name = spec[2]
		p.stream = stream
		p.volume_db = spec[1]
		p.unit_size = 14.0         # a big, vague source: hard to place
		p.max_distance = 60.0
		p.bus = "SFX"
		p.autoplay = true
		map.add_child(p)
		p.position = spec[0]


## Four seconds of drone that loops: two low organ notes a fifth apart, a slow beat
## between them, a little rumble.
static func drone() -> AudioStreamWAV:
	var rate := Sfx.RATE
	var n := rate * 4
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1013
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		# Whole cycles in 4 s for every partial, so the loop is seamless.
		var v := sin(TAU * 41.0 * t) * 0.5 + sin(TAU * 61.5 * t) * 0.3 + sin(TAU * 82.0 * t) * 0.12
		v *= 0.75 + 0.25 * sin(TAU * 0.5 * t)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.01)
		v += lp * 0.6
		data.encode_s16(i * 2, int(clampf(v * 0.6, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


# --- Signs and words ------------------------------------------------------------------------

## Stencilled area names where the routes split: which way to the confessionals, the crypt,
## the altar, the organ room and up to the gallery.
static func _area_signs(map: LastTestament) -> void:
	var root := TestamentArt.group(map, "Signs")
	var specs := []
	for s in [1.0, -1.0]:
		var face := 180.0 if s > 0 else 0.0       # on the aisle's outer wall, facing the nave
		for x in [-22.0, 22.0]:
			specs.append(["告解室 CONFESSIONALS", Vector3(x, 3.4, 19.98 * s), face, 0.42, 1.4])
		specs.append(["上層迴廊 GALLERY ↑", Vector3(36.0, 3.9, 19.98 * s), face, 0.42, 1.5])
		# Beside the chancel arch, between it and the side passage.
		specs.append(["主祭壇\nALTAR  A", Vector3(39.98, 3.6, 7.0 * s), -90.0, 0.4, 0.8])
		specs.append(["管風琴 ORGAN", Vector3(-47.98, 3.2, 12.0 * s), 90.0, 0.42, 1.5])
		specs.append(["地下墓室 CRYPT  B ↓", Vector3(-58.02, 2.6, 33.0 * s), -90.0, 0.42, 1.5])
	for spec in specs:
		var pos: Vector3 = spec[1]
		if not solid_behind(map, pos, spec[2], spec[4]):
			push_warning("testament: no wall for the sign %s" % spec[0])
			continue
		words(root, spec[0], pos, spec[2], spec[3], STENCIL)


## The institution's notices in the confessional corridors: red plates, stencilled.
static func _slogans(map: LastTestament) -> void:
	var root := TestamentArt.group(map, "Signs")
	var b := TestamentArt.Batch.new()
	for s in [1.0, -1.0]:
		var specs := [["CONFESS YOUR BUILD.", Vector3(-8.0, 2.4, 22.0 * s), 0.0 if s > 0 else 180.0],
			["NO ATTACHMENT IS INNOCENT.", Vector3(-16.0, 2.4, 32.0 * s), 180.0 if s > 0 else 0.0],
			["YOUR RECOIL HAS BEEN NOTED.", Vector3(16.0, 2.4, 32.0 * s), 180.0 if s > 0 else 0.0]]
		for spec in specs:
			var pos: Vector3 = spec[1]
			var yaw: float = spec[2]
			if not solid_behind(map, pos, yaw, 3.0):
				continue
			var out := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
			b.box(Vector3(6.4, 0.7, 0.04), pos + out * 0.02, "paint", NOTICE, Vector3(0, yaw, 0), 0.01)
			words(root, spec[0], pos + out * 0.05, yaw, 0.3, STENCIL)
	b.flush(root)


## "THE SAINT OF RECOIL" cut under the east window, and the broken tablet's two faces.
static func _altar_words(map: LastTestament) -> void:
	var root := TestamentArt.group(map, "Altar")
	words(root, "THE SAINT OF RECOIL", Vector3(73.97, 6.15, 0), -90.0, 0.34, CARVE)
	words(root, "BLESSED ARE\nTHE FLEXIBLE.", Vector3(72.18, 3.1, 0), -90.0, 0.42, CARVE)
	words(root, "FOR THEY SHALL NOT\nBE PREDICTABLE.", Vector3(72.82, 2.6, 0), 90.0, 0.36, CARVE)


# --- The eggs ---------------------------------------------------------------------------------

## A: the lost wall. Tiny chevrons and scuffs along the west lane's wall mark a wall run, a
## kick and a drop; where it ends, low in the corner: KEEP YOUR MOMENTUM.
static func _lost_wall(map: LastTestament, root: Node3D) -> void:
	var b := TestamentArt.Batch.new()
	var z := 38.0
	for x in range(-20, -55, -3):
		var at := Vector3(x, 1.75, z + 0.01)
		if map.layout.kind_at(Vector3(x, 0, z - 1.0)) != "#":
			continue
		words(root, "‹", at, 0.0, 0.18, STENCIL)   # pointing west, the way to run
		b.box(Vector3(0.34, 0.05, 0.01), Vector3(x + 1.2, 1.25 + 0.1 * sin(x), z + 0.005), "paint", TestamentArt.STONE_DEEP, Vector3.ZERO, 0.0, Color.BLACK, false)
	# The kick mark (a boot print's toe bar) and the drop chevron at the end of the run.
	b.box(Vector3(0.24, 0.1, 0.01), Vector3(-53.5, 2.3, z + 0.005), "paint", TestamentArt.STONE_DEEP, Vector3.ZERO, 0.0, Color.BLACK, false)
	words(root, "↓", Vector3(-55.5, 1.9, z + 0.01), 0.0, 0.18, STENCIL)
	words(root, "KEEP YOUR MOMENTUM.", Vector3(-56.4, 0.22, z + 0.01), 0.0, 0.09, CARVE)
	b.flush(root)


## B: the impossible weapon list. A requisition form on the counter of one confessional (the
## old grille's booth), for a gun nobody could hold, stamped APPROVED BY NO ONE. A counter
## in the twin booth too, so both sides play the same.
static func _weapon_list(map: LastTestament, root: Node3D) -> void:
	var b := TestamentArt.Batch.new()
	for s in [1.0, -1.0]:
		var at := Vector3(-0.225, 0.5, 27.4 * s)
		collider(root, Vector3(0.45, 1.0, 1.2), at)
		b.box(Vector3(0.45, 0.06, 1.2), at + Vector3(0, 0.47, 0), "polymer", TestamentArt.WOOD_LIGHT, Vector3.ZERO, 0.01)
		b.box(Vector3(0.4, 0.94, 1.12), at + Vector3(0.02, -0.03, 0), "polymer", TestamentArt.WOOD, Vector3.ZERO, 0.02)
	var paper := Vector3(-0.23, 1.005, 27.4)
	b.box(Vector3(0.3, 0.004, 0.42), paper, "polymer", Color("#D8D2C2"), Vector3(0, 8, 0), 0.0, Color.BLACK, false)
	b.flush(root)
	var form := "REQUISITION 77-B\nBARREL: 3 LMG BARRELS, END TO END\nGRIP: BEHIND THE STOCK\nSTOCK: ON THE MUZZLE\nOPTIC: FACING THE SHOOTER\nMAGAZINES: SIX, IN A RING\nWEIGHT: YES"
	var l := words(root, form, paper + Vector3(0, 0.004, 0.02), 90.0 + 8.0, 0.016, Color("#2B2B2B"), true, -90.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words(root, "APPROVED BY NO ONE.", paper + Vector3(0.09, 0.005, -0.03), 98.0, 0.03, NOTICE, true, -90.0)


## C: the last checkpoint. An old training timer bolted in the gallery's quiet west corner,
## frozen, with TIME IS A SUGGESTION scratched under it. Decoration only.
static func _checkpoint(map: LastTestament, root: Node3D) -> void:
	var b := TestamentArt.Batch.new()
	var at := Vector3(-47.92, LastTestament.GALLERY_Y + 1.5, 19.2)
	b.box(Vector3(0.14, 0.32, 0.7), at, "paint", TestamentArt.IRON, Vector3.ZERO, 0.02)
	b.box(Vector3(0.02, 0.16, 0.56), at + Vector3(0.075, 0.03, 0), "paint", Color("#1A1010"))
	b.box(Vector3(0.05, 0.05, 0.05), at + Vector3(0.07, -0.11, 0.28), "polymer", TestamentArt.WARN_RED, Vector3.ZERO, 0.01, TestamentArt.WARN_RED)
	b.flush(root)
	collider(root, Vector3(0.14, 0.32, 0.7), at)
	words(root, "00:00.00", at + Vector3(0.087, 0.03, 0), 90.0, 0.12, Color("#FF5A3C"), false)
	words(root, "TIME IS A SUGGESTION.", Vector3(-47.99, LastTestament.GALLERY_Y + 1.12, 19.2), 90.0, 0.07, CARVE)


## D: the thirteenth seat. The south choir row's last seat faces the wall; its back reads
## PLAYER NOT FOUND, and under it sits a tiny grey low-poly figure. It doesn't move.
static func _thirteenth_seat(map: LastTestament, root: Node3D) -> void:
	var b := TestamentArt.Batch.new()
	var w := TestamentArt.STALL_W
	var at := Vector3(TestamentArt.STALL_X0 + 12.5 * w, LastTestament.GALLERY_Y, 19.35)
	# Turned round: the high back on the nave side, the seat facing the wall.
	b.box(Vector3(w - 0.04, 1.1, 0.12), at + Vector3(0, 1.05, -0.3), "polymer", TestamentArt.WOOD_LIGHT)
	b.box(Vector3(w - 0.1, 0.06, 0.9), at + Vector3(0, 0.53, 0.1), "polymer", TestamentArt.WOOD_LIGHT)
	for e in [-0.5, 0.5]:
		b.box(Vector3(0.08, 1.6, 0.96), at + Vector3(e * (w - 0.08), 0.8, 0.12), "polymer", TestamentArt.WOOD)
	# The figure: block legs, a box body, T-posed arms, a cube head. 22 cm.
	var f := at + Vector3(0, 0, 0.1)
	var grey := Color("#8C8C88")
	b.box(Vector3(0.025, 0.08, 0.025), f + Vector3(-0.02, 0.04, 0), "polymer", grey, Vector3.ZERO, 0.0)
	b.box(Vector3(0.025, 0.08, 0.025), f + Vector3(0.02, 0.04, 0), "polymer", grey, Vector3.ZERO, 0.0)
	b.box(Vector3(0.07, 0.08, 0.035), f + Vector3(0, 0.12, 0), "polymer", grey, Vector3.ZERO, 0.0)
	b.box(Vector3(0.17, 0.02, 0.02), f + Vector3(0, 0.15, 0), "polymer", grey, Vector3.ZERO, 0.0)
	b.box(Vector3(0.045, 0.045, 0.045), f + Vector3(0, 0.19, 0), "polymer", grey, Vector3.ZERO, 0.0)
	b.flush(root)
	words(root, "PLAYER NOT FOUND.", at + Vector3(0, 1.2, -0.37), 180.0, 0.09, CARVE)


## E: the nameless one's sarcophagus. One of the crypt's tombs has its lid broken in half:
## inside, no body, only a blank build sheet. HERE LIES THE PERFECT BUILD on its side.
static func _perfect_build(map: LastTestament, root: Node3D) -> void:
	var tomb: StaticBody3D = null
	for n in map.get_children():
		if n is StaticBody3D and str(n.get_meta("art", "")) == "tomb" and absf(n.position.x + 70.0) < 0.1 and n.position.z > 0.0:
			tomb = n
	if tomb == null:
		return
	TestamentArt.hide_mesh(tomb)
	var size := ((tomb.get_child(1) as CollisionShape3D).shape as BoxShape3D).size
	var c := tomb.position
	var floor_y := c.y - size.y / 2.0
	var top := c.y + size.y / 2.0
	var b := TestamentArt.Batch.new()
	var stone := TestamentArt.STONE
	var t := 0.12
	# The walls and a raised floor inside.
	b.box(Vector3(size.x, top - 0.12 - floor_y, t), Vector3(c.x, (floor_y + top - 0.12) / 2.0, c.z - size.z / 2.0 + t / 2.0), "concrete", stone)
	b.box(Vector3(size.x, top - 0.12 - floor_y, t), Vector3(c.x, (floor_y + top - 0.12) / 2.0, c.z + size.z / 2.0 - t / 2.0), "concrete", stone)
	for e in [-1.0, 1.0]:
		b.box(Vector3(t, top - 0.12 - floor_y, size.z - 2 * t), Vector3(c.x + e * (size.x / 2.0 - t / 2.0), (floor_y + top - 0.12) / 2.0, c.z), "concrete", stone)
	b.box(Vector3(size.x - 2 * t, top - 0.38 - floor_y, size.z - 2 * t), Vector3(c.x, (floor_y + top - 0.38) / 2.0, c.z), "concrete", TestamentArt.STONE_DEEP)
	# Half a lid over the east end, its broken half inside.
	b.box(Vector3(size.x / 2.0, 0.12, size.z), Vector3(c.x + size.x / 4.0, top - 0.06, c.z), "concrete", TestamentArt.STONE_LIGHT)
	b.box(Vector3(size.x / 2.6, 0.1, size.z - 0.3), Vector3(c.x - size.x * 0.05, top - 0.3, c.z + 0.05), "concrete", TestamentArt.STONE_LIGHT, Vector3(0, 6, 9))
	# The sheet, on the floor of the open end.
	var sheet := Vector3(c.x - size.x * 0.33, top - 0.375, c.z - 0.1)
	b.box(Vector3(0.3, 0.004, 0.42), sheet, "polymer", Color("#D8D2C2"), Vector3(0, -12, 0), 0.0, Color.BLACK, false)
	b.flush(root)
	var l := words(root, "BUILD SHEET\nFRAME ________\nBARREL ________\nOPTIC ________\nSTOCK ________\nAMMO ________",
		sheet + Vector3(0, 0.004, 0), 90.0 - 12.0, 0.022, Color("#2B2B2B"), true, -90.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words(root, "HERE LIES THE PERFECT BUILD.", Vector3(c.x, floor_y + 0.45, c.z - size.z / 2.0 - 0.01), 180.0, 0.11, CARVE)


## F: the wrong icon. A solemn robed saint on a corbel on the arcade, holding up what looks
## like a cross from the nave; from the side it's a curved magazine (HAIKAI: CHAOS's own:
## a ribbed body with an amber round-count slot). Both arcades have one.
static func _wrong_icon(map: LastTestament, root: Node3D) -> void:
	var b := TestamentArt.Batch.new()
	for s in [1.0, -1.0]:
		# On the pier at x 1, on its nave face, facing the middle of the nave.
		# A third larger than life, so it reads from the floor 8 m below.
		var xf := Transform3D(Basis(Vector3.UP, PI if s > 0 else 0.0).scaled(Vector3.ONE * 1.3), Vector3(1.0, 8.2, 11.59 * s))
		_icon(b, xf)
		collider(root, Vector3(1.45, 4.2, 1.39), Vector3(1.0, 9.51, 11.5 * s))
	b.flush(root)


## The statue in its own space: standing at the origin on a corbel, facing +z.
static func _icon(b: TestamentArt.Batch, xf: Transform3D) -> void:
	var stone := TestamentArt.STONE_LIGHT
	var at := func(p: Vector3, rot: Vector3) -> Transform3D: return xf * LowPoly.at(p, rot)
	var zero := Vector3.ZERO
	# The corbel: stepped blocks out of the pier.
	b.add(LowPoly.chamfer_box(Vector3(1.1, 0.25, 0.9), 0.04), at.call(Vector3(0, -0.125, -0.02), zero), "concrete", stone)
	b.add(LowPoly.chamfer_box(Vector3(0.8, 0.35, 0.6), 0.04), at.call(Vector3(0, -0.42, -0.17), zero), "concrete", TestamentArt.STONE)
	# Robe, mantle, hood and the face in its shadow.
	b.add(LowPoly.prism(8, 0.42, 0.26, 1.8), at.call(Vector3(0, 0.9, 0), Vector3(0, 22.5, 0)), "concrete", stone)
	b.add(LowPoly.prism(8, 0.34, 0.2, 0.55), at.call(Vector3(0, 1.98, 0), Vector3(0, 22.5, 0)), "concrete", stone)
	b.add(LowPoly.prism(6, 0.19, 0.12, 0.4), at.call(Vector3(0, 2.42, -0.02), zero), "concrete", stone)
	b.add(LowPoly.chamfer_box(Vector3(0.16, 0.2, 0.06), 0.02), at.call(Vector3(0, 2.36, 0.12), zero), "concrete", TestamentArt.STONE_DARK)
	# Forearms raised to the chest, hands together at the front.
	for e in [-1.0, 1.0]:
		b.add(LowPoly.chamfer_box(Vector3(0.13, 0.13, 0.5), 0.03), at.call(Vector3(e * 0.16, 1.75, 0.26), Vector3(-20, -e * 14, 0)), "concrete", stone)
	b.add(LowPoly.chamfer_box(Vector3(0.3, 0.12, 0.12), 0.03), at.call(Vector3(0, 1.84, 0.48), zero), "concrete", stone)
	# The magazine: thin face-on (with the hands across it, a cross), a banana from the side.
	var mag := TestamentArt.IRON
	for k in 6:
		var y := 1.48 + k * 0.13
		var z := 0.5 - 0.012 * (k - 2) * (k - 2)
		b.add(LowPoly.chamfer_box(Vector3(0.07, 0.135, 0.24), 0.01), at.call(Vector3(0, y, z), Vector3(-6.0 * (k - 2), 0, 0)), "polymer", mag)
		b.add(LowPoly.chamfer_box(Vector3(0.075, 0.02, 0.2), 0.0), at.call(Vector3(0, y + 0.05, z), Vector3(-6.0 * (k - 2), 0, 0)), "paint", TestamentArt.STONE_DEEP)
	b.add(LowPoly.chamfer_box(Vector3(0.076, 0.4, 0.03), 0.0), at.call(Vector3(0, 1.75, 0.47), Vector3(8, 0, 0)), "polymer", TestamentArt.AMBER, TestamentArt.AMBER * 0.4)
	b.add(LowPoly.chamfer_box(Vector3(0.08, 0.06, 0.28), 0.01), at.call(Vector3(0, 1.42, 0.52), Vector3(12, 0, 0)), "polymer", mag)
	b.add(LowPoly.prism(6, 0.025, 0.02, 0.1), at.call(Vector3(0, 2.25, 0.36), Vector3(-70, 0, 0)), "bare", TestamentArt.BRASS)
