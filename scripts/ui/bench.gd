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
## A class picked on the bench (C6). Only at home: out in the field the row is locked.
signal kit_chosen(id: String)

## Numbers shown, and which way is better (+1 higher, -1 lower).
const STAT_ROWS := [
	["damage", "傷害", 1], ["pellets", "彈丸", 1], ["rate", "射速", 1], ["mag", "彈匣", 1],
	["reload", "換彈 s", -1], ["spread", "腰射散布", -1], ["moa", "精度 MOA", -1], ["recoil", "後座", -1],
	["ergo", "操控", 1], ["aim_time", "開鏡 s", -1], ["range", "射程 m", 1], ["zoom", "倍率", 0],
	["weight", "重量 kg", -1], ["sway", "晃動", -1],
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
var _status: Label
## Opened out in the field (not in a safe zone): a hit closes it (see Main).
var field := false
## 預算戰: (owned build, this build) -> the money line shown on top; empty = no shop.
var budget_text: Callable
## The class shown as picked, and whether it may be changed now.
var kit := Kit.DEFAULT
var kit_locked := false
var _kit_buttons := {}
var _kit_desc: Label
## The build the bench opened on (what you own).
var opened_on := {}
var _rng := RandomNumberGenerator.new()
var _strip_btn: Button
## The parts "拆下全部" took off, so a second press puts them back (until the build changes).
var _stripped := {}
var _after_strip := {}


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
	_status = FpUi.label("", 16, Faultprint.ui_ink, FpUi.bold())
	_status.position = Vector2(540, 24)
	add_child(_status)
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
	left.add_child(FpUi.label("職業（技能鍵 F）", 14, Faultprint.SLATE, FpUi.bold()))
	var kit_row := HBoxContainer.new()
	kit_row.add_theme_constant_override("separation", 3)
	left.add_child(kit_row)
	for id in Kit.IDS:
		var kb := FpUi.button(Kit.info(id).name, 13)
		kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kb.tooltip_text = "%s｜%s：%s" % [Kit.info(id).name, Kit.info(id).tag, Kit.info(id).pitch]
		kb.pressed.connect(func() -> void: _on_kit(id))
		kit_row.add_child(kb)
		_kit_buttons[id] = kb
	_kit_desc = FpUi.label("", 12, Faultprint.ui_ink, FpUi.body())
	_kit_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_kit_desc.custom_minimum_size = Vector2(300, 0)
	left.add_child(_kit_desc)
	var frame_row := HBoxContainer.new()
	frame_row.add_theme_constant_override("separation", 4)
	left.add_child(frame_row)
	var frame_btn := FpUi.button("換槍身…", 16)
	frame_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_btn.pressed.connect(_show_frames)
	frame_row.add_child(frame_btn)
	_strip_btn = FpUi.button("拆下全部", 16)
	_strip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip_btn.pressed.connect(strip_all)
	frame_row.add_child(_strip_btn)
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


func open(current: Dictionary, current_name: String, in_field := false) -> void:
	field = in_field
	_status.text = ("野外改槍：一被攻擊就會關上（已改的部分會保留）" if field
		else "安全區：敵人打不到你，慢慢改")
	_status.add_theme_color_override("font_color", Counterform.SULFUR if field else Faultprint.ui_ink)
	build = Arsenal.clean(current)
	opened_on = build.duplicate(true)
	gun_name = current_name
	_named = Blueprints.is_custom_name(build, current_name)
	_name_edit.text = current_name if _named else ""
	_slot = ""
	_pending = ""
	_stripped = {}
	_frame_mode = false
	visible = true
	_refresh_kit()
	_refresh()


func _on_kit(id: String) -> void:
	if kit_locked:
		_warn.text = "只能在重生區換職業"
		return
	kit = id
	_refresh_kit()
	kit_chosen.emit(id)


func _refresh_kit() -> void:
	for id in _kit_buttons:
		var b: Button = _kit_buttons[id]
		var on: bool = id == kit
		var c: Color = Kit.info(id).color
		b.add_theme_stylebox_override("normal", FpUi.panel(c if on else Faultprint.ui_paper, Faultprint.ui_ink, 4, 3 if on else 2))
		b.disabled = kit_locked and not on
	var i := Kit.info(kit)
	_kit_desc.text = "%s %s｜%s\n%s\n反制：%s%s" % [i.name, i.tag, i.ability, i.use, i.counter,
		"\n（在野外：回重生區才能換職業）" if kit_locked else ""]


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
	if not _stripped.is_empty() and build != _after_strip:
		_stripped = {}
	_strip_btn.text = "裝回 %d 件" % _stripped.parts.size() if not _stripped.is_empty() else "拆下全部"
	_strip_btn.disabled = _stripped.is_empty() and build.get("parts", {}).is_empty()
	if budget_text.is_valid():
		_status.text = budget_text.call(opened_on, build)
		_status.add_theme_color_override("font_color", Counterform.SULFUR)
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
			var b := _part_button(id, "%s　%.1f kg%s" % [f.name, float(f.weight), _price(id)], id == build.frame)
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
	if _slot == "ammo":
		# Ammo is the one part that follows the gun: only rounds that fit the calibre.
		var cal := Arsenal.caliber_of(build)
		_part_title.text = "彈藥（%s）" % Arsenal.CALIBERS.get(cal, {}).get("name", cal)
	var current: String = build.parts.get(_slot, "")
	var none := _part_button("", "（拆下）", current == "")
	none.pressed.connect(_on_part.bind(""))
	none.mouse_entered.connect(func() -> void: _fill_stats(_with(_slot, "")))
	_part_list.add_child(none)
	for id in Arsenal.parts_for(build, _slot):
		var p := Arsenal.part(id)
		var label := "%s　%+.2f kg%s" % [p.name, float(p.get("weight", 0.0)), _price(id)]
		var b := _part_button(id, label, id == current)
		b.pressed.connect(_on_part.bind(id))
		b.mouse_entered.connect(func() -> void:
			_desc.text = p.get("desc", "")
			_fill_stats(_with(_slot, id)))
		b.mouse_exited.connect(func() -> void: _fill_stats())
		_part_list.add_child(b)


## "　$180" next to a part while shopping.
func _price(id: String) -> String:
	return "　$%d" % Arsenal.price_of(id) if budget_text.is_valid() else ""


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


## One click takes every part off and leaves the bare frame; pressed again right after,
## it puts them all back.
func strip_all() -> void:
	_pending = ""
	if not _stripped.is_empty():
		build = Arsenal.clean(_stripped)
		_stripped = {}
		_warn.text = "零件都裝回去了。"
		_refresh()
		return
	if build.get("parts", {}).is_empty():
		return
	_stripped = build.duplicate(true)
	build = Arsenal.clean({"frame": build.frame, "parts": {}, "tune": {}})
	_after_strip = build.duplicate(true)
	_warn.text = "拆下了 %d 個零件，只剩槍身。再按一次可以全部裝回。" % _stripped.parts.size()
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
		_blueprints.add_child(FpUi.label("（還沒有。死亡畫面按 G 可以抄別人的槍）", 13, Faultprint.SLATE, FpUi.bold()))
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
