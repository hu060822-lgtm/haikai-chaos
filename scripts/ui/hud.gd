class_name Hud
extends Control
## The in-match HUD, kept out of the way so the fight is what you look at (C2.1 rework):
##   centre         crosshair with a reload ring, hit marks, damage numbers at the hit,
##                  kill call-outs below the crosshair ("擊殺 +3 新版本")
##   bottom left    health (big numerals, a trailing damage bar), one line of movement:
##                  speed, dash, wall kicks; the wall-run bar only while wall running
##   bottom right   ammo (big numerals), reserve, gun name, fire mode
##   top centre     team score bar (team match) or kills / deaths (practice)
##   top right      kill feed
##   whole screen   hurt vignette, low-health pulse, kill flash (ScreenFx)
## No boxes behind numbers: a soft shadow keeps them legible on any background.

var player: Player
var kills := 0
var deaths := 0
## The team match, when there is one (its score goes in the score bar).
var team_match: Node
var feed: KillFeed

var _hp: Label
var _hp_bar: HealthBar
var _move: Label
var _dash: Pips
var _wall: HealthBar
var _ammo: Label
var _reserve: Label
var _gun: Label
var _mode: Label
var _score: Label
var _scorebar: ScoreBar
var _cross: Crosshair
var _hint: Label
var _hint_box: PanelContainer
var _hint_left := 0.0
var _fps: Label
var _lines: SpeedLines
var _fx: ScreenFx
var _numbers: DamageNumbers
var _callouts: VBoxContainer
var _last_hp := 100.0
var _badge: AbilityBadge
var _smoke: ColorRect


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


static func _shadowed(l: Label, size := 2) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", size)
	l.add_theme_constant_override("shadow_outline_size", size * 2)
	return l


