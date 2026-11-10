class_name CardStrip
extends VBoxContainer
## 超規卡 (C11): the cards you hold, stacked up the left edge above the health bar, each
## a coloured tab with its name; a lit resonance gets its own line on top.


func _init() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 36
	offset_right = 300
	offset_top = -470
	offset_bottom = -160
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 3)
	mouse_filter = MOUSE_FILTER_IGNORE


func show_cards(cards: Array) -> void:
	for c in get_children():
		c.queue_free()
	for k in Augments.resonances(cards):
		add_child(_tab("共鳴：" + str(Augments.RESONANCE[k].name), Augments.color(k), true))
	for id in cards:
		var c := Augments.card(str(id))
		add_child(_tab(str(c.get("name", id)), Augments.color(str(c.get("kind", ""))), false))


static func _tab(text: String, tint: Color, lit: bool) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint, 0.9) if lit else Color(Counterform.GRAPHITE_DEEP, 0.72)
	sb.border_color = tint
	sb.border_width_left = 5
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.corner_detail = 1
	sb.corner_radius_bottom_right = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := FpUi.label(text, 14, Counterform.GRAPHITE_DEEP if lit else Counterform.DUST_WHITE, FpUi.bold())
	p.add_child(l)
	return p
