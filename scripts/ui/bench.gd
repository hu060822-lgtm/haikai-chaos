class_name Bench
extends Control
## The gunsmith bench (Tab). Built on HAIKAI's slot tree (Arsenal), laid out per the art
## brief: the real 3D gun in the middle (drag to turn), slots on the left, the parts that
## fit the picked slot on the right, numbers underneath with before/after deltas.
## Every change rebuilds the model at once. A part that would knock other parts off is
## never applied silently: the first click says what comes off, the second click does it.
## The stats come from the same Arsenal.stats() the game uses, so what you read is what
## you shoot.

signal closed(build: Dictionary, gun_name: String)

## Numbers shown, and which way is better (+1 higher, -1 lower).
const STAT_ROWS := [
	["damage", "傷害", 1], ["pellets", "彈丸", 1], ["rate", "射速", 1], ["mag", "彈匣", 1],
	["reload", "換彈 s", -1], ["spread", "腰射散布", -1], ["moa", "精度 MOA", -1], ["recoil", "後座", -1],
	["ergo", "操控", 1], ["aim_time", "開鏡 s", -1], ["range", "射程 m", 1], ["zoom", "倍率", 0],
	["weight", "重量 kg", -1], ["mobility", "機動性 %", 1],
]

var build := {}
var gun_name := ""
var _named := false
var _slot := ""
var _pending := ""
var _vp: SubViewport
var _view: TextureRect
var _slot_list: VBoxContainer
var _part_list: VBoxContainer
var _part_title: Label
var _desc: Label
var _warn: Label
var _stats_grid: GridContainer
var _name_edit: LineEdit
var _tune: HSlider
var _tune_label: Label
var _blueprints: VBoxContainer
var _frame_mode := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = FpUi.theme()
	visible = false
	_rng.randomize()


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Faultprint.ui_paper
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	# Print-layout blocks in the background: the bench is a printed sheet too.
	for spec in [[Vector2(-40, 0), Vector2(520, 70), Faultprint.ui_ink], [Vector2(0, 70), Vector2(14, 2000), Faultprint.ui_accent]]:
		var r := ColorRect.new()
		r.position = spec[0]
		r.size = spec[1]
		r.color = spec[2]
		r.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(r)
	var title := FpUi.PrintText.new("改槍工作台", 40, Faultprint.ui_paper)
	title.plate_b = Faultprint.ui_accent
	title.position = Vector2(28, 12)
	title.size = Vector2(480, 50)
	add_child(title)
	var root := HBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_right = -24
	root.offset_top = 84
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	# Left: frame, slots, blueprints.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	var frame_btn := FpUi.button("換槍身…", 16)
	frame_btn.pressed.connect(_show_frames)
	left.add_child(frame_btn)
	var slots_scroll := ScrollContainer.new()
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(slots_scroll)
	_slot_list = VBoxContainer.new()
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_scroll.add_child(_slot_list)
	left.add_child(FpUi.label("藍圖", 14, Faultprint.SLATE, FpUi.bold()))
	var bp_scroll := ScrollContainer.new()
	bp_scroll.custom_minimum_size = Vector2(0, 150)
	bp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(bp_scroll)
	_blueprints = VBoxContainer.new()
	_blueprints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_scroll.add_child(_blueprints)
	# Middle: name, the gun, stats.
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	root.add_child(mid)
	var name_row := HBoxContainer.new()
	mid.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "幫這把槍取名（擊殺列表會顯示）"
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.text_changed.connect(func(t: String) -> void:
		gun_name = t
		_named = t.strip_edges() != "")
	name_row.add_child(_name_edit)
	var dice := FpUi.button("骰一把", 16)
	dice.pressed.connect(_roll)
	name_row.add_child(dice)
	var save := FpUi.button("存成藍圖", 16)
	save.pressed.connect(_save_blueprint)
	name_row.add_child(save)
	var done := FpUi.button("裝備並出發 [Tab]", 16)
	done.pressed.connect(close)
	name_row.add_child(done)
	var view_panel := PanelContainer.new()
	view_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_panel.add_theme_stylebox_override("panel", FpUi.panel(Faultprint.ui_dust, Faultprint.ui_ink, 20, 3))
	mid.add_child(view_panel)
	_view = TextureRect.new()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.mouse_filter = MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	view_panel.add_child(_view)
	_warn = FpUi.label("", 16, Faultprint.ui_accent, FpUi.bold())
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(_warn)
	var tune_row := HBoxContainer.new()
	mid.add_child(tune_row)
	_tune_label = FpUi.label("", 14, Faultprint.ui_ink, FpUi.bold())
	_tune_label.custom_minimum_size = Vector2(220, 0)
	tune_row.add_child(_tune_label)
	_tune = HSlider.new()
	_tune.min_value = -1.0
	_tune.max_value = 1.0
	_tune.step = 0.05
	_tune.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tune.value_changed.connect(_on_tune)
	tune_row.add_child(_tune)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 5
	_stats_grid.add_theme_constant_override("h_separation", 16)
	mid.add_child(_stats_grid)
	# Right: parts for the picked slot.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)
	_part_title = FpUi.label("選一個插槽", 20, Faultprint.ui_ink, FpUi.display(0.6))
	right.add_child(_part_title)
	var parts_scroll := ScrollContainer.new()
	parts_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(parts_scroll)
	_part_list = VBoxContainer.new()
	_part_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_scroll.add_child(_part_list)
	_desc = FpUi.label("", 14, Faultprint.ui_ink, FpUi.bold())
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 90)
	right.add_child(_desc)