func _ready() -> void:
	var white := Counterform.DUST_WHITE
	_lines = SpeedLines.new()
	_lines.player = player
	add_child(_lines)
	# Inside smoke (C6): grey, for everyone the same.
	_smoke = ColorRect.new()
	_smoke.set_anchors_preset(PRESET_FULL_RECT)
	_smoke.color = Color(0.72, 0.74, 0.76, 0.0)
	_smoke.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_smoke)
	_fx = ScreenFx.new()
	_fx.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_fx)
	_fps = _shadowed(FpUi.label("", 12, Color(white, 0.7), FpUi.body()), 1)
	_fps.position = Vector2(14, 8)
	add_child(_fps)
	_cross = Crosshair.new()
	_cross.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_cross)
	var marks := Marks.new()
	marks.player = player
	marks.set_anchors_preset(PRESET_FULL_RECT)
	add_child(marks)
	_numbers = DamageNumbers.new()
	_numbers.player = player
	_numbers.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_numbers)
	# Kill call-outs, under the crosshair.
	_callouts = VBoxContainer.new()
	_callouts.anchor_left = 0.5
	_callouts.anchor_right = 0.5
	_callouts.anchor_top = 0.5
	_callouts.anchor_bottom = 0.5
	_callouts.offset_left = -300
	_callouts.offset_right = 300
	_callouts.offset_top = 70
	_callouts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_callouts.add_theme_constant_override("separation", 0)
	_callouts.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_callouts)
	# Bottom left: health, then one line of movement.
	var left := VBoxContainer.new()
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.offset_left = 36
	left.offset_top = -150
	left.offset_bottom = -26
	left.alignment = BoxContainer.ALIGNMENT_END
	left.add_theme_constant_override("separation", 2)
	left.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(left)
	_hp = _shadowed(FpUi.label("100", 68, white, FpUi.numerals()))
	left.add_child(_hp)
	_hp_bar = HealthBar.new()
	_hp_bar.custom_minimum_size = Vector2(260, 8)
	left.add_child(_hp_bar)
	var move_row := HBoxContainer.new()
	move_row.add_theme_constant_override("separation", 12)
	left.add_child(move_row)
	_move = _shadowed(FpUi.label("", 15, Color(white, 0.85), FpUi.bold()), 1)
	_move.custom_minimum_size = Vector2(84, 0)
	move_row.add_child(_move)
	_dash = Pips.new()
	_dash.custom_minimum_size = Vector2(150, 18)
	move_row.add_child(_dash)
	_wall = HealthBar.new()
	_wall.custom_minimum_size = Vector2(260, 4)
	_wall.color = Counterform.SULFUR
	_wall.segments = 1
	left.add_child(_wall)
	# Bottom middle: the class ability (C6).
	_badge = AbilityBadge.new()
	_badge.player = player
	_badge.anchor_left = 0.5
	_badge.anchor_right = 0.5
	_badge.anchor_top = 1.0
	_badge.anchor_bottom = 1.0
	_badge.offset_left = -110
	_badge.offset_right = 110
	_badge.offset_top = -96
	_badge.offset_bottom = -24
	_badge.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_badge)
	# Bottom right: the gun.
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -420
	right.offset_right = -36
	right.offset_top = -150
	right.offset_bottom = -26
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 0)
	right.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(right)
	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	ammo_row.add_theme_constant_override("separation", 6)
	right.add_child(ammo_row)
	_ammo = _shadowed(FpUi.label("30", 68, white, FpUi.numerals()))
	ammo_row.add_child(_ammo)
	_reserve = _shadowed(FpUi.label("/ 90", 24, Color(white, 0.6), FpUi.numerals()))
	_reserve.size_flags_vertical = Control.SIZE_SHRINK_END
	_reserve.custom_minimum_size = Vector2(0, 0)
	ammo_row.add_child(_reserve)
	_gun = _shadowed(FpUi.label("", 17, white, FpUi.bold()), 1)
	_gun.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_gun)
	_mode = _shadowed(FpUi.label("", 13, Color(white, 0.65), FpUi.body()), 1)
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_mode)
	# Top: score and kill feed.
	_scorebar = ScoreBar.new()
	_scorebar.anchor_left = 0.5
	_scorebar.anchor_right = 0.5
	_scorebar.offset_left = -240
	_scorebar.offset_right = 240
	_scorebar.offset_top = 14
	_scorebar.offset_bottom = 74
	_scorebar.visible = false
	add_child(_scorebar)
	_score = _shadowed(FpUi.label("", 18, white, FpUi.bold()), 1)
	_score.anchor_left = 0.5
	_score.anchor_right = 0.5
	_score.offset_left = -300
	_score.offset_right = 300
	_score.offset_top = 16
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_score)
	feed = KillFeed.new()
	feed.anchor_left = 1.0
	feed.anchor_right = 1.0
	feed.offset_left = -620
	feed.offset_right = -20
	feed.offset_top = 18
	add_child(feed)
	# Hints: a small dark pill under the call-outs.
	_hint_box = PanelContainer.new()
	var pill := FpUi.panel(Color(Counterform.GRAPHITE_DEEP, 0.72), Color.TRANSPARENT, 4)
	pill.content_margin_left = 14
	pill.content_margin_right = 14
	pill.content_margin_top = 5
	pill.content_margin_bottom = 5
	_hint_box.add_theme_stylebox_override("panel", pill)
	_hint_box.anchor_left = 0.5
	_hint_box.anchor_right = 0.5
	_hint_box.anchor_top = 0.72
	_hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_hint_box)
	_hint = FpUi.label("", 16, white, FpUi.body())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_box.add_child(_hint)
	var help := FpUi.label(HELP, 14, white, FpUi.body())
	var help_panel := PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", FpUi.panel(Color(Counterform.GRAPHITE_DEEP, 0.85), Color.TRANSPARENT, 8))
	help_panel.position = Vector2(24, 40)
	help_panel.name = "Help"
	help_panel.visible = false
	help_panel.add_child(help)
	add_child(help_panel)


const HELP := """操作（F1 開關）
WASD 移動　Shift 衝刺跑　Space 跳（落地前按也算）
Ctrl / C 蹲；跑動中按下 = 滑鏟，下坡越滑越快
滑鏟中跳 = 滑鏟跳（保留速度）；空中按住蹲落地 = 接滑鏟
空中靠近任何牆、方向鍵沿著牆 = 牆跑；Space 蹬牆跳，往方向鍵指的方向
空中貼任何牆 Space = 踢牆；面對牆按住 Space = 攀牆
Q 衝刺閃避（衝刺中跳 = 衝刺跳）　空中低頭看地面按蹲 = 重踩，落地瞬間跳 = 彈跳
左鍵 開火　右鍵 瞄準　R 換彈　B 射擊模式
F 職業技能（工作台左上選職業）　G 死亡畫面抄槍
Tab 輕按 = 改槍工作台，按住 = 記分板
F2 敵我顏色　F3 機器人開火　F4 移動除錯　F5 鏡頭效果
Esc 設定：靈敏度、FOV、音量、自訂按鍵
槍的重量只影響開鏡和晃動，不影響身法"""


