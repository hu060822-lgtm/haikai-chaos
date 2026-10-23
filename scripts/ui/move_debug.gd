class_name MoveDebug
extends Control
## The movement debug panel (F4): what the movement system is doing right now, so a failed
## move can be traced to a cause (too slow, wrong angle, wall not runnable, input timing).
## Left column: state, speeds, what limited the speed, open input windows, the wall in
## reach, recent transitions with their reasons, recent failures. Right: a top-down
## compass (velocity, input, wall normal) and the last 6 s of horizontal speed.
## In the world it draws the wall probes, the velocity vector and the floor normal.
## F7 cycles the physics tick rate (60 / 120 / 240) to compare feel.

const WIDTH := 470.0
const GRAPH_SECONDS := 6.0
const TICKS := [60, 120, 240]

var player: Player
var _history: Array[float] = []
var _history_state: Array[int] = []
var _world: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _font: Font


func _init() -> void:
	set_anchors_preset(PRESET_TOP_LEFT)
	position = Vector2(14, 14)
	size = Vector2(WIDTH, 640)
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	_font = FpUi.bold()


func toggle() -> void:
	visible = not visible
	if _world:
		_world.visible = visible


static func cycle_ticks() -> int:
	var i := TICKS.find(Engine.physics_ticks_per_second)
	Engine.physics_ticks_per_second = TICKS[(i + 1) % TICKS.size()]
	Engine.max_physics_steps_per_frame = maxi(8, Engine.physics_ticks_per_second / 15)
	return Engine.physics_ticks_per_second


func _ready() -> void:
	_world = MeshInstance3D.new()
	_world.mesh = _mesh
	_world.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.render_priority = 10
	_world.material_override = m
	_world.visible = visible
	(func() -> void: player.get_parent().add_child(_world)).call_deferred()


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	# Sample every tick even when hidden, so the graph is full the moment you open it.
	var per_second := Engine.physics_ticks_per_second
	_history.append(player.flat_speed())
	_history_state.append(player.move)
	var keep := int(GRAPH_SECONDS * per_second)
	while _history.size() > keep:
		_history.pop_front()
		_history_state.pop_front()


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	queue_redraw()
	_draw_world()


func _draw_world() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for r in player.rays:
		var c := Faultprint.TEAL if r[3] else (Faultprint.YELLOW if r[2] else Color(0.6, 0.6, 0.6))
		_line(r[0], r[1], c)
	# Drawn a little ahead of you on the ground, so it's in view while you look forward.
	var feet := player.global_position + Vector3(0, 0.05, 0) + Vector3(-player.global_basis.z.x, 0, -player.global_basis.z.z).normalized() * 2.5
	var v := player.velocity
	_line(feet, feet + v * 0.15, Faultprint.ORANGE)
	_line(feet + v * 0.15, feet + v * 0.15 + Vector3(0, 0.25, 0), Faultprint.ORANGE)
	if player.wish_dir != Vector3.ZERO:
		_line(feet + Vector3(0, 0.02, 0), feet + player.wish_dir * 1.2 + Vector3(0, 0.02, 0), Faultprint.TEAL)
	if player.is_on_floor():
		_line(feet, feet + player.get_floor_normal() * 0.8, Faultprint.BONE)
	if not player.wall_info.is_empty():
		var p: Vector3 = player.wall_info.point
		_line(p, p + player.wall_info.normal * 0.8, Faultprint.YELLOW)
	# The capsule's outline, as two rings and four lines.
	var h: float = player.get_node("Shape").shape.height
	for y in [0.0, h]:
		for i in 12:
			var a := TAU * i / 12.0
			var b := TAU * (i + 1) / 12.0
			_line(player.global_position + Vector3(cos(a), 0, sin(a)) * Player.RADIUS + Vector3(0, y, 0),
				player.global_position + Vector3(cos(b), 0, sin(b)) * Player.RADIUS + Vector3(0, y, 0), Color(1, 1, 1, 0.6))
	_mesh.surface_end()


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)