func open(current: Dictionary, current_name: String) -> void:
	build = Arsenal.clean(current)
	gun_name = current_name
	_named = Blueprints.is_custom_name(build, current_name)
	_name_edit.text = current_name if _named else ""
	_slot = ""
	_pending = ""
	_frame_mode = false
	visible = true
	_refresh()


func close() -> void:
	visible = false
	if _vp != null:
		_vp.queue_free()
		_vp = null
	var final_name := gun_name if _named else GunNames.auto_name(build, Arsenal.stats(build))
	closed.emit(build, final_name)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("bench") and not _name_edit.has_focus():
		close()
		get_viewport().set_input_as_handled()


func _refresh(preview: Dictionary = {}) -> void:
	_rebuild_view()
	_fill_slots()
	_fill_parts()
	_fill_stats(preview)
	_fill_blueprints()
	_fill_tune()
	if not _named:
		_name_edit.placeholder_text = "自動命名：" + GunNames.auto_name(build, Arsenal.stats(build))


func _rebuild_view() -> void:
	if _vp != null:
		_vp.queue_free()
	_vp = GunThumb.live(build, Vector2i(1000, 560))
	add_child(_vp)
	_view.texture = _vp.get_texture()


func _on_view_input(event: InputEvent) -> void:
	if _vp != null and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var turner := _vp.get_child(2)
		if turner is GunThumb.Turner:
			turner.drag += event.relative.x * 0.003


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill_slots() -> void:
	_clear(_slot_list)
	var head := FpUi.label("槍身：" + Arsenal.name_of(build.frame), 18, Faultprint.ui_ink, FpUi.display(0.6))
	_slot_list.add_child(head)
	var open := Arsenal.open_slots(build)
	for group in Arsenal.SLOT_GROUPS:
		var any := false
		for slot in group[1]:
			if slot in open:
				any = true
		if not any:
			continue
		_slot_list.add_child(FpUi.label(group[0], 13, Faultprint.SLATE, FpUi.bold()))
		for slot in group[1]:
			if not slot in open:
				continue
			var id: String = build.parts.get(slot, "")
			var b := FpUi.button("%s：%s" % [Arsenal.slot_name(slot), Arsenal.name_of(id) if id != "" else "—"], 15)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if slot == _slot and not _frame_mode:
				b.add_theme_stylebox_override("normal", FpUi.panel(Faultprint.YELLOW, Faultprint.ui_ink, 8, 2))
			b.pressed.connect(func() -> void:
				_slot = slot
				_pending = ""
				_frame_mode = false
				_warn.text = ""
				_refresh())
			_slot_list.add_child(b)