func show_hint(text: String, seconds := 2.5) -> void:
	_hint.text = text
	_hint_left = seconds if text != "" else 0.0


func toggle_help() -> void:
	var h := get_node("Help")
	h.visible = not h.visible


## A hit landed: the crosshair mark, a damage number at the hit, and on a kill the flash.
func hit_marker(head: bool, killed: bool, info := {}) -> void:
	_cross.mark(head, killed)
	if info.has("at") and float(info.get("damage", 0.0)) > 0.0:
		_numbers.add(info.get("target"), info.at, float(info.damage), head, killed)
	if killed:
		_fx.kill_flash()


## A kill call-out under the crosshair: "擊殺" big, the details (points, tags) under it.
func callout(title: String, detail := "", color := Counterform.DUST_WHITE) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	var big := _shadowed(FpUi.label(title, 34, color, FpUi.display()))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	if detail != "":
		var small := _shadowed(FpUi.label(detail, 16, Color(Counterform.DUST_WHITE, 0.9), FpUi.bold()), 1)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(small)
	_callouts.add_child(box)
	_callouts.move_child(box, 0)
	while _callouts.get_child_count() > 3:
		var last := _callouts.get_child(_callouts.get_child_count() - 1)
		_callouts.remove_child(last)
		last.queue_free()
	box.pivot_offset = Vector2(300, 20)
	box.scale = Vector2(1.6, 1.6)
	box.modulate.a = 0.0
	var t := box.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(box, "scale", Vector2.ONE, 0.18)
	t.parallel().tween_property(box, "modulate:a", 1.0, 0.08)
	t.tween_interval(1.8)
	t.tween_property(box, "modulate:a", 0.0, 0.35)
	t.tween_callback(box.queue_free)


func damage_from(dir_world: Vector3) -> void:
	if player == null:
		return
	var local := player.global_basis.inverse() * dir_world
	_cross.damage(atan2(local.x, -local.z))


func _process(delta: float) -> void:
	if player == null:
		return
	_hint_left -= delta
	_hint_box.visible = _hint_left > 0.0
	_fps.visible = Settings.show_fps
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
	var hp := player.health
	if hp < _last_hp - 0.5:
		_fx.hurt((_last_hp - hp) / Player.MAX_HEALTH)
	_last_hp = hp
	_fx.low = clampf(1.0 - hp / 40.0, 0.0, 1.0) if player.alive else 0.0
	var smoke := Deploy.smoke_at(player.camera.global_position) if player.alive else 0.0
	_smoke.color.a = lerpf(_smoke.color.a, 0.94 * smoke, 1.0 - exp(-14.0 * delta))
	_badge.queue_redraw()
	_hp.text = "%d" % ceili(hp)
	_hp.add_theme_color_override("font_color", Counterform.DUST_WHITE if hp > 35 else FpUi.enemy_color())
	_hp_bar.set_value(hp / Player.MAX_HEALTH)
	_move.text = "%s  %d" % [Player.MOVE_NAMES[player.move], roundi(player.flat_speed())]
	_dash.dash = player.dash_ready()
	_dash.kicks = player.kicks_left()
	_dash.max_kicks = player.max_kicks()
	_dash.queue_redraw()
	var wall := player.wall_time_left()
	_wall.modulate.a = lerpf(_wall.modulate.a, 1.0 if wall > 0.0 else 0.0, 1.0 - exp(-12.0 * delta))
	_wall.set_value(wall)
	var w := player.weapon
	_ammo.text = "%d" % w.ammo
	_ammo.add_theme_color_override("font_color", Counterform.DUST_WHITE if w.ammo > int(w.stats.mag) * 0.25 else Counterform.SULFUR)
	_reserve.text = "/ %d" % w.reserve
	_gun.text = w.name
	var mode_text: String = Arsenal.MODE_NAMES.get(w.mode(), w.mode())
	if w.overheated:
		mode_text = "過熱"
	elif w.charging:
		mode_text = "蓄力 %d%%" % roundi(w.charge * 100)
	_mode.text = "%s · %s" % [mode_text, Arsenal.caliber_name(w.stats.cal)]
	if team_match != null:
		_scorebar.visible = true
		_score.visible = false
		_scorebar.update_from(team_match, player.team)
	else:
		_score.text = "擊殺 %d   陣亡 %d" % [kills, deaths]
	_cross.spread = player.current_spread()
	_cross.fov = player.camera.fov
	_cross.off = player.weapon.stats.zoom >= 2.0 and player._aim > 0.9
	_cross.scoped = _cross.off
	_cross.reload = 1.0 - w.reload_left / maxf(w.reload_time(), 0.01) if w.is_reloading() else -1.0


