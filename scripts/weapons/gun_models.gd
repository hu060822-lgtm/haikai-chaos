class_name GunModels
## Low-poly FAULTPRINT models of Arsenal builds: every frame is its own cobbled-together
## scavenger contraption, and every part bolts on where it belongs on the slot tree:
## a quick-detach can over the flash hider, a handguard that brings its own rails, lights
## and lasers on the side rails, a grip or bipod under the handguard, an offset dot at 45°,
## the sight on top, the magazine in its well, the stock and its butt pad at the back. Ammo
## tints the rounds you can see, internal parts (triggers, bolts, gas) show as small cues,
## gadgets dangle as charms, and organs are grown on.
##
##   var model := GunModels.build(build)   # Node3D, points -Z, grip at the origin
##   model.get_node("Muzzle")             # Marker3D at the end of the barrel (moves with the gun)
##   GunModels.muzzle_point(build)        # the same point as a Vector3 in model space
##   model.get_meta("slots")              # {slot: Vector3} where each slot's part sits (every Arsenal slot)
##
## Sizes are real-ish metres (roughly the frame's "length" stat): pistols ~0.2-0.3 m, long
## guns 0.7-1.1 m, the anti-materiel rifle ~1.4 m. Textures are projected in each mesh's own
## space (not world space), so they don't swim on a held gun. A part id with no model of
## its own gets a small taped-on lump at its slot, so nothing a save names can crash this.

# Palette (tints over the shared 64px textures).
const STEEL := Faultprint.CONCRETE
const DARK := Faultprint.GRAPHITE
const BLACK := Faultprint.CARBON
const WOOD := Faultprint.KRAFT
const RUST := Faultprint.OXIDE
const TAPE := Faultprint.DUST
const ORANGE := Faultprint.ORANGE
const YELLOW := Faultprint.YELLOW
const RED := Color("#D2452F")
const OLIVE := Color("#7C8460")
const PINK := Color("#E07A8F")
const TEAL := Faultprint.TEAL
const BONE := Faultprint.BONE
const COPPER := Color("#D9763F")
const ZAP := Faultprint.TEAL
const FIRE := Faultprint.ORANGE
const POLY := Color("#2A2B2E")
const TAN := Color("#CDB48A")
const OD := Color("#6F7656")
const PLUM := Color("#8A4B4B")
const BAKELITE := Color("#C9663A")
const NICKEL := Color("#D8D4CB")
const SMOKE := Faultprint.SLATE
const BLUE := Color("#3D6FB0")
const GLASS := Color("#2F4A52")

## Colour of the rounds each ammo part shows, and whether they glow.
const AMMO_LOOK := {
	"fmj": [Color(1.3, 0.75, 0.45), Color.BLACK],
	"hollow_point": [Color(1.2, 0.62, 0.38), Color.BLACK],
	"ap_rounds": [Color(0.25, 0.32, 0.22), Color(0.1, 0.35, 0.05)],
	"subsonic": [Color(0.35, 0.3, 0.55), Color(0.04, 0.02, 0.1)],
	"plus_p": [Color(1.25, 0.4, 0.3), Color(0.25, 0.04, 0.0)],
	"tracer": [Color(1.3, 0.35, 0.2), Color(1.0, 0.25, 0.05)],
	"match_ammo": [Color(1.45, 1.35, 0.9), Color(0.08, 0.07, 0.0)],
	"incendiary": [Color(1.2, 0.3, 0.1), Color(0.75, 0.22, 0.0)],
	"api_rounds": [Color(0.9, 0.95, 1.05), Color(0.5, 0.08, 0.0)],
	"shock_rounds": [Color(0.4, 0.9, 1.1), Color(0.1, 0.45, 0.7)],
	"handload": [Color(0.85, 0.7, 0.45), Color.BLACK],
	"buckshot_mag": [Color(0.35, 0.9, 0.35), Color(0.0, 0.12, 0.0)],
	"slug": [Color(0.6, 0.62, 0.66), Color.BLACK],
	"birdshot": [Color(1.4, 1.25, 0.25), Color(0.1, 0.08, 0.0)],
	"flechette": [Color(1.2, 1.25, 1.35), Color(0.1, 0.12, 0.16)],
	"dragon_breath": [Color(1.4, 0.55, 0.1), Color(1.0, 0.35, 0.0)],
	"rock_salt": [Color(1.4, 1.4, 1.35), Color(0.12, 0.12, 0.12)],
	"beanbag": [Color(1.1, 0.95, 0.65), Color.BLACK],
	"explosive_bolt": [Color(1.3, 0.15, 0.1), Color(0.5, 0.05, 0.0)],
	"net_bolt": [Color(0.5, 1.2, 0.35), Color(0.05, 0.2, 0.0)],
	"broadhead": [Color(1.3, 1.3, 1.35), Color(0.3, 0.0, 0.0)],
	"rusty_nails": [Color(1.0, 0.5, 0.3), Color.BLACK],
	"ricochet_rounds": [Color(0.78, 0.8, 0.8), Color.BLACK],
	"magnet_rounds": [Color(0.55, 0.22, 0.17), Color.BLACK],
	"concussion_rounds": [Color(0.47, 0.49, 0.47), Color.BLACK],
	"vampire_rounds": [Color(0.56, 0.23, 0.17), Color(0.15, 0.0, 0.0)],
	"sky_rounds": [Color(0.91, 0.89, 0.85), Color.BLACK],
	"momentum_rounds": [Color(0.85, 0.78, 0.36), Color.BLACK],
	"cluster_rockets": [Color(0.65, 0.33, 0.22), Color(0.2, 0.06, 0.0)],
	"volatile_rounds": [Color(0.75, 0.3, 0.18), Color(0.45, 0.12, 0.0)],
	"adrenaline_rounds": [Color(0.9, 0.85, 0.35), Color(0.15, 0.12, 0.0)],
	"smart_rounds": [Color(0.4, 0.5, 0.55), Color(0.05, 0.2, 0.3)],
	"galvanized_nails": [Color(1.2, 1.22, 1.25), Color.BLACK],
	"napalm_gel": [Color(1.1, 0.45, 0.1), Color(0.6, 0.2, 0.0)],
	"high_octane": [Color(1.3, 0.9, 0.2), Color(0.5, 0.3, 0.0)],
	"overcharged_cell": [Color(1.2, 0.3, 0.9), Color(0.6, 0.1, 0.5)],
	"stable_cell": [Color(0.4, 1.0, 0.6), Color(0.05, 0.35, 0.15)],
	"big_duck": [Color(1.4, 1.2, 0.2), Color(0.2, 0.15, 0.0)],
	"diamond_saw": [Color(0.85, 1.2, 1.35), Color(0.15, 0.3, 0.4)],
	"sticky_soap": [Color(0.9, 0.6, 1.2), Color(0.2, 0.1, 0.3)],
	"co2_cartridge": [Color(0.5, 0.55, 0.6), Color.BLACK],
}


## A finished model of `build` (any Arsenal build; it is cleaned first).
static func build(build: Dictionary) -> Node3D:
	return _assemble(Arsenal.clean(build))


## Builds the model of an already-cleaned build. Ids it has no model for (and frames it
## doesn't know) still give a gun: tests feed it raw builds to prove that.
static func _assemble(build: Dictionary) -> Node3D:
	var r := Rig.new()
	r.root = Node3D.new()
	r.root.name = "Gun_" + str(build.get("frame", ""))
	r.frame = str(build.get("frame", "revolver"))
	r.parts = build.get("parts", {})
	r.tune = build.get("tune", {})
	match r.frame:
		"revolver": GunFrames.revolver(r)
		"service_pistol": GunFrames.service_pistol(r)
		"heavy_pistol": GunFrames.heavy_pistol(r)
		"machine_pistol": GunFrames.machine_pistol(r)
		"smg": GunFrames.smg(r)
		"pdw": GunFrames.pdw(r)
		"carbine": GunFrames.carbine(r)
		"ak": GunFrames.ak(r)
		"bullpup": GunFrames.bullpup(r)
		"battle_rifle": GunFrames.battle_rifle(r)
		"dmr": GunFrames.dmr(r)
		"rifle": GunFrames.rifle(r)
		"lever_action": GunFrames.lever_action(r)
		"lmg": GunFrames.lmg(r)
		"anti_materiel": GunFrames.anti_materiel(r)
		"shotgun": GunFrames.shotgun(r)
		"double_barrel": GunFrames.double_barrel(r)
		"auto_shotgun": GunFrames.auto_shotgun(r)
		"sawed_off": GunFrames.sawed_off(r)
		"nail_gun": GunFrames.nail_gun(r)
		"crossbow": GunFrames.crossbow(r)
		"flamethrower": GunFrames.flamethrower(r)
		"tesla": GunFrames.tesla(r)
		"harpoon": GunFrames.harpoon(r)
		"railgun": GunFrames.railgun(r)
		"duck_launcher": GunFrames.duck_launcher(r)
		"saw_launcher": GunFrames.saw_launcher(r)
		"bubble_gun": GunFrames.bubble_gun(r)
		"jump_shotgun": GunFrames.jump_shotgun(r)
		"gyrojet": GunFrames.gyrojet(r)
		"minigun": GunFrames.minigun(r)
		"quad_barrel": GunFrames.quad_barrel(r)
		"punt_gun": GunFrames.punt_gun(r)
		"pneumatic_lance": GunFrames.pneumatic_lance(r)
		"ricochet_smg": GunFrames.ricochet_smg(r)
		"glass_revolver": GunFrames.glass_revolver(r)
		"tuning_fork": GunFrames.tuning_fork(r)
		"anchor_gun": GunFrames.anchor_gun(r)
		"vector_smg": GunFrames.vector_smg(r)
		"scout_rifle": GunFrames.scout_rifle(r)
		"silent_rifle": GunFrames.silent_rifle(r)
		_: GunFrames.revolver(r)
	_settle_anchors(r)
	var bare_muzzle := r.muzzle
	r.barrel_end = r.muzzle
	_attach_parts(r)
	r.root.set_meta("slots", _slot_points(r, bare_muzzle))
	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = r.muzzle
	r.root.add_child(marker)
	r.root.set_meta("muzzle", r.muzzle)
	r.root.set_meta("frame", r.frame)
	r.root.set_meta("mag_style", r.mag_style)
	return r.root


## Where the shot leaves the gun (after any muzzle device, silencer or barrel), in model space.
static func muzzle_point(build: Dictionary) -> Vector3:
	var model := build(build)
	var point: Vector3 = model.get_meta("muzzle")
	model.free()
	return point


## The FAULTPRINT gun material. `texture` is the HAIKAI texture name: it now picks the
## print treatment (and the ink when the tint is plain white); tints come from the palette.
static func mat(texture: String, tint := Color.WHITE, glow := Color.BLACK, _density := 7.0) -> Material:
	var color := tint
	if tint == Color.WHITE:
		color = TEXTURE_INK.get(texture, Faultprint.CONCRETE)
	else:
		color = Color(minf(tint.r, 1.0), minf(tint.g, 1.0), minf(tint.b, 1.0)) * TEXTURE_SHADE.get(texture, 1.0)
		color.a = 1.0
	return Faultprint.gun(color, texture, glow)


## Ink for parts that were plain textured in HAIKAI.
const TEXTURE_INK := {
	"panel": Faultprint.CONCRETE, "brass": Faultprint.YELLOW, "wood": Faultprint.KRAFT,
	"grate": Faultprint.GRAPHITE, "pipe": Faultprint.DUST, "rust_metal": Faultprint.OXIDE,
	"concrete": Faultprint.SLATE,
}
## HAIKAI multiplied tints over mid-grey textures; this keeps the old light/dark balance.
const TEXTURE_SHADE := {"panel": 1.0, "brass": 1.0, "wood": 0.95, "grate": 0.8, "pipe": 1.0,
	"rust_metal": 0.9, "concrete": 0.85}


## Everything a frame builder tells the part step: where each slot's part bolts on.
## Anchors left at Vector3.INF are worked out from the others (_settle_anchors).
class Rig:
	var root: Node3D
	var frame := ""
	var parts := {}
	var tune := {}
	var done := {}                         # slots the frame already drew the part of itself
	var muzzle := Vector3(0, 0.07, -0.3)   # end of the bare barrel
	var barrel_start := Vector3(0, 0.07, -0.1)
	var barrel_r := 0.012
	var twin := 0.0                        # side-by-side barrels: x offset of each (devices doubled)
	var top := Vector3(0, 0.1, 0.0)        # top of the rail, sights sit on it
	var mag := Vector3(0, 0.04, -0.06)     # bottom of the magwell, mags hang from it
	var stock := Vector3(0, 0.07, 0.08)    # back of the receiver, stocks go +Z from it
	var under := Vector3(0, 0.04, -0.25)   # under the barrel
	var gadget := Vector3(0, 0.03, 0.05)   # charms hang from here
	var side := Vector3(0.03, 0.07, -0.05) # right side of the receiver (ammo holder)
	var mag_style := "box"                 # how magazine parts look on this frame
	var rounds: Array[MeshInstance3D] = [] # visible rounds that ammo parts recolour
	# The default magazine's shape (parts scale from it).
	var mag_len := 0.12
	var mag_w := 0.022
	var mag_d := 0.034
	var mag_tilt := 8.0
	var mag_curve := 0.0
	# Where the pistol grip is (grip parts replace the frame's own).
	var grip_top := Vector3.INF
	var grip_size := Vector3(0.032, 0.105, 0.042)
	var grip_rake := -16.0
	var trig := Vector3(0, 0.018, -0.027)  # the trigger blade
	var body_w := 0.016                    # half width of the receiver (side cues sit on it)
	# Handguard span (z of its back and front end), height and radius. 0 = from the barrel.
	var hg_start := 0.0
	var hg_end := 0.0
	var hg_y := 0.0
	var hg_r := 0.0
	var rail_l := Vector3.INF              # left / right rail (x = 0: a rail under, things hang down)
	var rail_r := Vector3.INF
	var foregrip := Vector3.INF            # under the handguard, grips hang from it
	var mount := Vector3.INF               # offset / backup sight spot on the top rail
	var gas := Vector3.INF                 # gas block on the barrel
	var recv := Vector3.INF                # middle of the receiver / upper
	var bolt := Vector3.INF                # ejection port, or the bolt handle's knob
	var charging := Vector3.INF            # charging handle
	var butt := Vector3.INF                # back face of the stock (butt pads)
	var butt_h := 0.09                     # how tall that face is
	var comb := Vector3.INF                # top of the stock where a cheek rests
	var tube_end := Vector3.INF            # front of a tube magazine (extensions)
	var tube_r := 0.011
	var device_start := Vector3.INF        # where the muzzle device starts (a can slides over it)
	var device_len := 0.0
	var has_buffer := false
	var mag_root: Node3D = null            # the "Magazine" node (see _into_mag)
	var barrel_end := Vector3.ZERO         # the bare muzzle, before devices and cans                # an AR buffer tube is already there for stocks


## How many placeholder lumps have been drawn (tests check new parts don't need one).
static var lumps := 0


# --- Shape helpers ----------------------------------------------------------------

static func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO,
		bevel := 0.004) -> MeshInstance3D:
	return _put(p, LowPoly.chamfer_box(size, minf(bevel, minf(size.x, minf(size.y, size.z)) * 0.45)), pos, m, rot)


## A rod along Z centred at `pos` (front radius, back radius): a smooth turned part with
## softened edges. `rot` turns it like a Y-axis prism turned by `rot` (the default lays it
## along Z).
static func _rod(p: Node3D, r_front: float, r_back: float, length: float, pos: Vector3, m: Material,
		sides := 8, rot := Vector3(90, 0, 0)) -> MeshInstance3D:
	var h := length / 2.0
	var c := minf(minf(r_front, r_back) * 0.12, minf(0.0012, h * 0.3))
	var prof := PackedVector2Array()
	if r_front > 0.0001 and c > 0.00005:
		prof.append_array([Vector2(-h, r_front - c), Vector2(-h + c, r_front)])
	else:
		prof.append(Vector2(-h, r_front))
	if r_back > 0.0001 and c > 0.00005:
		prof.append_array([Vector2(h - c, r_back), Vector2(h, r_back - c)])
	else:
		prof.append(Vector2(h, r_back))
	var node := _put(p, GunKit.turned(prof, clampi(sides * 2, 12, 24)), pos, m)
	node.transform = Transform3D(Basis.from_euler(rot * PI / 180.0) * Basis(Vector3.RIGHT, -PI / 2.0), pos)
	return node


## A rod from point a to point b.
static func _rod_between(p: Node3D, a: Vector3, b: Vector3, radius: float, m: Material, sides := 10) -> MeshInstance3D:
	sides = maxi(sides, 8)
	var path := PackedVector3Array([a, b])
	return _put(p, LowPoly.tube(path, PackedFloat32Array([radius, radius]), sides), Vector3.ZERO, m)


## A disc / drum with its axis along X.
static func _disc_x(p: Node3D, radius: float, thick: float, pos: Vector3, m: Material, sides := 10) -> MeshInstance3D:
	return _put(p, GunKit.rod(radius, thick, clampi(sides * 2, 12, 24)), pos, m, Vector3(0, 90, 0))


## A lathed profile along Z: points are (radius, z) listed front (-z) to back.
static func _lathe_z(p: Node3D, profile: Array, pos: Vector3, m: Material, sides := 8) -> MeshInstance3D:
	var packed := PackedVector2Array()
	for v: Vector2 in profile:
		packed.append(Vector2(v.y, v.x))
	return _put(p, GunKit.turned(packed, clampi(sides * 2, 12, 24)), pos, m)