func _draw() -> void:
	var p := player
	draw_style_box(FpUi.panel(Color(Faultprint.CARBON, 0.86), Faultprint.ORANGE, 10, 2), Rect2(Vector2.ZERO, size))
	var x := 14.0
	var y := 26.0
	var bone := Faultprint.BONE
	var dim := Color(Faultprint.BONE, 0.55)
	_text("移動除錯（F4 關閉 · F7 物理 %d Hz · F5 鏡頭 %s）" % [Engine.physics_ticks_per_second, CameraFx.level_name()],
		Vector2(x, y), 14, Faultprint.ORANGE)
	y += 26
	_text(Player.MOVE_NAMES[p.move], Vector2(x, y + 6), 28, bone)
	_text("落地：" + (p.landing if p.landing != "" else "—"), Vector2(x + 110, y), 13, dim)
	_text("限速：" + (p.limiter if p.limiter != "" else "—"), Vector2(x + 110, y + 17), 13, Faultprint.YELLOW)
	y += 38
	var v := p.velocity
	var rows := [
		["水平速度", "%.2f m/s" % p.flat_speed()],
		["垂直速度", "%+.2f m/s" % v.y],
		["總速度", "%.2f m/s" % v.length()],
		["水平加速度", "%+.1f m/s²" % p.accel],
		["空中轉向", ("%.0f °/s" % p.air_control) if p.air_control > 0.0 else "—"],
		["槍重", "%.1f kg（不影響身法）" % p.weapon.stats.weight],
	]
	for r in rows:
		_text(r[0], Vector2(x, y), 13, dim)
		_text(r[1], Vector2(x + 96, y), 15, bone)
		y += 19
	y += 4
	_text("輸入窗口", Vector2(x, y), 13, Faultprint.ORANGE)
	y += 18
	var w := p.windows()
	var tune := p.tune
	for spec in [["跳躍緩衝", w.jump, tune.jump_buffer], ["離地寬限", w.coyote, tune.coyote], ["蹲緩衝", w.crouch, tune.crouch_buffer],
			["離牆寬限", w.wall_coyote, tune.wall_coyote], ["落地不減速", w.grace, tune.land_grace]]:
		_text(spec[0], Vector2(x, y), 12, dim)
		var frac := clampf(float(spec[1]) / float(spec[2]), 0.0, 1.0)
		draw_rect(Rect2(x + 80, y - 9, 120, 8), Color(bone, 0.15))
		draw_rect(Rect2(x + 80, y - 9, 120 * frac, 8), Faultprint.TEAL if frac > 0.0 else dim)
		_text("%.0f ms" % (float(spec[1]) * 1000.0), Vector2(x + 208, y), 12, bone if frac > 0.0 else dim)
		y += 16
	y += 6
	_text("牆面", Vector2(x, y), 13, Faultprint.ORANGE)
	y += 18
	if p.wall_info.is_empty():
		_text("範圍內沒有牆", Vector2(x, y), 13, dim)
	else:
		var wi := p.wall_info
		var side: String = {1: "右側", -1: "左側", 0: "正前方"}.get(wi.side, "")
		_text("%s　距離 %.2f m　%s" % [side, wi.distance, "可牆跑" if wi.runnable else "不可牆跑"], Vector2(x, y), 13,
			Faultprint.TEAL if wi.runnable else bone)
		var n: Vector3 = wi.normal
		_text("法線 (%.2f, %.2f)　踢牆剩 %d　牆跑剩 %d%%" % [n.x, n.z, p.kicks_left(), roundi(p.wall_time_left() * 100)],
			Vector2(x, y + 16), 12, dim)
	y += 38
	_text("最近的狀態轉換", Vector2(x, y), 13, Faultprint.ORANGE)
	y += 18
	for t in p.transitions.slice(0, 5):
		var age := p.clock - float(t.t)
		_text("%4.1fs  %s → %s　%s" % [age, Player.MOVE_NAMES[t.from], Player.MOVE_NAMES[t.to], t.why], Vector2(x, y), 12,
			bone if age < 1.5 else dim)
		y += 16
	y += 6
	_text("最近沒成功的動作", Vector2(x, y), 13, Faultprint.ORANGE)
	y += 18
	if p.failures.is_empty():
		_text("—", Vector2(x, y), 12, dim)
	for f in p.failures.slice(0, 4):
		var age := p.clock - float(f.t)
		_text("%4.1fs  %s" % [age, f.why], Vector2(x, y), 12, Faultprint.YELLOW if age < 1.5 else dim)
		y += 16
	_draw_compass(Vector2(WIDTH - 70, 120), 52.0)
	_draw_graph(Rect2(x, size.y - 104, WIDTH - 28, 86))


