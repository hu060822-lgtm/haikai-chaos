class_name MovementLab
extends Node3D
## 移動測試場 MOVEMENT LAB: a fixed place to test and practise movement. Three timed routes
## and a free practice area, all running north (-Z) from the hub at the south end:
##   A 滑鏟循環   x -60  sprint -> slide down a ramp -> slide jump the hurdles -> land into
##                       a slide -> again (the core loop, on the ground)
##   B 牆跑連段   x -25  sprint -> jump -> wall run -> wall jump -> steer -> wall run on the
##                       other side, four walls over a pit
##   C 高速綜合   x  20  fast slide down a long ramp -> slide jump the ditch while shooting
##                       the boards -> kick off a wall onto a ledge -> fast landing -> run
##   practice     x 36..80: low obstacles of five heights, long and short run walls, a pair
##                of facing walls, a corner, a kick shaft, a narrow beam, a 12 m drop
##                tower, and landing pads to aim jumps at
## Gates are planes across the lane: crossing the first starts the clock, the last stops
## it. Falling into a pit (below y -2.5) puts you back at the route's start; T does too.
## Results (time, average / lowest speed, momentum breaks) and best times are kept.

signal route_finished(result: Dictionary)

const PIT_Y := -2.5
## Speed below which (for BREAK_TIME) a run counts a momentum break.
const BREAK_SPEED := 5.0
const BREAK_TIME := 0.25
const BEST_FILE := "user://routes.cfg"

var player_spawn := Transform3D(Basis.IDENTITY, Vector3(-60, 4.1, 42.0))
var bot_spawns: Array[Vector3] = []
var waypoints: Array[Vector3] = []
var range_targets: Array[Transform3D] = []
## id -> {id, name, how, start: Transform3D, gates: [{z, x0, x1, y0, y1}]}
var routes := {}
var player: Player
var active := {}            # the route being run, or {}
var last_route := "A"
var last_result := {}
var best := {}

var _gate := 0
var _t := 0.0
var _splits: Array[float] = []
var _dist := 0.0
var _min_speed := INF
var _max_speed := 0.0
var _breaks := 0
var _slow_for := 0.0
var _prev := Vector3.ZERO
var _has_prev := false
var _hud: Label
var _hud_sub: Label
var _hud_left := 0.0


func _ready() -> void:
	name = "MovementLab"
	Faultprint.environment(self, Vector3(-50.0, -30.0, 0.0))
	_load_best()
	_base()
	_lane_a()
	_lane_b()
	_lane_c()
	_practice()
	_make_hud()


func _process(delta: float) -> void:
	if _hud == null:
		return
	_hud_left -= delta
	if not active.is_empty():
		_hud.text = "路線 %s %s　%.2f s　門 %d / %d　%.1f m/s" % [active.id, active.name, _t, _gate, active.gates.size(),
			player.flat_speed() if player else 0.0]
		_hud_sub.text = active.how
		_hud.get_parent().visible = true
	elif _hud_left > 0.0:
		_hud.get_parent().visible = true
	else:
		_hud.get_parent().visible = false


func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
	if not player.alive:
		_has_prev = false
		return
	var pos := player.global_position
	if pos.y < PIT_Y:
		_fail_route("掉下去了")
		return
	if _has_prev:
		if not active.is_empty():
			_t += delta
			_dist += Vector2(pos.x - _prev.x, pos.z - _prev.z).length()
			var s := player.flat_speed()
			_max_speed = maxf(_max_speed, s)
			# The pull-up of a mantle is deliberately vertical: it doesn't count as slow.
			if _t > 1.0 and player.move != Player.Move.MANTLE:
				_min_speed = minf(_min_speed, s)
				if s < BREAK_SPEED:
					_slow_for += delta
					if _slow_for >= BREAK_TIME and _slow_for - delta < BREAK_TIME:
						_breaks += 1
				else:
					_slow_for = 0.0
			if _crossed(active.gates[_gate], _prev, pos):
				_splits.append(_t)
				_gate += 1
				Sfx.ui(get_tree(), "hit")
				if _gate >= active.gates.size():
					_finish()
		for id in routes:
			var r: Dictionary = routes[id]
			if (active.is_empty() or active.id != id or _gate > 1) and _crossed(r.gates[0], _prev, pos):
				_begin(r)
	_prev = pos
	_has_prev = true


