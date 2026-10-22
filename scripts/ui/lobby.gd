class_name Lobby
extends Control
## The netplay lobby (title -> 連線對戰): your name, host a room or join one by IP, the two
## team lists, and (for the host) the match settings and the start button. Everything
## here goes through NetSession; this only draws it.

signal closed()

var net: NetSession
var _name: LineEdit
var _ip: LineEdit
var _status: Label
var _teams: Array[VBoxContainer] = []
var _connect_row: HBoxContainer
var _room_row: HBoxContainer
var _settings: VBoxContainer
var _size_label: Label
var _score_label: Label
var _time_label: Label
var _bots: CheckButton
var _start: Button
var _rules: Label


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = FpUi.theme()
	visible = false


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Faultprint.CARBON, 0.6)
	shade.set_anchors_preset(PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -620
	panel.offset_right = 620
	panel.offset_top = -400
	panel.offset_bottom = 400
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := FpUi.PrintText.new("改版死鬥 PATCH WAR", 40)
	title.custom_minimum_size = Vector2(560, 48)
	title_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	var back := FpUi.button("返回", 18)
	back.pressed.connect(close)
	title_row.add_child(back)

	_rules = FpUi.label("同一把槍越殺越不值錢（3→2→1 分），改任何零件就是新版本、重新值 3 分；身法擊殺 +1。"
		+ "\n某個版本殺滿 %d 人就成為「版本答案」：帶著它的人全場透視可見，擊殺他 +%d。重生區內無法傷害與被傷害，並能隨時改槍。"
		% [TeamMatch.META_KILLS, TeamMatch.META_BONUS], 16, Faultprint.ui_ink, FpUi.bold())
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_rules)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	root.add_child(name_row)
	name_row.add_child(FpUi.label("你的名字", 18, Faultprint.ui_ink, FpUi.bold()))
	_name = _field(NetSession.my_name, 220)
	_name.max_length = 16
	_name.text_changed.connect(func(t: String) -> void: NetSession.my_name = t.strip_edges() if t.strip_edges() != "" else "玩家")
	name_row.add_child(_name)

	_connect_row = HBoxContainer.new()
	_connect_row.add_theme_constant_override("separation", 10)
	root.add_child(_connect_row)
	var host := FpUi.button("開房（埠 %d）" % NetSession.PORT, 18)
	host.pressed.connect(func() -> void: net.host())
	_connect_row.add_child(host)
	_connect_row.add_child(FpUi.label("或加入 IP", 18, Faultprint.ui_ink, FpUi.bold()))
	_ip = _field("127.0.0.1", 220)
	_connect_row.add_child(_ip)
	var join := FpUi.button("加入", 18)
	join.pressed.connect(func() -> void: net.join(_ip.text.strip_edges()))
	_connect_row.add_child(join)

	_room_row = HBoxContainer.new()
	_room_row.add_theme_constant_override("separation", 10)
	root.add_child(_room_row)
	var swap := FpUi.button("換隊", 18)
	swap.pressed.connect(func() -> void: net.switch_team())
	_room_row.add_child(swap)
	var leave := FpUi.button("離開房間", 18)
	leave.pressed.connect(func() -> void: net.leave())
	_room_row.add_child(leave)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(cols)
	for t in 2:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(330, 0)
		box.add_theme_constant_override("separation", 6)
		cols.add_child(box)
		_teams.append(box)
	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 8)
	_settings.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.add_child(_settings)
	_settings.add_child(FpUi.label("房間設定（房主）", 20, Faultprint.ui_accent, FpUi.bold()))
	_size_label = _stepper("team_size", 1, 5, 1)
	_score_label = _stepper("score", 20, 120, 10)
	_time_label = _stepper("minutes", 3, 15, 1)
	_bots = CheckButton.new()
	_bots.text = "空位補機器人"
	_bots.add_theme_font_override("font", FpUi.bold())
	_bots.add_theme_color_override("font_color", Faultprint.ui_ink)
	_bots.add_theme_color_override("font_hover_color", Faultprint.ui_ink)
	_bots.add_theme_color_override("font_pressed_color", Faultprint.ui_ink)
	_bots.focus_mode = Control.FOCUS_NONE
	_bots.toggled.connect(func(on: bool) -> void: net.set_config("bots", on))
	_settings.add_child(_bots)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	_status = FpUi.label("", 18, Faultprint.ui_ink, FpUi.bold())
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_status.clip_text = true
	bottom.add_child(_status)
	_start = FpUi.button("開始對戰", 22)
	_start.custom_minimum_size = Vector2(220, 52)
	_start.pressed.connect(func() -> void: net.start_match())
	bottom.add_child(_start)


func _field(text: String, width: float) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.custom_minimum_size = Vector2(width, 40)
	e.add_theme_font_override("font", FpUi.bold())
	e.add_theme_font_size_override("font_size", 18)
	return e


## A "label  [−] [+]" row for an integer setting.
func _stepper(key: String, lo: int, hi: int, step: int) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_settings.add_child(row)
	var l := FpUi.label("", 18, Faultprint.ui_ink, FpUi.bold())
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	for d in [-step, step]:
		var b := FpUi.button("−" if d < 0 else "+", 18)
		b.custom_minimum_size = Vector2(44, 36)
		b.pressed.connect(func() -> void:
			net.set_config(key, clampi(int(NetSession.config.get(key, lo)) + d, lo, hi)))
		row.add_child(b)
	return l


func open() -> void:
	visible = true
	if not net.roster_changed.is_connected(_refresh):
		net.roster_changed.connect(_refresh)
		net.status_changed.connect(func(_t: String) -> void: _refresh())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	if _status == null:
		return
	var in_room := NetSession.active and not NetSession.roster.is_empty()
	_connect_row.visible = not NetSession.active
	_room_row.visible = NetSession.active
	_name.editable = not NetSession.active
	var host := net.is_host()
	for c in _settings.get_children():
		if c is Control and c != _settings.get_child(0):
			(c as Control).modulate.a = 1.0 if host else 0.5
	_bots.disabled = not host
	var cfg := NetSession.config
	_size_label.text = "每隊人數　%d" % int(cfg.get("team_size", 4))
	_score_label.text = "目標分數　%d" % int(cfg.get("score", 50))
	_time_label.text = "時間上限　%d 分" % int(cfg.get("minutes", 8))
	_bots.set_pressed_no_signal(bool(cfg.get("bots", true)))
	for t in 2:
		var box := _teams[t]
		for c in box.get_children():
			c.queue_free()
		var head := FpUi.label(NetSession.TEAM_NAMES[t], 22, FpUi.ally_color() if t == 0 else FpUi.enemy_color(), FpUi.bold())
		box.add_child(head)
		var n := 0
		for peer in NetSession.roster:
			var info: Dictionary = NetSession.roster[peer]
			if int(info.team) != t:
				continue
			var tag := "（房主）" if int(peer) == 1 else ""
			var you := "　← 你" if int(peer) == net.my_id() else ""
			box.add_child(FpUi.label("%s%s%s" % [info.name, tag, you], 18, Faultprint.ui_ink, FpUi.bold()))
			n += 1
		if in_room and bool(cfg.get("bots", true)):
			for i in maxi(int(cfg.get("team_size", 4)) - n, 0):
				box.add_child(FpUi.label("機器人", 18, Faultprint.SLATE, FpUi.bold()))
	_start.visible = host
	var status := NetSession.last_status
	if not NetSession.active:
		status = status if status != "" else "開一個房間，或輸入房主的 IP 加入（區網或虛擬區網）"
	elif not host and in_room:
		status = "已在房間裡，等房主開始"
	_status.text = status