## A side silhouette: points are (forward, up) from `pos`, extruded `thick` across X with
## chamfered edges (a GunKit slab).
static func _profile(p: Node3D, points: Array, thick: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var packed := PackedVector2Array()
	for v: Vector2 in points:
		packed.append(Vector2(pos.z - v.x, pos.y + v.y))
	return _put(p, GunKit.slab(packed, thick, minf(0.003, thick * 0.12)), Vector3(pos.x, 0, 0), m)


static func _ball(p: Node3D, radius: float, pos: Vector3, m: Material, squash := Vector3.ONE, lump := 0.0) -> MeshInstance3D:
	if lump > 0.0:
		return _put(p, LowPoly.blob(radius, squash, 1, lump, 3), pos, m)
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	var node := _put(p, sphere, pos, m)
	node.scale = squash
	return node


static func _tube(p: Node3D, points: Array, radius: float, m: Material, sides := 8) -> MeshInstance3D:
	sides = maxi(sides, 8)
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for v: Vector3 in points:
		path.append(v)
		radii.append(radius)
	return _put(p, LowPoly.tube(path, radii, sides), Vector3.ZERO, m)


static func _put(p: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = m
	node.transform = LowPoly.at(pos, rot)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(node)
	return node


# --- Counterform finishes and machined shapes (GunKit) --------------------------------

## Gun finishes (art direction §6): name -> [Counterform material class, colour, old-look
## texture, old-look ink]. Use fin("black") etc. instead of raw colours in new models.
const FINISHES := {
	"black": ["anodized", Color("#2A2D2F"), "panel", Faultprint.GRAPHITE],
	"steel": ["phosphate", Color("#4C5153"), "panel", Faultprint.CONCRETE],
	"bore": ["anodized", Color("#141617"), "panel", Faultprint.CARBON],
	"polymer": ["polymer", Color("#222426"), "panel", Faultprint.CARBON],
	"poly_grey": ["polymer", Color("#4A4E50"), "panel", Faultprint.SLATE],
	"poly_tan": ["polymer", Color("#7E6A52"), "wood", Faultprint.KRAFT],
	"poly_green": ["polymer", Color("#5C635D"), "panel", Faultprint.DEEP_TEAL],
	"laminate": ["polymer", Color("#5A4636"), "wood", Faultprint.KRAFT],
	"oxide": ["paint", Color("#A65339"), "panel", Faultprint.ORANGE],
	"rust": ["oxide", Color("#6E3A28"), "rust_metal", Faultprint.OXIDE],
	"green": ["paint", Color("#777D77"), "panel", Faultprint.TEAL],
	"dust": ["paint", Color("#E9E4D9"), "panel", Faultprint.BONE],
	"sand": ["paint", Color("#B9AC92"), "panel", Faultprint.DUST],
	"sulfur": ["paint", Color("#D9C75B"), "panel", Faultprint.YELLOW],
	"bare": ["bare", Color("#A3A5A3"), "pipe", Faultprint.DUST],
	"chrome": ["bare", Color("#C9CBCB"), "pipe", Faultprint.BONE],
	"brass": ["bare", Color("#A88B55"), "brass", Faultprint.YELLOW],
	"copper": ["bare", Color("#B0704A"), "brass", Faultprint.ORANGE],
	"rubber": ["rubber", Color("#26282A"), "panel", Faultprint.CARBON],
	"lens": ["lens", Color("#24343A"), "panel", Faultprint.DEEP_TEAL],
	"glass": ["glass", Color("#9FB8BE"), "panel", Faultprint.TEAL],
	"shell_red": ["polymer", Color("#8E3A2C"), "panel", Faultprint.OXIDE],
	"shell_green": ["polymer", Color("#55634F"), "panel", Faultprint.DEEP_TEAL],
}


static func fin(name: String, glow := Color.BLACK) -> Material:
	var f: Array = FINISHES.get(name, FINISHES.steel)
	if Settings.look == Faultprint.COUNTERFORM:
		return Counterform.material(f[0], f[1], false, glow)
	return Faultprint.gun(f[3], f[2], glow)


## A side silhouette `points` (z, y) in model space, `thick` across X at `x`, chamfered.
static func _slab(p: Node3D, points: Array, thick: float, m: Material, x := 0.0, bevel := 0.0015) -> MeshInstance3D:
	var packed := PackedVector2Array()
	for v: Vector2 in points:
		packed.append(v)
	return _put(p, GunKit.slab(packed, thick, bevel), Vector3(x, 0, 0), m)


## A turned part: `profile` (z, radius) front to back, placed with its axis through `at`
## (the profile's z is added to at.z).
static func _turn(p: Node3D, profile: Array, at: Vector3, m: Material, sides := 16) -> MeshInstance3D:
	var packed := PackedVector2Array()
	for v: Vector2 in profile:
		packed.append(v)
	return _put(p, GunKit.turned(packed, sides), at, m)


## A plain machined cylinder along Z centred at `at`.
static func _cyl(p: Node3D, radius: float, length: float, at: Vector3, m: Material, sides := 14) -> MeshInstance3D:
	return _put(p, GunKit.rod(radius, length, sides), at, m)


## A cylinder along X (pins, knobs, wheels) centred at `at`.
static func _cyl_x(p: Node3D, radius: float, length: float, at: Vector3, m: Material, sides := 10) -> MeshInstance3D:
	return _put(p, GunKit.rod(radius, length, sides), at, m, Vector3(0, 90, 0))


## A cylinder along Y centred at `at`.
static func _cyl_y(p: Node3D, radius: float, length: float, at: Vector3, m: Material, sides := 10) -> MeshInstance3D:
	return _put(p, GunKit.rod(radius, length, sides), at, m, Vector3(90, 0, 0))


## Cross pins showing on both sides of a receiver `half` wide.
static func _pins(r: Rig, points: Array, half: float, radius := 0.0022) -> void:
	for v: Vector2 in points:
		_cyl_x(r.root, radius, half * 2.0 + 0.0012, Vector3(0, v.y, v.x), fin("steel"), 8)


## Grooves (slide serrations, grip texture): `count` thin dark ridges on both sides.
static func _grooves(r: Rig, z_back: float, z_front: float, y: float, h: float, half: float, count: int, rake := 0.0) -> void:
	for i in count:
		var z := lerpf(z_back, z_front, (i + 0.5) / count)
		for sx: float in [-1.0, 1.0]:
			_box(r.root, Vector3(0.0012, h, 0.0016), Vector3(sx * (half + 0.0002), y, z), fin("bore"), Vector3(rake, 0, 0), 0.0)


## An engraved split line: a hairline of dark along a side, from a to b ((z, y) points).
static func _seam(r: Rig, a: Vector2, b: Vector2, half: float, both := true) -> void:
	var mid := (a + b) / 2.0
	var d := b - a
	var ang := rad_to_deg(atan2(d.y, -d.x))
	for sx: float in ([-1.0, 1.0] if both else [1.0]):
		_box(r.root, Vector3(0.0008, 0.0012, d.length()), Vector3(sx * (half + 0.0002), mid.y, mid.x), fin("bore"), Vector3(ang, 0, 0), 0.0)


## A pistol grip whose top is at `top` (raked back), with a strip of tape round it. The rig
## remembers where it is; with a grip part fitted the part is drawn there instead.
static func _grip(r: Rig, top: Vector3, m: Material, size := Vector3(0.032, 0.105, 0.042), rake := -16.0) -> void:
	r.grip_top = top
	r.grip_size = size
	r.grip_rake = rake
	if r.parts.has("grip"):
		return
	_grip_shape(r, top, m, size, rake)


static func _grip_shape(r: Rig, top: Vector3, m: Material, size: Vector3, rake: float, _tape := true, grooves := true) -> void:
	_put(r.root, GunKit.slab(_grip_outline(top, size, rake, grooves, 1.0), size.x, 0.004), Vector3.ZERO, m)
	# A textured panel on each side (stippling), a shade darker, inset from the edges.
	_put(r.root, GunKit.slab(_grip_outline(top, size, rake, false, 0.7), size.x + 0.0012, 0.001), Vector3.ZERO, fin("rubber"))


## The side outline of a moulded grip: palm swell at the back, finger grooves at the front
## (optional), a flared heel. `k` < 1 shrinks it about its middle (for inset panels).
static func _grip_outline(top: Vector3, size: Vector3, rake: float, grooves: bool, k: float) -> PackedVector2Array:
	var d := size.z
	var h := size.y
	var local := [Vector2(0.5, 0.0), Vector2(0.53, 0.28)]
	if grooves:
		local.append_array([Vector2(0.45, 0.42), Vector2(0.53, 0.55), Vector2(0.46, 0.69), Vector2(0.53, 0.82)])
	else:
		local.append_array([Vector2(0.54, 0.55), Vector2(0.53, 0.82)])
	local.append_array([Vector2(0.52, 0.97), Vector2(0.44, 1.02), Vector2(-0.52, 1.03), Vector2(-0.6, 0.94),
		Vector2(-0.62, 0.62), Vector2(-0.58, 0.32), Vector2(-0.52, 0.08), Vector2(-0.47, 0.0)])
	var fwd := Vector3(0, sin(deg_to_rad(rake)), -cos(deg_to_rad(rake)))
	var down := _grip_down(rake)
	var out := PackedVector2Array()
	for v: Vector2 in local:
		var lv := Vector2(v.x * k, 0.5 + (v.y - 0.5) * k) if k < 1.0 else v
		var p := top + fwd * lv.x * d + down * lv.y * h
		out.append(Vector2(p.z, p.y))
	return out


## A trigger guard loop from under the frame at `front` (z) back to the grip at `back`,
## hanging `depth` below `y` (the frame's underside).
static func _guard(r: Rig, front: float, back: float, y: float, depth: float, m: Material, w := 0.009, t := 0.0042) -> void:
	_slab(r.root, [Vector2(front, y + 0.002), Vector2(front - 0.004, y - depth * 0.55), Vector2(front + 0.006, y - depth),
			Vector2(back, y - depth + 0.002), Vector2(back, y - depth + 0.002 + t), Vector2(front + 0.008, y - depth + t),
			Vector2(front + t - 0.003, y - depth * 0.55), Vector2(front + t, y + 0.002)], w, m, 0.0, 0.0012)


## A curved trigger blade whose pivot is at (z, y).
static func _blade_at(r: Rig, z: float, y: float, m: Material) -> void:
	_slab(r.root, [Vector2(z, y), Vector2(z - 0.004, y - 0.008), Vector2(z - 0.003, y - 0.018), Vector2(z + 0.002, y - 0.024),
			Vector2(z + 0.004, y - 0.022), Vector2(z + 0.001, y - 0.016), Vector2(z + 0.002, y - 0.006), Vector2(z + 0.005, y)],
			0.006, m, 0.0, 0.001)


static func _grip_down(rake: float) -> Vector3:
	return Vector3(0, -cos(deg_to_rad(rake)), -sin(deg_to_rad(rake)))


## The bottom of the pistol grip (where a pistol's magazine comes out).
static func _grip_bottom(r: Rig) -> Vector3:
	return r.grip_top + _grip_down(r.grip_rake) * r.grip_size.y


## A trigger and a bent-wire guard in front of a grip at the origin.
static func _trigger(r: Rig, y := 0.03, z := -0.015, guard := true) -> void:
	r.trig = Vector3(0, y - 0.012, z - 0.012)
	_blade_at(r, z - 0.014, y, fin("black"))
	if guard:
		_guard(r, z - 0.05, z + 0.012, y + 0.003, 0.042, fin("polymer"))


## A picatinny rail: a flat bar with cross slots, `centre` on its base, along Z. `roll`
## turns it round Z (90 faces left, -90 right, 180 down).
static func _pic(r: Rig, centre: Vector3, length: float, roll := 0.0, width := 0.02, m: Material = null) -> void:
	var up := Vector3(0, 1, 0).rotated(Vector3(0, 0, 1), deg_to_rad(roll))
	var bar := m if m != null else fin("black")
	_box(r.root, Vector3(width, 0.007, length), centre + up * 0.0035, bar, Vector3(0, 0, roll), 0.0015)
	var count := int(length / 0.016)
	for i in count:
		var z := -length / 2.0 + (i + 0.5) * length / count
		_box(r.root, Vector3(width + 0.002, 0.004, 0.005), centre + up * 0.0062 + Vector3(0, 0, z), bar, Vector3(0, 0, roll), 0.0008)


## Magazine drawing goes into one "Magazine" node (at the gun's origin), so the view
## model can pull it out and slot a fresh one in on a reload. Returns the node to draw
## into afterwards; nested calls keep drawing into the magazine.
static func _into_mag(r: Rig) -> Node3D:
	var keep := r.root
	if r.mag_root == null:
		r.mag_root = Node3D.new()
		r.mag_root.name = "Magazine"
		r.root.add_child(r.mag_root)
	r.root = r.mag_root
	return keep


## A box magazine (optionally curved like a banana) hanging from `top`; returns its bottom.
static func _mag_body(r: Rig, top: Vector3, length: float, w: float, d: float, tilt: float, curve: float,
		m: Material, plate := true) -> Vector3:
	var keep := _into_mag(r)
	var out := _mag_body_draw(r, top, length, w, d, tilt, curve, m, plate)
	r.root = keep
	return out


static func _mag_body_draw(r: Rig, top: Vector3, length: float, w: float, d: float, tilt: float, curve: float,
		m: Material, plate := true) -> Vector3:
	# The magazine's side silhouette along a curve (a banana when curve > 0), with stiffening
	# ribs down its side and a flared base plate.
	var steps := 8
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	var p := top
	var a := tilt
	var seg := length / steps
	for i in steps + 1:
		a = tilt + curve * float(i) / steps
		var down := Vector3(0, -cos(deg_to_rad(a)), -sin(deg_to_rad(a)))
		var fwd := Vector3(0, sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
		var fp := p + fwd * d * 0.5
		var bp := p - fwd * d * 0.5
		front.append(Vector2(fp.z, fp.y))
		back.append(Vector2(bp.z, bp.y))
		if i < steps:
			p += down * seg
	var outline := PackedVector2Array()
	outline.append_array(front)
	for i in range(back.size() - 1, -1, -1):
		outline.append(back[i])
	_put(r.root, GunKit.slab(outline, w, 0.0025), Vector3(top.x, 0, 0), m)
	# Ribs: two raised strips down each side, following the curve.
	for k: float in [-0.22, 0.22]:
		var rib := PackedVector2Array()
		for i in front.size():
			var c := (front[i] + back[i]) * 0.5 + (front[i] - back[i]) * k
			rib.append(c)
		for i in range(front.size() - 1, -1, -1):
			var c := (front[i] + back[i]) * 0.5 + (front[i] - back[i]) * (k + 0.07)
			rib.append(c)
		var rib_cut := PackedVector2Array(Array(rib).slice(1, rib.size() - 1))
		_put(r.root, GunKit.slab(rib_cut, w + 0.0016, 0.0005), Vector3(top.x, 0, 0), m)
	if plate:
		var down := Vector3(0, -cos(deg_to_rad(a)), -sin(deg_to_rad(a)))
		_box(r.root, Vector3(w + 0.004, 0.008, d + 0.008), p + down * 0.002, fin("polymer"), Vector3(a, 0, 0), 0.002)
	return p


## The frame's own magazine, in its usual shape, with the top round showing.
static func _std_mag(r: Rig, m: Material, length_scale := 1.0) -> Vector3:
	var keep := _into_mag(r)
	var out := _std_mag_draw(r, m, length_scale)
	r.root = keep
	return out


static func _std_mag_draw(r: Rig, m: Material, length_scale := 1.0) -> Vector3:
	_box(r.root, Vector3(r.mag_w + 0.008, 0.014, r.mag_d + 0.008), r.mag + Vector3(0, -0.004, 0), mat("panel", DARK))
	_round(r, _rod(r.root, 0.0055, 0.0055, minf(r.mag_d * 0.8, 0.06), r.mag + Vector3(0, 0.004, -0.002), mat("brass"), 5))
	return _mag_body(r, r.mag, r.mag_len * length_scale, r.mag_w, r.mag_d, r.mag_tilt, r.mag_curve, m)


## A small taped-on lump for a part with no model of its own: something shows where it went.
static func _generic(r: Rig, at: Vector3, id: String) -> void:
	lumps += 1
	var h := absi(hash(id))
	var tint := Color.from_hsv(float(h % 360) / 360.0, 0.45, 0.85)
	_box(r.root, Vector3(0.022, 0.016, 0.03), at, mat("panel", tint), Vector3.ZERO, 0.004)
	_box(r.root, Vector3(0.026, 0.02, 0.008), at, mat("panel", TAPE), Vector3.ZERO, 0.002)


## How much the barrel part stretches or cuts this frame's barrel.
static func _barrel_scale(r: Rig) -> float:
	match r.parts.get("barrel", ""):
		"long_barrel", "nail_guide": return 1.5
		"short_barrel": return 0.6
		"bbl_338": return 1.25
		"telescoping_barrel": return 1.0 + 0.45 * float(r.tune.get("barrel", 0.0))
		"organ_pipes": return 0.7
	return 1.0


## A plain barrel from `start` forward; sets the rig's muzzle and barrel anchors. Every
## barrel part shows here: longer, shorter, fatter, fluted, threaded, a can built round it.
static func _barrel(r: Rig, start: Vector3, length: float, radius: float, m: Material, sight := true) -> float:
	var id: String = r.parts.get("barrel", "")
	var len := length * _barrel_scale(r)
	var rad := radius
	match id:
		"heavy_barrel": rad = radius * 1.5
		"bbl_338": rad = radius * 1.3
	# Turned barrel: a step down from the chamber, a crowned muzzle, the bore showing.
	var step := minf(len * 0.25, 0.06)
	_turn(r.root, [Vector2(-len, rad * 0.8), Vector2(-len + rad * 0.25, rad), Vector2(-step, rad), Vector2(-step + 0.002, rad * 1.12),
			Vector2(0.0, rad * 1.12)], start, m, 16)
	_cyl(r.root, rad * 0.45, 0.0016, start + Vector3(0, 0, -len - 0.0002), fin("bore"), 10)
	var end := start + Vector3(0, 0, -len)
	match id:
		"long_barrel":
			# The extension is a second pipe welded on, with a hose clamp over the joint.
			var joint := start + Vector3(0, 0, -length * 0.95)
			_rod(r.root, rad * 1.6, rad * 1.6, 0.02, joint, mat("panel", TAPE), 8)
			_rod(r.root, rad * 1.15, rad * 1.15, len - length, joint + Vector3(0, 0, -(len - length) / 2.0),
					mat("rust_metal", RUST), 6)
		"red_hot_barrel":
			# Heat-blued rings along the barrel, glowing toward the front end.
			for n in 6:
				var hot := float(n) / 5.0
				_turn(r.root, [Vector2(-0.003, rad * 1.25), Vector2(0.003, rad * 1.25)], start + Vector3(0, 0, -len * (0.2 + 0.72 * hot)),
						fin("rust", Color(0.9, 0.18, 0.02) * hot * 1.4), 14)
		"short_barrel":
			_rod(r.root, rad * 1.4, rad * 1.4, 0.012, start + Vector3(0, 0, -len + 0.006), mat("brass", COPPER), 6)
		"heavy_barrel":
			_rod(r.root, rad * 1.12, rad * 1.12, 0.012, end + Vector3(0, 0, 0.012), mat("panel", BLACK), 8)
		"fluted_barrel":
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				_box(r.root, Vector3(0.0035, 0.0035, len * 0.55), start + Vector3(cos(a) * rad, sin(a) * rad, -len * 0.5),
						mat("panel", BLACK), Vector3(0, 0, rad_to_deg(a)), 0.0)
		"match_barrel":
			_rod(r.root, rad * 1.08, rad * 1.08, len * 0.4, start + Vector3(0, 0, -len * 0.75), mat("panel", NICKEL), 8)
			_rod(r.root, rad * 1.2, rad * 1.2, 0.006, end + Vector3(0, 0, 0.003), mat("brass"), 8)
		"polygonal_barrel":
			_rod(r.root, rad * 1.1, rad * 1.1, 0.008, start + Vector3(0, 0, -len * 0.3), mat("brass", COPPER), 6)
			_rod(r.root, rad * 1.1, rad * 1.1, 0.008, start + Vector3(0, 0, -len * 0.35), mat("brass", COPPER), 6)
		"threaded_barrel":
			# Threads cut on the end: a short brass-bright stub past the old muzzle.
			_rod(r.root, rad * 0.85, rad * 0.85, 0.03, end + Vector3(0, 0, -0.015), mat("brass", Color(1.1, 1.0, 0.8)), 8)
			for i in 4:
				_rod(r.root, rad * 0.95, rad * 0.95, 0.002, end + Vector3(0, 0, -0.005 - i * 0.007), mat("panel", DARK), 8)
			end += Vector3(0, 0, -0.03)
		"integral_suppressor":
			# A fat can welded round the front half of the barrel, a strip of tape on it.
			var can_r := maxf(rad * 2.4, 0.017)
			var back := start + Vector3(0, 0, -len * 0.35)
			var can_len := len * 0.65 + 0.12
			_rod(r.root, can_r, can_r, can_len, back + Vector3(0, 0, -can_len / 2.0), mat("panel", Color(0.28, 0.3, 0.28)), 10)
			_rod(r.root, can_r * 1.04, can_r * 1.04, 0.03, back + Vector3(0, 0, -can_len * 0.3), mat("panel", TAPE), 10)
			_rod(r.root, can_r * 0.75, can_r, 0.012, back + Vector3(0, 0, -can_len - 0.006), mat("panel", BLACK), 10)
			end = back + Vector3(0, 0, -can_len - 0.012)
			sight = false
		"bbl_338":
			_rod(r.root, rad * 1.2, rad * 1.2, 0.02, start + Vector3(0, 0, -0.03), mat("panel", BLACK), 8)
			_rod(r.root, rad * 1.15, rad * 1.15, 0.008, start + Vector3(0, 0, -0.06), mat("panel", YELLOW), 8)
			for i in 3:
				var a := TAU * i / 3.0
				_box(r.root, Vector3(0.003, 0.003, len * 0.4), start + Vector3(cos(a) * rad, sin(a) * rad, -len * 0.55),
						mat("panel", BLACK), Vector3(0, 0, rad_to_deg(a)), 0.0)
		"rifled_slug_barrel":
			# A cantilever rail over the chamber and rifle sights: a ramp and an orange blade.
			_box(r.root, Vector3(0.008, 0.012, 0.03), end + Vector3(0, rad + 0.006, 0.02), mat("panel", DARK), Vector3.ZERO, 0.002)
			_box(r.root, Vector3(0.003, 0.008, 0.006), end + Vector3(0, rad + 0.016, 0.02), mat("panel", ORANGE, FIRE * 0.6), Vector3.ZERO, 0.0)
			_rod(r.root, rad * 1.1, rad * 1.1, 0.01, start + Vector3(0, 0, -len * 0.5), mat("panel", OLIVE), 8)
			sight = false
		"nail_guide":
			_rod(r.root, rad * 1.3, rad * 1.3, 0.02, end + Vector3(0, 0, 0.01), mat("panel", YELLOW), 6)
			_rod(r.root, rad * 1.6, rad * 1.3, 0.012, end + Vector3(0, 0, -0.004), mat("panel", BLACK), 6)
		"corkscrew_barrel":
			# A helix of steel wound round the barrel, welded at both ends.
			var helix := []
			var turns := maxi(int(len / 0.03), 4)
			for i in turns * 8 + 1:
				var a := TAU * i / 8.0
				helix.append(start + Vector3(cos(a) * rad * 1.5, sin(a) * rad * 1.5, -len * float(i) / (turns * 8)))
			_tube(r.root, helix, maxf(rad * 0.32, 0.0022), fin("steel"), 8)
			for z: float in [0.004, len - 0.004]:
				_turn(r.root, [Vector2(-0.004, rad * 1.85), Vector2(0.004, rad * 1.85)], start + Vector3(0, 0, -z), fin("black"), 16)
		"glass_barrel":
			# A thick glass sleeve over a thin steel liner; the liner shows through.
			_turn(r.root, [Vector2(-len + 0.004, rad * 1.7), Vector2(-len + 0.008, rad * 2.0), Vector2(-0.01, rad * 2.0), Vector2(-0.006, rad * 1.7)],
					start, fin("glass"), 18)
			for z: float in [0.004, len - 0.002]:
				_turn(r.root, [Vector2(-0.004, rad * 2.1), Vector2(0.004, rad * 2.1)], start + Vector3(0, 0, -z), fin("chrome"), 18)
		"telescoping_barrel":
			# Three nested sections, each a step thinner, with a collar where they meet.
			for k in 3:
				var z0 := len * k / 3.0
				var rr := rad * (1.6 - k * 0.22)
				_turn(r.root, [Vector2(-len / 3.0, rr), Vector2(0.0, rr)], start + Vector3(0, 0, -z0), fin("black" if k % 2 == 0 else "steel"), 16)
				_turn(r.root, [Vector2(-0.006, rr * 1.18), Vector2(0.0, rr * 1.18)], start + Vector3(0, 0, -z0 - len / 3.0 + 0.006), fin("oxide"), 16)
		"twin_linked":
			# A second barrel welded on top, clamped at both ends.
			var up := Vector3(0, rad * 2.3, 0)
			_turn(r.root, [Vector2(-len, rad * 0.8), Vector2(-len + rad * 0.25, rad), Vector2(0.0, rad)], start + up, m, 16)
			_cyl(r.root, rad * 0.45, 0.0016, start + up + Vector3(0, 0, -len - 0.0002), fin("bore"), 10)
			for z: float in [0.02, len - 0.02]:
				_slab(r.root, [Vector2(start.z - z + 0.008, start.y - rad * 1.1), Vector2(start.z - z - 0.008, start.y - rad * 1.1),
						Vector2(start.z - z - 0.008, start.y + up.y + rad * 1.1), Vector2(start.z - z + 0.008, start.y + up.y + rad * 1.1)],
						rad * 2.4, fin("steel"), start.x, 0.0015)
			sight = false
		"organ_pipes":
			# Six short pipes round the barrel, bundled with two brass bands.
			for i in 6:
				var a := TAU * i / 6.0
				var off := Vector3(cos(a), sin(a), 0) * rad * 2.05
				_turn(r.root, [Vector2(-len * (0.85 + 0.15 * float(i % 2)), rad * 0.95), Vector2(0.0, rad * 0.95)], start + off, fin("steel"), 12)
				_cyl(r.root, rad * 0.55, 0.0016, start + off + Vector3(0, 0, -len * (0.85 + 0.15 * float(i % 2)) - 0.0002), fin("bore"), 10)
			for z: float in [0.015, len * 0.6]:
				_turn(r.root, [Vector2(-0.006, rad * 3.1), Vector2(0.006, rad * 3.1)], start + Vector3(0, 0, -z), fin("brass"), 20)
			sight = false
	if sight:
		_box(r.root, Vector3(0.004, 0.014, 0.008), start + Vector3(0, rad + 0.006, -len + 0.012), mat("panel", DARK))
	# Energy coils go on the end of any barrel (_barrel_part draws them after).
	if id != "" and not Arsenal.is_organ(id) and not id in ["coil_barrel", "cooling_coil"]:
		r.done["barrel"] = true
		if not id in ["long_barrel", "short_barrel", "heavy_barrel", "fluted_barrel", "match_barrel", "polygonal_barrel",
				"threaded_barrel", "integral_suppressor", "bbl_338", "rifled_slug_barrel", "nail_guide", "corkscrew_barrel",
				"glass_barrel", "telescoping_barrel", "twin_linked", "organ_pipes", "red_hot_barrel"]:
			_generic(r, start + Vector3(0, rad + 0.006, -len * 0.5), id)
	r.barrel_start = start
	r.barrel_r = rad
	r.muzzle = end
	return len


## A visible round (a cartridge tip, shell, bolt head): recoloured by the ammo part.
static func _round(r: Rig, node: MeshInstance3D) -> MeshInstance3D:
	r.rounds.append(node)
	return node


## A straight box magazine hanging from `top`, with the top round showing.
static func _box_mag(r: Rig, top: Vector3, length: float, m: Material, width := 0.022, depth := 0.034, tilt := 8.0) -> void:
	var keep := _into_mag(r)
	_box_mag_draw(r, top, length, m, width, depth, tilt)
	r.root = keep


static func _box_mag_draw(r: Rig, top: Vector3, length: float, m: Material, width := 0.022, depth := 0.034, tilt := 8.0) -> void:
	var down := Vector3(0, -cos(deg_to_rad(tilt)), -sin(deg_to_rad(tilt)))
	_box(r.root, Vector3(width + 0.008, 0.02, depth + 0.008), top + Vector3(0, -0.006, 0), mat("panel", DARK))
	_box(r.root, Vector3(width, length, depth), top + down * length * 0.5, m, Vector3(tilt, 0, 0))
	_box(r.root, Vector3(width + 0.004, 0.012, depth + 0.006), top + down * (length - 0.006), mat("panel", BLACK),
			Vector3(tilt, 0, 0))
	_round(r, _rod(r.root, 0.006, 0.006, depth * 0.8, top + Vector3(0, 0.004, -0.004), mat("brass"), 5))


# --- Frames ---------------------------------------------------------------------------

static func _tank(r: Rig, pos: Vector3, radius: float, length: float, m: Material) -> void:
	var keep := _into_mag(r)
	_tank_draw(r, pos, radius, length, m)
	r.root = keep


static func _tank_draw(r: Rig, pos: Vector3, radius: float, length: float, m: Material) -> void:
	var h := length / 2.0
	_lathe_z(r.root, [Vector2(0, -h), Vector2(radius * 0.7, -h + 0.008), Vector2(radius, -h + 0.03),
			Vector2(radius, h - 0.03), Vector2(radius * 0.7, h - 0.008), Vector2(0, h)], pos, m, 10)
	_rod(r.root, radius * 1.03, radius * 1.03, 0.03, pos + Vector3(0, 0, -h * 0.3), mat("panel", YELLOW), 10)
	_rod(r.root, radius * 1.04, radius * 1.04, 0.012, pos + Vector3(0, 0, -h * 0.3), mat("panel", BLACK), 10)
	_rod(r.root, 0.006, 0.006, 0.02, pos + Vector3(0, radius + 0.008, h * 0.4), mat("brass"), 5, Vector3.ZERO)
	_put(r.root, LowPoly.prism(8, 0.014, 0.014, 0.004), pos + Vector3(0, radius + 0.02, h * 0.4), mat("panel", RED))
	_tube(r.root, [pos + Vector3(0, 0, h), pos + Vector3(0, 0.0, h + 0.03), Vector3(0, 0.045, 0.1), Vector3(0, 0.06, 0.08)],
			0.007, mat("panel", BLACK), 5)


static func _cells(r: Rig, top: Vector3, count: int, radius: float, length: float, m: Material) -> void:
	var keep := _into_mag(r)
	_cells_draw(r, top, count, radius, length, m)
	r.root = keep


static func _cells_draw(r: Rig, top: Vector3, count: int, radius: float, length: float, m: Material) -> void:
	for i in count:
		var x := (i - (count - 1) / 2.0) * radius * 2.1
		var pos := top + Vector3(x, -radius, 0)
		_rod(r.root, radius, radius, length, pos, m, 8)
		_rod(r.root, radius * 1.05, radius * 1.05, 0.012, pos + Vector3(0, 0, -length * 0.25), mat("panel", BLACK, ZAP), 8)
		_rod(r.root, radius * 0.5, radius * 0.5, 0.01, pos + Vector3(0, 0, length / 2.0 + 0.004), mat("panel", STEEL), 6)
	_box(r.root, Vector3(radius * 2.2 * count, 0.008, 0.02), top + Vector3(0, -0.002, 0), mat("panel", DARK))


static func _duck(p: Node3D, pos: Vector3, s: float) -> void:
	var yellow := mat("panel", Color(1.5, 1.25, 0.15))
	_ball(p, 0.03 * s, pos + Vector3(0, 0, 0.012) * s, yellow, Vector3(1, 0.75, 1.2))
	_ball(p, 0.02 * s, pos + Vector3(0, 0.03, -0.012) * s, yellow)
	_box(p, Vector3(0.02, 0.006, 0.016) * s, pos + Vector3(0, 0.026, -0.034) * s, mat("panel", ORANGE), Vector3.ZERO, 0.002)
	for sx: float in [-1.0, 1.0]:
		_box(p, Vector3(0.005, 0.005, 0.003) * s, pos + Vector3(sx * 0.009, 0.036, -0.03) * s, mat("panel", BLACK), Vector3.ZERO, 0.0)
	_box(p, Vector3(0.012, 0.012, 0.012) * s, pos + Vector3(0, 0.012, 0.045) * s, yellow, Vector3(30, 0, 0), 0.002)


static func _blade(p: Node3D, pos: Vector3, radius: float) -> void:
	var outline := PackedVector2Array()
	var teeth := 14
	for i in teeth:
		var a := TAU * i / teeth
		var b := TAU * (i + 0.6) / teeth
		outline.append(Vector2(cos(a), sin(a)) * radius * 0.82)
		outline.append(Vector2(cos(b), sin(b)) * radius)
	# Tipped up a little at the front so it reads from the side too.
	_put(p, LowPoly.extrude(outline, 0.005), pos, mat("panel", Color(1.3, 1.32, 1.38)), Vector3(80, 0, 0))
	_put(p, LowPoly.prism(8, radius * 0.25, radius * 0.25, 0.009), pos, mat("panel", RED), Vector3(-10, 0, 0))


## Spare blades stacked in a little cage under the body.
static func _blade_stack(r: Rig, top: Vector3, count: int) -> void:
	var keep := _into_mag(r)
	_blade_stack_draw(r, top, count)
	r.root = keep


static func _blade_stack_draw(r: Rig, top: Vector3, count: int) -> void:
	for i in count:
		_put(r.root, LowPoly.prism(12, 0.045, 0.045, 0.004), top + Vector3(0, -0.006 - i * 0.008, 0), mat("panel", STEEL))
	for sx: float in [-1.0, 1.0]:
		_box(r.root, Vector3(0.004, 0.012 + count * 0.008, 0.004), top + Vector3(sx * 0.05, -count * 0.004, 0), mat("panel", DARK))
	_box(r.root, Vector3(0.1, 0.004, 0.02), top + Vector3(0, -0.01 - count * 0.008, 0), mat("panel", DARK))


static func _ring(centre: Vector3, radius: float, segments: int) -> Array:
	var points := []
	for i in segments + 1:
		var a := TAU * i / segments
		points.append(centre + Vector3(cos(a), sin(a), 0) * radius)
	return points


# --- Handguns (gunsmith v2) --------------------------------------------------------

static func _pistol_mag(r: Rig, stick := 0.0, m: Material = null) -> void:
	var keep := _into_mag(r)
	_pistol_mag_draw(r, stick, m)
	r.root = keep


static func _pistol_mag_draw(r: Rig, stick := 0.0, m: Material = null) -> void:
	r.mag = _grip_bottom(r)
	r.mag_style = "pistol"
	r.mag_tilt = r.grip_rake
	r.mag_w = r.grip_size.x - 0.008
	r.mag_d = r.grip_size.z - 0.012
	r.mag_len = maxf(stick, 0.03)
	r.gadget = r.mag + Vector3(0, -0.004, 0.02)
	if r.parts.has("magazine"):
		return
	if stick > 0.0:
		_mag_body(r, r.mag, stick, r.mag_w, r.mag_d, r.mag_tilt, 0.0, m if m != null else mat("panel", DARK))
	else:
		_box(r.root, Vector3(r.grip_size.x + 0.003, 0.009, r.grip_size.z + 0.005), r.mag, mat("panel", BLACK),
				Vector3(r.grip_rake, 0, 0), 0.002)


# --- PDW -----------------------------------------------------------------------------

static func _top_mag(r: Rig, length: float, m: Material, width := 0.044) -> void:
	var keep := _into_mag(r)
	_top_mag_draw(r, length, m, width)
	r.root = keep


static func _top_mag_draw(r: Rig, length: float, m: Material, width := 0.044) -> void:
	_box(r.root, Vector3(width, 0.026, length), r.mag + Vector3(0, 0.013, 0), m, Vector3.ZERO, 0.006)
	# Two staggered rows of rounds inside (seen through a clear body), the feed lips in black.
	for sx: float in [-1.0, 1.0]:
		_round(r, _box(r.root, Vector3(0.008, 0.008, length * 0.85), r.mag + Vector3(sx * width * 0.2, 0.012, 0.0), fin("brass"), Vector3.ZERO, 0.002))
	_box(r.root, Vector3(width + 0.002, 0.03, 0.02), r.mag + Vector3(0, 0.014, length * 0.5), fin("polymer"), Vector3.ZERO, 0.004)


# --- Rifles ------------------------------------------------------------------------

static func _lever(r: Rig, s: float) -> void:
	var m := mat("panel", STEEL if s > 1.0 else DARK)
	var o := Vector3(0, 0.038, -0.02)
	_tube(r.root, [o, o + Vector3(0, -0.04, -0.004) * Vector3(1, s, 1), o + Vector3(0, -0.06, 0.02) * Vector3(1, s, s),
			o + Vector3(0, -0.055, 0.075) * Vector3(1, s, s), o + Vector3(0, -0.02, 0.095) * Vector3(1, s, s),
			o + Vector3(0, -0.004, 0.08)], 0.0042 * minf(s, 1.3), m, 5)


static func _belt_box(r: Rig, size: Vector3, m: Material) -> void:
	var keep := _into_mag(r)
	_belt_box_draw(r, size, m)
	r.root = keep


static func _belt_box_draw(r: Rig, size: Vector3, m: Material) -> void:
	var c := r.mag + Vector3(0, -size.y / 2.0 - 0.004, 0)
	_box(r.root, Vector3(0.03, 0.01, 0.04), r.mag + Vector3(0, -0.002, 0), mat("panel", BLACK), Vector3.ZERO, 0.002)
	_box(r.root, size, c, m, Vector3.ZERO, 0.006)
	_box(r.root, Vector3(size.x + 0.003, 0.012, size.z * 0.6), c + Vector3(0, size.y * 0.15, 0), mat("panel", TAPE), Vector3.ZERO, 0.002)
	_box(r.root, Vector3(size.x * 0.4, 0.006, 0.02), c + Vector3(0, -size.y / 2.0 - 0.002, 0), mat("panel", BLACK), Vector3.ZERO, 0.001)
	# Belt: links of rounds climbing from the box lid to the feed port on the left.
	var from := c + Vector3(-size.x * 0.3, size.y / 2.0, 0)
	var to := Vector3(-0.03, r.mag.y + 0.06, -0.05)
	for i in 6:
		var t := i / 5.0
		var p := from.lerp(to, t) + Vector3(-sin(t * PI) * 0.016, 0, 0)
		_round(r, _rod(r.root, 0.0045, 0.0045, 0.026, p, mat("brass"), 5))
		_box(r.root, Vector3(0.011, 0.006, 0.006), p + Vector3(0, 0, 0.006), mat("panel", BLACK), Vector3.ZERO, 0.001)


# --- Shotguns ----------------------------------------------------------------------

## Two barrels side by side from `start` (the centre between them): returns the length.
static func _twin_barrels(r: Rig, start: Vector3, length: float, radius: float, m: Material) -> float:
	var gap := radius + 0.0012
	_barrel(r, start + Vector3(gap, 0, 0), length, radius, m, false)
	var len := _barrel(r, start + Vector3(-gap, 0, 0), length, radius, m, false)
	r.twin = gap
	r.barrel_start = start
	r.muzzle = Vector3(0, start.y, r.muzzle.z)
	# The rib between them with a brass bead at the end.
	_box(r.root, Vector3(0.008, 0.004, len), start + Vector3(0, radius + 0.002, -len / 2.0), mat("panel", DARK), Vector3.ZERO, 0.001)
	_ball(r.root, 0.0025, Vector3(0, start.y + radius + 0.006, r.muzzle.z + 0.006), mat("brass"))
	return len


# --- Anchors ----------------------------------------------------------------------

## Works out every anchor the frame left open from the ones it set.
static func _settle_anchors(r: Rig) -> void:
	if r.hg_end == 0.0 and r.hg_start == 0.0:
		r.hg_start = r.barrel_start.z
		r.hg_end = lerpf(r.barrel_start.z, r.muzzle.z, 0.6)
		r.hg_y = r.barrel_start.y
		r.hg_r = maxf(r.barrel_r * 1.8, 0.016)
	var mid := (r.hg_start + r.hg_end) / 2.0
	if r.rail_l == Vector3.INF:
		r.rail_l = Vector3(-(r.hg_r + 0.002), r.hg_y, mid)
	if r.rail_r == Vector3.INF:
		r.rail_r = Vector3(absf(r.rail_l.x) if r.rail_l.x != 0.0 else r.hg_r + 0.002, r.rail_l.y, r.rail_l.z)
	if r.foregrip == Vector3.INF:
		r.foregrip = Vector3(0, r.hg_y - r.hg_r, lerpf(r.hg_start, r.hg_end, 0.4))
	if r.mount == Vector3.INF:
		r.mount = r.top + Vector3(0, 0, -0.045)
	if r.gas == Vector3.INF:
		r.gas = r.barrel_start.lerp(r.muzzle, 0.45)
	if r.recv == Vector3.INF:
		r.recv = Vector3(0, r.top.y - 0.025, (r.stock.z + r.barrel_start.z) / 2.0)
	if r.bolt == Vector3.INF:
		r.bolt = r.side + Vector3(0, 0.012, 0.02)
	if r.charging == Vector3.INF:
		r.charging = Vector3(0, r.top.y - 0.006, r.stock.z - 0.012)
	if r.grip_top == Vector3.INF:
		r.grip_top = Vector3(0, 0.04, 0.02)
	if r.tube_end == Vector3.INF:
		r.tube_end = Vector3(0, r.under.y + 0.01, r.under.z)


## Where each slot's part sits, for menus to point at (every Arsenal slot).
static func _slot_points(r: Rig, bare_muzzle: Vector3) -> Dictionary:
	var butt := r.butt if r.butt != Vector3.INF else r.stock + Vector3(0, -0.02, 0.1)
	var comb := r.comb if r.comb != Vector3.INF else r.stock + Vector3(0, 0.0, 0.1)
	var can := r.muzzle.lerp(r.device_start if r.device_start != Vector3.INF else bare_muzzle, 0.5)
	return {
		"receiver": r.recv, "barrel": r.barrel_start.lerp(bare_muzzle, 0.5), "muzzle": r.muzzle.lerp(bare_muzzle, 0.5),
		"silencer": can, "gas": r.gas, "handguard": Vector3(0, r.hg_y, (r.hg_start + r.hg_end) / 2.0),
		"rail_l": r.rail_l, "rail_r": r.rail_r, "foregrip": r.foregrip + Vector3(0, -0.03, 0), "underbarrel": r.under,
		"mount": r.mount + Vector3(0.012, 0.012, 0), "sight": r.top + Vector3(0, 0.02, 0),
		"grip": r.grip_top + _grip_down(r.grip_rake) * r.grip_size.y * 0.5, "trigger": r.trig, "bolt": r.bolt,
		"charging": r.charging, "magazine": r.mag + Vector3(0, -0.03, 0), "ammo": r.side,
		"stock": r.stock + Vector3(0, -0.02, 0.08), "buttpad": butt.lerp(comb, 0.15), "gadget": r.gadget + Vector3(0, -0.04, 0.01),
		"tactical": GunPartsC7.tactical_point(r) + Vector3(0, 0.02, 0), "spring": r.stock, "magwell": r.mag,
		"cheek": GunPartsC7.cheek_point(r), "sling": GunPartsC7.sling_point(r),
	}


# --- Parts ----------------------------------------------------------------------------

static func _attach_parts(r: Rig) -> void:
	var p: Dictionary = r.parts.duplicate()
	for slot: String in r.done:
		p.erase(slot)
	# The handguard first: it decides where rails, grips, gas cues and underbarrel things go.
	if p.has("handguard"):
		_handguard(r, p.handguard)
	for slot in Arsenal.SLOTS:
		if not p.has(slot) or slot in ["handguard", "ammo"]:
			continue
		var id: String = p[slot]
		match slot:
			"receiver": _receiver(r, id)
			"barrel": _barrel_part(r, id)
			"muzzle": _muzzle(r, id)
			"silencer": _silencer(r, id)
			"gas": _gas(r, id)
			"rail_l", "rail_r": _rail_part(r, slot, id)
			"foregrip": _foregrip(r, id)
			"underbarrel": _underbarrel(r, id)
			"mount": _mount(r, id)
			"sight": _sight(r, id)
			"grip": _grip_part(r, id)
			"trigger": _trigger_part(r, id)
			"bolt": _bolt_part(r, id)
			"charging": _charging(r, id)
			"magazine": _magazine(r, id)
			"stock": _stock(r, id)
			"buttpad": _buttpad(r, id)
			"gadget": _gadget(r, id)
			"tactical", "spring", "magwell", "cheek", "sling": GunPartsC7.draw(r, slot, id)
			_: _generic(r, r.recv, id)
	# Ammo last, so every visible round (even ones a part added) takes its colour.
	if p.has("ammo"):
		_ammo(r, p.ammo)


## Receivers the frame didn't draw itself (unknown ones): a painted band on the receiver.
static func _receiver(r: Rig, id: String) -> void:
	match id:
		"cylinder_8", "cylinder_45", "upper_300", "upper_pcc", "upper_light", "upper_billet", "ak_cover", "ak_modern", "precision_chassis":
			# Drawn by a frame that takes it; anywhere else it is just a marked-up receiver.
			_box(r.root, Vector3(r.body_w * 2.0 + 0.003, 0.008, 0.04), r.recv, mat("panel", ORANGE), Vector3.ZERO, 0.001)
		_:
			_generic(r, r.recv + Vector3(0, 0, 0.02), id)


## Barrel parts on frames whose barrel isn't a plain tube (energy coils).
static func _barrel_part(r: Rig, id: String) -> void:
	match id:
		"coil_barrel":
			_coil_barrel(r)
		"cooling_coil":
			# Coolant hoses wound round the front, a little blue tank of it.
			var start := r.muzzle
			var points := []
			for i in 25:
				var a := TAU * i / 7.0
				points.append(start + Vector3(cos(a) * (r.barrel_r * 0.6 + 0.012), sin(a) * (r.barrel_r * 0.6 + 0.012), -0.004 - i * 0.004))
			_tube(r.root, points, 0.003, mat("panel", BLUE, Color(0.0, 0.08, 0.25)), 4)
			_rod(r.root, 0.012, 0.012, 0.05, start + Vector3(0, r.barrel_r * 0.6 + 0.024, -0.05), mat("panel", BLUE, Color(0.05, 0.15, 0.4)), 8)
			_rod(r.root, 0.007, 0.007, 0.104, start + Vector3(0, 0, -0.052), mat("panel", BLACK, ZAP * 0.5), 6)
			r.muzzle = start + Vector3(0, 0, -0.104)
		"red_hot_barrel":
			# Heat-blued rings along the barrel, glowing toward the front end.
			var count := 7
			for n in count:
				var z := r.barrel_start.z + (r.muzzle.z - r.barrel_start.z) * (0.2 + 0.75 * n / float(count - 1))
				var hot := float(n) / (count - 1)
				_turn(r.root, [Vector2(-0.003, r.barrel_r * 1.25), Vector2(0.003, r.barrel_r * 1.25)], Vector3(r.muzzle.x, r.barrel_start.y, z),
						fin("rust", Color(0.9, 0.18, 0.02) * hot * 1.4), 14)
		_:
			_barrel_sleeve(r, id)


## A barrel part on a frame that doesn't draw a plain barrel (C7, everything fits): a
## sleeve clamped over the front of whatever it shoots from, as long as the part says.
static func _barrel_sleeve(r: Rig, id: String) -> void:
	var length: float = {"long_barrel": 0.12, "short_barrel": 0.025, "heavy_barrel": 0.07, "integral_suppressor": 0.14,
		"telescoping_barrel": 0.16, "bbl_338": 0.1}.get(id, 0.06)
	var rad := r.barrel_r * 1.1 + (0.012 if id == "integral_suppressor" else 0.004)
	var finish := "black" if id in ["integral_suppressor", "heavy_barrel"] else ("glass" if id == "glass_barrel" else "steel")
	var start := r.muzzle
	_rod(r.root, rad, rad, length, start + Vector3(0, 0, -length / 2.0), fin(finish), 10)
	_rod(r.root, rad + 0.003, rad + 0.003, 0.01, start + Vector3(0, 0, -0.004), fin("oxide"), 10)
	if id == "twin_linked":
		_rod(r.root, rad, rad, length, start + Vector3(rad * 2.2, 0, -length / 2.0), fin(finish), 10)
	r.muzzle = start + Vector3(0, 0, -length)


static func _coil_barrel(r: Rig) -> void:
	var copper := mat("brass", COPPER)
	var length := 0.1
	var start := r.muzzle
	_rod(r.root, 0.008, 0.008, length + 0.01, start + Vector3(0, 0, -length / 2.0), mat("panel", BLACK, ZAP), 6)
	for i in 6:
		_rod(r.root, r.barrel_r * 0.55 + 0.012, r.barrel_r * 0.55 + 0.012, 0.009, start + Vector3(0, 0, -0.008 - i * 0.017), copper, 8)
	_rod(r.root, 0.006, 0.006, length, start + Vector3(0.0, r.barrel_r * 0.55 + 0.014, -length / 2.0), mat("panel", DARK), 4)
	r.muzzle = start + Vector3(0, 0, -length)


## A muzzle part's length in metres (its "length" mod, or a default).
static func _part_len(id: String, fallback: float) -> float:
	var add: Dictionary = Arsenal.part(id).get("+", {})
	return float(add.get("length", fallback * 100.0)) / 100.0


static func _muzzle(r: Rig, id: String) -> void:
	var m := r.muzzle
	var br := maxf(r.barrel_r, 0.008)
	r.device_start = m
	var len := 0.0
	if r.twin > 0.0:
		for sx: float in [-1.0, 1.0]:
			len = _muzzle_device(r, id, m + Vector3(sx * r.twin, 0, 0), br)
	else:
		len = _muzzle_device(r, id, m, br)
	r.device_len = len
	r.muzzle = m + Vector3(0, 0, -len)


## Draws one muzzle device starting at `m` on a barrel of radius `br`; returns its length.
static func _muzzle_device(r: Rig, id: String, m: Vector3, br: float) -> float:
	var black := fin("black")
	var bore := fin("bore")
	match id:
		"rocket_nozzle":
			# A rocket-engine bell facing forward: the gas goes out the front and pushes you back.
			_turn(r.root, [Vector2(-0.075, br * 3.4), Vector2(-0.072, br * 3.6), Vector2(-0.05, br * 2.4), Vector2(-0.025, br * 1.6),
					Vector2(-0.02, br * 1.9), Vector2(0.0, br * 1.9)], m, fin("oxide"), 22)
			_turn(r.root, [Vector2(-0.073, br * 3.1), Vector2(-0.05, br * 2.0), Vector2(-0.03, br * 1.1)], m, bore, 20)
			for i in 4:
				_turn(r.root, [Vector2(-0.0015, br * 2.0), Vector2(0.0015, br * 2.0)], m + Vector3(0, 0, -0.004 - i * 0.005), black, 18)
			return 0.075
		"bell_mouth":
			# A blunderbuss bell in brass.
			_turn(r.root, [Vector2(-0.09, br * 3.4), Vector2(-0.087, br * 3.5), Vector2(-0.06, br * 2.0), Vector2(-0.02, br * 1.4), Vector2(0.0, br * 1.5)],
					m, fin("brass"), 22)
			_turn(r.root, [Vector2(-0.088, br * 3.1), Vector2(-0.06, br * 1.6), Vector2(-0.04, br * 1.0)], m, bore, 20)
			return 0.09
		"grapple_spike":
			# A steel collar with four hooked claws reaching forward.
			_turn(r.root, [Vector2(-0.03, br * 1.6), Vector2(-0.028, br * 1.9), Vector2(-0.004, br * 1.9), Vector2(0.0, br * 1.6)], m, fin("steel"), 18)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				var d := Vector3(cos(a), sin(a), 0)
				_tube(r.root, [m + d * br * 1.8 + Vector3(0, 0, -0.02), m + d * br * 2.8 + Vector3(0, 0, -0.04), m + d * br * 3.0 + Vector3(0, 0, -0.058),
						m + d * br * 2.0 + Vector3(0, 0, -0.064)], 0.0022, fin("bare"), 8)
			_cyl(r.root, br * 0.6, 0.0016, m + Vector3(0, 0, -0.0302), bore, 12)
			return 0.03
		"turbine_brake":
			# A spinning brake: a drum with angled vanes round it.
			_turn(r.root, [Vector2(-0.055, br * 1.5), Vector2(-0.052, br * 2.0), Vector2(-0.006, br * 2.0), Vector2(0.0, br * 1.5)], m, black, 20)
			for i in 8:
				var a := TAU * i / 8.0
				_box(r.root, Vector3(0.0018, br * 1.4, 0.04), m + Vector3(cos(a), sin(a), 0) * br * 2.3 + Vector3(0, 0, -0.03), fin("bare"),
						Vector3(0, 25, rad_to_deg(a) + 90.0), 0.0)
			_cyl(r.root, br * 0.7, 0.0016, m + Vector3(0, 0, -0.0552), bore, 12)
			return 0.055
		"suppressor":
			# A direct-thread can: knurled mount, a long body, a stepped front cap.
			var rad := maxf(br * 2.2, 0.018)
			_turn(r.root, [Vector2(-0.155, rad * 0.5), Vector2(-0.152, rad * 0.85), Vector2(-0.145, rad), Vector2(-0.02, rad), Vector2(-0.018, br * 1.4),
					Vector2(0.0, br * 1.4)], m, fin("black"), 20)
			for i in 6:
				_turn(r.root, [Vector2(-0.0015, rad * 1.015), Vector2(0.0015, rad * 1.015)], m + Vector3(0, 0, -0.03 - i * 0.004), fin("bore"), 20)
			_cyl(r.root, br * 0.7, 0.0016, m + Vector3(0, 0, -0.1552), bore, 12)
			return 0.155
		"compensator":
			# A squared comp with three top ports.
			var size := maxf(br * 2.6, 0.022)
			_slab(r.root, [Vector2(m.z, m.y + size / 2.0), Vector2(m.z - 0.04, m.y + size / 2.0), Vector2(m.z - 0.045, m.y + size * 0.3),
					Vector2(m.z - 0.045, m.y - size / 2.0), Vector2(m.z, m.y - size / 2.0)], size, black, m.x, 0.002)
			for i in 3:
				_box(r.root, Vector3(size * 0.6, 0.0016, 0.006), m + Vector3(0, size / 2.0 + 0.0002, -0.01 - i * 0.012), bore, Vector3.ZERO, 0.0)
			return 0.045
		"muzzle_brake":
			# A tank-style brake: a block with big side windows.
			var w := maxf(br * 3.4, 0.03)
			_slab(r.root, [Vector2(m.z, m.y + br * 1.2), Vector2(m.z - 0.056, m.y + br * 1.2), Vector2(m.z - 0.06, m.y + br * 0.8),
					Vector2(m.z - 0.06, m.y - br * 1.2), Vector2(m.z, m.y - br * 1.2)], w, black, m.x, 0.002)
			for i in 3:
				_box(r.root, Vector3(w + 0.0012, br * 1.4, 0.009), m + Vector3(0, 0, -0.012 - i * 0.016), bore, Vector3.ZERO, 0.0)
			_cyl(r.root, br * 0.6, 0.0016, m + Vector3(0, 0, -0.0602), bore, 12)
			return 0.06
		"flash_hider":
			_turn(r.root, [Vector2(-0.05, br * 1.3), Vector2(-0.047, br * 1.5), Vector2(-0.008, br * 1.5), Vector2(0.0, br * 1.25)], m, black, 16)
			for i in 4:
				var ang := TAU * i / 4.0 + PI / 4.0
				_box(r.root, Vector3(0.0018, 0.004, 0.03), m + Vector3(cos(ang), sin(ang), 0) * br * 1.5 + Vector3(0, 0, -0.03), bore,
						Vector3(0, 0, rad_to_deg(ang) + 90.0), 0.0)
			_cyl(r.root, br * 0.9, 0.0016, m + Vector3(0, 0, -0.0502), bore, 12)
			return 0.05
		"thread_adapter":
			_turn(r.root, [Vector2(-0.02, br * 1.2), Vector2(-0.004, br * 1.2), Vector2(-0.004, br * 1.4), Vector2(0.0, br * 1.4)], m, fin("bare"), 16)
			return 0.02
		"linear_comp":
			_turn(r.root, [Vector2(-0.05, br * 1.6), Vector2(-0.048, br * 2.0), Vector2(-0.006, br * 2.0), Vector2(0.0, br * 1.4)], m, black, 18)
			for i in 6:
				var ang := TAU * i / 6.0
				_cyl_x(r.root, 0.0025, 0.002, m + Vector3(cos(ang), sin(ang), 0) * br * 2.0 + Vector3(0, 0, -0.012), bore, 8).rotation_degrees = Vector3(0, 90, rad_to_deg(ang))
			_cyl(r.root, br * 1.4, 0.0016, m + Vector3(0, 0, -0.0502), bore, 12)
			return 0.05
		"solvent_trap":
			# A ribbed aluminium tube with cups inside, in sand cerakote.
			var rad := maxf(br * 2.0, 0.019)
			_turn(r.root, [Vector2(-0.18, rad * 0.7), Vector2(-0.176, rad), Vector2(-0.02, rad), Vector2(-0.016, br * 1.3), Vector2(0.0, br * 1.3)],
					m, fin("sand"), 20)
			for i in 6:
				_turn(r.root, [Vector2(-0.002, rad * 1.04), Vector2(0.002, rad * 1.04)], m + Vector3(0, 0, -0.035 - i * 0.025), fin("black"), 20)
			return 0.18
		"bottle_can":
			# A clear bottle over the muzzle: glass, a rubber collar.
			var rad := maxf(br * 2.8, 0.03)
			_lathe_z(r.root, [Vector2(0.0, -0.22), Vector2(rad * 0.8, -0.218), Vector2(rad, -0.2), Vector2(rad, -0.06),
					Vector2(rad * 0.4, -0.02), Vector2(br * 1.4, 0.0), Vector2(0.0, 0.002)], m, fin("glass"), 10)
			_turn(r.root, [Vector2(-0.03, br * 1.6), Vector2(0.0, br * 1.6)], m, fin("rubber"), 16)
			return 0.22
		"choke":
			_turn(r.root, [Vector2(-0.055, br * 0.95), Vector2(-0.052, br * 1.3), Vector2(-0.006, br * 1.3), Vector2(0.0, br * 1.1)], m, fin("bare"), 18)
			for i in 6:
				var ang := TAU * i / 6.0
				_box(r.root, Vector3(0.002, 0.002, 0.012), m + Vector3(cos(ang), sin(ang), 0) * br * 1.31 + Vector3(0, 0, -0.012), black,
						Vector3(0, 0, rad_to_deg(ang)), 0.0)
			return 0.055
		"duckbill":
			_slab(r.root, [Vector2(m.z, m.y + br * 1.1), Vector2(m.z - 0.05, m.y + br * 0.5), Vector2(m.z - 0.055, m.y + br * 0.4),
					Vector2(m.z - 0.055, m.y - br * 0.4), Vector2(m.z - 0.05, m.y - br * 0.5), Vector2(m.z, m.y - br * 1.1)], br * 4.0, black, m.x, 0.002)
			_box(r.root, Vector3(br * 3.4, br * 0.35, 0.0016), m + Vector3(0, 0, -0.0552), bore, Vector3.ZERO, 0.0)
			return 0.055
		"breacher":
			_turn(r.root, [Vector2(-0.03, br * 1.5), Vector2(0.0, br * 1.5)], m, black, 16)
			for i in 6:
				var ang := TAU * i / 6.0
				_rod(r.root, 0.0, 0.004, 0.016, m + Vector3(cos(ang) * br * 1.3, sin(ang) * br * 1.3, -0.036), fin("bare"), 4)
			return 0.044
		"wide_nozzle":
			_lathe_z(r.root, [Vector2(0.0, -0.075), Vector2(0.05, -0.074), Vector2(0.05, -0.068), Vector2(0.022, -0.02), Vector2(0.018, 0.0),
					Vector2(0.0, 0.002)], m, fin("copper"), 12)
			return 0.075
		"long_nozzle":
			_turn(r.root, [Vector2(-0.18, 0.012), Vector2(0.0, 0.016)], m + Vector3(0, 0, 0.0), fin("bare"), 14)
			_turn(r.root, [Vector2(-0.2, 0.014), Vector2(-0.18, 0.02), Vector2(-0.175, 0.012)], m, fin("copper"), 14)
			_turn(r.root, [Vector2(-0.075, 0.017), Vector2(-0.065, 0.017)], m, fin("sulfur"), 14)
			return 0.2
	_generic(r, m + Vector3(0, 0, -0.015), id)
	return 0.03


## A quick-detach can slid over the muzzle device (flash hider, brake, adapter): its back
## collar locks behind the device and it reaches well past it. The Muzzle moves to its end.
static func _silencer(r: Rig, id: String) -> void:
	var back: Vector3 = r.device_start if r.device_start != Vector3.INF else r.muzzle
	var br := maxf(r.barrel_r, 0.008)
	var length := maxf(_part_len(id, 0.14), r.device_len + 0.04)
	var rad := maxf(br * 2.3, 0.02)
	var body := fin("black")
	match id:
		"can_light":
			body = fin("steel")
		"can_heavy":
			rad = maxf(br * 2.8, 0.025)
			body = fin("green")
		"can_titanium":
			rad = maxf(br * 2.1, 0.018)
			body = fin("bare")
		"can_wet":
			body = fin("black")
		_:
			body = fin("oxide")
	if r.twin > 0.0:
		rad = minf(rad, r.twin * 0.98)
	var xs: Array = [0.0] if r.twin <= 0.0 else [-r.twin, r.twin]
	for x: float in xs:
		var b := back + Vector3(x, 0, 0)
		# Body with a stepped front cap, a QD collar with a ratchet ring at the back.
		_turn(r.root, [Vector2(-length, rad * 0.4), Vector2(-length + 0.002, rad * 0.78), Vector2(-length + 0.008, rad * 0.86),
				Vector2(-length + 0.01, rad), Vector2(-0.024, rad), Vector2(-0.022, rad * 1.08), Vector2(0.0, rad * 1.08)], b, body, 22)
		for i in 8:
			var ang := TAU * i / 8.0
			_box(r.root, Vector3(0.0016, 0.0024, 0.018), b + Vector3(cos(ang), sin(ang), 0) * rad * 1.08 + Vector3(0, 0, -0.011), fin("bore"),
					Vector3(0, 0, rad_to_deg(ang) + 90.0), 0.0)
		_cyl(r.root, br * 0.7, 0.0016, b + Vector3(0, 0, -length - 0.0002), fin("bore"), 12)
		match id:
			"can_light":
				_box(r.root, Vector3(0.004, 0.008, 0.012), b + Vector3(rad, 0, -0.012), fin("oxide"), Vector3.ZERO, 0.001)
			"can_heavy":
				for i in 5:
					_turn(r.root, [Vector2(-0.002, rad * 1.025), Vector2(0.002, rad * 1.025)], b + Vector3(0, 0, -length * 0.3 - i * 0.012), fin("black"), 22)
			"can_titanium":
				for i in 3:
					_turn(r.root, [Vector2(-0.0012, rad * 1.012), Vector2(0.0012, rad * 1.012)], b + Vector3(0, 0, -0.04 - i * 0.014), fin("copper"), 22)
			"can_wet":
				_cyl_y(r.root, 0.004, 0.012, b + Vector3(0, rad + 0.004, -length * 0.5), fin("sulfur"), 10)
			"echo_can":
				# Skewed baffles show through a side window; a brass ring at the front.
				for i in 4:
					_box(r.root, Vector3(0.003, rad * 1.5, 0.0025), b + Vector3(rad * 0.98, 0, -0.03 - i * 0.022), fin("brass"), Vector3(0, 0, 20), 0.0)
				_turn(r.root, [Vector2(-0.003, rad * 1.03), Vector2(0.003, rad * 1.03)], b + Vector3(0, 0, -length + 0.008), fin("brass"), 22)
	r.muzzle = Vector3(0, back.y, back.z - length - 0.002)


## Gas parts: a cue on the gas block. Under a handguard the knob or rod sticks out the side.
static func _gas(r: Rig, id: String) -> void:
	var g := r.gas
	var br := maxf(r.barrel_r, 0.008)
	var out := r.hg_r + 0.006
	match id:
		"adjustable_gas":
			_rod(r.root, br * 1.9, br * 1.9, 0.026, g, mat("panel", DARK), 6)
			_rod_between(r.root, g, g + Vector3(-out, 0, 0), 0.004, mat("panel", STEEL))
			var knob := _disc_x(r.root, 0.009, 0.006, g + Vector3(-out, 0, 0), mat("panel", RED), 6)
			knob.rotation_degrees.x = float(r.tune.get("gas", 0.0)) * 60.0
			_box(r.root, Vector3(0.007, 0.002, 0.012), g + Vector3(-out - 0.0035, 0, 0), mat("panel", BONE), Vector3(float(r.tune.get("gas", 0.0)) * 60.0, 0, 0), 0.0)
		"low_profile_gas":
			_rod(r.root, br * 1.5, br * 1.5, 0.018, g, mat("panel", BLACK), 6)
			_box(r.root, Vector3(0.005, 0.004, 0.006), g + Vector3(0, -br * 1.5, 0), mat("panel", STEEL), Vector3.ZERO, 0.0)
		"piston_kit":
			_box(r.root, Vector3(br * 2.6, br * 3.4, 0.032), g + Vector3(0, br * 0.6, 0), mat("panel", STEEL), Vector3.ZERO, 0.003)
			_rod(r.root, br * 0.9, br * 0.9, 0.02, g + Vector3(0, br * 1.5, -0.02), mat("panel", NICKEL), 6)
			_box(r.root, Vector3(0.006, 0.008, 0.05), g + Vector3(out - 0.002, 0, 0.03), mat("panel", NICKEL), Vector3.ZERO, 0.001)
		_:
			_generic(r, g, id)


## A handguard round the barrel from hg_start, bringing its own rail, grip and underbarrel spots.
static func _handguard(r: Rig, id: String) -> void:
	var a := r.hg_start
	var b := r.hg_end
	var y := r.hg_y
	var hr := r.hg_r
	var outer := hr
	match id:
		"short_handguard":
			b = lerpf(a, b, 0.62)
			GunFrames._mlok_tube(r, y, a, b, hr, fin("black"))
		"long_handguard":
			b = minf(b, lerpf(a, r.muzzle.z, 0.82))
			GunFrames._mlok_tube(r, y, a, b, hr + 0.002, fin("poly_tan"))
			outer = hr + 0.002
		"quad_rail":
			var len := absf(b - a)
			var oct := GunKit.turned(PackedVector2Array([Vector2(-len / 2.0, hr * 0.85), Vector2(-len / 2.0 + 0.003, hr * 0.95),
					Vector2(len / 2.0, hr * 0.95)]), 8)
			_put(r.root, oct, Vector3(0, y, (a + b) / 2.0), fin("black"), Vector3(0, 0, 22.5))
			for roll: float in [0.0, 90.0, -90.0, 180.0]:
				var dir := Vector3(0, 1, 0).rotated(Vector3(0, 0, 1), deg_to_rad(roll))
				_pic(r, Vector3(0, y, (a + b) / 2.0) + dir * hr * 0.9, len - 0.006, roll, 0.019)
			_turn(r.root, [Vector2(-0.006, hr * 1.05), Vector2(0.006, hr * 1.05)], Vector3(0, y, a - 0.006), fin("black"), 16)
			outer = hr * 0.9 + 0.007
		"wood_handguard":
			# Laminate furniture: a two-piece guard held by a pair of steel bands.
			_turn(r.root, [Vector2(-absf(b - a), hr * 0.9), Vector2(-absf(b - a) + 0.006, hr + 0.003), Vector2(-0.004, hr + 0.003),
					Vector2(0.0, hr * 0.92)], Vector3(0, y, a), fin("laminate"), 14)
			for z: float in [a - 0.006, b + 0.006]:
				_turn(r.root, [Vector2(-0.004, hr + 0.0045), Vector2(0.004, hr + 0.0045)], Vector3(0, y, z), fin("steel"), 16)
			_seam(r, Vector2(a, y), Vector2(b, y), hr + 0.0028)
			outer = hr + 0.003
		"heatshield":
			_turn(r.root, [Vector2(-absf(b - a), hr + 0.002), Vector2(0.0, hr + 0.002)], Vector3(0, y, a), fin("steel"), 16)
			var holes := int(absf(b - a) / 0.016)
			for i in holes:
				for ang: float in [40.0, 90.0, 140.0, 220.0, 320.0]:
					var dir := Vector3(cos(deg_to_rad(ang)), sin(deg_to_rad(ang)), 0)
					var hole := _cyl_x(r.root, 0.004, 0.0015, Vector3(0, y, a - 0.01 - i * 0.016 - (0.008 if int(ang) % 80 == 0 else 0.0)) + dir * (hr + 0.0022),
							fin("bore"), 8)
					hole.rotation_degrees = Vector3(0, 90, ang)
			for z: float in [a, b, (a + b) / 2.0]:
				_turn(r.root, [Vector2(-0.004, hr + 0.004), Vector2(0.004, hr + 0.004)], Vector3(0, y, z), fin("black"), 16)
			_pic(r, Vector3(0, y + hr * 0.95, lerpf(a, b, 0.25)), absf(b - a) * 0.4)
			outer = hr + 0.002
		"pump_rail":
			# A railed pump: a squared polymer forend with grip ribs, rails left and under.
			var len := absf(b - a)
			_slab(r.root, [Vector2(a, y + hr * 0.9), Vector2(b, y + hr * 0.9), Vector2(b - 0.004, y), Vector2(b, y - hr), Vector2(a, y - hr),
					Vector2(a + 0.004, y)], hr * 2.1, fin("polymer"), 0.0, 0.004)
			for i in 6:
				_box(r.root, Vector3(hr * 2.1 + 0.001, 0.003, 0.004), Vector3(0, y - hr * 0.3, a - 0.012 - i * len / 7.0), fin("bore"), Vector3.ZERO, 0.0)
			_pic(r, Vector3(-hr * 1.05, y, (a + b) / 2.0), len - 0.02, 90.0, 0.018)
			_pic(r, Vector3(0, y - hr, (a + b) / 2.0), len - 0.02, 180.0, 0.018)
			outer = hr * 1.05 + 0.007
		"vent_handguard":
			# A round handguard bristling with heat-sink fins all along it.
			GunFrames._mlok_tube(r, y, a, b, hr + 0.002, fin("black"))
			outer = hr + 0.012
			var count := int((a - b) / 0.012)
			for i in count:
				var z := a - 0.008 - i * 0.012
				_turn(r.root, [Vector2(-0.002, hr + 0.012), Vector2(0.002, hr + 0.012)], Vector3(0, y, z), fin("bare"), 18)
		_:
			GunFrames._mlok_tube(r, y, a, b, hr + 0.002, fin("oxide"))
	r.hg_end = b
	r.rail_l = Vector3(-(outer + 0.001), y, lerpf(a, b, 0.62))
	r.rail_r = Vector3(outer + 0.001, y, lerpf(a, b, 0.62))
	r.foregrip = Vector3(0, y - outer, lerpf(a, b, 0.42))
	r.under = Vector3(0, y - outer, lerpf(a, b, 0.92))


## M-LOK slots down both sides and the bottom of a handguard tube.
static func _mlok(r: Rig, a: float, b: float, y: float, hr: float) -> void:
	var count := int(absf(b - a) / 0.045)
	for i in count:
		var z := lerpf(a, b, (i + 0.5) / count)
		for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, -1, 0)]:
			var size := Vector3(0.003, 0.007, 0.022) if d.y == 0.0 else Vector3(0.007, 0.003, 0.022)
			_box(r.root, size, Vector3(0, y, z) + d * hr * 0.97, mat("panel", BLACK), Vector3.ZERO, 0.0)


## Rail accessories: they clamp to the left or right rail and stick out sideways (or hang
## under a pistol's dust cover).
static func _rail_part(r: Rig, slot: String, id: String) -> void:
	var a: Vector3 = r.rail_l if slot == "rail_l" else r.rail_r
	if slot == "rail_r" and r.rail_r.x == 0.0 and r.rail_l.x == 0.0:
		a += Vector3(0, -0.02, 0)
	var side := absf(a.x) > 0.001
	var dir := Vector3(signf(a.x), 0, 0) if side else Vector3(0, -1, 0)
	var clamp_size := Vector3(0.008, 0.016, 0.022) if side else Vector3(0.016, 0.008, 0.022)
	var black := fin("black")
	_box(r.root, clamp_size, a + dir * 0.004, black, Vector3.ZERO, 0.0015)
	var c := a + dir * 0.017
	var beam := fin("dust", Color(1.0, 0.95, 0.75) * 1.2)
	match id:
		"flashlight", "strobe_light":
			# A weapon light: knurled body, a stepped head, tail cap; the strobe has a crenellated bezel.
			var big := id == "strobe_light"
			var hr := 0.017 if big else 0.015
			_turn(r.root, [Vector2(-0.05, hr), Vector2(-0.045, hr), Vector2(-0.03, 0.011), Vector2(0.035, 0.011), Vector2(0.038, 0.0095),
					Vector2(0.045, 0.0095)], c + Vector3(0, 0, 0.004), black, 20)
			for i in 5:
				_turn(r.root, [Vector2(-0.0012, 0.0114), Vector2(0.0012, 0.0114)], c + Vector3(0, 0, -0.01 + i * 0.008), fin("bore"), 20)
			_cyl(r.root, hr - 0.002, 0.002, c + Vector3(0, 0, -0.0465), beam, 20)
			if big:
				for i in 6:
					var ang := TAU * i / 6.0
					_box(r.root, Vector3(0.004, 0.004, 0.005), c + Vector3(cos(ang), sin(ang), 0) * hr + Vector3(0, 0, -0.048), black, Vector3(0, 0, rad_to_deg(ang)), 0.0)
				_turn(r.root, [Vector2(-0.003, 0.0118), Vector2(0.003, 0.0118)], c + Vector3(0, 0, 0.02), fin("oxide"), 20)
		"laser", "laser_ir":
			var ir := id == "laser_ir"
			_slab(r.root, [Vector2(c.z + 0.026, c.y + 0.01), Vector2(c.z - 0.024, c.y + 0.01), Vector2(c.z - 0.028, c.y + 0.004),
					Vector2(c.z - 0.028, c.y - 0.01), Vector2(c.z + 0.026, c.y - 0.01)], 0.02, fin("green") if ir else black, c.x, 0.003)
			_cyl(r.root, 0.004, 0.002, c + Vector3(0, 0.003, -0.0285), fin("bore", Color(0.18, 0.0, 0.08) if ir else Color(1.0, 0.05, 0.05) * 1.4), 12)
			_cyl_y(r.root, 0.0035, 0.004, c + Vector3(0, 0.011, 0.01), fin("rubber"), 10)
		"combo_light":
			_slab(r.root, [Vector2(c.z + 0.032, c.y + 0.013), Vector2(c.z - 0.03, c.y + 0.013), Vector2(c.z - 0.034, c.y + 0.008),
					Vector2(c.z - 0.034, c.y - 0.013), Vector2(c.z + 0.032, c.y - 0.013)], 0.026, fin("poly_tan"), c.x + dir.x * 0.003, 0.004)
			_cyl(r.root, 0.009, 0.002, c + dir * 0.003 + Vector3(0, 0.004, -0.0345), beam, 18)
			_cyl(r.root, 0.003, 0.002, c + dir * 0.003 + Vector3(0, -0.008, -0.0345), fin("bore", Color(1.0, 0.05, 0.05) * 1.4), 10)
		"rail_counter":
			_slab(r.root, [Vector2(c.z + 0.015, c.y + 0.009), Vector2(c.z - 0.015, c.y + 0.009), Vector2(c.z - 0.015, c.y - 0.009),
					Vector2(c.z + 0.015, c.y - 0.009)], 0.016, black, c.x - dir.x * 0.005, 0.002)
			_box(r.root, Vector3(0.012, 0.002, 0.02), c - dir * 0.005 + Vector3(0, 0.0095, 0.002), fin("bore", Color(0.2, 0.9, 0.3)), Vector3.ZERO, 0.0)
		"dash_feed":
			# A spring-loaded side feeder: a short rounds tube on a coil, with a brass cap.
			var tube_at := c + dir * 0.002
			_cyl(r.root, 0.007, 0.06, tube_at, fin("black"), 12)
			_cyl(r.root, 0.0075, 0.004, tube_at + Vector3(0, 0, -0.03), fin("brass"), 12)
			for i in 4:
				_turn(r.root, [Vector2(-0.001, 0.008), Vector2(0.001, 0.008)], tube_at + Vector3(0, 0, -0.016 + i * 0.01), fin("sulfur"), 12)
		_:
			_generic(r, c, id)


## Foregrips and bipods hang from the bottom of the handguard.
static func _foregrip(r: Rig, id: String) -> void:
	var f := r.foregrip
	var black := fin("black")
	_box(r.root, Vector3(0.016, 0.006, 0.026), f + Vector3(0, -0.003, 0), black, Vector3.ZERO, 0.0012)
	match id:
		"vertical_grip":
			_slab(r.root, [Vector2(f.z + 0.012, f.y - 0.004), Vector2(f.z - 0.014, f.y - 0.004), Vector2(f.z - 0.016, f.y - 0.05),
					Vector2(f.z - 0.012, f.y - 0.085), Vector2(f.z + 0.012, f.y - 0.085), Vector2(f.z + 0.014, f.y - 0.05)], 0.024, fin("polymer"), 0.0, 0.005)
			_slab(r.root, [Vector2(f.z + 0.013, f.y - 0.085), Vector2(f.z - 0.013, f.y - 0.085), Vector2(f.z - 0.013, f.y - 0.091),
					Vector2(f.z + 0.013, f.y - 0.091)], 0.025, fin("oxide"), 0.0, 0.002)
			for i in 4:
				_box(r.root, Vector3(0.0252, 0.0016, 0.022), f + Vector3(0, -0.025 - i * 0.014, 0), fin("rubber"), Vector3.ZERO, 0.0)
		"angled_grip":
			_slab(r.root, [Vector2(f.z + 0.035, f.y - 0.004), Vector2(f.z - 0.06, f.y - 0.004), Vector2(f.z - 0.045, f.y - 0.018), Vector2(f.z + 0.02, f.y - 0.044),
					Vector2(f.z + 0.034, f.y - 0.04)], 0.022, fin("poly_tan"), 0.0, 0.004)
		"stubby_grip":
			_slab(r.root, [Vector2(f.z + 0.012, f.y - 0.004), Vector2(f.z - 0.012, f.y - 0.004), Vector2(f.z - 0.013, f.y - 0.042),
					Vector2(f.z + 0.013, f.y - 0.042)], 0.024, fin("polymer"), 0.0, 0.006)
		"handstop":
			_slab(r.root, [Vector2(f.z + 0.014, f.y - 0.004), Vector2(f.z - 0.014, f.y - 0.004), Vector2(f.z + 0.006, f.y - 0.026),
					Vector2(f.z + 0.016, f.y - 0.024)], 0.018, black, 0.0, 0.003)
		"bipod", "grip_pod":
			var big := float(Arsenal.frame(r.frame).get("length", 80.0)) / 100.0
			var leg := clampf(big * 0.2, 0.1, 0.3)
			if id == "grip_pod":
				_slab(r.root, [Vector2(f.z + 0.013, f.y - 0.004), Vector2(f.z - 0.013, f.y - 0.004), Vector2(f.z - 0.014, f.y - 0.088),
						Vector2(f.z + 0.014, f.y - 0.088)], 0.026, fin("polymer"), 0.0, 0.006)
				leg = 0.035
				f += Vector3(0, -0.085, 0)
			else:
				_slab(r.root, [Vector2(f.z + 0.014, f.y - 0.004), Vector2(f.z - 0.014, f.y - 0.004), Vector2(f.z - 0.014, f.y - 0.022),
						Vector2(f.z + 0.014, f.y - 0.022)], 0.032, black, 0.0, 0.003)
				f += Vector3(0, -0.016, 0)
			# Two legs splayed out and forward, telescoping, with rubber feet.
			for sx: float in [-1.0, 1.0]:
				var foot := f + Vector3(sx * leg * 0.45, -leg * 0.85, -leg * 0.3)
				_rod_between(r.root, f + Vector3(sx * 0.008, 0, 0), foot, 0.0045 if id == "grip_pod" else 0.0055, black, 10)
				_rod_between(r.root, (f + Vector3(sx * 0.008, 0, 0)).lerp(foot, 0.55), foot, 0.0036, fin("bare"), 10)
				_ball(r.root, 0.006, foot, fin("rubber"), Vector3(1, 0.6, 1.2))
		"riot_foregrip":
			# A vertical grip with a small steel plate in front of the hand, a slot cut in it.
			_slab(r.root, [Vector2(f.z + 0.012, f.y - 0.004), Vector2(f.z - 0.012, f.y - 0.004), Vector2(f.z - 0.012, f.y - 0.075),
					Vector2(f.z + 0.012, f.y - 0.075)], 0.022, fin("polymer"), 0.0, 0.004)
			_box(r.root, Vector3(0.09, 0.08, 0.006), f + Vector3(0, -0.04, -0.026), fin("steel"), Vector3(-6, 0, 0), 0.002)
			_box(r.root, Vector3(0.05, 0.008, 0.007), f + Vector3(0, -0.012, -0.0265), fin("bore"), Vector3(-6, 0, 0), 0.0)
			_box(r.root, Vector3(0.092, 0.01, 0.0065), f + Vector3(0, -0.078, -0.026), fin("sulfur"), Vector3(-6, 0, 0), 0.001)
		_:
			_generic(r, f + Vector3(0, -0.015, 0), id)


static func _underbarrel(r: Rig, id: String) -> void:
	var u := r.under
	match id:
		"bayonet", "spike_bayonet":
			# The lug clamps round the barrel just behind the bare muzzle (or at the handguard tip).
			var mount := Vector3(u.x, u.y, minf(u.z, r.barrel_end.z + 0.07))
			var lug_h := maxf(r.barrel_end.y - mount.y, 0.0) + 0.016
			_box(r.root, Vector3(0.012, lug_h, 0.03), Vector3(0, mount.y + lug_h / 2.0 - 0.01, mount.z), mat("panel", DARK))
			var blade_start := mount + Vector3(0, -0.006, -0.02)
			var reach := clampf(blade_start.z - r.barrel_end.z + 0.09, 0.1, 0.2)
			if id == "bayonet":
				_profile(r.root, [Vector2(0.0, 0.006), Vector2(reach * 0.85, 0.006), Vector2(reach, 0.0), Vector2(reach * 0.8, -0.012),
						Vector2(0.0, -0.01)], 0.004, blade_start, mat("panel", Color(0.9, 0.93, 0.98)))
			else:
				reach = clampf(blade_start.z - r.barrel_end.z + 0.2, 0.2, 0.32)
				_rod(r.root, 0.0, 0.006, reach, blade_start + Vector3(0, 0, -reach / 2.0), mat("panel", Color(0.8, 0.84, 0.9)), 3)
				_rod(r.root, 0.008, 0.008, 0.012, blade_start + Vector3(0, 0, -0.004), mat("panel", BLACK), 6)
		"chainsaw_bayonet":
			# A little two-stroke motor under the barrel with its bar and chain sticking forward.
			var body := u + Vector3(0, -0.028, 0.05)
			_box(r.root, Vector3(0.032, 0.04, 0.07), body, mat("panel", ORANGE), Vector3.ZERO, 0.006)
			_box(r.root, Vector3(0.02, 0.012, 0.04), body + Vector3(0, 0.026, 0), mat("panel", DARK), Vector3.ZERO, 0.002)
			_rod(r.root, 0.006, 0.006, 0.04, body + Vector3(0.019, 0, 0), mat("grate", Color(1.3, 1.3, 1.3)), 6)
			var bar_len := clampf(body.z - r.barrel_end.z - 0.02, 0.14, 0.24)
			var bar := body + Vector3(0, -0.004, -0.035 - bar_len / 2.0)
			_box(r.root, Vector3(0.006, 0.026, bar_len), bar, mat("panel", STEEL), Vector3.ZERO, 0.004)
			var teeth := int(bar_len / 0.012)
			for i in teeth:
				for sy: float in [-1.0, 1.0]:
					_box(r.root, Vector3(0.008, 0.005, 0.006), bar + Vector3(0, sy * 0.015, -bar_len / 2.0 + (i + 0.5) * bar_len / teeth),
							mat("panel", DARK), Vector3.ZERO, 0.0)
		"riot_shield":
			# A small plate hung under the barrel, with a slot to see through.
			var c := u + Vector3(0, -0.08, 0.0)
			_box(r.root, Vector3(0.2, 0.16, 0.01), c, mat("panel", Color(0.3, 0.32, 0.36)), Vector3(-6, 0, 0), 0.004)
			_box(r.root, Vector3(0.21, 0.02, 0.012), c + Vector3(0, 0.06, 0), mat("panel", YELLOW), Vector3(-6, 0, 0), 0.002)
			_box(r.root, Vector3(0.21, 0.012, 0.013), c + Vector3(0, 0.06, 0), mat("panel", BLACK), Vector3(-6, 0, 0), 0.0)
			_box(r.root, Vector3(0.012, 0.03, 0.03), u + Vector3(0, -0.008, 0.012), mat("panel", DARK), Vector3.ZERO, 0.002)
		"grappling_hook":
			# A launch tube under the barrel, a three-claw hook in its mouth, a coil of line behind.
			var c := u + Vector3(0, -0.022, 0.0)
			_box(r.root, Vector3(0.012, 0.02, 0.03), u + Vector3(0, -0.006, 0.01), fin("black"), Vector3.ZERO, 0.002)
			_turn(r.root, [Vector2(-0.07, 0.013), Vector2(-0.066, 0.016), Vector2(0.05, 0.016), Vector2(0.055, 0.012)], c, fin("black"), 16)
			_cyl(r.root, 0.004, 0.03, c + Vector3(0, 0, -0.08), fin("steel"), 10)
			for i in 3:
				var a := TAU * i / 3.0 + PI / 2.0
				var d := Vector3(cos(a), sin(a), 0)
				_tube(r.root, [c + Vector3(0, 0, -0.09), c + d * 0.016 + Vector3(0, 0, -0.088), c + d * 0.02 + Vector3(0, 0, -0.072),
						c + d * 0.014 + Vector3(0, 0, -0.064)], 0.0025, fin("steel"), 8)
			_cyl(r.root, 0.017, 0.022, c + Vector3(0, 0, 0.06), fin("sand"), 16)
			_cyl(r.root, 0.019, 0.003, c + Vector3(0, 0, 0.048), fin("black"), 16)
			_cyl(r.root, 0.019, 0.003, c + Vector3(0, 0, 0.072), fin("black"), 16)
		"jet_can":
			# A small extinguisher strapped under the barrel, nozzle forward, with a gauge.
			var c := u + Vector3(0, -0.03, 0.02)
			_turn(r.root, [Vector2(-0.07, 0.0), Vector2(-0.068, 0.012), Vector2(-0.058, 0.02), Vector2(0.05, 0.02), Vector2(0.056, 0.014),
					Vector2(0.058, 0.0)], c, fin("oxide"), 18)
			_turn(r.root, [Vector2(-0.1, 0.008), Vector2(-0.095, 0.006), Vector2(-0.07, 0.004)], c, fin("black"), 12)
			for z: float in [-0.03, 0.03]:
				_turn(r.root, [Vector2(-0.005, 0.021), Vector2(0.005, 0.021)], c + Vector3(0, 0, z), fin("black"), 18)
			_cyl_x(r.root, 0.007, 0.006, c + Vector3(0.02, 0.006, 0.0), fin("black"), 14)
			_cyl_x(r.root, 0.0055, 0.002, c + Vector3(0.024, 0.006, 0.0), fin("dust"), 14)
			_box(r.root, Vector3(0.012, 0.016, 0.02), u + Vector3(0, -0.006, 0.02), fin("black"), Vector3.ZERO, 0.002)
		"tracker_dart":
			# A slim dart tube under the barrel, three fletched darts clipped to its side.
			var c := u + Vector3(0, -0.022, 0.0)
			_cyl(r.root, 0.011, 0.12, c, fin("black"), 14)
			_turn(r.root, [Vector2(-0.066, 0.0125), Vector2(-0.06, 0.0125)], c, fin("sulfur"), 14)
			_cyl(r.root, 0.006, 0.002, c + Vector3(0, 0, -0.061), fin("bore"), 10)
			for i in 3:
				var d := c + Vector3(0.016, -0.006 + i * 0.006, 0.02)
				_cyl(r.root, 0.0018, 0.07, d, fin("chrome"), 6)
				_box(r.root, Vector3(0.006, 0.0008, 0.012), d + Vector3(0, 0, 0.03), fin("oxide"), Vector3.ZERO, 0.0)
			_box(r.root, Vector3(0.006, 0.02, 0.03), c + Vector3(0.012, 0, 0.02), fin("black"), Vector3.ZERO, 0.001)
			_box(r.root, Vector3(0.012, 0.026, 0.02), u + Vector3(0, -0.006, 0.02), fin("black"), Vector3.ZERO, 0.002)
		_:
			_generic(r, u + Vector3(0, -0.012, 0), id)


## Offset and backup sights on the top rail; risers and cantilevers move the main sight.
static func _mount(r: Rig, id: String) -> void:
	var m := r.mount
	var black := fin("black")
	match id:
		"canted_dot":
			# A mini dot on a 45° offset plate to the right.
			_slab(r.root, [Vector2(m.z + 0.012, m.y), Vector2(m.z - 0.012, m.y), Vector2(m.z - 0.012, m.y + 0.008), Vector2(m.z + 0.012, m.y + 0.008)],
					0.022, black, 0.0, 0.0012)
			var c := m + Vector3(0.024, 0.022, 0)
			_box(r.root, Vector3(0.03, 0.006, 0.022), m + Vector3(0.012, 0.012, 0), black, Vector3(0, 0, -45), 0.0012)
			_box(r.root, Vector3(0.022, 0.012, 0.028), c, black, Vector3(0, 0, -45), 0.002)
			_box(r.root, Vector3(0.02, 0.016, 0.004), c + Vector3(0.006, 0.006, -0.01), black, Vector3(0, 0, -45), 0.001)
			_box(r.root, Vector3(0.015, 0.011, 0.002), c + Vector3(0.006, 0.006, -0.0125), fin("lens"), Vector3(0, 0, -45), 0.0)
		"backup_irons":
			# Two flip-ups folded flat, one at each end of the rail.
			for k in 2:
				var at := m if k == 0 else r.top + Vector3(0, 0, 0.05)
				_slab(r.root, [Vector2(at.z + 0.012, at.y), Vector2(at.z - 0.012, at.y), Vector2(at.z - 0.01, at.y + 0.01), Vector2(at.z + 0.01, at.y + 0.01)],
						0.02, black, 0.0, 0.0012)
				_box(r.root, Vector3(0.016, 0.003, 0.022), at + Vector3(0, 0.0115, 0.002 if k == 0 else -0.002), fin("steel"), Vector3.ZERO, 0.0006)
		"cantilever":
			_slab(r.root, [Vector2(r.top.z + 0.035, r.top.y), Vector2(r.top.z - 0.015, r.top.y), Vector2(r.top.z - 0.02, r.top.y + 0.01),
					Vector2(r.top.z - 0.065, r.top.y + 0.01), Vector2(r.top.z - 0.065, r.top.y + 0.018), Vector2(r.top.z + 0.035, r.top.y + 0.018)],
					0.024, black, 0.0, 0.0015)
			r.top += Vector3(0, 0.012, -0.04)
			_pic(r, r.top + Vector3(0, -0.006, 0.02), 0.07)
		"riser":
			_slab(r.root, [Vector2(r.top.z + 0.03, r.top.y), Vector2(r.top.z - 0.03, r.top.y), Vector2(r.top.z - 0.03, r.top.y + 0.014),
					Vector2(r.top.z + 0.03, r.top.y + 0.014)], 0.024, black, 0.0, 0.0015)
			_box(r.root, Vector3(0.0244, 0.003, 0.03), r.top + Vector3(0, 0.007, 0), fin("oxide"), Vector3.ZERO, 0.0)
			r.top += Vector3(0, 0.02, 0)
			_pic(r, r.top + Vector3(0, -0.006, 0), 0.06)
		_:
			_generic(r, m + Vector3(0.015, 0.01, 0), id)


## Optics on the top rail: each has a mount, a machined housing and coated glass.
static func _sight(r: Rig, id: String) -> void:
	var t := r.top
	var black := fin("black")
	var lens := fin("lens")
	var bore := fin("bore")
	match id:
		"eagle_eye":
			# A long high-power scope with an oversized objective in an oxide ring.
			var c := t + Vector3(0, 0.032, 0)
			for z: float in [-0.03, 0.03]:
				_slab(r.root, [Vector2(t.z + z + 0.01, t.y), Vector2(t.z + z - 0.01, t.y), Vector2(t.z + z - 0.01, c.y), Vector2(t.z + z + 0.01, c.y)],
						0.02, black, 0.0, 0.001)
				_turn(r.root, [Vector2(-0.006, 0.0165), Vector2(0.006, 0.0165)], c + Vector3(0, 0, z), black, 20)
			_turn(r.root, [Vector2(-0.13, 0.03), Vector2(-0.126, 0.032), Vector2(-0.09, 0.032), Vector2(-0.06, 0.0145), Vector2(0.05, 0.0145),
					Vector2(0.07, 0.019), Vector2(0.1, 0.019), Vector2(0.104, 0.017)], c, black, 24)
			_turn(r.root, [Vector2(-0.124, 0.0325), Vector2(-0.11, 0.0325)], c, fin("oxide"), 24)
			_cyl(r.root, 0.029, 0.002, c + Vector3(0, 0, -0.128), lens, 22)
			_cyl(r.root, 0.017, 0.002, c + Vector3(0, 0, 0.103), lens, 18)
			_cyl_y(r.root, 0.009, 0.014, c + Vector3(0, 0.02, 0.0), black, 14)
			_cyl_x(r.root, 0.009, 0.014, c + Vector3(0.02, 0.0, 0.0), black, 14)
			r.top = c + Vector3(0, 0.032, 0)
		"sky_sight":
			# A reflex pane tilted back hard on an open frame: only lines up when you're airborne.
			var black_m := black
			_slab(r.root, [Vector2(t.z + 0.025, t.y), Vector2(t.z - 0.025, t.y), Vector2(t.z - 0.022, t.y + 0.008), Vector2(t.z + 0.022, t.y + 0.008)],
					0.026, black_m, 0.0, 0.0015)
			for sx: float in [-1.0, 1.0]:
				_slab(r.root, [Vector2(t.z + 0.012, t.y + 0.006), Vector2(t.z - 0.02, t.y + 0.006), Vector2(t.z - 0.004, t.y + 0.04),
						Vector2(t.z + 0.008, t.y + 0.04)], 0.004, black_m, sx * 0.013, 0.0008)
			_box(r.root, Vector3(0.022, 0.03, 0.002), t + Vector3(0, 0.024, -0.004), fin("glass"), Vector3(-35, 0, 0), 0.0)
			_box(r.root, Vector3(0.024, 0.004, 0.012), t + Vector3(0, 0.042, 0.004), fin("sulfur"), Vector3.ZERO, 0.001)
			_ball(r.root, 0.0016, t + Vector3(0, 0.024, -0.004), fin("bore", Color(1.0, 0.12, 0.05) * 1.5))
		"red_dot":
			# A closed tube dot on a QD mount.
			_slab(r.root, [Vector2(t.z + 0.026, t.y), Vector2(t.z - 0.026, t.y), Vector2(t.z - 0.022, t.y + 0.012), Vector2(t.z + 0.022, t.y + 0.012)],
					0.022, black, 0.0, 0.0015)
			_cyl_x(r.root, 0.006, 0.006, t + Vector3(0.013, 0.006, 0.008), black, 12)
			var c := t + Vector3(0, 0.03, 0)
			_turn(r.root, [Vector2(-0.032, 0.016), Vector2(-0.028, 0.018), Vector2(-0.02, 0.018), Vector2(-0.018, 0.0155), Vector2(0.02, 0.0155),
					Vector2(0.022, 0.017), Vector2(0.03, 0.017), Vector2(0.032, 0.015)], c, black, 22)
			_cyl(r.root, 0.0158, 0.002, c + Vector3(0, 0, -0.028), lens, 20)
			_cyl(r.root, 0.0145, 0.002, c + Vector3(0, 0, 0.028), lens, 20)
			_ball(r.root, 0.0018, c + Vector3(0, 0, -0.026), fin("bore", Color(1.0, 0.12, 0.05) * 1.5))
			_cyl_y(r.root, 0.006, 0.008, c + Vector3(0, 0.019, 0.0), black, 12)
			_cyl_x(r.root, 0.006, 0.008, c + Vector3(0.019, 0.0, 0.0), black, 12)
			_slab(r.root, [Vector2(c.z + 0.012, c.y - 0.014), Vector2(c.z - 0.012, c.y - 0.014), Vector2(c.z - 0.012, t.y + 0.01), Vector2(c.z + 0.012, t.y + 0.01)],
					0.014, black, 0.0, 0.001)
		"peep_sight":
			_slab(r.root, [Vector2(t.z + 0.014, t.y), Vector2(t.z - 0.014, t.y), Vector2(t.z - 0.01, t.y + 0.022), Vector2(t.z + 0.008, t.y + 0.022)],
					0.014, black, 0.0, 0.0015)
			_turn(r.root, [Vector2(-0.003, 0.0085), Vector2(0.003, 0.0085)], t + Vector3(0, 0.03, 0.002), black, 18)
			_cyl(r.root, 0.0032, 0.0064, t + Vector3(0, 0.03, 0.002), bore, 12)
		"pistol_dot":
			# A shielded mini dot milled flat to the slide.
			_slab(r.root, [Vector2(t.z + 0.016, t.y), Vector2(t.z - 0.016, t.y), Vector2(t.z - 0.016, t.y + 0.006), Vector2(t.z - 0.012, t.y + 0.022),
					Vector2(t.z - 0.008, t.y + 0.022), Vector2(t.z - 0.006, t.y + 0.008), Vector2(t.z + 0.008, t.y + 0.008), Vector2(t.z + 0.012, t.y + 0.018),
					Vector2(t.z + 0.016, t.y + 0.018)], 0.022, black, 0.0, 0.0012)
			_box(r.root, Vector3(0.017, 0.012, 0.002), t + Vector3(0, 0.015, -0.0085), lens, Vector3(-18, 0, 0), 0.0)
			_ball(r.root, 0.0016, t + Vector3(0, 0.015, -0.01), fin("bore", Color(1.0, 0.12, 0.05) * 1.5))
		"holo":
			# A box sight with a big window under a hood, buttons at the back.
			_slab(r.root, [Vector2(t.z + 0.035, t.y), Vector2(t.z - 0.035, t.y), Vector2(t.z - 0.035, t.y + 0.022), Vector2(t.z + 0.035, t.y + 0.022)],
					0.034, black, 0.0, 0.003)
			_slab(r.root, [Vector2(t.z + 0.012, t.y + 0.022), Vector2(t.z - 0.034, t.y + 0.022), Vector2(t.z - 0.034, t.y + 0.058),
					Vector2(t.z - 0.03, t.y + 0.062), Vector2(t.z + 0.012, t.y + 0.062), Vector2(t.z + 0.012, t.y + 0.058), Vector2(t.z - 0.028, t.y + 0.056),
					Vector2(t.z - 0.028, t.y + 0.026), Vector2(t.z + 0.012, t.y + 0.026)], 0.036, black, 0.0, 0.0012)
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.003, 0.034, 0.04), t + Vector3(sx * 0.0165, 0.042, -0.011), black, Vector3.ZERO, 0.0008)
			_box(r.root, Vector3(0.029, 0.03, 0.002), t + Vector3(0, 0.042, -0.03), lens, Vector3.ZERO, 0.0)
			_box(r.root, Vector3(0.029, 0.03, 0.002), t + Vector3(0, 0.042, 0.01), lens, Vector3.ZERO, 0.0)
			_tube(r.root, _ring(t + Vector3(0, 0.042, -0.031), 0.007, 12), 0.0008, fin("bore", Color(1.0, 0.15, 0.05) * 1.4), 6)
			for i in 2:
				_cyl_y(r.root, 0.003, 0.004, t + Vector3(-0.006 + i * 0.012, 0.024, 0.026), fin("rubber"), 10)
		"acog":
			# A short prism scope on a flat-top mount, a sulfur fibre on top.
			var c := t + Vector3(0, 0.034, 0.0)
			_slab(r.root, [Vector2(t.z + 0.028, t.y), Vector2(t.z - 0.028, t.y), Vector2(t.z - 0.022, t.y + 0.022), Vector2(t.z + 0.022, t.y + 0.022)],
					0.024, black, 0.0, 0.002)
			_turn(r.root, [Vector2(-0.052, 0.019), Vector2(-0.05, 0.021), Vector2(-0.03, 0.021), Vector2(-0.016, 0.015), Vector2(0.03, 0.015),
					Vector2(0.04, 0.0135), Vector2(0.046, 0.0135), Vector2(0.048, 0.012)], c, fin("poly_tan"), 22)
			_cyl(r.root, 0.0195, 0.002, c + Vector3(0, 0, -0.05), lens, 22)
			_cyl(r.root, 0.012, 0.002, c + Vector3(0, 0, 0.047), lens, 18)
			_cyl(r.root, 0.0025, 0.04, c + Vector3(0, 0.0165, 0.006), fin("sulfur", Color(0.35, 0.3, 0.05)), 8)
			_cyl_y(r.root, 0.006, 0.006, c + Vector3(0, 0.016, -0.014), black, 12)
		"scope", "variable_scope":
			# A 30 mm tube in two rings: objective bell, turrets, the eyepiece. The LPVO adds a
			# magnification ring with its throw lever.
			var long := id == "variable_scope"
			var c := t + Vector3(0, 0.034, 0.0)
			for z: float in [-0.03, 0.03]:
				_slab(r.root, [Vector2(t.z + z + 0.008, t.y), Vector2(t.z + z - 0.008, t.y), Vector2(t.z + z - 0.008, c.y),
						Vector2(t.z + z + 0.008, c.y)], 0.02, black, 0.0, 0.0015)
				_turn(r.root, [Vector2(-0.008, 0.0145), Vector2(0.008, 0.0145)], c + Vector3(0, 0, z), black, 22)
			var obj := 0.024 if long else 0.021
			_turn(r.root, [Vector2(-0.11, obj - 0.002), Vector2(-0.108, obj), Vector2(-0.075, obj), Vector2(-0.05, 0.0125), Vector2(0.05, 0.0125),
					Vector2(0.06, 0.016), Vector2(0.09, 0.0175), Vector2(0.095, 0.016)], c, black, 24)
			_cyl(r.root, obj - 0.0015, 0.002, c + Vector3(0, 0, -0.108), lens, 24)
			_cyl(r.root, 0.015, 0.002, c + Vector3(0, 0, 0.094), lens, 22)
			_cyl_y(r.root, 0.008, 0.016, c + Vector3(0, 0.017, -0.006), black, 14)
			_cyl_x(r.root, 0.008, 0.016, c + Vector3(0.017, 0, -0.006), black, 14)
			for i in 6:
				_box(r.root, Vector3(0.0012, 0.0018, 0.004), c + Vector3(cos(TAU * i / 6.0) * 0.0081, 0.025, -0.006 + sin(TAU * i / 6.0) * 0.0081),
						bore, Vector3.ZERO, 0.0)
			if long:
				_turn(r.root, [Vector2(-0.006, 0.0172), Vector2(0.006, 0.0172)], c + Vector3(0, 0, 0.066), fin("oxide"), 22)
				var zoom := float(r.tune.get("sight", 0.0))
				var lever := Vector3(0.022, 0.0, 0).rotated(Vector3(0, 0, 1), deg_to_rad(20.0 + zoom * 60.0))
				_rod_between(r.root, c + Vector3(0, 0, 0.066), c + lever + Vector3(0, 0, 0.066), 0.0022, black)
		"thermal":
			# A thermal imager: a squared housing, a germanium lens, a screen glowing at the back.
			var c := t + Vector3(0, 0.03, 0.0)
			_slab(r.root, [Vector2(c.z + 0.045, c.y + 0.022), Vector2(c.z - 0.04, c.y + 0.022), Vector2(c.z - 0.045, c.y + 0.016),
					Vector2(c.z - 0.045, c.y - 0.022), Vector2(c.z + 0.045, c.y - 0.022)], 0.042, fin("green"), 0.0, 0.004)
			_slab(r.root, [Vector2(t.z + 0.03, t.y), Vector2(t.z - 0.03, t.y), Vector2(t.z - 0.03, c.y - 0.022), Vector2(t.z + 0.03, c.y - 0.022)],
					0.024, black, 0.0, 0.002)
			_turn(r.root, [Vector2(-0.022, 0.018), Vector2(-0.02, 0.021), Vector2(0.0, 0.021)], c + Vector3(0, 0, -0.045), black, 22)
			_cyl(r.root, 0.0175, 0.002, c + Vector3(0, 0, -0.0665), fin("lens", Color(0.25, 0.08, 0.02)), 22)
			_box(r.root, Vector3(0.03, 0.024, 0.002), c + Vector3(0, 0.0, 0.0462), fin("bore", Color(1.0, 0.45, 0.05) * 0.9), Vector3.ZERO, 0.0)
			for i in 3:
				_cyl_y(r.root, 0.003, 0.004, c + Vector3(-0.01 + i * 0.01, 0.023, 0.02), fin("rubber"), 10)
		"night_vision":
			# A green-grey intensifier tube, an IR illuminator alongside, the eyepiece lit green.
			var c := t + Vector3(0, 0.032, 0.0)
			_slab(r.root, [Vector2(t.z + 0.03, t.y), Vector2(t.z - 0.03, t.y), Vector2(t.z - 0.03, c.y - 0.012), Vector2(t.z + 0.03, c.y - 0.012)],
					0.024, black, 0.0, 0.002)
			_turn(r.root, [Vector2(-0.075, 0.022), Vector2(-0.072, 0.024), Vector2(-0.05, 0.024), Vector2(-0.045, 0.02), Vector2(0.045, 0.02),
					Vector2(0.05, 0.016), Vector2(0.055, 0.016)], c, fin("green"), 22)
			_cyl(r.root, 0.022, 0.002, c + Vector3(0, 0, -0.0735), lens, 22)
			_cyl(r.root, 0.014, 0.002, c + Vector3(0, 0, 0.0545), fin("bore", Color(0.2, 0.9, 0.25) * 0.8), 18)
			_turn(r.root, [Vector2(-0.028, 0.008), Vector2(0.024, 0.008)], c + Vector3(-0.03, -0.004, -0.02), black, 14)
			_cyl(r.root, 0.007, 0.002, c + Vector3(-0.03, -0.004, -0.048), fin("bore", Color(0.25, 0.0, 0.05)), 12)
			_box(r.root, Vector3(0.012, 0.006, 0.01), c + Vector3(-0.02, -0.004, -0.02), black, Vector3.ZERO, 0.0)
		"bounty_scope":
			# A long scope with a wanted-poster tag hung off the turret and a red ring.
			var c := t + Vector3(0, 0.03, 0)
			for z: float in [-0.03, 0.03]:
				_slab(r.root, [Vector2(t.z + z + 0.008, t.y), Vector2(t.z + z - 0.008, t.y), Vector2(t.z + z - 0.008, c.y), Vector2(t.z + z + 0.008, c.y)],
						0.018, black, 0.0, 0.001)
			_turn(r.root, [Vector2(-0.11, 0.024), Vector2(-0.106, 0.026), Vector2(-0.07, 0.026), Vector2(-0.05, 0.013), Vector2(0.05, 0.013),
					Vector2(0.065, 0.017), Vector2(0.09, 0.017), Vector2(0.094, 0.015)], c, black, 22)
			_turn(r.root, [Vector2(-0.104, 0.022), Vector2(-0.1, 0.022)], c, lens, 18)
			_turn(r.root, [Vector2(-0.072, 0.0265), Vector2(-0.066, 0.0265)], c, fin("shell_red"), 22)
			_cyl_y(r.root, 0.008, 0.016, c + Vector3(0, 0.018, 0), black, 12)
			_box(r.root, Vector3(0.002, 0.03, 0.024), c + Vector3(0.016, -0.008, 0.01), fin("sand"), Vector3(0, 0, -8), 0.0)
			_box(r.root, Vector3(0.0022, 0.008, 0.016), c + Vector3(0.0165, -0.002, 0.01), fin("oxide"), Vector3(0, 0, -8), 0.0)
		"juggler_sight":
			# An open ring sight with three juggling balls stuck on its posts.
			for z: float in [-0.012, 0.012]:
				_slab(r.root, [Vector2(t.z + z + 0.005, t.y), Vector2(t.z + z - 0.005, t.y), Vector2(t.z + z - 0.004, t.y + 0.028), Vector2(t.z + z + 0.004, t.y + 0.028)],
						0.006, black, 0.0, 0.0008)
			_turn(r.root, [Vector2(-0.002, 0.014), Vector2(0.002, 0.014)], t + Vector3(0, 0.032, 0), fin("chrome"), 22)
			var cols := ["oxide", "sulfur", "green"]
			for i in 3:
				_ball(r.root, 0.0045, t + Vector3(-0.012 + i * 0.012, 0.05 + (i % 2) * 0.006, 0.0), fin(cols[i]))
		_:
			_generic(r, t + Vector3(0, 0.02, 0), id)