## Top-down, facing up: velocity (orange), input (teal), the wall's normal (yellow).
func _draw_compass(c: Vector2, r: float) -> void:
	var p := player
	draw_arc(c, r, 0, TAU, 40, Color(Faultprint.BONE, 0.4), 1.5)
	draw_line(c + Vector2(0, -r), c + Vector2(0, -r + 8), Faultprint.BONE, 2)
	var inv := p.global_basis.inverse()
	var vl := inv * Vector3(p.velocity.x, 0, p.velocity.z)
	var scale := r / 16.0
	var vv := Vector2(vl.x, vl.z) * scale
	if vv.length() > r:
		vv = vv.normalized() * r
	draw_line(c, c + vv, Faultprint.ORANGE, 3)
	var wl := inv * p.wish_dir
	if p.wish_dir != Vector3.ZERO:
		draw_line(c, c + Vector2(wl.x, wl.z) * r * 0.6, Faultprint.TEAL, 2)
	if not p.wall_info.is_empty():
		var nl := inv * (p.wall_info.normal as Vector3)
		draw_line(c - Vector2(nl.x, nl.z) * r, c - Vector2(nl.x, nl.z) * r * 0.6, Faultprint.YELLOW, 3)
	_text("速度 · 輸入 · 牆", c + Vector2(-46, r + 18), 11, Color(Faultprint.BONE, 0.55))


## Horizontal speed over the last few seconds, coloured by state, with run/sprint lines.
func _draw_graph(rect: Rect2) -> void:
	draw_rect(rect, Color(Faultprint.BONE, 0.08))
	var top := 20.0
	for line in [[player.tune.run_speed * player.mobility, "跑"], [player.tune.sprint_speed * player.mobility, "衝"], [15.0, "15"]]:
		var yy: float = rect.end.y - rect.size.y * float(line[0]) / top
		draw_line(Vector2(rect.position.x, yy), Vector2(rect.end.x, yy), Color(Faultprint.BONE, 0.2), 1)
		_text(line[1], Vector2(rect.end.x - 18, yy - 2), 10, Color(Faultprint.BONE, 0.5))
	var n := _history.size()
	if n < 2:
		return
	var keep := GRAPH_SECONDS * Engine.physics_ticks_per_second
	var colors := {Player.Move.GROUND: Faultprint.BONE, Player.Move.AIR: Faultprint.TEAL, Player.Move.SLIDE: Faultprint.YELLOW,
		Player.Move.WALLRUN: Faultprint.ORANGE}
	var step := maxi(n / 300, 1)
	var prev := Vector2.ZERO
	for i in range(0, n, step):
		var px := rect.end.x - rect.size.x * float(n - 1 - i) / keep
		var py := rect.end.y - rect.size.y * clampf(_history[i] / top, 0.0, 1.0)
		var pt := Vector2(px, py)
		if i > 0:
			draw_line(prev, pt, colors.get(_history_state[i], Color(0.8, 0.5, 1.0)), 2)
		prev = pt
	_text("水平速度（6 秒）　白 地面　黃 滑鏟　藍綠 空中　橘 牆跑", Vector2(rect.position.x + 4, rect.position.y + 12), 11,
		Color(Faultprint.BONE, 0.6))


func _text(s: String, at: Vector2, font_size: int, c: Color) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)