func _fill_parts() -> void:
	_clear(_part_list)
	if _frame_mode:
		_part_title.text = "槍身（換槍身會清掉不合的零件）"
		for id in Arsenal.FRAMES:
			var f := Arsenal.frame(id)
			var b := _part_button(id, "%s　%.1f kg" % [f.name, float(f.weight)], id == build.frame)
			b.pressed.connect(_on_frame.bind(id))
			b.mouse_entered.connect(func() -> void:
				_desc.text = f.get("desc", "")
				_fill_stats(Arsenal.clean({"frame": id, "parts": build.parts, "tune": build.tune})))
			_part_list.add_child(b)
		return
	if _slot == "":
		_part_title.text = "選一個插槽"
		return
	_part_title.text = Arsenal.slot_name(_slot)
	var current: String = build.parts.get(_slot, "")
	var none := _part_button("", "（拆下）", current == "")
	none.pressed.connect(_on_part.bind(""))
	none.mouse_entered.connect(func() -> void: _fill_stats(_with(_slot, "")))
	_part_list.add_child(none)
	for id in Arsenal.parts_for(build, _slot):
		var p := Arsenal.part(id)
		var label := "%s　%+.2f kg" % [p.name, float(p.get("weight", 0.0))]
		var b := _part_button(id, label, id == current)
		b.pressed.connect(_on_part.bind(id))
		b.mouse_entered.connect(func() -> void:
			_desc.text = p.get("desc", "")
			_fill_stats(_with(_slot, id)))
		b.mouse_exited.connect(func() -> void: _fill_stats())
		_part_list.add_child(b)


func _part_button(_id: String, text: String, current: bool) -> Button:
	var b := FpUi.button(text, 15)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if current:
		b.add_theme_stylebox_override("normal", FpUi.panel(Faultprint.TEAL, Faultprint.ui_ink, 8, 2))
	return b


func _with(slot: String, id: String) -> Dictionary:
	var b := build.duplicate(true)
	if id == "":
		b.parts.erase(slot)
	else:
		b.parts[slot] = id
	return Arsenal.clean(b)


## Which installed parts a change would knock off (other than the slot being changed).
func _lost_by(next: Dictionary, slot: String) -> Array:
	var lost := []
	for s in build.parts:
		if s == slot:
			continue
		if next.parts.get(s, "") != build.parts[s]:
			lost.append("%s（%s）" % [Arsenal.name_of(build.parts[s]), Arsenal.slot_name(s)])
	return lost


func _on_part(id: String) -> void:
	var next := _with(_slot, id)
	var lost := _lost_by(next, _slot)
	var key := "%s|%s" % [_slot, id]
	if not lost.is_empty() and _pending != key:
		_pending = key
		_warn.text = "裝上「%s」會拆下：%s。再點一次確認。" % [Arsenal.name_of(id) if id != "" else "（拆下）", "、".join(lost)]
		return
	_pending = ""
	_warn.text = ""
	build = next
	_refresh()


func _show_frames() -> void:
	_frame_mode = true
	_slot = ""
	_refresh()


func _on_frame(id: String) -> void:
	var next := Arsenal.clean({"frame": id, "parts": build.parts, "tune": build.tune})
	var lost := _lost_by(next, "")
	var key := "frame|" + id
	if not lost.is_empty() and _pending != key:
		_pending = key
		_warn.text = "換成「%s」會拆下：%s。再點一次確認。" % [Arsenal.name_of(id), "、".join(lost)]
		return
	_pending = ""
	_warn.text = ""
	build = next
	_frame_mode = false
	_refresh()