## A bar in segments with a white "ghost" that trails behind on loss (you see the chunk
## you just lost).
class HealthBar:
	extends Control
	var value := 1.0
	var ghost := 1.0
	var segments := 5
	var color := Counterform.DUST_WHITE

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		v = clampf(v, 0.0, 1.0)
		if v > ghost:
			ghost = v
		value = v

	func _process(delta: float) -> void:
		if ghost > value:
			ghost = maxf(value, ghost - delta * 0.6)
		queue_redraw()

	func _draw() -> void:
		var gap := 3.0
		var w := (size.x - gap * (segments - 1)) / segments
		for i in segments:
			var x := i * (w + gap)
			var r := Rect2(Vector2(x, 0), Vector2(w, size.y))
			draw_rect(r, Color(0, 0, 0, 0.35))
			var lo := float(i) / segments
			var hi := float(i + 1) / segments
			var g := clampf((ghost - lo) / (hi - lo), 0.0, 1.0)
			if g > 0.0:
				draw_rect(Rect2(r.position, Vector2(w * g, size.y)), Color(FpUi.enemy_color(), 0.8))
			var f := clampf((value - lo) / (hi - lo), 0.0, 1.0)
			if f > 0.0:
				draw_rect(Rect2(r.position, Vector2(w * f, size.y)), color if value > 0.35 or segments == 1 else FpUi.enemy_color())


## Dash charge (a bar) and wall kicks (diamonds), drawn small beside the speed.
class Pips:
	extends Control
	var dash := 1.0
	var kicks := 0
	var max_kicks := 0

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y / 2.0
		# One bar per dash charge; the one refilling is dim.
		for i in int(Player.DASH_CHARGES):
			var fill := clampf(dash - i, 0.0, 1.0)
			var x := i * 24.0
			draw_rect(Rect2(Vector2(x, y - 3), Vector2(21, 6)), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(Vector2(x, y - 3), Vector2(21 * fill, 6)),
				Counterform.DUST_WHITE if fill >= 1.0 else Color(Counterform.DUST_WHITE, 0.45))
		for i in max_kicks:
			var c := Vector2(62 + i * 14, y)
			var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)])
			if i < kicks:
				draw_colored_polygon(pts, Counterform.SULFUR)
			else:
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Counterform.DUST_WHITE, 0.4), 1.2)


## Team score at the top: your team on the left in your colour, the clock in the middle,
## each side's progress toward the score limit as a thin bar.
class ScoreBar:
	extends Control
	var left := 0
	var right := 0
	var limit := 50
	var clock := ""
	var meta := ""
	var _font: Font
	var _num: Font

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		_font = FpUi.bold()
		_num = FpUi.numerals()

	func update_from(tm: Node, my_team: int) -> void:
		var s: Array = tm.scores
		left = int(s[my_team])
		right = int(s[1 - my_team])
		limit = int(tm.score_limit())
		var t := int(ceil(float(tm.time_left)))
		clock = "%d:%02d" % [t / 60, t % 60]
		meta = str(tm.bar_note())
		queue_redraw()

	func _draw() -> void:
		var c := size.x / 2.0
		var white := Counterform.DUST_WHITE
		draw_rect(Rect2(Vector2(c - 46, 0), Vector2(92, 34)), Color(Counterform.GRAPHITE_DEEP, 0.75))
		draw_string(_num, Vector2(c - 46, 27), clock, HORIZONTAL_ALIGNMENT_CENTER, 92, 26, white)
		for side in 2:
			var value := left if side == 0 else right
			var col := FpUi.ally_color() if side == 0 else FpUi.enemy_color()
			var x0 := c - 50 - 130 if side == 0 else c + 50
			draw_rect(Rect2(Vector2(x0, 0), Vector2(130, 34)), Color(col, 0.82))
			draw_string(_num, Vector2(x0, 29), str(value), HORIZONTAL_ALIGNMENT_CENTER, 130, 32, Counterform.GRAPHITE_DEEP)
			var frac := clampf(float(value) / maxf(limit, 1), 0.0, 1.0)
			draw_rect(Rect2(Vector2(x0, 37), Vector2(130, 4)), Color(0, 0, 0, 0.35))
			if side == 0:
				draw_rect(Rect2(Vector2(x0 + 130 * (1.0 - frac), 37), Vector2(130 * frac, 4)), col)
			else:
				draw_rect(Rect2(Vector2(x0, 37), Vector2(130 * frac, 4)), col)
		if meta != "":
			draw_string(_font, Vector2(0, 58), meta, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Counterform.SULFUR)


