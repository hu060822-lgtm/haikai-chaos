class_name Lobby
extends Control
## The room screen (C2.1): the room code to share (and a button to open the room to the
## internet through the router), the map, both teams with who's ready, the host's settings,
## and the rules in one breath. Everything goes through NetSession; this only draws it.

signal closed()

var net: NetSession
var _code: Label
var _code_note: Label
var _net_btn: Button
var _status: Label
var _teams: Array[VBoxContainer] = []
var _team_heads: Array[Label] = []
var _map_buttons := {}
var _mode_buttons := {}
var _rounds_label: Label
var _rules: Label
var _title: Label
var _subtitle: Label
var _size_label: Label
var _score_label: Label
var _time_label: Label
var _bots: CheckButton
var _bot_level_label: Label
var _start: Button
var _ready_btn: Button
var _swap: Button
var _host_box: VBoxContainer
var _flash_left := 0.0


const RULES_PATCH := ("・同一把槍越殺越不值錢（3、3、2、2、1 分）；改任何零件就是新版本，重新值 3 分。\n"
	+ "・身法擊殺 +1。某個版本殺滿 4 人成為「版本答案」：帶著它的人全場可見，擊殺他 +3。\n"
	+ "・重生區內打不到人也不會被打，隨時能改槍；外面要 4 秒沒交火才能改。")
const RULES_ROUNDS := ("・每回合一條命。開頭 15 秒備戰：工作台就是商店，加零件付全價、拆下來退一半。\n"
	+ "・活下來槍就留著；陣亡就沒了，下回合從左輪重來。擊殺 +$100，外加對方槍價的 25%（拆件）。\n"
	+ "・贏 $1500，輸 $1000 起（連輸會多）。全滅對方、時間到血多，或最後 40 秒單獨佔住中央超頻區 6 秒就贏。")