## A grip part where the frame's pistol grip was.
static func _grip_part(r: Rig, id: String) -> void:
	var top := r.grip_top
	var size := r.grip_size
	var rake := r.grip_rake
	var down := _grip_down(rake)
	var fwd := Vector3(0, sin(deg_to_rad(rake)), -cos(deg_to_rad(rake)))
	match id:
		"rubber_grip":
			# An overmoulded rubber grip with deep finger grooves.
			_put(r.root, GunKit.slab(_grip_outline(top, size + Vector3(0.003, 0, 0.003), rake, true, 1.0), size.x + 0.003, 0.005), Vector3.ZERO, fin("rubber"))
		"skeleton_grip":
			# A machined skeleton: the outline frame with the middle cut away.
			var outline := _grip_outline(top, size, rake, false, 1.0)
			var inner := _grip_outline(top, size, rake, false, 0.62)
			var m := fin("black")
			_put(r.root, GunKit.slab(outline, size.x * 0.5, 0.0012), Vector3.ZERO, m)
			_put(r.root, GunKit.slab(inner, size.x * 0.5 + 0.001, 0.0), Vector3.ZERO, fin("bore"))
			for sx: float in [-1.0, 1.0]:
				_put(r.root, GunKit.slab(_grip_outline(top, size, rake, false, 1.0), size.x * 0.12, 0.0006), Vector3(sx * size.x * 0.32, 0, 0), m)
		"wood_grip":
			_grip_shape(r, top, fin("laminate"), size + Vector3(0.002, 0.0, 0.002), rake, false, false)
			_pins(r, [Vector2((top + down * size.y * 0.3).z, (top + down * size.y * 0.3).y), Vector2((top + down * size.y * 0.75).z, (top + down * size.y * 0.75).y)],
					size.x * 0.5 + 0.002, 0.003)
		"tape_grip":
			# Wrapped in grip tape: a sleeve of rubber with sulfur bands.
			_grip_shape(r, top, fin("black"), size, rake, false, false)
			for i in 4:
				_box(r.root, Vector3(size.x + 0.003, 0.004, size.z * 1.1), top + down * size.y * (0.2 + i * 0.2), fin("sulfur" if i % 2 == 0 else "rubber"),
						Vector3(rake, 0, 0), 0.001)
		"stippled_grip":
			_grip_shape(r, top, fin("poly_tan"), size, rake, false, true)
			for i in 12:
				var p := top + down * size.y * (0.2 + (i / 3) * 0.18) + fwd * size.z * (-0.25 + (i % 3) * 0.25)
				for sx: float in [-1.0, 1.0]:
					_box(r.root, Vector3(0.0014, 0.004, 0.004), p + Vector3(sx * (size.x * 0.5 + 0.0012), 0, 0), fin("bore"), Vector3(45, 0, 0), 0.0)
		"runner_grip":
			# A slim grip with an oxide stripe down its back strap.
			_grip_shape(r, top, fin("poly_grey"), size - Vector3(0.0, 0.0, 0.004), rake, false, true)
			_box(r.root, Vector3(size.x + 0.002, size.y * 0.75, 0.006), top + down * size.y * 0.5 - fwd * size.z * 0.48, fin("oxide"), Vector3(rake, 0, 0), 0.001)
		"spur_grip":
			# A cowboy's spur rowel spinning on the heel of the grip.
			_grip_shape(r, top, fin("black"), size, rake, false, true)
			var heel := top + down * size.y * 0.95 - fwd * size.z * 0.6
			_cyl_x(r.root, 0.004, size.x + 0.006, heel, fin("chrome"), 12)
			for i in 8:
				var a := TAU * i / 8.0
				_box(r.root, Vector3(0.002, 0.012, 0.003), heel + Vector3(size.x * 0.5 + 0.004, cos(a) * 0.008, sin(a) * 0.008), fin("brass"),
						Vector3(-rad_to_deg(a), 0, 0), 0.0)
		"berserker_grip":
			# A rubber grip studded with steel spikes down its back.
			_grip_shape(r, top, fin("rubber"), size, rake, false, true)
			for i in 5:
				var at := top + down * size.y * (0.15 + i * 0.17) - fwd * size.z * 0.55
				_cyl(r.root, 0.0035, 0.008, at - fwd * 0.004, fin("chrome"), 6)
				_ball(r.root, 0.003, at - fwd * 0.009, fin("chrome"))
		"leech_grip":
			# A glossy dark-red grip with ringed segments, like something alive.
			_grip_shape(r, top, fin("shell_red"), size, rake, false, false)
			for i in 6:
				var at := top + down * size.y * (0.12 + i * 0.15)
				_box(r.root, Vector3(size.x + 0.004, 0.003, size.z + 0.004), at, fin("rust"), Vector3(-rake, 0, 0), 0.001)
		_:
			_grip_shape(r, top, fin("oxide"), size, rake, true)


