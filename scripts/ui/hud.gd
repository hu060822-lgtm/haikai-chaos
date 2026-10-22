class_name Hud
extends Control
## The in-match HUD. The middle of the screen stays clean: just the crosshair, hit marks
## and damage direction. Everything else sits at the edges:
##   bottom left   health; the movement panel (state, speed, dash charge, wall kicks,
##                 wall-run time)
##   bottom right  ammo, gun name, fire mode, weight and mobility
##   top right     kill feed (killer, gun picture + name, tags, victim)
##   top centre    score

var player: Player
var kills := 0
var deaths := 0
var feed: KillFeed

var _hp: FpUi.PrintText
var _hp_bar: FpUi.PrintBar
var _state: FpUi.PrintText
var _speed: Label
var _dash: FpUi.PrintBar
var _wall: FpUi.PrintBar
var _kicks: Label
var _ammo: FpUi.PrintText
var _reserve: Label
var _gun: Label
var _mode: Label
var _weight: Label
var _score: FpUi.PrintText
var _help: Label
var _cross: Crosshair
var _hint: Label
var _hint_left := 0.0
var _fps: Label
var _lines: SpeedLines


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	_lines = SpeedLines.new()
	_lines.player = player
	add_child(_lines)
	_fps = FpUi.label("", 13, Faultprint.ui_ink, FpUi.bold())
	_fps.anchor_left = 1.0
	_fps.anchor_right = 1.0
	_fps.anchor_top = 1.0
	_fps.anchor_bottom = 1.0
	_fps.offset_left = -330
	_fps.offset_top = -204
	add_child(_fps)
	_cross = Crosshair.new()
	_cross.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_cross)
	var marks := Marks.new()
	marks.player = player
	marks.set_anchors_preset(PRESET_FULL_RECT)
	add_child(marks)
	# Bottom left: health and movement.
	var left := VBoxContainer.new()
	left.position = Vector2(28, 0)
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.offset_top = -210
	left.add_theme_constant_override("separation", 4)
	add_child(left)
	var hp_row := HBoxContainer.new()
	left.add_child(hp_row)
	_hp = FpUi.PrintText.new("100", 54, Faultprint.ui_ink)
	hp_row.add_child(_hp)
	var hp_tag := FpUi.label("體力", 14, Faultprint.ui_ink, FpUi.bold())
	hp_tag.size_flags_vertical = Control.SIZE_SHRINK_END
	hp_row.add_child(hp_tag)
	_hp_bar = FpUi.PrintBar.new()
	_hp_bar.custom_minimum_size = Vector2(240, 12)
	left.add_child(_hp_bar)
	var move_panel := PanelContainer.new()
	move_panel.add_theme_stylebox_override("panel", FpUi.panel(Color(Faultprint.ui_paper, 0.88), Faultprint.ui_ink, 10, 2))
	left.add_child(move_panel)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 3)
	move_panel.add_child(mv)
	var top := HBoxContainer.new()
	mv.add_child(top)
	_state = FpUi.PrintText.new("地面", 26)
	_state.custom_minimum_size = Vector2(120, 30)
	top.add_child(_state)
	_speed = FpUi.label("0.0 m/s", 15, Faultprint.ui_ink, FpUi.bold())
	_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_speed)
	for spec in [["衝刺 Q", "_dash"], ["牆跑", "_wall"]]:
		var row := HBoxContainer.new()
		mv.add_child(row)
		var l := FpUi.label(spec[0], 12, Faultprint.ui_ink, FpUi.bold())
		l.custom_minimum_size = Vector2(56, 0)
		row.add_child(l)
		var bar := FpUi.PrintBar.new()
		bar.custom_minimum_size = Vector2(170, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.ticks = 4
		row.add_child(bar)
		set(spec[1], bar)
	_wall.fill = Faultprint.ui_accent
	_kicks = FpUi.label("", 13, Faultprint.ui_ink, FpUi.bold())
	mv.add_child(_kicks)
	# Bottom right: the gun.
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -380
	right.offset_right = -28
	right.offset_top = -190
	right.offset_bottom = -22
	right.alignment = BoxContainer.ALIGNMENT_END
	# A bone block behind the gun readout so it reads over the view model.
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", FpUi.panel(Color(Faultprint.ui_paper, 0.86), Faultprint.ui_ink, 12, 2))
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = -330
	back.offset_right = -14
	back.offset_top = -178
	back.offset_bottom = -14
	back.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(back)
	add_child(right)
	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(ammo_row)
	_ammo = FpUi.PrintText.new("30", 64)
	_ammo.align = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_row.add_child(_ammo)
	_reserve = FpUi.label("/ 90", 22, Faultprint.ui_ink, FpUi.bold())
	_reserve.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo_row.add_child(_reserve)
	_gun = FpUi.label("", 18, Faultprint.ui_ink, FpUi.bold())
	_gun.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_gun)
	_mode = FpUi.label("", 14, Faultprint.ui_ink, FpUi.bold())
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_mode)
	_weight = FpUi.label("", 14, Faultprint.ui_ink, FpUi.bold())
	_weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_weight)
	# Top: score and kill feed.
	_score = FpUi.PrintText.new("", 26)
	_score.align = HORIZONTAL_ALIGNMENT_CENTER
	_score.anchor_left = 0.5
	_score.anchor_right = 0.5
	_score.offset_left = -200
	_score.offset_right = 200
	_score.offset_top = 14
	_score.offset_bottom = 50
	add_child(_score)
	feed = KillFeed.new()
	feed.anchor_left = 1.0
	feed.anchor_right = 1.0
	feed.offset_left = -620
	feed.offset_right = -20
	feed.offset_top = 18
	add_child(feed)
	_hint = FpUi.label("", 18, Faultprint.ui_ink, FpUi.bold())
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 0.62
	_hint.offset_left = -400
	_hint.offset_right = 400
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_help = FpUi.label(HELP, 14, Faultprint.ui_ink, FpUi.bold())
	_help.position = Vector2(28, 70)
	_help.visible = false
	var help_panel := PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", FpUi.panel(Color(Faultprint.ui_paper, 0.92), Faultprint.ui_ink, 12, 2))
	help_panel.position = Vector2(24, 66)
	help_panel.name = "Help"
	help_panel.visible = false
	help_panel.add_child(_help)
	_help.visible = true
	add_child(help_panel)