func _crossed(g: Dictionary, a: Vector3, b: Vector3) -> bool:
	if not (a.z > g.z and b.z <= g.z):
		return false
	var t: float = (a.z - g.z) / maxf(a.z - b.z, 0.0001)
	var p := a.lerp(b, t)
	return p.x >= g.x0 and p.x <= g.x1 and p.y >= g.y0 and p.y <= g.y1


func _begin(r: Dictionary) -> void:
	active = r
	last_route = r.id
	_gate = 1
	_t = 0.0
	_splits = [0.0]
	_dist = 0.0
	_min_speed = INF
	_max_speed = 0.0
	_breaks = 0
	_slow_for = 0.0


func _finish() -> void:
	var r := active
	var avg := _dist / maxf(_t, 0.01)
	last_result = {"route": r.id, "time": _t, "avg": avg, "min": _min_speed if _min_speed < INF else 0.0,
		"max": _max_speed, "breaks": _breaks, "splits": _splits.duplicate(), "ok": true}
	var prev_best: float = best.get(r.id, INF)
	var record := _t < prev_best
	if record:
		best[r.id] = _t
		_save_best()
	_hud.text = "路線 %s 完成　%.2f s%s" % [r.id, _t, "　新紀錄！" if record else "　最佳 %.2f s" % prev_best]
	_hud_sub.text = "平均 %.1f m/s　最低 %.1f m/s　最高 %.1f m/s　動量中斷 %d 次" % [avg, last_result.min, _max_speed, _breaks]
	_hud_left = 6.0
	active = {}
	Sfx.ui(get_tree(), "kill")
	route_finished.emit(last_result)


func _fail_route(why: String) -> void:
	var id := last_route
	if not active.is_empty():
		last_result = {"route": active.id, "time": _t, "ok": false, "why": why, "gate": _gate}
		_hud.text = "路線 %s 失敗：%s（門 %d / %d）" % [active.id, why, _gate, active.gates.size()]
		_hud_sub.text = "按 T 或從起點重新開始"
		_hud_left = 4.0
		active = {}
	restart(id)


## Back to the start of route `id` (T), standing still.
func restart(id := "") -> void:
	if id == "":
		id = last_route
	if player == null:
		return
	active = {}
	_has_prev = false
	player.spawn_at(routes[id].start)
	last_route = id


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(BEST_FILE) == OK:
		for id in ["A", "B", "C"]:
			if cfg.has_section_key("best", id):
				best[id] = float(cfg.get_value("best", id))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	for id in best:
		cfg.set_value("best", id, best[id])
	cfg.save(BEST_FILE)


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FpUi.panel(Color(Faultprint.BONE, 0.9), Faultprint.CARBON, 10, 2))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = 14
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_hud = FpUi.label("", 20, Faultprint.CARBON, FpUi.bold())
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hud)
	_hud_sub = FpUi.label("", 14, Faultprint.GRAPHITE, FpUi.bold())
	_hud_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hud_sub)


# --- Building -----------------------------------------------------------------------------

func _base() -> void:
	# The paper floor far below everything: falling there resets you.
	Geo.slab(self, Vector2(-95, -75), Vector2(95, 75), -6.0, 1.0, Faultprint.DUST,
		{"print": {"slip": null, "wear": 0.5, "shadow_ink": 0.3, "dot_px": 7.0}})
	# The hub along the south end.
	Geo.slab(self, Vector2(-80, 44), Vector2(84, 62), 0.0, 6.0, Faultprint.CONCRETE,
		{"print": {"slip": null, "wear": 0.4, "shadow_ink": 0.3, "shadow_tone": 0.7, "dot_px": 7.0}})
	_sign("移動測試場　MOVEMENT LAB\nF4 除錯面板　F5 鏡頭效果　F7 物理頻率　T 回到路線起點", Vector3(-20, 4.5, 60.5), 0.0, 2.2)


func _route(id: String, title: String, how: String, start: Transform3D, gates: Array) -> void:
	var list := []
	for g in gates:
		list.append({"z": g[0], "x0": g[1], "x1": g[2], "y0": g[3], "y1": g[4]})
		_gate_mark(g, list.size() == 1, list.size() == gates.size(), list.size() - 1)
	routes[id] = {"id": id, "name": title, "how": how, "start": start, "gates": list}
	var p := start.origin
	_sign("路線 %s　%s\n%s" % [id, title, how], p + Vector3(0, 3.2, -4.0), 0.0, 1.0)