func _roll() -> void:
	build = GunNames.random_build(_rng)
	_named = false
	_name_edit.text = ""
	_slot = ""
	_warn.text = "骰到：" + GunNames.auto_name(build, Arsenal.stats(build))
	_refresh()


func _fill_tune() -> void:
	var id: String = build.parts.get(_slot, "") if _slot != "" else ""
	var p := Arsenal.part(id) if id != "" else {}
	var has := p.has("tune")
	_tune.visible = has
	_tune_label.visible = has
	if has:
		var t: Dictionary = p.tune
		_tune_label.text = "微調 %s（%s ↔ %s）" % [t.name, t.lo, t.hi]
		_tune.set_value_no_signal(float(build.tune.get(_slot, 0.0)))


func _on_tune(v: float) -> void:
	if _slot == "":
		return
	build.tune[_slot] = v
	build = Arsenal.clean(build)
	_fill_stats()


func _stat(s: Dictionary, key: String) -> float:
	if key == "mobility":
		return Player.mobility_of(s) * 100.0
	if key == "damage":
		return Weapon.pvp_damage(s)
	return float(s.get(key, 0.0))


func _fill_stats(preview: Dictionary = {}) -> void:
	_clear(_stats_grid)
	var now := Arsenal.stats(build)
	var then := Arsenal.stats(preview) if not preview.is_empty() else {}
	for row in STAT_ROWS:
		var key: String = row[0]
		var v := _stat(now, key)
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(120, 0)
		cell.add_child(FpUi.label(row[1], 13, Faultprint.SLATE, FpUi.bold()))
		var val := FpUi.label(_fmt(v), 17, Faultprint.ui_ink, FpUi.display(0.5))
		cell.add_child(val)
		if not then.is_empty():
			var w := _stat(then, key)
			var d := w - v
			if absf(d) > 0.005:
				var better: bool = d * row[2] > 0.0
				var col := Faultprint.DEEP_TEAL if better else Faultprint.ui_accent
				if row[2] == 0:
					col = Faultprint.SLATE
				cell.add_child(FpUi.label(("+" if d > 0 else "") + _fmt(d), 14, col, FpUi.bold()))
		_stats_grid.add_child(cell)
	var info := FpUi.label("口徑 %s　模式 %s　%s" % [now.caliber, "/".join(now.modes.map(func(m) -> String: return Arsenal.MODE_NAMES.get(m, m))),
		"（%s）" % now.kind if now.kind != "hitscan" else ""], 13, Faultprint.ui_ink, FpUi.bold())
	_stats_grid.add_child(info)


static func _fmt(v: float) -> String:
	if absf(v - roundf(v)) < 0.01:
		return "%d" % roundi(v)
	return "%.2f" % v if absf(v) < 10.0 else "%.1f" % v


func _fill_blueprints() -> void:
	_clear(_blueprints)
	var list := Blueprints.load_all()
	if list.is_empty():
		_blueprints.add_child(FpUi.label("（還沒有。死亡畫面按 F 可以抄別人的槍）", 13, Faultprint.SLATE, FpUi.bold()))
	for i in list.size():
		var bp: Dictionary = list[i]
		var row := HBoxContainer.new()
		var b := FpUi.button(bp.name, 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			build = Arsenal.clean(bp.build)
			gun_name = bp.name
			_named = true
			_name_edit.text = bp.name
			_refresh())
		row.add_child(b)
		var x := FpUi.button("×", 14)
		x.pressed.connect(func() -> void:
			Blueprints.remove(i)
			_fill_blueprints())
		row.add_child(x)
		_blueprints.add_child(row)


func _save_blueprint() -> void:
	var final_name := gun_name if _named else GunNames.auto_name(build, Arsenal.stats(build))
	Blueprints.add(build, final_name)
	_warn.text = "已存成藍圖：" + final_name
	_fill_blueprints()