const HELP := """操作（F1 開關）
WASD 移動　Shift 衝刺跑　Space 跳（落地前按也算）
Ctrl / C 蹲；跑動中按下 = 滑鏟，下坡越滑越快
滑鏟中跳 = 滑鏟跳（保留速度）；空中按住蹲落地 = 接滑鏟
空中靠近橘色線牆、方向鍵沿著牆 = 牆跑；Space 蹬牆跳，往方向鍵指的方向
空中貼任何牆 Space = 踢牆；面對牆按住 Space = 攀牆
Q 衝刺閃避（衝刺中跳 = 衝刺跳）　空中低頭看地面按蹲 = 重踩，落地瞬間跳 = 彈跳
左鍵 開火　右鍵 瞄準　R 換彈　B 射擊模式　Tab 改槍
F2 敵我顏色　F3 機器人開火　F4 移動除錯　F5 鏡頭效果
Esc 設定：靈敏度、FOV、V-Sync、自訂按鍵
槍越重，身法越鈍（看右下角機動性）"""


func show_hint(text: String, seconds := 2.5) -> void:
	_hint.text = text
	_hint_left = seconds


func toggle_help() -> void:
	var h := get_node("Help")
	h.visible = not h.visible


func hit_marker(head: bool, killed: bool) -> void:
	_cross.mark(head, killed)


func damage_from(dir_world: Vector3) -> void:
	if player == null:
		return
	var local := player.global_basis.inverse() * dir_world
	_cross.damage(atan2(local.x, -local.z))


func _process(delta: float) -> void:
	if player == null:
		return
	_hint_left -= delta
	_hint.visible = _hint_left > 0.0
	_fps.visible = Settings.show_fps
	_fps.text = "FPS %d　物理 %d Hz" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second]
	_hp.set_text("%d" % ceili(player.health))
	_hp.main = Faultprint.ui_ink if player.health > 35 else FpUi.enemy_color()
	_hp_bar.set_value(player.health / Player.MAX_HEALTH)
	_state.set_text(Player.MOVE_NAMES[player.move])
	_speed.text = "%.1f m/s" % player.flat_speed()
	_dash.set_value(player.dash_ready())
	_dash.fill = Faultprint.ui_ink if player.dash_ready() >= 1.0 else Faultprint.SLATE
	_wall.set_value(player.wall_time_left())
	_kicks.text = "踢牆 " + "◆".repeat(player.kicks_left()) + "◇".repeat(maxi(player.max_kicks() - player.kicks_left(), 0))
	var w := player.weapon
	_ammo.set_text("%d" % w.ammo)
	_ammo.main = Faultprint.ui_ink if w.ammo > int(w.stats.mag) * 0.25 else Faultprint.ui_accent
	_reserve.text = " / %d" % w.reserve
	_gun.text = w.name
	var mode_text: String = Arsenal.MODE_NAMES.get(w.mode(), w.mode())
	if w.is_reloading():
		mode_text = "換彈中…"
	elif w.overheated:
		mode_text = "過熱！"
	elif w.charging:
		mode_text = "蓄力 %d%%" % roundi(w.charge * 100)
	_mode.text = "%s　%s" % [mode_text, Arsenal.caliber_name(w.stats.cal)]
	_weight.text = "重量 %.1f kg　機動性 %d%%" % [w.stats.weight, roundi(player.mobility * 100)]
	_score.set_text("擊殺 %d　/　陣亡 %d" % [kills, deaths])
	_cross.spread = player.current_spread()
	_cross.fov = player.camera.fov
	_cross.off = player.weapon.stats.zoom >= 2.0 and player._aim > 0.9
	_cross.scoped = _cross.off


