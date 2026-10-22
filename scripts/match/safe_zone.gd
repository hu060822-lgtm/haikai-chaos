class_name SafeZone
## Team safe zones (the spawn rooms): where you can mod your gun in peace.
##   inside your own zone   enemies can't hurt you, and you can't hurt anyone outside it
##                          (so nobody camps the exit from cover they can't be shot in)
##   inside the enemy's     the zone pushes back: REPEL damage per second (team matches)
##   anywhere else          the bench only opens out of combat (Player.can_mod)
## Zones are plain data set by whoever builds the match ({"at", "radius", "team"}); the
## floor rings are drawn by draw().

const REPEL := 25.0
const HEIGHT := 6.0

static var zones: Array = []
## Team matches turn the push-back on; practice keeps it off (the bots wander anywhere).
static var repel := false


static func clear() -> void:
	zones.clear()
	repel = false


static func add(at: Vector3, radius: float, team: int) -> void:
	zones.append({"at": at, "radius": radius, "team": team})


## The team whose zone `pos` is in, or -1.
static func team_at(pos: Vector3) -> int:
	for z in zones:
		var d: Vector3 = pos - z.at
		if Vector2(d.x, d.z).length() <= float(z.radius) and d.y > -1.0 and d.y < HEIGHT:
			return int(z.team)
	return -1


static func is_safe(pos: Vector3, team: int) -> bool:
	return team >= 0 and team_at(pos) == team


## True when a hit described by `info` must not land on someone of `team` at `pos`:
## the victim is home, or the shot came from inside the shooter's own zone.
static func blocks(info: Dictionary, team: int, pos: Vector3) -> bool:
	if info.get("self_hit", false) or info.get("zone_hit", false):
		return false
	if int(info.get("team", -1)) == team:
		return false
	if is_safe(pos, team) or info.get("from_safe", false):
		info.blocked = true
		return true
	return false


## Push-back damage per second for someone of `team` standing at `pos` (0 when fine).
static func repel_at(pos: Vector3, team: int) -> float:
	if not repel:
		return 0.0
	var t := team_at(pos)
	return REPEL if t >= 0 and t != team else 0.0


## Floor rings for every zone, tinted by team (ally blue for `my_team`, enemy red).
static func draw(parent: Node3D, my_team: int) -> void:
	for z in zones:
		var ally: bool = int(z.team) == my_team
		var tint := FpUi.ally_color() if ally else FpUi.enemy_color()
		var ring := MeshInstance3D.new()
		var outer := float(z.radius)
		ring.mesh = _ring_mesh(outer - 0.25, outer, 48)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(tint, 0.75)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = (z.at as Vector3) + Vector3(0, 0.03, 0)
		ring.name = "SafeZone%d" % int(z.team)
		parent.add_child(ring)
		var fill := MeshInstance3D.new()
		fill.mesh = _ring_mesh(0.0, outer - 0.25, 48)
		var mf := m.duplicate() as StandardMaterial3D
		mf.albedo_color = Color(tint, 0.08)
		fill.material_override = mf
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fill.position = ring.position + Vector3(0, -0.005, 0)
		parent.add_child(fill)


static func _ring_mesh(inner: float, outer: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		st.add_vertex(p0 * inner)
		st.add_vertex(p1 * outer)
		st.add_vertex(p0 * outer)
		if inner > 0.0:
			st.add_vertex(p0 * inner)
			st.add_vertex(p1 * inner)
			st.add_vertex(p1 * outer)
	return st.commit()