## Whole-screen feedback: a red edge when you're hit (stronger for bigger hits), a slow
## pulse at low health, one bright frame on a kill.
class ScreenFx:
	extends Control
	var low := 0.0
	var _hurt := 0.0
	var _flash := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func hurt(amount: float) -> void:
		_hurt = clampf(_hurt + 0.35 + amount * 2.0, 0.0, 1.0)

	func kill_flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		_t += delta
		_hurt = maxf(_hurt - delta * 1.6, 0.0)
		_flash = maxf(_flash - delta * 9.0, 0.0)
		if _hurt > 0.0 or _flash > 0.0 or low > 0.0:
			queue_redraw()

	func _draw() -> void:
		var pulse := low * (0.55 + 0.45 * sin(_t * 6.0))
		var a := maxf(_hurt, pulse * 0.8)
		if a > 0.01:
			var red := FpUi.enemy_color()
			# Edge bands that fade toward the middle (cheap vignette, no shader).
			var steps := 10
			for i in steps:
				var k := float(i) / steps
				var alpha := a * 0.42 * pow(1.0 - k, 2.0)
				var inset := size * 0.11 * k
				var w := size.x * 0.011
				var h := size.y * 0.011
				draw_rect(Rect2(inset, Vector2(size.x - inset.x * 2, h + 1)), Color(red, alpha))
				draw_rect(Rect2(Vector2(inset.x, size.y - inset.y - h - 1), Vector2(size.x - inset.x * 2, h + 1)), Color(red, alpha))
				draw_rect(Rect2(inset, Vector2(w + 1, size.y - inset.y * 2)), Color(red, alpha))
				draw_rect(Rect2(Vector2(size.x - inset.x - w - 1, inset.y), Vector2(w + 1, size.y - inset.y * 2)), Color(red, alpha))
		if _flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12 * _flash))


## Damage numbers where the shots land; hits on the same target within a moment add up
## into one number that grows (so a spray reads as one total, not a cloud of digits).
class DamageNumbers:
	extends Control
	var player: Player
	var _items: Array = []   # {target, at, amount, head, kill, t, rise}
	var _font: Font

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		_font = FpUi.numerals()

	func add(target: Object, at: Vector3, amount: float, head: bool, kill: bool) -> void:
		for it in _items:
			if it.target == target and it.t < 0.6 and not it.kill:
				it.amount += amount
				it.at = at
				it.t = 0.0
				it.head = it.head or head
				it.kill = kill
				it.pop = 1.0
				return
		_items.append({"target": target, "at": at, "amount": amount, "head": head, "kill": kill, "t": 0.0, "pop": 1.0,
			"side": randf_range(-1.0, 1.0)})

	func _process(delta: float) -> void:
		for it in _items:
			it.t += delta
			it.pop = maxf(float(it.pop) - delta * 6.0, 0.0)
		_items = _items.filter(func(it) -> bool: return it.t < 1.1)
		queue_redraw()

	func _draw() -> void:
		if player == null or not player.is_inside_tree():
			return
		var cam := player.camera
		for it in _items:
			var at: Vector3 = it.at
			if cam.is_position_behind(at):
				continue
			var p := cam.unproject_position(at) + Vector2(float(it.side) * 18.0, -26.0 - float(it.t) * 40.0)
			var col := Counterform.SULFUR if it.head else Counterform.DUST_WHITE
			if it.kill:
				col = FpUi.enemy_color()
			var alpha := clampf(1.0 - (float(it.t) - 0.7) / 0.4, 0.0, 1.0)
			var size_px := int(24 + 10 * float(it.pop) + minf(float(it.amount) / 10.0, 8.0))
			var text := str(roundi(float(it.amount)))
			p.x -= _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / 2.0
			draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px, 5, Color(0, 0, 0, 0.6 * alpha))
			draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px, Color(col, alpha))