## Trigger groups: a different blade in the guard and a cue on the selector.
static func _trigger_part(r: Rig, id: String) -> void:
	var t := r.trig
	var side := Vector3(r.body_w + 0.002, 0.03, 0.015) + Vector3(0, t.y, t.z)
	match id:
		"match_trigger":
			_box(r.root, Vector3(0.008, 0.02, 0.006), t + Vector3(0, 0, -0.002), mat("panel", RED), Vector3(-5, 0, 0), 0.001)
			_rod(r.root, 0.002, 0.002, 0.008, t + Vector3(0, 0.012, 0.004), mat("panel", NICKEL), 4, Vector3(float(r.tune.get("trigger", 0.0)) * 30.0, 0, 0))
		"auto_sear":
			_box(r.root, Vector3(0.004, 0.012, 0.012), side, mat("panel", NICKEL), Vector3.ZERO, 0.001)
			_box(r.root, Vector3(0.003, 0.006, 0.02), side + Vector3(0.002, -0.012, 0.0), mat("panel", ORANGE), Vector3(25, 0, 0), 0.0)
		"burst_group":
			_box(r.root, Vector3(0.003, 0.006, 0.02), side + Vector3(0.002, -0.012, 0.0), mat("panel", YELLOW), Vector3(-25, 0, 0), 0.0)
			for i in 3:
				_box(r.root, Vector3(0.003, 0.003, 0.003), side + Vector3(0.002, -0.002, -0.01 + i * 0.006), mat("panel", YELLOW), Vector3.ZERO, 0.0)
		"binary_trigger":
			_box(r.root, Vector3(0.008, 0.022, 0.007), t + Vector3(0, 0, -0.001), mat("panel", BLUE), Vector3(-15, 0, 0), 0.001)
		"hair_trigger":
			_box(r.root, Vector3(0.004, 0.024, 0.004), t + Vector3(0, -0.002, -0.004), mat("panel", NICKEL), Vector3(-25, 0, 0), 0.0)
			_rod(r.root, 0.002, 0.002, 0.01, t + Vector3(0, 0.012, 0.006), mat("panel", YELLOW), 4, Vector3.ZERO)
		"double_set":
			_box(r.root, Vector3(0.006, 0.02, 0.006), t + Vector3(0, 0.0, 0.012), mat("brass"), Vector3(-10, 0, 0), 0.001)
			_box(r.root, Vector3(0.0065, 0.022, 0.007), t, mat("brass"), Vector3(-15, 0, 0), 0.001)
		"dead_mans_trigger":
			# A long oxide lever that hangs out under the guard.
			_slab(r.root, [Vector2(t.z + 0.002, t.y + 0.012), Vector2(t.z - 0.004, t.y - 0.01), Vector2(t.z - 0.002, t.y - 0.03), Vector2(t.z + 0.004, t.y - 0.032),
					Vector2(t.z + 0.006, t.y - 0.012), Vector2(t.z + 0.006, t.y + 0.012)], 0.007, fin("oxide"), 0.0, 0.001)
		"gamble_trigger":
			# A die set into the side of the frame, pips up.
			_box(r.root, Vector3(0.012, 0.012, 0.012), side, fin("dust"), Vector3(10, 20, 0), 0.002)
			for i in 3:
				_ball(r.root, 0.0013, side + Vector3(0.0062, -0.003 + i * 0.003, -0.003 + i * 0.003), fin("bore"))
		"overclock_trigger":
			_blade_at(r, t.z + 0.002, t.y + 0.012, fin("oxide"))
			for i in 5:
				_box(r.root, Vector3(0.004, 0.014, 0.0016), side + Vector3(0.002, 0.0, -0.012 + i * 0.006), fin("bare"), Vector3.ZERO, 0.0)
		"spool_trigger":
			# A trigger on a little spring drum, its line wound round a spool on the side.
			_blade_at(r, t.z + 0.002, t.y + 0.012, fin("chrome"))
			_cyl_x(r.root, 0.008, 0.008, side, fin("brass"), 16)
			for i in 3:
				_cyl_x(r.root, 0.0085, 0.0012, side + Vector3(-0.003 + i * 0.003, 0, 0), fin("sulfur"), 16)
		"ambush_trigger":
			# A black blade with a hooded guard and a small sulfur safety tab.
			_blade_at(r, t.z + 0.002, t.y + 0.012, fin("bore"))
			_box(r.root, Vector3(0.004, 0.006, 0.01), side + Vector3(0, 0.004, 0), fin("sulfur"), Vector3(-20, 0, 0), 0.0)
		_:
			_blade_at(r, t.z + 0.002, t.y + 0.012, fin("oxide"))