const RULES_BOMB := ("・預算戰的回合與經濟（工作台就是商店，陣亡掉槍）。藍隊先攻，打到一半交換攻守，資金重來。\n"
	+ "・進攻：在 A 或 B 點按住 E 3.5 秒安裝炸彈，40 秒後引爆就贏；或全滅防守方。\n"
	+ "・防守：時間到還沒裝、裝之前全滅進攻方、或按住 E 6 秒拆掉炸彈。安裝、拆除各 +$300。")


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = FpUi.theme()
	visible = false


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Counterform.GRAPHITE_DEEP, 0.72)
	shade.set_anchors_preset(PRESET_FULL_RECT)
	add_child(shade)
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.offset_left = 70
	root.offset_right = -70
	root.offset_top = 46
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	# Header: the mode, the room code, internet.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	root.add_child(head)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", -6)
	head.add_child(title_col)
	_title = FrontEnd.heading("改版死鬥", 56)
	title_col.add_child(_title)
	_subtitle = FpUi.label("", 16, Color(Counterform.DUST_WHITE, 0.6), FpUi.bold())
	title_col.add_child(_subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(spacer)
	var code_card := FrontEnd.card()
	head.add_child(code_card)
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 14)
	code_card.add_child(code_row)
	var code_col := VBoxContainer.new()
	code_col.add_theme_constant_override("separation", -2)
	code_row.add_child(code_col)
	code_col.add_child(FpUi.label("房間碼", 13, Color(Counterform.DUST_WHITE, 0.55), FpUi.bold()))
	_code = FpUi.label("—", 38, Counterform.SULFUR, FpUi.numerals())
	code_col.add_child(_code)
	_code_note = FpUi.label("", 12, Color(Counterform.DUST_WHITE, 0.55), FpUi.body())
	code_col.add_child(_code_note)
	var copy := FrontEnd.action("複製", false, 15)
	copy.size_flags_vertical = SIZE_SHRINK_CENTER
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_code.text)
		flash("房間碼已複製：%s" % _code.text))
	code_row.add_child(copy)
	_net_btn = FrontEnd.action("開放網路連線", false, 15)
	_net_btn.size_flags_vertical = SIZE_SHRINK_CENTER
	_net_btn.tooltip_text = "請路由器（UPnP）把遊戲埠轉給這台電腦，房間碼換成外部位址：不在同一個網路的朋友也能加入"
	_net_btn.pressed.connect(func() -> void:
		_net_btn.disabled = true
		flash("正在詢問路由器…", 6.0)
		net.matchmaker.open_internet(NetSession.PORT))
	code_row.add_child(_net_btn)

	# Body: two teams | settings.
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	for t in 2:
		var card := FrontEnd.card()
		card.custom_minimum_size = Vector2(330, 0)
		body.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		card.add_child(col)
		var th := FpUi.label(NetSession.TEAM_NAMES[t], 28, FpUi.ally_color() if t == 0 else FpUi.enemy_color(), FpUi.display())
		col.add_child(th)
		_team_heads.append(th)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 6)
		col.add_child(list)
		_teams.append(list)
	var right := FrontEnd.card()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(right)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 10)
	right.add_child(rc)
	rc.add_child(FpUi.label("地圖", 22, Counterform.DUST_WHITE, FpUi.display()))
	var maps := HBoxContainer.new()
	maps.add_theme_constant_override("separation", 8)
	rc.add_child(maps)
	for id in NetSession.MAPS:
		var b := FrontEnd.action(NetSession.MAPS[id], false, 16)
		b.toggle_mode = true
		var map_id: String = id
		b.pressed.connect(func() -> void:
			net.set_config("map", map_id)
			_refresh())
		maps.add_child(b)
		_map_buttons[id] = b
	rc.add_child(FpUi.label("模式", 22, Counterform.DUST_WHITE, FpUi.display()))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	rc.add_child(modes)
	for id in NetSession.MODES:
		var b := FrontEnd.action(NetSession.MODES[id], false, 16)
		b.toggle_mode = true
		var mode_id: String = id
		b.pressed.connect(func() -> void:
			net.set_config("mode", mode_id)
			_refresh())
		modes.add_child(b)
		_mode_buttons[id] = b
	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 8)
	rc.add_child(_host_box)
	_host_box.add_child(FpUi.label("規則（房主設定）", 22, Counterform.DUST_WHITE, FpUi.display()))
	_size_label = _stepper("team_size", 1, 5, 1)
	_score_label = _stepper("score", 20, 120, 10)
	_time_label = _stepper("minutes", 3, 15, 1)
	_rounds_label = _stepper("rounds", 2, 9, 1)
	_bots = CheckButton.new()
	_bots.text = "空位補機器人"
	_bots.add_theme_font_override("font", FpUi.bold())
	_bots.add_theme_color_override("font_color", Counterform.DUST_WHITE)
	_bots.add_theme_color_override("font_hover_color", Counterform.DUST_WHITE)
	_bots.add_theme_color_override("font_pressed_color", Counterform.DUST_WHITE)
	_bots.focus_mode = Control.FOCUS_NONE
	_bots.toggled.connect(func(on: bool) -> void: net.set_config("bots", on))
	_host_box.add_child(_bots)
	_bot_level_label = _stepper("bot_level", 0, 2, 1)
	_rules = FpUi.label("", 15, Color(Counterform.DUST_WHITE, 0.75), FpUi.body())
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.size_flags_vertical = SIZE_EXPAND_FILL
	rc.add_child(_rules)

	# Footer: status | leave, swap, ready, start.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	root.add_child(foot)
	_status = FpUi.label("", 17, Counterform.SULFUR, FpUi.bold())
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_status.clip_text = true
	foot.add_child(_status)
	var leave := FrontEnd.action("離開房間", false, 18)
	leave.pressed.connect(func() -> void:
		net.leave()
		close())
	foot.add_child(leave)
	_swap = FrontEnd.action("換隊", false, 18)
	_swap.pressed.connect(func() -> void: net.switch_team())
	foot.add_child(_swap)
	_ready_btn = FrontEnd.action("準備", false, 18)
	_ready_btn.toggle_mode = true
	_ready_btn.toggled.connect(func(on: bool) -> void: net.set_ready(on))
	foot.add_child(_ready_btn)
	_start = FrontEnd.action("開始對戰", true, 22)
	_start.custom_minimum_size = Vector2(220, 0)
	_start.pressed.connect(func() -> void: net.start_match())
	foot.add_child(_start)
	net.matchmaker.internet_done.connect(func(ok: bool, code: String, message: String) -> void:
		_net_btn.disabled = false
		if ok:
			NetSession.internet_code = code
			_net_btn.text = "網路已開放"
		flash(message, 8.0)
		_refresh())


## "label   [−] [+]" for an integer setting.
func _stepper(key: String, lo: int, hi: int, step: int) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_host_box.add_child(row)
	var l := FpUi.label("", 18, Counterform.DUST_WHITE, FpUi.bold())
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	for d in [-step, step]:
		var b := FrontEnd.action("−" if d < 0 else "+", false, 18)
		b.custom_minimum_size = Vector2(48, 0)
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
	Music.play(get_tree(), "lobby")
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


## A message in the status line for a while (overrides the connection status).
func flash(text: String, seconds := 5.0) -> void:
	_status.text = text
	_flash_left = seconds


func _process(delta: float) -> void:
	_flash_left -= delta
	if visible and not NetSession.active:
		# The room went away under us (host left, connection failed).
		close()


