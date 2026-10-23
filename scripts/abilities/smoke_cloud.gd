class_name SmokeCloud
extends Node3D
## VEIL's smoke (C6). The canister flies the arc its thrower worked out (`from` → `to` in
## `flight` seconds, the same on every machine), then the cloud swells to a dome RADIUS
## wide and HEIGHT tall over the landing point and holds for LIFE seconds.
##
## Fair both ways: nobody sees through it, players or bots (Deploy.sight_blocked), and
## inside it the screen goes grey for everyone. Its edge is sharp and its top is open, so
## the movement decides the angle you come out at: over the top on a wall run or a line,
## low out of a slide, or straight through. Counters: it ends, it can be held from outside,
## and a blast (explosion or slam) blows it thin for BLOWN seconds.

const RADIUS := 5.5
const HEIGHT := 3.6        # half-height of the dome above its centre
const LIFT := 1.2          # the centre sits this far above the ground
const GROW := 0.8
const LIFE := 10.0
const FADE := 1.0
const BLOWN := 1.5
const PUFFS := 14

var uid := ""
var owner_id := ""
var team := 0
var from := Vector3.ZERO
var to := Vector3.ZERO
var flight := 0.6
var t := 0.0
var _canister: MeshInstance3D
var _cloud: Node3D
var _body: MeshInstance3D
var _mat: StandardMaterial3D
var _puffs: Array[MeshInstance3D] = []
var _puff_mat: StandardMaterial3D
var _blown := 0.0
var _rng := RandomNumberGenerator.new()


func setup(data: Dictionary) -> void:
	from = data.get("from", Vector3.ZERO)
	to = data.get("to", Vector3.ZERO)
	flight = maxf(float(data.get("flight", 0.6)), 0.05)
	_rng.seed = hash(uid)


func _ready() -> void:
	add_to_group("deployables")
	top_level = true
	global_position = to
	_canister = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = 0.26
	_canister.mesh = cyl
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Kit.info("veil").color
	cm.emission_enabled = true
	cm.emission = Kit.info("veil").color * 0.4
	_canister.material_override = cm
	add_child(_canister)
	_cloud = Node3D.new()
	_cloud.position = Vector3(0, LIFT, 0)
	_cloud.visible = false
	add_child(_cloud)
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_mat.albedo_color = Color(0.74, 0.76, 0.78, 0.9)
	_mat.roughness = 1.0
	_body = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 24
	s.rings = 12
	_body.mesh = s
	_body.material_override = _mat
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud.add_child(_body)
	_puff_mat = _mat.duplicate()
	_puff_mat.albedo_color = Color(0.82, 0.83, 0.85, 0.75)
	for i in PUFFS:
		var p := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 1.0
		ps.height = 2.0
		ps.radial_segments = 12
		ps.rings = 6
		p.mesh = ps
		p.material_override = _puff_mat
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := _rng.randf() * TAU
		var up := _rng.randf_range(-0.2, 0.9)
		var r := _rng.randf_range(0.55, 0.85)
		p.position = Vector3(cos(a) * RADIUS * r, up * HEIGHT, sin(a) * RADIUS * r)
		p.set_meta("base", p.position)
		p.set_meta("size", _rng.randf_range(1.6, 2.6))
		p.set_meta("spin", _rng.randf_range(0.2, 0.6) * (1.0 if _rng.randf() < 0.5 else -1.0))
		_cloud.add_child(p)
		_puffs.append(p)
	_place_canister(0.0)


func _physics_process(delta: float) -> void:
	t += delta
	_blown = maxf(_blown - delta, 0.0)
	if t < flight:
		_place_canister(t / flight)
		return
	if not _cloud.visible:
		_cloud.visible = true
		_canister.position = Vector3(0, 0.1, 0)
		Sfx.play(self, "smoke_pop", -2.0)
	var k := scale_now()
	_cloud.scale = Vector3.ONE * maxf(k, 0.01)
	_body.scale = Vector3(RADIUS, HEIGHT, RADIUS)
	var fade := clampf((flight + LIFE - t) / FADE, 0.0, 1.0)
	var thin := 1.0 - 0.7 * clampf(_blown / 0.4, 0.0, 1.0)
	_mat.albedo_color.a = 0.9 * fade * thin
	_puff_mat.albedo_color.a = 0.75 * fade * thin
	var age := t - flight
	for p in _puffs:
		var base: Vector3 = p.get_meta("base")
		var spin := float(p.get_meta("spin"))
		p.position = base.rotated(Vector3.UP, age * spin * 0.15) + Vector3(0, sin(age * 0.7 + base.x) * 0.25, 0)
		p.scale = Vector3.ONE * float(p.get_meta("size")) * (1.0 + 0.08 * sin(age * 1.3 + base.z))
	if t >= flight + LIFE:
		queue_free()


## The canister's arc: a straight line plus a parabola that peaks a little above both ends.
func _place_canister(k: float) -> void:
	var p := from.lerp(to, k)
	var peak := maxf(1.5, from.distance_to(to) * 0.18)
	p.y += 4.0 * peak * k * (1.0 - k)
	_canister.global_position = p
	_canister.rotation = Vector3(k * 9.0, k * 4.0, 0)


## How big the cloud is now, 0..1 of full size.
func scale_now() -> float:
	if t < flight:
		return 0.0
	var grow := clampf((t - flight) / GROW, 0.0, 1.0)
	return 1.0 - pow(1.0 - grow, 3.0)


func live() -> bool:
	return t >= flight and t < flight + LIFE - FADE * 0.5


func blow(at: Vector3, radius: float) -> void:
	if not live():
		return
	var c := global_position + Vector3(0, LIFT, 0)
	if at.distance_to(c) <= RADIUS + radius:
		_blown = BLOWN


## The point `p` in the cloud's unit sphere (1 = its edge).
func _unit(p: Vector3) -> Vector3:
	var c := global_position + Vector3(0, LIFT, 0)
	var k := maxf(scale_now(), 0.01)
	var d := p - c
	return Vector3(d.x / (RADIUS * k), d.y / (HEIGHT * k), d.z / (RADIUS * k))


## Does the cloud hide `b` from `a`? A line that passes well inside it (not just grazing
## the edge) is blocked; blown-thin smoke blocks nothing.
func blocks(a: Vector3, b: Vector3) -> bool:
	if not live() or _blown > 0.0 or scale_now() < 0.5:
		return false
	var p := _unit(a)
	var q := _unit(b)
	var d := q - p
	var len2 := d.length_squared()
	var s := 0.0 if len2 < 0.0001 else clampf(-p.dot(d) / len2, 0.0, 1.0)
	return (p + d * s).length() < 0.85


## 0..1: how deep `p` is in the cloud.
func density_at(p: Vector3) -> float:
	if t < flight or t >= flight + LIFE:
		return 0.0
	var fade := clampf((flight + LIFE - t) / FADE, 0.0, 1.0)
	var thin := 0.3 if _blown > 0.0 else 1.0
	return clampf((1.0 - _unit(p).length()) * 4.0, 0.0, 1.0) * fade * thin


func on_event(what: String, _amount: float) -> void:
	if what == "clear":
		queue_free()