## Bolt parts: what shows through the ejection port, a buffer band, or a bigger handle.
static func _bolt_part(r: Rig, id: String) -> void:
	var b := r.bolt
	var out := Vector3(signf(b.x) if b.x != 0.0 else 1.0, 0, 0)
	match id:
		"heavy_buffer", "light_spring", "heavy_spring":
			var colour: Color = {"heavy_buffer": RED, "light_spring": YELLOW, "heavy_spring": BLUE}[id]
			var rad := 0.016 if r.has_buffer else maxf(r.body_w, 0.012) + 0.002
			_rod(r.root, rad, rad, 0.008, r.stock + Vector3(0, 0, 0.02), mat("panel", colour), 8)
			if id != "heavy_buffer":
				var points := []
				for i in 13:
					var a := TAU * i / 4.0
					points.append(b + out * 0.001 + Vector3(0, cos(a) * 0.004, sin(a) * 0.004 - 0.012 + i * 0.002))
				_tube(r.root, points, 0.0012, mat("panel", colour), 3)
		"light_bolt":
			_box(r.root, Vector3(0.003, 0.01, 0.026), b + out * 0.0005, mat("panel", Color(0.9, 0.55, 0.3)), Vector3.ZERO, 0.0)
			for i in 3:
				_box(r.root, Vector3(0.004, 0.004, 0.004), b + out * 0.001 + Vector3(0, 0, -0.008 + i * 0.008), mat("panel", BLACK), Vector3.ZERO, 0.0)
		"nickel_bolt":
			_box(r.root, Vector3(0.003, 0.011, 0.028), b + out * 0.0005, mat("panel", NICKEL), Vector3.ZERO, 0.0)
		"bolt_knob":
			if r.frame == "lever_action":
				_ball(r.root, 0.009, Vector3(0, -0.022, 0.03), mat("panel", BLACK))
			else:
				_ball(r.root, 0.017 if r.frame == "anti_materiel" else 0.013, b, mat("panel", BLACK), Vector3(1, 1, 1.2))
				_ball(r.root, 0.009, b + out * 0.006, mat("panel", RED))
		"lever_loop":
			if r.frame == "lever_action":
				_lever(r, 1.45)
				_box(r.root, Vector3(0.012, 0.006, 0.03), Vector3(0, -0.038, 0.06), mat("panel", TAPE), Vector3(-20, 0, 0), 0.002)
			else:
				# Any other gun: a big loop round the trigger guard (C7, everything fits).
				var t := r.trig + Vector3(0, -0.006, 0.0)
				var ring := []
				for i in 13:
					var a := TAU * i / 12.0
					ring.append(t + Vector3(0, -0.012 + sin(a) * 0.024, cos(a) * 0.032))
				_tube(r.root, ring, 0.0028, fin("black"), 8)
		"eject_bolt":
			# A stiff spring showing through the port, the bolt face in oxide.
			var points := []
			for i in 25:
				var a := TAU * i / 6.0
				points.append(b + out * 0.002 + Vector3(0, cos(a) * 0.004, sin(a) * 0.004 - 0.016 + i * 0.0013))
			_tube(r.root, points, 0.0011, fin("chrome"), 8)
			_box(r.root, Vector3(0.003, 0.009, 0.008), b + out * 0.001 + Vector3(0, 0, -0.02), fin("oxide"), Vector3.ZERO, 0.0)
		"feather_bolt":
			# A skeletonised bolt: a plate full of holes behind the port.
			_box(r.root, Vector3(0.003, 0.011, 0.028), b + out * 0.0005, fin("bare"), Vector3.ZERO, 0.0)
			for i in 4:
				_cyl_x(r.root, 0.0022, 0.0034, b + out * 0.0008 + Vector3(0, 0, -0.01 + i * 0.0068), fin("bore"), 10)
		"echo_chamber":
			# A second, empty chamber hung beside the port, with a ringing brass bell mouth.
			var at := b + out * 0.012
			_cyl(r.root, 0.007, 0.05, at, fin("steel"), 14)
			_turn(r.root, [Vector2(-0.034, 0.011), Vector2(-0.025, 0.007), Vector2(-0.02, 0.007)], at, fin("brass"), 16)
			for z: float in [-0.012, 0.012]:
				_box(r.root, Vector3(0.012, 0.004, 0.004), at + Vector3(-out.x * 0.006, 0, z), fin("black"), Vector3.ZERO, 0.0)
		"skate_bolt":
			# Skate bearings on the bolt carrier showing through the port, orange wheels out.
			for z: float in [-0.014, 0.014]:
				_cyl_x(r.root, 0.007, 0.006, b + out * 0.004 + Vector3(0, 0, z), fin("oxide"), 14)
				_cyl_x(r.root, 0.003, 0.0075, b + out * 0.004 + Vector3(0, 0, z), fin("chrome"), 10)
			_box(r.root, Vector3(0.003, 0.004, 0.04), b + out * 0.002, fin("black"), Vector3.ZERO, 0.0)
		_:
			_generic(r, b + out * 0.008, id)


