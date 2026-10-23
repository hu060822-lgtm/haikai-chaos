class_name SettingsMenu
extends Control
## The settings menu (Esc): mouse sensitivity, field of view, V-Sync, FPS counter, camera
## effects, and every key binding. Click a binding, then press the key or mouse button you
## want (Esc cancels). Everything is saved as it changes.

signal closed()

var _waiting := ""                 # the action waiting for a new key, or ""
var _bind_buttons := {}            # action -> Button
var _sens_label: Label
var _fov_label: Label


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = FpUi.theme()
	visible = false


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Faultprint.CARBON, 0.55)
	shade.set_anchors_preset(PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -380
	panel.offset_bottom = 380
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := FpUi.PrintText.new("設定", 40)
	title.custom_minimum_size = Vector2(200, 48)
	title_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	var back := FpUi.button("回到遊戲（Esc）", 18)
	back.pressed.connect(close)
	title_row.add_child(back)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(cols)
	cols.add_child(_general())
	cols.add_child(_keys())


func _general() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	box.add_child(FpUi.label("畫面與操作", 20, Faultprint.ui_accent, FpUi.bold()))
	_sens_label = FpUi.label("", 16)
	box.add_child(_sens_label)
	box.add_child(_slider(0.1, 4.0, 0.05, Settings.sens, func(v: float) -> void:
		Settings.sens = v
		Settings.save()
		_refresh_labels()))
	_fov_label = FpUi.label("", 16)
	box.add_child(_fov_label)
	box.add_child(_slider(80.0, 120.0, 1.0, Settings.fov, func(v: float) -> void:
		Settings.fov = v
		Settings.save()
		var p := get_tree().get_first_node_in_group("player") as Player
		if p:
			p.base_fov = v
		_refresh_labels()))
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	box.add_child(vol_row)
	for spec in [["音樂", Settings.music_vol, true], ["音效", Settings.sfx_vol, false]]:
		var col := VBoxContainer.new()
		vol_row.add_child(col)
		var vl := FpUi.label("%s　%d%%" % [spec[0], roundi(float(spec[1]) * 100)], 16)
		col.add_child(vl)
		var is_music: bool = spec[2]
		var sl := _slider(0.0, 1.0, 0.05, float(spec[1]), func(v: float) -> void:
			if is_music:
				Settings.music_vol = v
			else:
				Settings.sfx_vol = v
			Settings.save()
			Music.apply_volumes()
			vl.text = "%s　%d%%" % [spec[0], roundi(v * 100)])
		sl.custom_minimum_size = Vector2(184, 24)
		col.add_child(sl)
	box.add_child(_toggle("V-Sync（開啟會增加輸入延遲）", Settings.vsync, func(on: bool) -> void:
		Settings.vsync = on
		Settings.save()
		Settings.apply_display()))
	box.add_child(FpUi.label("畫面風格（Counterform 與介面配色需重開遊戲）", 16))
	var look_row := HBoxContainer.new()
	box.add_child(look_row)
	var look_buttons: Array[Button] = []
	for i in Faultprint.LOOKS.size():
		var lb := FpUi.button(Faultprint.LOOKS[i], 16)
		lb.toggle_mode = true
		lb.button_pressed = Settings.look == i
		look_buttons.append(lb)
		look_row.add_child(lb)
		lb.pressed.connect(func() -> void:
			Settings.look = i
			Settings.save()
			Faultprint.set_look(i)
			for j in look_buttons.size():
				look_buttons[j].set_pressed_no_signal(j == i))
	box.add_child(_toggle("描邊（物件輪廓的墨線）", Settings.ink_lines, func(on: bool) -> void:
		Settings.ink_lines = on
		Settings.save()
		Faultprint.apply_post()))
	box.add_child(FpUi.label("像素化（低解析度的顆粒感）", 16))
	var px_row := HBoxContainer.new()
	box.add_child(px_row)
	var px_buttons: Array[Button] = []
	for i in Faultprint.PIXEL_NAMES.size():
		var pb := FpUi.button(Faultprint.PIXEL_NAMES[i], 16)
		pb.toggle_mode = true
		pb.button_pressed = Settings.pixels == i
		px_buttons.append(pb)
		px_row.add_child(pb)
		pb.pressed.connect(func() -> void:
			Settings.pixels = i
			Settings.save()
			Faultprint.apply_post()
			for j in px_buttons.size():
				px_buttons[j].set_pressed_no_signal(j == i))
	box.add_child(_toggle("顯示 FPS", Settings.show_fps, func(on: bool) -> void:
		Settings.show_fps = on
		Settings.save()))
	box.add_child(FpUi.label("鏡頭效果（速度 FOV、傾斜、落地晃動、速度線）", 16))
	var fx_row := HBoxContainer.new()
	box.add_child(fx_row)
	var fx_buttons: Array[Button] = []
	for i in CameraFx.LEVELS.size():
		var b := FpUi.button(CameraFx.LEVELS[i][1], 16)
		b.toggle_mode = true
		b.button_pressed = CameraFx.level == i
		fx_buttons.append(b)
		fx_row.add_child(b)
		b.pressed.connect(func() -> void:
			while CameraFx.level != i:
				CameraFx.cycle()
			for j in fx_buttons.size():
				fx_buttons[j].set_pressed_no_signal(j == i))
	box.add_child(FpUi.label("中繼伺服器（空白＝遊戲內建的）", 16))
	var relay := LineEdit.new()
	relay.text = Settings.relay_url
	relay.placeholder_text = Matchmaker.DEFAULT_RELAY if Matchmaker.DEFAULT_RELAY != "" else "wss://haikai-relay.你的帳號.workers.dev"
	relay.custom_minimum_size = Vector2(420, 34)
	relay.text_changed.connect(func(t: String) -> void:
		Settings.relay_url = t.strip_edges()
		Settings.save())
	box.add_child(relay)
	var report := FpUi.button("匯出平衡報表（槍身／零件／對戰紀錄）", 16)
	report.pressed.connect(func() -> void:
		var path := Balance.export()
		if path != "":
			report.text = "已寫到 " + ProjectSettings.globalize_path(path).get_file() + "（資料夾已開啟）"
			OS.shell_open(ProjectSettings.globalize_path("user://")))
	box.add_child(report)
	_refresh_labels()
	return box


func _keys() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	box.add_child(head)
	var l := FpUi.label("按鍵（點一下再按新的鍵或滑鼠鍵）", 20, Faultprint.ui_accent, FpUi.bold())
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(l)
	var reset := FpUi.button("恢復預設", 15)
	reset.pressed.connect(func() -> void:
		InputSetup.reset()
		_refresh_keys())
	head.add_child(reset)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for pair in InputSetup.BINDABLE:
		var name_label := FpUi.label(pair[1], 16)
		name_label.custom_minimum_size = Vector2(170, 0)
		grid.add_child(name_label)
		var b := FpUi.button("", 16)
		b.custom_minimum_size = Vector2(300, 0)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_waiting = pair[0]
			_refresh_keys())
		grid.add_child(b)
		_bind_buttons[pair[0]] = b
	_refresh_keys()
	return box


