class_name DeathScreen
extends Control
## Shown when you die: who got you and with what. The killer's gun turns slowly in the
## middle (its real model), with its name, frame, every part on it and the numbers that
## matter. The damage exchange says how close it was. "抄下這把槍" (F) saves the gun as
## one of your blueprints and equips it on respawn, so losing is how you learn builds.

signal respawn_requested()
signal copy_requested(build: Dictionary, gun_name: String)

var _info := {}
var _vp: SubViewport
var _view: TextureRect
var _title: FpUi.PrintText
var _sub: Label
var _gun_name: FpUi.PrintText
var _parts: Label
var _stats: Label
var _exchange: Label
var _copy: Button
var _copied := false


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	theme = FpUi.theme()


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Faultprint.ui_paper, 0.82)
	shade.set_anchors_preset(PRESET_FULL_RECT)
	add_child(shade)
	# A diagonal ink band behind the title: the print's "headline plate".
	var band := Polygon2D.new()
	band.color = Faultprint.ui_accent
	band.polygon = PackedVector2Array([Vector2(0, 40), Vector2(2400, 0), Vector2(2400, 120), Vector2(0, 170)])
	add_child(band)
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	_title = FpUi.PrintText.new("", 64)
	_title.custom_minimum_size = Vector2(0, 84)
	_title.plate_b = Faultprint.ui_ink
	_title.main = Faultprint.ui_paper
	root.add_child(_title)
	_sub = FpUi.label("", 20, Faultprint.ui_ink, FpUi.bold())
	root.add_child(_sub)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)
	var view_panel := PanelContainer.new()
	view_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_panel.size_flags_stretch_ratio = 1.6
	view_panel.add_theme_stylebox_override("panel", FpUi.panel(Faultprint.ui_dust, Faultprint.ui_ink, 18, 3))
	body.add_child(view_panel)
	var vbox := VBoxContainer.new()
	view_panel.add_child(vbox)
	_gun_name = FpUi.PrintText.new("", 34)
	_gun_name.custom_minimum_size = Vector2(0, 46)
	vbox.add_child(_gun_name)
	_view = TextureRect.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_view)
	# The exchange and the numbers come first; the parts list of a heavily modded gun is
	# long, so it scrolls in what is left of the column instead of growing it. The buttons
	# below always stay on screen at any window size.
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)
	side.add_child(FpUi.label("交手", 16, Faultprint.SLATE, FpUi.bold()))
	_exchange = FpUi.label("", 18, Faultprint.ui_ink, FpUi.bold())
	side.add_child(_exchange)
	side.add_child(FpUi.label("數值", 16, Faultprint.SLATE, FpUi.bold()))
	_stats = FpUi.label("", 16, Faultprint.ui_ink, FpUi.bold())
	side.add_child(_stats)
	side.add_child(FpUi.label("零件", 16, Faultprint.SLATE, FpUi.bold()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_parts = FpUi.label("", 16, Faultprint.ui_ink, FpUi.bold())
	_parts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_parts)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(buttons)
	_copy = FpUi.button("抄下這把槍  [F]", 22)
	_copy.pressed.connect(_on_copy)
	# Room to spare: scaled windows measure the text a little narrower than they draw it.
	_copy.custom_minimum_size = Vector2(300, 48)
	buttons.add_child(_copy)
	var again := FpUi.button("重生  [Space / Enter]", 22)
	again.pressed.connect(func() -> void: respawn_requested.emit())
	again.custom_minimum_size = Vector2(300, 48)
	buttons.add_child(again)


func show_death(info: Dictionary, dealt: float, taken: float) -> void:
	_info = info
	_copied = false
	visible = true
	var killer: String = info.get("attacker_name", "?")
	var self_kill: bool = info.get("attacker") is Player
	_title.set_text("你被 %s 擊殺" % killer if not self_kill else "你把自己炸飛了")
	var tags: Array = []
	if info.get("zone", "") == "head":
		tags.append("爆頭")
	if info.get("through_wall", false):
		tags.append("穿牆")
	tags.append_array(info.get("moves", []))
	_sub.text = "距離 %.1f m　%s" % [float(info.get("distance", 0.0)), "　".join(tags)]
	var build: Dictionary = info.get("build", {})
	_gun_name.set_text(info.get("gun_name", "?"))
	if _vp != null:
		_vp.queue_free()
		_vp = null
	if not build.is_empty():
		_vp = GunThumb.live(build, Vector2i(900, 480))
		add_child(_vp)
		_view.texture = _vp.get_texture()
		_parts.text = _parts_text(build)
		_parts.add_theme_font_size_override("font_size", 16 if _parts.text.count("\n") < 9 else 14)
		_stats.text = _stats_text(Arsenal.stats(build))
		_copy.disabled = false
	else:
		_view.texture = null
		_parts.text = "—"
		_stats.text = "—"
		_copy.disabled = true
	_exchange.text = "你對他　%d 傷害\n他對你　%d 傷害" % [roundi(dealt), roundi(taken)]
	_copy.text = "抄下這把槍  [F]"


func hide_death() -> void:
	visible = false
	if _vp != null:
		_vp.queue_free()
		_vp = null


static func _parts_text(build: Dictionary) -> String:
	var lines := ["槍身：" + Arsenal.name_of(build.frame)]
	for slot in Arsenal.SLOTS:
		var id: String = build.parts.get(slot, "")
		if id != "":
			lines.append("%s：%s" % [Arsenal.slot_name(slot), Arsenal.name_of(id)])
	return "\n".join(lines)


static func _stats_text(s: Dictionary) -> String:
	return "傷害 %d × %d　射速 %.1f/s\n彈匣 %d　射程 %d m\n重量 %.1f kg　機動性 %d%%\n口徑 %s" % [
		roundi(Weapon.pvp_damage(s)), int(s.pellets), float(s.rate), int(s.mag), roundi(float(s.range)),
		float(s.weight), roundi(Player.mobility_of(s) * 100), s.caliber]


func _on_copy() -> void:
	var build: Dictionary = _info.get("build", {})
	if build.is_empty() or _copied:
		return
	_copied = true
	_copy.text = "已抄下：重生時裝備"
	copy_requested.emit(build, str(_info.get("gun_name", "")))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("copy_gun"):
		_on_copy()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") or event.is_action_pressed("respawn"):
		respawn_requested.emit()
		get_viewport().set_input_as_handled()
	if _vp != null and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var turner := _vp.get_child(2)
		if turner is GunThumb.Turner:
			turner.drag += event.relative.x * 0.002