## A gate: two posts and a bar across the lane (start teal, finish yellow, splits orange).
func _gate_mark(g: Array, first: bool, last: bool, index: int) -> void:
	var color := Faultprint.TEAL if first else (Faultprint.YELLOW if last else Faultprint.ORANGE)
	var m := Faultprint.surface(color, {"slip": null, "pattern": 2})
	var floor_y: float = g[3] + 1.0
	for x in [g[1], g[2]]:
		var post := MeshInstance3D.new()
		post.mesh = LowPoly.chamfer_box(Vector3(0.25, 4.0, 0.25), 0.03)
		post.position = Vector3(x, floor_y + 2.0, g[0])
		post.material_override = m
		add_child(post)
	var bar := MeshInstance3D.new()
	bar.mesh = LowPoly.chamfer_box(Vector3(float(g[2]) - float(g[1]), 0.22, 0.22), 0.03)
	bar.position = Vector3((float(g[1]) + float(g[2])) / 2.0, floor_y + 4.0, g[0])
	bar.material_override = m
	add_child(bar)
	var label := "起點" if first else ("終點" if last else "%d" % index)
	_sign(label, Vector3(g[2] - 0.6, floor_y + 4.6, g[0]), 0.0, 1.4)


func _sign(text: String, at: Vector3, yaw: float, scale := 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = FpUi.bold()
	l.font_size = 64
	l.pixel_size = 0.006 * scale
	l.modulate = Faultprint.ui_ink
	l.outline_modulate = Faultprint.ui_paper
	l.outline_size = 14
	l.position = at
	l.rotation.y = yaw
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.double_sided = true
	add_child(l)


func _lane_a() -> void:
	var x := -60.0
	Geo.slab(self, Vector2(x - 6, -62), Vector2(x + 6, 44), 0.0, 6.0, Faultprint.CONCRETE,
		{"print": {"slip": null, "wear": 0.4, "shadow_ink": 0.3, "shadow_tone": 0.7, "dot_px": 7.0}})
	Geo.slab(self, Vector2(x - 6, 32), Vector2(x + 6, 44), 4.0, 4.0, Faultprint.BONE)
	Geo.stairs(self, Vector3(x, 0, 50.0), Vector3(0, 0, -1), 4.0, 3.0, Faultprint.CONCRETE)
	Geo.ramp(self, Vector3(x, 0.0, 12.0), Vector3(x, 4.0, 32.0), 12.0, Faultprint.CONCRETE)
	for z in [-6.0, -26.0]:
		Geo.block(self, Vector3(12.0, 0.55, 0.6), Vector3(x, 0.275, z), Faultprint.YELLOW)
	# Lane stripes so speed reads.
	for i in 14:
		var z := 8.0 - i * 5.0
		Geo.slab(self, Vector2(x - 0.15, z - 2.0), Vector2(x + 0.15, z), 0.03, 0.05, Faultprint.DUST,
			{"print": {"slip": null, "pattern": 2}, "bevel": 0.01})
	_route("A", "滑鏟循環", "衝刺 → 下坡滑鏟 → 滑鏟跳過欄 → 落地接滑鏟 → 再跳",
		Transform3D(Basis.IDENTITY, Vector3(x, 4.1, 42.0)),
		[[33.0, x - 6, x + 6, 3.0, 10.0], [12.0, x - 6, x + 6, -1.0, 10.0], [-16.0, x - 6, x + 6, -1.0, 10.0],
		[-36.0, x - 6, x + 6, -1.0, 10.0], [-52.0, x - 6, x + 6, -1.0, 10.0]])


func _lane_b() -> void:
	var x := -25.0
	Geo.slab(self, Vector2(x - 7, 24), Vector2(x + 7, 44), 0.0, 6.0, Faultprint.CONCRETE)
	Geo.slab(self, Vector2(x - 7, -62), Vector2(x + 7, -28), 0.0, 6.0, Faultprint.CONCRETE)
	for edge in [24.0, -28.0]:
		Geo.slab(self, Vector2(x - 7, edge - 0.15), Vector2(x + 7, edge + 0.15), 0.04, 0.06, Faultprint.YELLOW,
			{"print": {"slip": null, "pattern": 2}, "bevel": 0.01})
	# Four run walls over the pit, alternating sides, 5.2 m apart (inner faces).
	for w in [[x - 3.0, 22.0, 8.0], [x + 3.0, 10.0, -4.0], [x - 3.0, -2.0, -16.0], [x + 3.0, -14.0, -28.0]]:
		Geo.run_wall(self, Vector2(w[0], w[1]), Vector2(w[0], w[2]), -6.0, 11.0, 0.8,
			Faultprint.TEAL if w[0] < x else Faultprint.CONCRETE, 7.3)
	_route("B", "牆跑連段", "衝刺 → 跳上左牆 → 蹬牆跳（W+D）→ 右牆 → 蹬牆跳（W+A）→ 左牆 → 右牆 → 落地",
		Transform3D(Basis.IDENTITY, Vector3(x - 1.6, 0.1, 42.0)),
		[[25.0, x - 7, x + 7, -1.0, 10.0], [8.0, x - 7, x + 7, -3.0, 10.0], [-8.0, x - 7, x + 7, -3.0, 10.0],
		[-22.0, x - 7, x + 7, -3.0, 10.0], [-34.0, x - 7, x + 7, -1.0, 10.0]])


func _lane_c() -> void:
	var x := 20.0
	Geo.slab(self, Vector2(x - 7, 34), Vector2(x + 7, 46), 8.0, 14.0, Faultprint.BONE)
	Geo.stairs(self, Vector3(x, 0, 57.4), Vector3(0, 0, -1), 8.0, 3.0, Faultprint.CONCRETE)
	Geo.ramp(self, Vector3(x, 0.0, 8.0), Vector3(x, 8.0, 34.0), 14.0, Faultprint.CONCRETE)
	Geo.slab(self, Vector2(x - 7, 2), Vector2(x + 7, 8), 0.0, 6.0, Faultprint.CONCRETE)
	Geo.slab(self, Vector2(x - 7, -24), Vector2(x + 7, -7), 0.0, 6.0, Faultprint.CONCRETE)
	Geo.slab(self, Vector2(x - 7, -62), Vector2(x + 7, -36), 0.0, 6.0, Faultprint.CONCRETE)
	for edge in [2.0, -7.0]:
		Geo.slab(self, Vector2(x - 7, edge - 0.15), Vector2(x + 7, edge + 0.15), 0.04, 0.06, Faultprint.YELLOW,
			{"print": {"slip": null, "pattern": 2}, "bevel": 0.01})
	# Boards to shoot from the air over the ditch, on pillars beside it.
	for t in [[Vector3(x + 9.0, 1.5, -1.0), -50.0], [Vector3(x - 9.0, 1.5, -4.0), 50.0], [Vector3(x + 9.5, 1.5, -9.0), -30.0]]:
		var p: Vector3 = t[0]
		Geo.block(self, Vector3(1.2, p.y + 6.0, 1.2), Vector3(p.x, (p.y - 6.0) / 2.0, p.z), Faultprint.SLATE)
		range_targets.append(Transform3D(Basis(Vector3.UP, deg_to_rad(t[1])), p))
	# A plain wall to kick off, and the ledge it gets you onto.
	Geo.block(self, Vector3(0.8, 8.0, 14.0), Vector3(x + 7.6, 4.0, -22.0), Faultprint.CONCRETE)
	Geo.slab(self, Vector2(x - 7, -36), Vector2(x + 7, -24), 4.2, 4.2, Faultprint.TEAL)
	Geo.slab(self, Vector2(x - 7, -24.15), Vector2(x + 7, -23.85), 4.24, 0.06, Faultprint.YELLOW,
		{"print": {"slip": null, "pattern": 2}, "bevel": 0.01})
	_route("C", "高速綜合", "長坡滑鏟 → 滑鏟跳過溝並射擊標靶 → 跳起踢右牆上平台 → 高速落地 → 跑到終點",
		Transform3D(Basis.IDENTITY, Vector3(x, 8.1, 44.0)),
		[[35.0, x - 7, x + 7, 7.0, 14.0], [0.0, x - 7, x + 7, -1.0, 10.0], [-12.0, x - 7, x + 7, -1.0, 10.0],
		[-30.0, x - 7, x + 7, 3.5, 12.0], [-52.0, x - 7, x + 7, -1.0, 10.0]])


func _practice() -> void:
	Geo.slab(self, Vector2(34, -62), Vector2(84, 44), 0.0, 6.0, Faultprint.CONCRETE,
		{"print": {"slip": null, "wear": 0.4, "shadow_ink": 0.3, "shadow_tone": 0.7, "dot_px": 7.0}})
	_sign("自由練習區", Vector3(58, 4.0, 43.0), 0.0, 1.6)
	# Low obstacles: what you vault, mantle, or can't.
	for i in 5:
		var h := 0.5 + i * 0.5
		var px := 40.0 + i * 4.0
		Geo.block(self, Vector3(2.4, h, 1.2), Vector3(px, h / 2.0, 36.0), Faultprint.YELLOW if i % 2 == 0 else Faultprint.BONE)
		_sign("%.1f m" % h, Vector3(px, h + 0.6, 37.0), 0.0, 0.8)
	# Run walls: long, short, a facing pair, a corner.
	Geo.run_wall(self, Vector2(42, 20), Vector2(42, -20), 0.0, 7.0, 0.8, Faultprint.CONCRETE)
	_sign("長牆 40 m", Vector3(43.5, 7.6, 18.0), 0.0, 0.9)
	Geo.run_wall(self, Vector2(50, 22), Vector2(50, 16), 0.0, 6.0, 0.8, Faultprint.TEAL)
	_sign("短牆 6 m", Vector3(51.5, 6.6, 20.0), 0.0, 0.9)
	for wx in [58.0, 63.2]:
		Geo.run_wall(self, Vector2(wx, 10), Vector2(wx, -10), 0.0, 8.0, 0.8, Faultprint.CONCRETE)
	_sign("相鄰雙牆", Vector3(60.6, 8.6, 8.0), 0.0, 0.9)
	Geo.run_wall(self, Vector2(70, -14), Vector2(70, -28.4), 0.0, 7.0, 0.8, Faultprint.TEAL)
	Geo.run_wall(self, Vector2(70.4, -28), Vector2(80, -28), 0.0, 7.0, 0.8, Faultprint.TEAL)
	_sign("轉角", Vector3(72.0, 7.6, -26.0), 0.0, 0.9)
	# Kick shaft: plain walls 3.4 m apart.
	for wx in [64.1, 67.9]:
		Geo.block(self, Vector3(0.5, 12.0, 8.0), Vector3(wx, 6.0, -40.0), Faultprint.BONE)
	_sign("踢牆井", Vector3(66.0, 12.6, -36.0), 0.0, 0.9)
	# Narrow beam.
	Geo.block(self, Vector3(0.5, 1.4, 18.0), Vector3(78.0, 0.7, 1.0), Faultprint.SLATE)
	_sign("窄平台", Vector3(78.0, 2.2, 10.5), 0.0, 0.9)
	# Drop tower for fast and hard landings.
	Geo.slab(self, Vector2(53, -46), Vector2(59, -40), 12.0, 12.0, Faultprint.CONCRETE)
	Geo.stairs(self, Vector3(36.5, 0, -43.0), Vector3(1, 0, 0), 12.0, 2.4, Faultprint.BONE)
	_sign("高速落地 12 m", Vector3(56.0, 13.4, -40.0), 0.0, 0.9)
	# Jump platform and landing pads for air steering.
	Geo.slab(self, Vector2(64, 34), Vector2(72, 40), 5.0, 5.0, Faultprint.BONE)
	Geo.stairs(self, Vector3(68.0, 0, 47.2), Vector3(0, 0, -1), 5.0, 2.4, Faultprint.CONCRETE)
	for pad in [Vector3(64, 0, 24), Vector3(73, 0, 20), Vector3(68, 0, 13)]:
		var disc := MeshInstance3D.new()
		disc.mesh = LowPoly.prism(12, 1.2, 1.2, 0.06)
		disc.position = pad + Vector3(0, 0.02, 0)
		disc.material_override = Faultprint.surface(Faultprint.ORANGE, {"slip": null, "pattern": 2})
		add_child(disc)
	_sign("落點修正", Vector3(68.0, 7.0, 34.5), 0.0, 0.9)