static func _charging(r: Rig, id: String) -> void:
	var c := r.charging
	var dark := mat("panel", DARK)
	var on_side := absf(c.x) > 0.01
	match id:
		"ambi_charging":
			if on_side:
				for sx: float in [-1.0, 1.0]:
					_rod_between(r.root, Vector3(sx * r.body_w, c.y, c.z), Vector3(sx * absf(c.x), c.y, c.z), 0.0045, dark)
					_box(r.root, Vector3(0.008, 0.014, 0.014), Vector3(sx * absf(c.x), c.y, c.z), mat("panel", BLACK), Vector3.ZERO, 0.002)
			else:
				_box(r.root, Vector3(0.05, 0.008, 0.018), c, mat("panel", BLACK), Vector3.ZERO, 0.002)
				for sx: float in [-1.0, 1.0]:
					_box(r.root, Vector3(0.01, 0.009, 0.014), c + Vector3(sx * 0.026, 0, 0.002), mat("panel", RED), Vector3.ZERO, 0.002)
		"extended_latch":
			if on_side:
				_rod_between(r.root, Vector3(signf(c.x) * r.body_w, c.y, c.z), c, 0.004, dark)
				_box(r.root, Vector3(0.012, 0.02, 0.016), c, mat("panel", ORANGE), Vector3.ZERO, 0.002)
			else:
				_box(r.root, Vector3(0.03, 0.008, 0.016), c, dark, Vector3.ZERO, 0.002)
				_box(r.root, Vector3(0.022, 0.008, 0.012), c + Vector3(-0.024, 0, 0.002), mat("panel", ORANGE), Vector3(0, -15, 0), 0.002)
		"side_charging":
			var at := Vector3(-r.body_w, r.recv.y + 0.004, r.recv.z - 0.04)
			_box(r.root, Vector3(0.004, 0.008, 0.06), at + Vector3(-0.002, 0, 0.0), mat("panel", BLACK), Vector3.ZERO, 0.0)
			_rod_between(r.root, at + Vector3(0, 0, -0.025), at + Vector3(-0.026, 0, -0.025), 0.004, dark)
			_box(r.root, Vector3(0.01, 0.014, 0.016), at + Vector3(-0.028, 0, -0.025), mat("panel", BLACK), Vector3.ZERO, 0.002)
			if not on_side:
				_box(r.root, Vector3(0.02, 0.006, 0.012), c, dark, Vector3.ZERO, 0.001)
		"slide_loader":
			# A long hooked lever off the charging handle with a rubber knob: it snags on your
			# leg when you slide and racks the gun for you.
			_box(r.root, Vector3(0.02, 0.006, 0.012), c, fin("black"), Vector3.ZERO, 0.001)
			var hook := Vector3(r.body_w + 0.014, c.y - 0.06, c.z + 0.012)
			_rod_between(r.root, c + Vector3(0.012, 0, 0), hook, 0.003, fin("chrome"))
			_ball(r.root, 0.007, hook, fin("rubber"))
			_box(r.root, Vector3(0.004, 0.012, 0.004), hook + Vector3(0, 0.009, 0), fin("oxide"), Vector3.ZERO, 0.0)
		"crank_handle":
			# A hand crank on the side of the receiver geared to a little brass dynamo.
			var at := Vector3(r.body_w + 0.006, c.y - 0.012, c.z - 0.02)
			_cyl_x(r.root, 0.012, 0.012, at, fin("brass"), 16)
			_cyl_x(r.root, 0.006, 0.02, at + Vector3(0.01, 0, 0), fin("black"), 10)
			_box(r.root, Vector3(0.004, 0.004, 0.03), at + Vector3(0.022, 0, 0.013), fin("chrome"), Vector3.ZERO, 0.0)
			_cyl_x(r.root, 0.004, 0.016, at + Vector3(0.03, 0, 0.026), fin("oxide"), 8)
		_:
			_generic(r, c, id)


static func _magazine(r: Rig, id: String) -> void:
	var keep := _into_mag(r)
	_magazine_draw(r, id)
	r.root = keep


static func _magazine_draw(r: Rig, id: String) -> void:
	var t := r.mag
	# C7: feeds from other kinds of guns hang where any magazine goes.
	if id == "big_tank" and r.mag_style != "tank":
		_tank(r, t + Vector3(0, -0.04, 0.0), 0.04, 0.16, mat("panel", RED))
		return
	if id == "capacitor" and r.mag_style != "cell":
		_cells(r, t, 2, 0.013, 0.08, mat("panel", Color(0.95, 0.75, 0.2)))
		return
	if id == "nail_coil" and r.mag_style != "coil":
		_nail_coil(r, t + Vector3(0, -0.02, 0), 0.045, true)
		return
	match r.mag_style:
		"tank":
			if id == "big_tank":
				_tank(r, t + Vector3(0, -0.012, 0.0), 0.06, 0.26, mat("panel", RED))
				_box(r.root, Vector3(0.13, 0.012, 0.016), t + Vector3(0, -0.012, -0.06), mat("panel", BLACK), Vector3.ZERO, 0.002)
			else:
				_tank(r, t, 0.045, 0.2, mat("panel", OLIVE))
				_mag_pouch(r, id)
			return
		"cell":
			if id == "capacitor":
				_cells(r, t, 3 if r.frame != "bubble_gun" else 2, 0.016, 0.11, mat("panel", Color(0.95, 0.75, 0.2)))
			else:
				_cells(r, t, 2, 0.016, 0.1, mat("panel", Color(0.5, 0.55, 0.6)))
				_mag_pouch(r, id)
			return
		"hopper":
			var size := 0.09 if id == "extended_mag" else 0.06
			_box(r.root, Vector3(0.05, size, 0.08), t + Vector3(-0.022, size * 0.15, 0), mat("panel", YELLOW), Vector3.ZERO, 0.006)
			for i in (3 if id == "extended_mag" else 2):
				_duck(r.root, t + Vector3(-0.022, size * 0.65, -0.02 + i * 0.03), 0.45)
			if id == "quick_mag":
				_tube(r.root, [t + Vector3(-0.05, 0.0, 0.03), t + Vector3(-0.07, -0.02, 0.04), t + Vector3(-0.05, -0.03, 0.03)], 0.004, mat("panel", RED), 4)
			return
		"blades":
			_blade_stack(r, t, 6 if id == "extended_mag" else 3)
			if id == "quick_mag":
				_tube(r.root, [t + Vector3(0.05, -0.02, 0.0), t + Vector3(0.07, -0.04, 0.0), t + Vector3(0.05, -0.05, 0.0)], 0.004, mat("panel", RED), 4)
			return
		"coil":
			_nail_coil(r, t, 0.058 if id == "nail_coil" else 0.04, id == "nail_coil")
			if id != "nail_coil":
				_mag_pouch(r, id)
			return
		"top":
			match id:
				"extended_mag": _top_mag(r, r.mag_len * 1.25, mat("panel", SMOKE))
				"drum_mag", "casket_mag": _top_mag(r, r.mag_len, mat("panel", SMOKE), 0.06)
				"polymer_mag": _top_mag(r, r.mag_len, mat("panel", TAN))
				"coupled_mag":
					_top_mag(r, r.mag_len, mat("panel", SMOKE))
					_box(r.root, Vector3(0.05, 0.03, r.mag_len * 0.6), r.mag + Vector3(-0.045, 0.012, 0.0), mat("panel", SMOKE), Vector3.ZERO, 0.006)
					_box(r.root, Vector3(0.1, 0.02, 0.03), r.mag + Vector3(-0.022, 0.012, 0.0), mat("panel", TAPE), Vector3.ZERO, 0.003)
				"quick_mag":
					_top_mag(r, r.mag_len, mat("panel", SMOKE))
					_tube(r.root, [r.mag + Vector3(0, 0.026, 0.15), r.mag + Vector3(0, 0.04, 0.17), r.mag + Vector3(0, 0.026, 0.18)], 0.004, mat("panel", ORANGE), 4)
				_:
					_top_mag(r, r.mag_len, mat("panel", SMOKE))
					_mag_pouch(r, id)
			return
		"tube":
			if id in ["tube_extension", "extended_mag"]:
				_tube_extension(r, 0.1 if id == "tube_extension" else 0.07)
				return
			if id == "side_saddle":
				_side_saddle(r)
				return
			if id == "box_mag_conv":
				_shell_box_mag(r)
				return
		"belt":
			if id == "belt_box":
				_belt_box(r, Vector3(0.07, 0.11, 0.14), mat("panel", Color(0.4, 0.45, 0.3)))
				_box(r.root, Vector3(0.072, 0.03, 0.01), r.mag + Vector3(0, -0.05, -0.071), mat("panel", YELLOW), Vector3.ZERO, 0.002)
				return
	if id == "speedloader":
		# Hung under the grip on a cord: six rounds in a ring.
		var at := _grip_bottom(r) + Vector3(0, -0.04, 0.0)
		_tube(r.root, [_grip_bottom(r), _grip_bottom(r) + Vector3(0, -0.014, 0.004), at + Vector3(0, 0.012, 0)], 0.0015, mat("panel", RED), 3)
		_rod(r.root, 0.017, 0.017, 0.012, at, mat("panel", BLACK), 8, Vector3.ZERO)
		for i in 6:
			var a := TAU * i / 6.0
			_round(r, _rod(r.root, 0.005, 0.005, 0.03, at + Vector3(cos(a) * 0.012, -0.018, sin(a) * 0.012), mat("brass"), 5, Vector3.ZERO))
		return
	if r.mag_style == "none":
		_mag_pouch(r, id)
		return
	_box_magazine(r, id)