## The crosshair: four ticks that open with the cone of fire and a centre dot, in white
## with a carbon edge so it reads on any surface. Hit marks: an X (yellow X for a head,
## a filled diamond for a kill). Damage taken shows as a wedge around the ring.
class Crosshair:
	extends Control
	var spread := 1.0
	var fov := 90.0
	var off := false
	var scoped := false
	## Reload progress 0..1 (a ring around the crosshair), or < 0 when not reloading.
	var reload := -1.0
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
			draw_arc(c, r, 0, TAU, 72, Counterform.GRAPHITE_DEEP, 6.0)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
				draw_line(c + d * r, c + d * r * 0.25, Counterform.GRAPHITE_DEEP, 4.0)
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Counterform.GRAPHITE_DEEP, 1.0)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), Counterform.GRAPHITE_DEEP, 1.0)
		elif not off:
			var px := tan(deg_to_rad(spread)) / tan(deg_to_rad(fov / 2.0)) * size.y / 2.0
			var gap := clampf(px, 4.0, 120.0)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var a: Vector2 = c + d * gap
				var b: Vector2 = c + d * (gap + 9.0)
				draw_line(a, b, Color(0, 0, 0, 0.55), 4.0)
				draw_line(a, b, Color.WHITE, 2.0)
			draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
		if reload >= 0.0:
			draw_arc(c, 26.0, 0, TAU, 48, Color(0, 0, 0, 0.35), 4.0)
			draw_arc(c, 26.0, -PI / 2.0, -PI / 2.0 + TAU * reload, 48, Color(Color.WHITE, 0.9), 3.0)
		if _mark > 0.0:
			var s := 9.0 + (4.0 if _mark_kill else 0.0)
			var col := Faultprint.YELLOW if _mark_head else Color.WHITE
			if _mark_kill:
				var pts := PackedVector2Array([c + Vector2(0, -s - 6), c + Vector2(s + 6, 0), c + Vector2(0, s + 6), c + Vector2(-s - 6, 0)])
				draw_colored_polygon(pts, Color(FpUi.enemy_color(), 0.9))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Faultprint.ui_ink, 2.0)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 6.0, c + d * (6.0 + s), Color(0, 0, 0, 0.6), 5.0)
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


## The class ability (C6): its name and key, a ring that fills while a charge comes back,
## a pip per charge, lit while it's in use.
class AbilityBadge:
	extends Control
	var player: Player

	func _draw() -> void:
		if player == null or player.ability == null or not player.alive:
			return
		var a := player.ability
		var info := Kit.info(a.kit)
		var c: Color = info.color
		var centre := Vector2(size.x / 2.0, 30)
		var r := 24.0
		var up := a.charges >= 1.0
		draw_circle(centre, r + 3, Color(Counterform.GRAPHITE_DEEP, 0.7))
		draw_arc(centre, r, -PI / 2.0, -PI / 2.0 + TAU * (1.0 if up else a.refill_progress()), 40,
			c if up else Color(c, 0.45), 4.0, true)
		if a.busy:
			draw_circle(centre, r - 5, Color(c, 0.85))
		var font := FpUi.bold()
		draw_string(font, centre + Vector2(-8, 7), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Counterform.GRAPHITE_DEEP if a.busy else (Counterform.DUST_WHITE if up else Color(Counterform.DUST_WHITE, 0.5)))
		var label := "%s · %s" % [info.ability, info.name]
		draw_string(font, Vector2(0, 70), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(Counterform.DUST_WHITE, 0.9))
		var n := int(a.max_charges())
		for i in n:
			var p := centre + Vector2(r + 14 + i * 12, -10)
			draw_rect(Rect2(p, Vector2(8, 8)), c if a.charges >= i + 1.0 else Color(c, 0.25))