## The crosshair: four ticks that open with the cone of fire and a centre dot, in white
## with a carbon edge so it reads on any surface. Hit marks: an X (yellow X for a head,
## a filled diamond for a kill). Damage taken shows as a wedge around the ring.
class Crosshair:
	extends Control
	var spread := 1.0
	var fov := 90.0
	var off := false
	var scoped := false
	var _mark := 0.0
	var _mark_head := false
	var _mark_kill := false
	var _hurt: Array = []

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func mark(head: bool, killed: bool) -> void:
		_mark = 0.22 if not killed else 0.45
		_mark_head = head
		_mark_kill = killed

	func damage(angle: float) -> void:
		_hurt.append([angle, 1.0])

	func _process(delta: float) -> void:
		_mark = maxf(_mark - delta, 0.0)
		for h in _hurt:
			h[1] -= delta * 1.2
		_hurt = _hurt.filter(func(h) -> bool: return h[1] > 0.0)
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		if scoped:
			# A printed scope: carbon ring and posts, thin cross.
			var r := minf(size.x, size.y) * 0.42
			draw_arc(c, r, 0, TAU, 72, Faultprint.ui_ink, 6.0)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
				draw_line(c + d * r, c + d * r * 0.25, Faultprint.ui_ink, 4.0)
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Faultprint.ui_ink, 1.0)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), Faultprint.ui_ink, 1.0)
		elif not off:
			var px := tan(deg_to_rad(spread)) / tan(deg_to_rad(fov / 2.0)) * size.y / 2.0
			var gap := clampf(px, 4.0, 120.0)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var a: Vector2 = c + d * gap
				var b: Vector2 = c + d * (gap + 9.0)
				draw_line(a, b, Faultprint.ui_ink, 4.0)
				draw_line(a, b, Color.WHITE, 2.0)
			draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Faultprint.ui_ink)
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
		if _mark > 0.0:
			var s := 9.0 + (4.0 if _mark_kill else 0.0)
			var col := Faultprint.YELLOW if _mark_head else Color.WHITE
			if _mark_kill:
				var pts := PackedVector2Array([c + Vector2(0, -s - 6), c + Vector2(s + 6, 0), c + Vector2(0, s + 6), c + Vector2(-s - 6, 0)])
				draw_colored_polygon(pts, Color(FpUi.enemy_color(), 0.9))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Faultprint.ui_ink, 2.0)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 6.0, c + d * (6.0 + s), Faultprint.ui_ink, 5.0)
				draw_line(c + d * 6.0, c + d * (6.0 + s), col, 2.5)
		for h in _hurt:
			var ang: float = h[0] - PI / 2.0
			var r := 110.0
			var w := 0.35
			var pts := PackedVector2Array()
			for i in 7:
				var a := ang - w + 2.0 * w * i / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			for i in range(6, -1, -1):
				var a := ang - w + 2.0 * w * i / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r + 14.0))
			draw_colored_polygon(pts, Color(FpUi.enemy_color(), float(h[1]) * 0.85))


## Enemies tagged by a "mark" part (tracker dart, bounty scope): a sulfur diamond over
## their heads, drawn through walls, while the mark lasts.
class Marks:
	extends Control
	var player: Player

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if player == null or not player.is_inside_tree():
			return
		var cam := player.camera
		for t in player.get_tree().get_nodes_in_group("hittable"):
			if not (t is Node3D) or t.get("marked") == null or float(t.marked) <= 0.0 or not t.get("alive"):
				continue
			if t.get("team") != null and int(t.team) == player.team:
				continue
			var at: Vector3 = (t as Node3D).global_position + Vector3(0, 2.15, 0)
			if cam.is_position_behind(at):
				continue
			var p := cam.unproject_position(at)
			var r := 9.0
			var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)])
			draw_polyline(pts, Counterform.SULFUR, 2.5)
			draw_circle(p, 2.5, Counterform.SULFUR)
			var left := float(t.marked)
			draw_line(p + Vector2(-r, r + 5), p + Vector2(-r + 2.0 * r * clampf(left / 6.0, 0.0, 1.0), r + 5), Counterform.SULFUR, 2.0)