## Frames with no box magazine carry the feed part as a pouch strapped under the grip.
static func _mag_pouch(r: Rig, id: String) -> void:
	var at := _grip_bottom(r) + Vector3(0, -0.03, 0.0)
	var colour: String = {"parkour_feed": "poly_grey", "pain_feed": "shell_red", "bomb_mag": "steel"}.get(id, "black")
	_box(r.root, Vector3(0.03, 0.04, 0.03), at, fin(colour), Vector3.ZERO, 0.006)
	_box(r.root, Vector3(0.034, 0.008, 0.034), at + Vector3(0, 0.02, 0), fin("black"), Vector3.ZERO, 0.002)
	match id:
		"parkour_feed": _cyl_x(r.root, 0.012, 0.008, at + Vector3(-0.02, 0, 0), fin("rubber"), 16)
		"pain_feed": _tube(r.root, [at, at + Vector3(0.02, -0.02, 0.05), at + Vector3(0.03, -0.01, 0.12)], 0.004, fin("shell_red"), 6)
		"bomb_mag": _cyl_y(r.root, 0.01, 0.04, at + Vector3(0.024, 0, 0), fin("shell_red"), 12)


## Box-magazine parts in the frame's own magazine shape (or a pistol's, out of the grip).
static func _box_magazine(r: Rig, id: String) -> void:
	var t := r.mag
	var steel := mat("panel", DARK)
	var pistol := r.mag_style == "pistol"
	var base := 0.0 if pistol else r.mag_len
	var w := r.mag_w
	var d := r.mag_d
	if not pistol:
		_box(r.root, Vector3(w + 0.008, 0.014, d + 0.008), t + Vector3(0, -0.004, 0), mat("panel", DARK))
		_round(r, _rod(r.root, 0.0055, 0.0055, minf(d * 0.8, 0.06), t + Vector3(0, 0.004, -0.002), mat("brass"), 5))
	match id:
		"extended_mag":
			var bottom := _mag_body(r, t, maxf(base * 1.55, 0.06), w, d, r.mag_tilt, r.mag_curve * 1.3, steel)
			_box(r.root, Vector3(w + 0.004, 0.026, d + 0.004), t.lerp(bottom, 0.55), mat("panel", TAPE), Vector3(r.mag_tilt + r.mag_curve * 0.6, 0, 0), 0.003)
		"drum_mag":
			var neck := _mag_body(r, t, maxf(base * 0.3, 0.02), w, d, r.mag_tilt, 0.0, steel, false)
			var rad := clampf(base * 0.45, 0.04, 0.07) if not pistol else 0.045
			var c := neck + Vector3(0, -rad * 0.85, 0)
			_disc_x(r.root, rad, w + 0.03, c, steel, 12)
			_disc_x(r.root, rad * 0.8, w + 0.034, c, mat("panel", Color(0.5, 0.52, 0.56)), 12)
			_disc_x(r.root, 0.012, w + 0.038, c, mat("panel", RED), 6)
		"twin_drum":
			var neck := _mag_body(r, t, maxf(base * 0.35, 0.025), w, d, r.mag_tilt, 0.0, steel, false)
			var rad := clampf(base * 0.42, 0.04, 0.06)
			for sx: float in [-1.0, 1.0]:
				var c := neck + Vector3(sx * (rad * 0.62 + 0.004), -rad * 0.5, 0)
				_put(r.root, LowPoly.prism(12, rad, rad, 0.036), c, steel, Vector3(90, 0, 0))
				_put(r.root, LowPoly.prism(12, rad * 0.75, rad * 0.75, 0.04), c, mat("panel", Color(0.55, 0.57, 0.6)), Vector3(90, 0, 0))
			_box(r.root, Vector3(0.02, 0.012, 0.02), neck + Vector3(0, -0.004, 0), mat("panel", RED), Vector3.ZERO, 0.002)
		"quick_mag":
			var bottom := _mag_body(r, t, maxf(base, 0.012), w, d, r.mag_tilt, r.mag_curve, steel)
			_tube(r.root, [bottom + Vector3(0, 0, -d * 0.3), bottom + Vector3(0, -0.022, -d * 0.1), bottom + Vector3(0, -0.022, d * 0.2),
					bottom + Vector3(0, 0, d * 0.35)], 0.0035, mat("panel", ORANGE), 4)
		"coupled_mag":
			var bottom := _mag_body(r, t, maxf(base, 0.04), w, d, r.mag_tilt, r.mag_curve, steel)
			# A second mag taped alongside, upside down so it's ready.
			var length := maxf(base, 0.04)
			var off := Vector3(w + 0.004, 0, 0)
			_mag_body(r, t + off + Vector3(0, -0.01, 0), length, w, d, r.mag_tilt, r.mag_curve, mat("panel", Color(0.36, 0.38, 0.4)), true)
			_box(r.root, Vector3(w * 2.0 + 0.012, 0.024, d + 0.006), t.lerp(bottom, 0.5) + off * 0.5, mat("panel", TAPE), Vector3(r.mag_tilt + r.mag_curve * 0.5, 0, 0), 0.003)
		"polymer_mag":
			var bottom := _mag_body(r, t, maxf(base, 0.012), w, d, r.mag_tilt, r.mag_curve, mat("panel", TAN))
			if not pistol:
				_box(r.root, Vector3(w + 0.002, base * 0.5, 0.006), t.lerp(bottom, 0.45) + Vector3(0, 0, d * 0.25), mat("panel", SMOKE), Vector3(r.mag_tilt + r.mag_curve * 0.5, 0, 0), 0.0)
		"casket_mag":
			_mag_body(r, t, maxf(base, 0.03), w * 1.9, d, r.mag_tilt, r.mag_curve * 0.6, mat("panel", Color(0.4, 0.42, 0.46)))
		"hourglass_mag":
			# A glass magazine pinched in the middle, sand running through it.
			var length := maxf(base, 0.05)
			var bottom := _mag_body(r, t, length, w, d, r.mag_tilt, r.mag_curve, fin("glass"))
			var mid := t.lerp(bottom, 0.5)
			_box(r.root, Vector3(w + 0.004, 0.008, d + 0.004), mid, fin("brass"), Vector3(r.mag_tilt, 0, 0), 0.002)
			_box(r.root, Vector3(w * 0.7, length * 0.3, d * 0.7), t.lerp(bottom, 0.8), fin("sand"), Vector3(r.mag_tilt, 0, 0), 0.003)
			_box(r.root, Vector3(w * 0.5, length * 0.12, d * 0.5), t.lerp(bottom, 0.2), fin("sand"), Vector3(r.mag_tilt, 0, 0), 0.002)
		"jumbo_mag":
			var bottom := _mag_body(r, t, maxf(base * 2.6, 0.12), w * 1.2, d * 1.1, r.mag_tilt, r.mag_curve * 1.6, steel)
			for k: float in [0.3, 0.65]:
				_box(r.root, Vector3(w * 1.2 + 0.004, 0.02, d * 1.1 + 0.004), t.lerp(bottom, k), fin("sulfur" if k < 0.5 else "black"),
						Vector3(r.mag_tilt + r.mag_curve * k * 1.6, 0, 0), 0.002)
		"one_shot_mag":
			# A stub of a magazine holding one fat round, its tip showing.
			var bottom := _mag_body(r, t, maxf(base * 0.25, 0.02), w, d, r.mag_tilt, 0.0, fin("oxide"), false)
			_round(r, _cyl(r.root, minf(w, d) * 0.4, minf(d * 0.9, 0.05), t + Vector3(0, 0.004, -0.002), fin("brass"), 12))
			_box(r.root, Vector3(w + 0.004, 0.006, d + 0.006), bottom, fin("black"), Vector3(r.mag_tilt, 0, 0), 0.0015)
		"tube_extension", "side_saddle", "box_mag_conv", "belt_box":
			# Only fits frames whose own style draws it; anywhere else, a plain magazine.
			_mag_body(r, t, maxf(base, 0.012), w, d, r.mag_tilt, r.mag_curve, steel)
		"parkour_feed":
			# A magazine with a rubber wheel on its spine that rolls along the wall.
			var bottom := _mag_body(r, t, maxf(base * 0.85, 0.04), w, d, r.mag_tilt, r.mag_curve, fin("poly_grey"))
			var spine := t.lerp(bottom, 0.55) + Vector3(-w * 0.5 - 0.006, 0, 0)
			_cyl_x(r.root, 0.014, 0.008, spine, fin("rubber"), 18)
			_cyl_x(r.root, 0.006, 0.01, spine, fin("oxide"), 10)
			_box(r.root, Vector3(0.004, 0.012, 0.02), spine + Vector3(0.004, 0, 0), fin("black"), Vector3.ZERO, 0.0)
		"pain_feed":
			# A magazine with a ribbed hose running up from its base toward the wearer.
			var bottom := _mag_body(r, t, maxf(base, 0.04), w, d, r.mag_tilt, r.mag_curve, fin("black"))
			_tube(r.root, [bottom, bottom + Vector3(0.01, -0.02, 0.03), bottom + Vector3(0.02, -0.03, 0.09), bottom + Vector3(0.03, -0.02, 0.16)],
					0.004, fin("shell_red"), 6)
			_box(r.root, Vector3(w + 0.004, 0.01, d + 0.004), bottom, fin("chrome"), Vector3(r.mag_tilt, 0, 0), 0.0015)
		"bomb_mag":
			# A magazine taped to a red charge with a pull ring.
			var bottom := _mag_body(r, t, maxf(base, 0.04), w, d, r.mag_tilt, r.mag_curve, fin("steel"))
			var mid := t.lerp(bottom, 0.6)
			_cyl_y(r.root, 0.012, 0.05, mid + Vector3(w * 0.5 + 0.012, 0, 0), fin("shell_red"), 14)
			_box(r.root, Vector3(w + 0.03, 0.01, d + 0.006), mid, fin("dust"), Vector3(r.mag_tilt, 0, 0), 0.001)
			_tube(r.root, [mid + Vector3(w * 0.5 + 0.012, 0.03, 0), mid + Vector3(w * 0.5 + 0.02, 0.036, -0.006), mid + Vector3(w * 0.5 + 0.028, 0.03, 0)],
					0.0016, fin("brass"), 4)
		_:
			var bottom := _mag_body(r, t, maxf(base, 0.04), w, d, r.mag_tilt, r.mag_curve, steel)
			_generic(r, bottom, id)


## A tube magazine extension: more tube clamped on past the old cap.
static func _tube_extension(r: Rig, length: float) -> void:
	var e := r.tube_end
	_rod(r.root, r.tube_r, r.tube_r, length, e + Vector3(0, 0, -length / 2.0), mat("panel", STEEL), 6)
	_rod(r.root, r.tube_r * 1.25, r.tube_r * 1.25, 0.012, e + Vector3(0, 0, -length - 0.004), mat("panel", BLACK), 6)
	var clamp_at := e + Vector3(0, 0, -length * 0.6)
	_box(r.root, Vector3(0.018, (r.barrel_start.y - e.y) + 0.026, 0.012), Vector3(0, (r.barrel_start.y + e.y) / 2.0, clamp_at.z),
			mat("panel", DARK), Vector3.ZERO, 0.002)
	r.tube_end = e + Vector3(0, 0, -length)


## A side saddle of spare shells on the left of the receiver.
static func _side_saddle(r: Rig) -> void:
	var at := Vector3(-(r.body_w + 0.004), r.recv.y, r.recv.z)
	_box(r.root, Vector3(0.006, 0.05, 0.08), at, mat("panel", BLACK), Vector3.ZERO, 0.002)
	for i in 5:
		var z := at.z - 0.032 + i * 0.016
		_round(r, _rod(r.root, 0.0072, 0.0072, 0.04, Vector3(at.x - 0.009, at.y + 0.004, z), mat("panel", RED), 6, Vector3.ZERO))
		_rod(r.root, 0.0078, 0.0078, 0.01, Vector3(at.x - 0.009, at.y - 0.02, z), mat("brass"), 6, Vector3.ZERO)


## A shotgun box magazine: fat, with the top shell showing.
static func _shell_box_mag(r: Rig) -> void:
	var t := r.mag
	_box(r.root, Vector3(0.038, 0.014, 0.07), t + Vector3(0, -0.004, 0), mat("panel", DARK))
	_round(r, _rod(r.root, 0.009, 0.009, 0.055, t + Vector3(0, 0.006, 0), mat("panel", RED), 6))
	var bottom := _mag_body(r, t, 0.11, 0.034, 0.07, 4.0, 0.0, mat("panel", BLACK))
	_box(r.root, Vector3(0.036, 0.03, 0.072), t.lerp(bottom, 0.4), mat("panel", OD), Vector3(4, 0, 0), 0.002)


## A nail gun's coil canister of nails.
static func _nail_coil(r: Rig, at: Vector3, radius: float, big: bool) -> void:
	var keep := _into_mag(r)
	_nail_coil_draw(r, at, radius, big)
	r.root = keep


static func _nail_coil_draw(r: Rig, at: Vector3, radius: float, big: bool) -> void:
	var c := at + Vector3(0, -radius + 0.008, 0)
	_disc_x(r.root, radius, 0.034 + (0.01 if big else 0.0), c, mat("panel", RED if big else DARK), 10)
	_round(r, _disc_x(r.root, radius * 0.76, 0.036 + (0.01 if big else 0.0), c, mat("panel", STEEL), 10))
	_box(r.root, Vector3(0.02, 0.035, 0.02), at + Vector3(0, 0.008, -0.01), mat("panel", DARK))


static func _stock(r: Rig, id: String) -> void:
	var s := r.stock
	var black := mat("panel", BLACK)
	# Folding, wire and tube stocks leave nothing solid behind the receiver for the side
	# anchor (spare ammo, gadgets): move it onto the receiver wall.
	if id in ["folding_stock", "wire_stock", "light_stock", "pistol_brace"] and r.side.z > s.z - 0.01:
		var at := r.recv if r.recv != Vector3.INF else s + Vector3(0, -0.01, -0.06)
		# The folded stock lies along the right, so its spares go on the left.
		var sx := -1.0 if id == "folding_stock" else (signf(r.side.x) if r.side.x != 0.0 else 1.0)
		r.side = Vector3(sx * (r.body_w + 0.002), at.y, at.z + 0.03)
	match id:
		"heavy_stock":
			# A laminated sporter stock: straight comb, pistol-grip wrist, a thick rubber pad.
			_box(r.root, Vector3(0.036, 0.034, 0.018), s + Vector3(0, -0.002, 0.008), fin("steel"), Vector3.ZERO, 0.002)
			_sl(r, s, [Vector2(0.012, 0.018), Vector2(0.21, 0.024), Vector2(0.226, 0.018), Vector2(0.228, -0.082), Vector2(0.2, -0.09),
					Vector2(0.13, -0.06), Vector2(0.07, -0.04), Vector2(0.03, -0.03), Vector2(0.012, -0.026)], 0.036, fin("laminate"))
			_sl(r, s, [Vector2(0.228, 0.022), Vector2(0.244, 0.022), Vector2(0.246, -0.088), Vector2(0.228, -0.086)], 0.038, fin("rubber"), 0.002)
			for z: float in [0.08, 0.17]:
				_cyl_x(r.root, 0.004, 0.039, s + Vector3(0, -0.01, z), fin("steel"), 10)
			_stock_ends(r, s + Vector3(0, -0.033, 0.246), 0.11, s + Vector3(0, 0.022, 0.14))
		"light_stock":
			# A skeletonised two-strut stock machined from one plate, with a bare-steel butt.
			var plate := fin("black")
			_sl(r, s, [Vector2(0.0, 0.012), Vector2(0.21, 0.012), Vector2(0.21, -0.004), Vector2(0.0, -0.004)], 0.022, plate, 0.002)
			_sl(r, s, [Vector2(0.0, -0.022), Vector2(0.02, -0.034), Vector2(0.21, -0.074), Vector2(0.21, -0.09), Vector2(0.196, -0.09),
					Vector2(0.0, -0.04)], 0.022, plate, 0.002)
			_sl(r, s, [Vector2(0.12, -0.002), Vector2(0.132, -0.002), Vector2(0.118, -0.05), Vector2(0.106, -0.048)], 0.018, plate, 0.0015)
			_sl(r, s, [Vector2(0.0, 0.012), Vector2(0.012, 0.012), Vector2(0.012, -0.04), Vector2(0.0, -0.04)], 0.026, plate, 0.002)
			_sl(r, s, [Vector2(0.204, 0.016), Vector2(0.218, 0.016), Vector2(0.218, -0.092), Vector2(0.204, -0.092)], 0.03, fin("bare"), 0.0015)
			_stock_ends(r, s + Vector3(0, -0.036, 0.218), 0.1, s + Vector3(0, 0.012, 0.13))
		"folding_stock":
			# Folded flat along the right of the receiver, butt forward: a triangle of flat bar.
			var hinge := s + Vector3(r.body_w + 0.007, 0, 0)
			_cyl_y(r.root, 0.007, 0.03, hinge + Vector3(0, -0.006, -0.004), fin("black"), 12)
			var x := hinge.x + 0.002
			_slab(r.root, [Vector2(hinge.z, hinge.y + 0.006), Vector2(hinge.z - 0.2, hinge.y + 0.004), Vector2(hinge.z - 0.212, hinge.y - 0.004),
					Vector2(hinge.z - 0.212, hinge.y - 0.08), Vector2(hinge.z - 0.2, hinge.y - 0.084), Vector2(hinge.z - 0.19, hinge.y - 0.074),
					Vector2(hinge.z - 0.02, hinge.y - 0.024), Vector2(hinge.z, hinge.y - 0.02)], 0.008, fin("steel"), x, 0.0012)
			_slab(r.root, [Vector2(hinge.z - 0.03, hinge.y - 0.004), Vector2(hinge.z - 0.18, hinge.y - 0.006), Vector2(hinge.z - 0.19, hinge.y - 0.014),
					Vector2(hinge.z - 0.19, hinge.y - 0.062), Vector2(hinge.z - 0.04, hinge.y - 0.02)], 0.0084, fin("bore"), x, 0.0)
			_slab(r.root, [Vector2(hinge.z - 0.212, hinge.y + 0.004), Vector2(hinge.z - 0.222, hinge.y + 0.004),
					Vector2(hinge.z - 0.222, hinge.y - 0.084), Vector2(hinge.z - 0.212, hinge.y - 0.084)], 0.016, fin("rubber"), x, 0.002)
		"adjustable_stock":
			# A collapsible stock on a buffer tube; its tune slides it in and out.
			var t := float(r.tune.get("stock", 0.0))
			var off := 0.1 * t if t < 0.0 else 0.06 * t
			if not r.has_buffer:
				_box(r.root, Vector3(0.03, 0.03, 0.024), s + Vector3(0, 0, 0.01), fin("black"), Vector3.ZERO, 0.002)
				_cyl(r.root, 0.0145, 0.22, s + Vector3(0, 0, 0.11), fin("black"), 16)
			var front := 0.12 + off
			var m := fin("poly_tan")
			_sl(r, s, [Vector2(front, 0.02), Vector2(front + 0.14, 0.022), Vector2(front + 0.146, 0.014), Vector2(front + 0.148, -0.072),
					Vector2(front + 0.13, -0.08), Vector2(front + 0.1, -0.068), Vector2(front + 0.04, -0.03), Vector2(front, -0.022)], 0.036, m)
			_sl(r, s, [Vector2(front + 0.07, -0.024), Vector2(front + 0.122, -0.02), Vector2(front + 0.124, -0.052), Vector2(front + 0.108, -0.054)],
					0.0372, fin("bore"), 0.0)
			_sl(r, s, [Vector2(front + 0.148, 0.02), Vector2(front + 0.16, 0.02), Vector2(front + 0.16, -0.078), Vector2(front + 0.148, -0.08)],
					0.038, fin("rubber"), 0.002)
			_box(r.root, Vector3(0.008, 0.006, 0.036), s + Vector3(0, -0.024, front + 0.03), fin("black"), Vector3(-6, 0, 0), 0.0015)
			_stock_ends(r, s + Vector3(0, -0.03, front + 0.16), 0.098, s + Vector3(0, 0.02, front + 0.08))
		"precision_stock":
			# A chassis stock: aluminium spine, adjustable cheek on two posts, spacer stack, monopod.
			var m := fin("black")
			_box(r.root, Vector3(0.03, 0.03, 0.03), s + Vector3(0, 0, 0.012), fin("steel"), Vector3.ZERO, 0.002)
			_sl(r, s, [Vector2(0.02, 0.006), Vector2(0.27, 0.006), Vector2(0.274, -0.084), Vector2(0.24, -0.09), Vector2(0.15, -0.052),
					Vector2(0.08, -0.05), Vector2(0.02, -0.03)], 0.032, m)
			_sl(r, s, [Vector2(0.09, -0.008), Vector2(0.22, -0.008), Vector2(0.24, -0.03), Vector2(0.24, -0.06), Vector2(0.15, -0.038),
					Vector2(0.09, -0.036)], 0.0332, fin("bore"), 0.0)
			for z: float in [0.12, 0.21]:
				_cyl_y(r.root, 0.003, 0.018, s + Vector3(0, 0.014, z), fin("chrome"), 10)
			_sl(r, s, [Vector2(0.1, 0.03), Vector2(0.23, 0.03), Vector2(0.236, 0.024), Vector2(0.236, 0.02), Vector2(0.1, 0.02)], 0.03, fin("polymer"), 0.002)
			for i in 3:
				_sl(r, s, [Vector2(0.274 + i * 0.006, 0.008), Vector2(0.28 + i * 0.006, 0.008), Vector2(0.28 + i * 0.006, -0.088),
						Vector2(0.274 + i * 0.006, -0.088)], 0.034, fin("rubber" if i == 2 else ("black" if i == 0 else "steel")), 0.0008)
			_cyl_y(r.root, 0.008, 0.03, s + Vector3(0, -0.078, 0.23), fin("steel"), 12)
			_cyl_y(r.root, 0.011, 0.006, s + Vector3(0, -0.095, 0.23), fin("rubber"), 14)
			_stock_ends(r, s + Vector3(0, -0.04, 0.292), 0.1, s + Vector3(0, 0.03, 0.165))
			r.comb = s + Vector3(0, 0.03, 0.2)
		"wire_stock":
			# Bent rod: two side loops, a cross bar for a butt, a strip of tape for the cheek.
			var m := fin("bare")
			for sx: float in [-1.0, 1.0]:
				_tube(r.root, [s + Vector3(sx * 0.012, 0.01, 0.0), s + Vector3(sx * 0.012, 0.008, 0.21), s + Vector3(sx * 0.012, 0.0, 0.222),
						s + Vector3(sx * 0.012, -0.078, 0.222), s + Vector3(sx * 0.012, -0.085, 0.21), s + Vector3(sx * 0.012, -0.03, 0.0)], 0.0035, m, 10)
			for y: float in [-0.005, -0.07]:
				_cyl_x(r.root, 0.004, 0.028, s + Vector3(0, y, 0.222), m, 10)
			_box(r.root, Vector3(0.03, 0.02, 0.02), s + Vector3(0, -0.01, 0.005), fin("black"), Vector3.ZERO, 0.002)
			_box(r.root, Vector3(0.03, 0.01, 0.04), s + Vector3(0, 0.01, 0.15), fin("sand"), Vector3.ZERO, 0.002)
			_stock_ends(r, s + Vector3(0, -0.04, 0.226), 0.1, s + Vector3(0, 0.01, 0.15))
		"pistol_brace":
			# A tube off the back of the pistol, a finned arm brace and its velcro strap.
			_box(r.root, Vector3(0.022, 0.024, 0.03), s + Vector3(0, 0, 0.01), fin("black"), Vector3.ZERO, 0.002)
			_cyl(r.root, 0.011, 0.12, s + Vector3(0, 0.0, 0.08), fin("black"), 14)
			var m := fin("polymer")
			for sx: float in [-1.0, 1.0]:
				_slab(r.root, [Vector2(s.z + 0.07, s.y + 0.006), Vector2(s.z + 0.18, s.y + 0.012), Vector2(s.z + 0.186, s.y - 0.004),
						Vector2(s.z + 0.17, s.y - 0.06), Vector2(s.z + 0.08, s.y - 0.03)], 0.006, m, sx * 0.016, 0.0015)
			_sl(r, s, [Vector2(0.07, 0.008), Vector2(0.18, 0.014), Vector2(0.18, -0.004), Vector2(0.07, -0.014)], 0.028, m)
			_box(r.root, Vector3(0.046, 0.012, 0.022), s + Vector3(0, -0.052, 0.15), fin("poly_green"), Vector3(-20, 0, 0), 0.002)
			_stock_ends(r, s + Vector3(0, -0.012, 0.186), 0.05, s + Vector3(0, 0.013, 0.12))
		"hydraulic_stock":
			# A recoil-damping stock: oil cylinder and chrome ram along the top of the frame.
			var m := fin("steel")
			_box(r.root, Vector3(0.03, 0.03, 0.03), s + Vector3(0, 0, 0.012), fin("black"), Vector3.ZERO, 0.002)
			_sl(r, s, [Vector2(0.04, -0.004), Vector2(0.25, -0.004), Vector2(0.256, -0.09), Vector2(0.22, -0.096), Vector2(0.04, -0.04)], 0.034, m)
			_sl(r, s, [Vector2(0.08, -0.016), Vector2(0.2, -0.016), Vector2(0.21, -0.06), Vector2(0.08, -0.034)], 0.0352, fin("bore"), 0.0)
			_turn(r.root, [Vector2(0.05, 0.0), Vector2(0.05, 0.012), Vector2(0.15, 0.012), Vector2(0.155, 0.009), Vector2(0.155, 0.0)],
					Vector3(0, s.y + 0.014, s.z), fin("sulfur"), 16)
			_cyl(r.root, 0.005, 0.09, s + Vector3(0, 0.014, 0.2), fin("chrome"), 12)
			_cyl(r.root, 0.013, 0.008, s + Vector3(0, 0.014, 0.05), fin("black"), 16)
			_sl(r, s, [Vector2(0.244, 0.02), Vector2(0.264, 0.02), Vector2(0.264, -0.096), Vector2(0.244, -0.096)], 0.04, fin("rubber"), 0.002)
			_stock_ends(r, s + Vector3(0, -0.04, 0.264), 0.11, s + Vector3(0, 0.002, 0.15))
		"bump_stock":
			# A bulky slide-fire shell over a buffer, its finger rest reaching for the trigger.
			var m := fin("polymer")
			_sl(r, s, [Vector2(0.0, 0.02), Vector2(0.2, 0.024), Vector2(0.214, 0.014), Vector2(0.216, -0.08), Vector2(0.196, -0.086),
					Vector2(0.17, -0.07), Vector2(0.1, -0.036), Vector2(0.0, -0.034)], 0.042, m, 0.004)
			_grooves(r, s.z + 0.04, s.z + 0.14, s.y - 0.006, 0.02, 0.0215, 5)
			_box(r.root, Vector3(0.036, 0.008, 0.05), s + Vector3(0, 0.026, 0.12), fin("oxide"), Vector3.ZERO, 0.002)
			var rest := r.grip_top + Vector3(0, -0.004, -0.01)
			_box(r.root, Vector3(0.03, 0.01, absf(s.z - rest.z) + 0.02), Vector3(0, rest.y, (s.z + rest.z) / 2.0 + 0.01), m, Vector3.ZERO, 0.002)
			_box(r.root, Vector3(0.008, 0.016, 0.008), Vector3(0.016, rest.y - 0.01, rest.z), fin("oxide"), Vector3.ZERO, 0.002)
			_stock_ends(r, s + Vector3(0, -0.035, 0.216), 0.09, s + Vector3(0, 0.024, 0.12))
		"spring_stock":
			# A tube with a big exposed coil spring between the receiver and a sliding butt.
			_box(r.root, Vector3(0.03, 0.03, 0.024), s + Vector3(0, 0, 0.01), fin("black"), Vector3.ZERO, 0.002)
			_cyl(r.root, 0.007, 0.2, s + Vector3(0, 0, 0.11), fin("chrome"), 12)
			var coil := []
			for i in 57:
				var a := TAU * i / 8.0
				coil.append(s + Vector3(cos(a) * 0.014, sin(a) * 0.014, 0.025 + i * 0.0026))
			_tube(r.root, coil, 0.0022, fin("oxide"), 8)
			_sl(r, s, [Vector2(0.175, 0.02), Vector2(0.2, 0.02), Vector2(0.205, 0.012), Vector2(0.205, -0.075), Vector2(0.19, -0.08),
					Vector2(0.175, -0.072)], 0.034, fin("black"))
			_sl(r, s, [Vector2(0.205, 0.016), Vector2(0.217, 0.016), Vector2(0.217, -0.078), Vector2(0.205, -0.078)], 0.036, fin("rubber"), 0.002)
			_stock_ends(r, s + Vector3(0, -0.03, 0.217), 0.094, s + Vector3(0, 0.02, 0.19))
		"counterweight_stock":
			# A solid stock with a stack of lead weights bolted through it.
			_box(r.root, Vector3(0.03, 0.03, 0.03), s + Vector3(0, 0, 0.012), fin("black"), Vector3.ZERO, 0.002)
			_sl(r, s, [Vector2(0.02, 0.012), Vector2(0.24, 0.016), Vector2(0.246, 0.008), Vector2(0.248, -0.088), Vector2(0.226, -0.094),
					Vector2(0.12, -0.06), Vector2(0.02, -0.034)], 0.036, fin("poly_grey"))
			for i in 4:
				_cyl_x(r.root, 0.018, 0.012, s + Vector3(0.024, -0.036, 0.13 + i * 0.026), fin("steel"), 18)
				_cyl_x(r.root, 0.018, 0.012, s + Vector3(-0.024, -0.036, 0.13 + i * 0.026), fin("steel"), 18)
			_cyl_x(r.root, 0.004, 0.064, s + Vector3(0, -0.036, 0.17), fin("chrome"), 10)
			_sl(r, s, [Vector2(0.248, 0.014), Vector2(0.26, 0.014), Vector2(0.26, -0.092), Vector2(0.248, -0.092)], 0.038, fin("rubber"), 0.002)
			_stock_ends(r, s + Vector3(0, -0.04, 0.26), 0.106, s + Vector3(0, 0.016, 0.15))
		"glider_stock":
			# A skeleton stock with two folded canvas wings along its sides.
			_box(r.root, Vector3(0.026, 0.026, 0.02), s + Vector3(0, 0, 0.008), fin("black"), Vector3.ZERO, 0.002)
			_sl(r, s, [Vector2(0.01, 0.01), Vector2(0.22, 0.012), Vector2(0.226, -0.08), Vector2(0.2, -0.084), Vector2(0.03, -0.03)],
					0.012, fin("steel"))
			for sx: float in [-1.0, 1.0]:
				_slab(r.root, [Vector2(s.z + 0.02, s.y + 0.004), Vector2(s.z + 0.21, s.y + 0.03), Vector2(s.z + 0.215, s.y - 0.06),
						Vector2(s.z + 0.04, s.y - 0.03)], 0.003, fin("sand"), s.x + sx * 0.01, 0.0005)
				for k in 3:
					_cyl(r.root, 0.0016, 0.18, Vector3(s.x + sx * 0.012, s.y + 0.012 - k * 0.026, s.z + 0.12), fin("black"), 6)
			_sl(r, s, [Vector2(0.21, 0.014), Vector2(0.224, 0.014), Vector2(0.224, -0.086), Vector2(0.21, -0.086)], 0.03, fin("rubber"), 0.002)
			_stock_ends(r, s + Vector3(0, -0.035, 0.224), 0.1, s + Vector3(0, 0.012, 0.15))
		_:
			_sl(r, s, [Vector2(0.0, 0.004), Vector2(0.2, 0.004), Vector2(0.2, -0.045), Vector2(0.0, -0.045)], 0.034, fin("poly_grey"))
			_generic(r, s + Vector3(0, 0.0, 0.1), id)
			_stock_ends(r, s + Vector3(0, -0.02, 0.2), 0.05, s + Vector3(0, 0.005, 0.1))