func _refresh() -> void:
	if _status == null or not visible:
		return
	var host := net.is_host()
	var cfg := NetSession.config
	var code := NetSession.internet_code if NetSession.internet_code != "" else NetSession.room_code
	if NetSession.relay:
		# A relay room: the code works from anywhere, so everyone can pass it on.
		_code.text = code if code != "" else "…"
		_code_note.text = "中繼伺服器：任何網路都能加入"
		_code.get_parent().get_parent().get_parent().visible = true
		_net_btn.visible = false
	else:
		_code.text = code if code != "" else "—"
		_code_note.text = "外部位址（網路）" if NetSession.internet_code != "" else "區網／虛擬區網"
		_code.get_parent().get_parent().get_parent().visible = host and code != ""
		_net_btn.visible = host
	for id in _map_buttons:
		var b: Button = _map_buttons[id]
		b.set_pressed_no_signal(str(cfg.get("map", "folded")) == id)
		b.disabled = not host
	var mode := str(cfg.get("mode", "patch"))
	var rounds := mode != "patch"
	for id in _mode_buttons:
		var b: Button = _mode_buttons[id]
		b.set_pressed_no_signal(str(cfg.get("mode", "patch")) == id)
		b.disabled = not host
	_score_label.get_parent().visible = not rounds
	_time_label.get_parent().visible = not rounds
	_rounds_label.get_parent().visible = rounds
	_rounds_label.text = "先贏　%d 回合" % int(cfg.get("rounds", 5))
	_rules.text = {"rounds": RULES_ROUNDS, "bomb": RULES_BOMB}.get(mode, RULES_PATCH)
	_title.text = NetSession.MODES.get(mode, "改版死鬥")
	_subtitle.text = {"rounds": "BUDGET WAR　回合制", "bomb": "DEMOLITION　回合制爆破"}.get(mode, "PATCH WAR　團隊死鬥")
	_host_box.modulate.a = 1.0 if host else 0.55
	_bots.disabled = not host
	_size_label.text = "每隊人數　%d" % int(cfg.get("team_size", 4))
	_score_label.text = "目標分數　%d" % int(cfg.get("score", 50))
	_time_label.text = "時間上限　%d 分" % int(cfg.get("minutes", 8))
	_bots.set_pressed_no_signal(bool(cfg.get("bots", true)))
	_bot_level_label.get_parent().visible = bool(cfg.get("bots", true))
	_bot_level_label.text = "機器人難度　%s" % BotLevel.label(int(cfg.get("bot_level", 1)))
	_bot_level_label.tooltip_text = BotLevel.INFO[clampi(int(cfg.get("bot_level", 1)), 0, 2)]
	_bot_level_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var in_room := NetSession.active and not NetSession.roster.is_empty()
	for t in 2:
		var box := _teams[t]
		for c in box.get_children():
			c.queue_free()
		var n := 0
		for peer in NetSession.roster:
			var info: Dictionary = NetSession.roster[peer]
			if int(info.team) != t:
				continue
			box.add_child(_player_row(str(info.name), int(peer) == 1, int(peer) == net.my_id(), bool(info.get("ready", false))))
			n += 1
		if in_room and bool(cfg.get("bots", true)):
			for i in maxi(int(cfg.get("team_size", 4)) - n, 0):
				box.add_child(_player_row("機器人", false, false, true, true))
		_team_heads[t].text = "%s　%d" % [NetSession.TEAM_NAMES[t], n]
	_start.visible = host
	_ready_btn.visible = not host
	_ready_btn.set_pressed_no_signal(bool(NetSession.roster.get(net.my_id(), {}).get("ready", false)))
	_ready_btn.text = "已準備" if _ready_btn.button_pressed else "準備"
	if _flash_left > 0.0:
		return
	var status := NetSession.last_status
	if host:
		status = "所有人都準備好了" if net.all_ready() else "等其他人準備（也可以直接開始）"
		if NetSession.roster.size() == 1:
			status = "把房間碼傳給朋友，或直接和機器人打"
	elif in_room:
		status = "按「準備」，等房主開始"
	_status.text = status


func _player_row(name: String, is_host: bool, you: bool, ready: bool, bot := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var mark := FpUi.label("✓" if ready else "·", 18, Counterform.SULFUR if ready and not bot else Color(Counterform.DUST_WHITE, 0.3),
		FpUi.bold())
	mark.custom_minimum_size = Vector2(18, 0)
	row.add_child(mark)
	var l := FpUi.label(name, 20, Color(Counterform.DUST_WHITE, 0.4) if bot else Counterform.DUST_WHITE, FpUi.bold())
	row.add_child(l)
	if is_host:
		row.add_child(FpUi.label("房主", 13, Color(Counterform.DUST_WHITE, 0.5), FpUi.body()))
	if you:
		row.add_child(FpUi.label("你", 13, Counterform.SULFUR, FpUi.bold()))
	return row