func _slider(lo: float, hi: float, step: float, value: float, changed: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(380, 24)
	s.value_changed.connect(changed)
	return s


func _toggle(text: String, on: bool, changed: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_override("font", FpUi.bold())
	c.add_theme_color_override("font_color", Faultprint.ui_ink)
	c.add_theme_color_override("font_hover_color", Faultprint.ui_ink)
	c.add_theme_color_override("font_pressed_color", Faultprint.ui_ink)
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(changed)
	return c


func _refresh_labels() -> void:
	_sens_label.text = "滑鼠靈敏度　%.2f×" % Settings.sens
	_fov_label.text = "視野（FOV）　%d°" % roundi(Settings.fov)


func _refresh_keys() -> void:
	for action in _bind_buttons:
		var b: Button = _bind_buttons[action]
		b.text = "按下新的鍵…（Esc 取消）" if action == _waiting else InputSetup.describe(action)


func open() -> void:
	visible = true
	_waiting = ""
	_refresh_keys()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if _waiting != "":
		_waiting = ""
		_refresh_keys()
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _waiting != "":
		var ev: InputEvent = null
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
				_waiting = ""
				_refresh_keys()
				get_viewport().set_input_as_handled()
				return
			var k := InputEventKey.new()
			k.physical_keycode = (event as InputEventKey).physical_keycode
			ev = k
		elif event is InputEventMouseButton and event.pressed:
			var m := InputEventMouseButton.new()
			m.button_index = (event as InputEventMouseButton).button_index
			ev = m
		if ev:
			InputSetup.rebind(_waiting, ev)
			_waiting = ""
			_refresh_keys()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