## A stock silhouette from `s` (points are (back, up) offsets from the stock anchor).
static func _sl(r: Rig, s: Vector3, pts: Array, thick: float, m: Material, bevel := 0.003) -> void:
	var out := []
	for v: Vector2 in pts:
		out.append(Vector2(s.z + v.x, s.y + v.y))
	_slab(r.root, out, thick, m, s.x, bevel)


static func _stock_ends(r: Rig, butt: Vector3, height: float, comb: Vector3) -> void:
	r.butt = butt
	r.butt_h = height
	r.comb = comb


static func _buttpad(r: Rig, id: String) -> void:
	var b := r.butt if r.butt != Vector3.INF else r.stock + Vector3(0, -0.02, 0.02)
	var c := r.comb if r.comb != Vector3.INF else b + Vector3(0, r.butt_h * 0.5, -0.08)
	var h := r.butt_h
	match id:
		"rubber_pad":
			_box(r.root, Vector3(0.042, h + 0.004, 0.02), b + Vector3(0, 0, 0.01), mat("panel", BLACK), Vector3.ZERO, 0.006)
			for i in 3:
				_box(r.root, Vector3(0.044, 0.003, 0.004), b + Vector3(0, -h * 0.3 + i * h * 0.3, 0.016), mat("panel", DARK), Vector3.ZERO, 0.0)
		"gel_pad":
			_box(r.root, Vector3(0.044, h + 0.006, 0.026), b + Vector3(0, 0, 0.013), mat("grate", Color(1.3, 0.35, 0.25), Color(0.15, 0.02, 0.0)), Vector3.ZERO, 0.008)
		"cheek_riser":
			_box(r.root, Vector3(0.032, 0.022, 0.09), c + Vector3(0, 0.011, 0), mat("panel", TAN), Vector3.ZERO, 0.006)
			for z: float in [-0.025, 0.025]:
				_box(r.root, Vector3(0.04, 0.03, 0.012), c + Vector3(0, -0.002, z), mat("panel", OD), Vector3.ZERO, 0.002)
		"ammo_sleeve":
			# A nylon sleeve round the stock with a row of spare rounds on its right.
			var at := c + Vector3(0, -0.026, 0.0)
			_box(r.root, Vector3(0.046, 0.05, 0.08), at, mat("panel", OD), Vector3.ZERO, 0.006)
			for i in 5:
				_round(r, _rod(r.root, 0.0045, 0.0045, 0.03, at + Vector3(0.025, 0.0, -0.028 + i * 0.014), mat("brass"), 5, Vector3.ZERO))
			_box(r.root, Vector3(0.006, 0.012, 0.075), at + Vector3(0.025, -0.012, 0), mat("panel", BLACK), Vector3.ZERO, 0.001)
		"pogo_pad":
			# A butt pad on a fat coil spring, with a rubber foot.
			var points := []
			for i in 25:
				var a := TAU * i / 6.0
				points.append(b + Vector3(cos(a) * 0.014, sin(a) * 0.014, 0.004 + i * 0.0012))
			_tube(r.root, points, 0.0025, fin("chrome"), 4)
			_box(r.root, Vector3(0.04, h + 0.004, 0.014), b + Vector3(0, 0, 0.04), fin("rubber"), Vector3.ZERO, 0.005)
			_box(r.root, Vector3(0.042, 0.006, 0.016), b + Vector3(0, -h * 0.5, 0.04), fin("oxide"), Vector3.ZERO, 0.001)
		_:
			_generic(r, b + Vector3(0, 0, 0.012), id)


static func _ammo(r: Rig, id: String) -> void:
	var look: Array = AMMO_LOOK.get(id, [Color(0.9, 0.85, 0.7), Color.BLACK])
	var m := mat("panel", look[0], look[1])
	for node in r.rounds:
		node.material_override = m
	# A little holder on the side with spares, so the ammo reads from any angle.
	var s := r.side
	var out := signf(s.x) if s.x != 0.0 else 1.0
	var bolt := r.frame in ["crossbow", "harpoon"]
	var shell: bool = Arsenal.frame(r.frame).get("cal", "") == "12g"
	_box(r.root, Vector3(0.004, 0.022, 0.06), s + Vector3(out * 0.003, 0, 0), mat("panel", BLACK), Vector3.ZERO, 0.001)
	for i in 3 if bolt else 4:
		var z := (i - 1.5) * 0.015
		if bolt:
			_rod(r.root, 0.003, 0.003, 0.08, s + Vector3(out * 0.009, 0.006 - i * 0.008, z * 0.4), mat("wood", BONE), 4)
			_rod(r.root, 0.0, 0.006, 0.02, s + Vector3(out * 0.009, 0.006 - i * 0.008, z * 0.4 - 0.05), m, 4)
		elif shell:
			_rod(r.root, 0.0065, 0.0065, 0.034, s + Vector3(out * 0.01, 0.002, z), m, 6, Vector3.ZERO)
			_rod(r.root, 0.007, 0.007, 0.008, s + Vector3(out * 0.01, -0.018, z), mat("brass"), 6, Vector3.ZERO)
		else:
			_rod(r.root, 0.005, 0.005, 0.03, s + Vector3(out * 0.009, 0.002, z), m, 5, Vector3.ZERO)
			_rod(r.root, 0.0055, 0.0055, 0.008, s + Vector3(out * 0.009, -0.014, z), mat("brass"), 5, Vector3.ZERO)
	if not AMMO_LOOK.has(id):
		_generic(r, s + Vector3(out * 0.012, 0.02, 0), id)


static func _gadget(r: Rig, id: String) -> void:
	if id == "spring_bolt":
		# A fat spring bolted along the left of the receiver.
		var s := Vector3(-absf(r.side.x) - 0.008, r.side.y + 0.012, r.side.z + 0.02)
		var points := []
		for i in 25:
			var a := TAU * i / 6.0
			points.append(s + Vector3(cos(a) * 0.008, sin(a) * 0.008, -0.05 + i * 0.004))
		_tube(r.root, points, 0.0022, mat("panel", STEEL), 3)
		for z: float in [-0.054, 0.05]:
			_box(r.root, Vector3(0.008, 0.02, 0.006), s + Vector3(0.004, 0, z), mat("panel", DARK))
		return
	if id == "heatsink_fins":
		# A computer heatsink clipped to the top of the barrel with a zip tie.
		var at := r.barrel_start.lerp(r.muzzle, 0.35) + Vector3(0, r.barrel_r + 0.004, 0)
		if r.parts.has("handguard"):
			at = Vector3(0, r.hg_y + r.hg_r + 0.008, lerpf(r.hg_start, r.hg_end, 0.3))
		_box(r.root, Vector3(0.026, 0.004, 0.05), at, mat("panel", DARK), Vector3.ZERO, 0.0)
		for i in 6:
			_box(r.root, Vector3(0.028, 0.016, 0.0025), at + Vector3(0, 0.009, -0.022 + i * 0.0088), mat("panel", NICKEL), Vector3.ZERO, 0.0)
		_box(r.root, Vector3(0.004, 0.03, 0.006), at + Vector3(0, -0.008, 0.0), mat("panel", BLACK), Vector3.ZERO, 0.0)
		return
	# Everything else is a charm on a short chain.
	var g := r.gadget
	var hang := g + Vector3(0.004, -0.04, 0.012)
	_tube(r.root, [g, g + Vector3(0.002, -0.014, 0.004), g + Vector3(0.0, -0.028, 0.01), hang], 0.0018, mat("brass"), 3)
	var c := hang + Vector3(0, -0.012, 0)
	match id:
		"vampire_charm":
			var fur := mat("panel", Color(0.35, 0.2, 0.4))
			_ball(r.root, 0.009, c, fur, Vector3(1, 1.2, 0.9))
			for sx: float in [-1.0, 1.0]:
				_put(r.root, LowPoly.extrude(PackedVector2Array([Vector2(0, 0.004), Vector2(sx * 0.028, 0.012), Vector2(sx * 0.022, 0.0),
						Vector2(sx * 0.016, -0.004), Vector2(sx * 0.01, -0.002), Vector2(0, -0.004)]), 0.002), c, fur)
				_box(r.root, Vector3(0.003, 0.003, 0.002), c + Vector3(sx * 0.003, 0.004, -0.008), mat("panel", BLACK, Color(1, 0.05, 0.05)), Vector3.ZERO, 0.0)
				_box(r.root, Vector3(0.003, 0.006, 0.003), c + Vector3(sx * 0.004, 0.012, 0), fur, Vector3(0, 0, sx * -15.0), 0.0)
		"ghost_chamber":
			var ghost := mat("panel", Color(0.8, 0.95, 0.9), Color(0.25, 0.5, 0.4))
			_ball(r.root, 0.011, c + Vector3(0, -0.002, 0), ghost)
			_rod(r.root, 0.011, 0.0, 0.016, c + Vector3(0, -0.014, 0), ghost, 6, Vector3(180, 0, 0))
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.003, 0.005, 0.002), c + Vector3(sx * 0.004, 0.0, -0.01), mat("panel", BLACK), Vector3.ZERO, 0.0)
		"lucky_cat":
			var white := mat("panel", BONE)
			_ball(r.root, 0.012, c + Vector3(0, -0.006, 0), white, Vector3(1, 1.1, 0.9))
			_ball(r.root, 0.01, c + Vector3(0, 0.01, 0), white)
			for sx: float in [-1.0, 1.0]:
				_rod(r.root, 0.0, 0.004, 0.008, c + Vector3(sx * 0.006, 0.02, 0), white, 4, Vector3.ZERO)
			_box(r.root, Vector3(0.004, 0.012, 0.004), c + Vector3(0.012, 0.006, 0), white, Vector3(0, 0, -20), 0.001)
			_rod(r.root, 0.0085, 0.0085, 0.003, c + Vector3(0, 0.002, 0), mat("panel", RED), 8, Vector3.ZERO)
			_disc_x(r.root, 0.006, 0.002, c + Vector3(0, -0.006, -0.011), mat("brass", Color(1.3, 1.1, 0.5)), 8).rotation_degrees = Vector3(90, 0, 0)
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.003, 0.0015, 0.002), c + Vector3(sx * 0.004, 0.012, -0.009), mat("panel", BLACK), Vector3.ZERO, 0.0)
		"echo_bell":
			_lathe_z(r.root, [Vector2(0.0, -0.014), Vector2(0.004, -0.013), Vector2(0.007, -0.006), Vector2(0.008, 0.004),
					Vector2(0.012, 0.01), Vector2(0.0, 0.01)], Vector3.ZERO, mat("brass", Color(1.3, 1.1, 0.6)), 8).transform = \
					LowPoly.at(c + Vector3(0, -0.002, 0), Vector3(180, 0, 0))
			_ball(r.root, 0.003, c + Vector3(0, -0.014, 0), mat("panel", DARK))
		"oil_can":
			# A little oiler: a squat can with a long spout.
			_rod(r.root, 0.011, 0.011, 0.014, c + Vector3(0, -0.006, 0), mat("panel", RED), 8, Vector3.ZERO)
			_rod(r.root, 0.003, 0.011, 0.012, c + Vector3(0, 0.007, 0), mat("panel", RED), 8, Vector3.ZERO)
			_rod_between(r.root, c + Vector3(0, 0.012, 0), c + Vector3(0, 0.02, -0.022), 0.0016, mat("brass"), 4)
			_ball(r.root, 0.003, c + Vector3(0, -0.006, 0.012), mat("panel", BLACK, Color(0.2, 0.15, 0.0)))
		"rabbit_foot":
			var fur := mat("panel", Color(1.2, 1.1, 0.95))
			_ball(r.root, 0.009, c + Vector3(0, -0.01, 0), fur, Vector3(1, 1.8, 1), 0.25)
			_ball(r.root, 0.007, c + Vector3(0, -0.026, -0.004), mat("panel", Color(0.8, 0.6, 0.45)), Vector3(1, 1, 1.3), 0.3)
			_rod(r.root, 0.006, 0.006, 0.006, c + Vector3(0, 0.002, 0), mat("brass"), 6, Vector3.ZERO)
		"feather_charm":
			_slab(r.root, [Vector2(c.z, c.y + 0.004), Vector2(c.z - 0.006, c.y - 0.01), Vector2(c.z - 0.004, c.y - 0.03), Vector2(c.z, c.y - 0.04),
					Vector2(c.z + 0.005, c.y - 0.028), Vector2(c.z + 0.006, c.y - 0.008)], 0.002, fin("dust"), c.x, 0.0)
			_cyl_y(r.root, 0.0008, 0.046, c + Vector3(0, -0.018, 0), fin("sand"), 6)
		"skull_charm":
			var bone := fin("dust")
			_ball(r.root, 0.011, c + Vector3(0, -0.004, 0), bone, Vector3(1, 1, 1.1))
			_box(r.root, Vector3(0.012, 0.008, 0.01), c + Vector3(0, -0.015, -0.004), bone, Vector3.ZERO, 0.002)
			for sx: float in [-1.0, 1.0]:
				_ball(r.root, 0.0032, c + Vector3(sx * 0.0045, -0.004, -0.0095), fin("bore"))
		"propeller":
			_cyl_y(r.root, 0.004, 0.012, c, fin("chrome"), 12)
			for sx: float in [-1.0, 1.0]:
				_box(r.root, Vector3(0.05, 0.002, 0.012), c + Vector3(sx * 0.026, 0.006, 0), fin("oxide"), Vector3(0, 0, sx * 8.0), 0.0008)
		"anchor_charm":
			var iron := fin("steel")
			_cyl_y(r.root, 0.0035, 0.05, c + Vector3(0, -0.022, 0), iron, 10)
			_cyl_x(r.root, 0.003, 0.03, c + Vector3(0, -0.006, 0), iron, 8)
			_tube(r.root, [c + Vector3(-0.02, -0.036, 0), c + Vector3(-0.014, -0.046, 0), c + Vector3(0, -0.05, 0), c + Vector3(0.014, -0.046, 0),
					c + Vector3(0.02, -0.036, 0)], 0.0035, iron, 8)
		"lucky_dice":
			for k in 2:
				var at := c + Vector3(-0.006 + k * 0.012, -0.008 - k * 0.006, 0)
				_box(r.root, Vector3(0.011, 0.011, 0.011), at, fin("dust"), Vector3(15 + k * 30, 25, 10), 0.002)
				_ball(r.root, 0.0014, at + Vector3(0, 0, -0.0058), fin("oxide"))
		"metronome":
			# A little pyramid metronome with its pendulum swung to one side.
			_slab(r.root, [Vector2(c.z - 0.01, c.y - 0.022), Vector2(c.z + 0.01, c.y - 0.022), Vector2(c.z + 0.004, c.y + 0.012),
					Vector2(c.z - 0.004, c.y + 0.012)], 0.016, fin("laminate"), c.x, 0.001)
			_rod_between(r.root, c + Vector3(0, -0.016, -0.009), c + Vector3(0.006, 0.016, -0.009), 0.0012, fin("chrome"))
			_box(r.root, Vector3(0.004, 0.004, 0.002), c + Vector3(0.004, 0.008, -0.009), fin("brass"), Vector3.ZERO, 0.0)
		"trophy_charm":
			# A small brass cup on a black base.
			_box(r.root, Vector3(0.012, 0.006, 0.012), c + Vector3(0, -0.018, 0), fin("black"), Vector3.ZERO, 0.001)
			_cyl_y(r.root, 0.0015, 0.008, c + Vector3(0, -0.012, 0), fin("brass"), 8)
			_turn(r.root, [Vector2(-0.008, 0.002), Vector2(-0.004, 0.002), Vector2(0.0, 0.009), Vector2(0.006, 0.01), Vector2(0.008, 0.0)],
					c + Vector3(0, -0.002, 0), fin("brass"), 14).rotation_degrees = Vector3(-90, 0, 0)
			for sx: float in [-1.0, 1.0]:
				_tube(r.root, [c + Vector3(sx * 0.008, 0.004, 0), c + Vector3(sx * 0.013, 0.0, 0), c + Vector3(sx * 0.008, -0.004, 0)], 0.0012, fin("brass"), 3)
		"glass_heart":
			var red := fin("glass", Color(0.4, 0.05, 0.05))
			_ball(r.root, 0.008, c + Vector3(-0.0045, 0.0, 0), red)
			_ball(r.root, 0.008, c + Vector3(0.0045, 0.0, 0), red)
			_put(r.root, GunKit.rod(0.0, 0.0115, 12), c + Vector3(0, -0.012, 0), red, Vector3(90, 0, 0))
		"black_tape":
			# The gun is wound in black tape here and there, a roll still hanging off it.
			for z: float in [-0.12, -0.04, 0.03]:
				var at := (r.recv if r.recv != Vector3.INF else r.gadget + Vector3(0, 0.03, 0)) + Vector3(0, 0, z)
				_box(r.root, Vector3(maxf(r.body_w * 2.0, 0.026) + 0.004, 0.034, 0.016), at, fin("bore"), Vector3(0, 0, 4), 0.003)
			_cyl_x(r.root, 0.012, 0.012, c, fin("bore"), 16)
			_cyl_x(r.root, 0.006, 0.0125, c, fin("sand"), 12)
		"stopwatch":
			_cyl(r.root, 0.011, 0.006, c, fin("chrome"), 18)
			_cyl(r.root, 0.0095, 0.001, c + Vector3(0, 0, -0.0035), fin("dust"), 18)
			_box(r.root, Vector3(0.0012, 0.008, 0.001), c + Vector3(0, 0.003, -0.0042), fin("oxide"), Vector3(0, 0, -30), 0.0)
			_cyl_y(r.root, 0.002, 0.006, c + Vector3(0, 0.014, 0), fin("chrome"), 8)
		"chicken_foot":
			var skin := fin("sulfur")
			_cyl_y(r.root, 0.0025, 0.026, c + Vector3(0, -0.006, 0), skin, 6)
			for k in 3:
				var a := deg_to_rad(-40.0 + k * 40.0)
				_rod_between(r.root, c + Vector3(0, -0.019, 0), c + Vector3(sin(a) * 0.014, -0.028, -cos(a) * 0.008), 0.0018, skin)
		_:
			_generic(r, c + Vector3(0, -0.006, 0), id)
