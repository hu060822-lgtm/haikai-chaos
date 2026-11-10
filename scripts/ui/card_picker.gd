class_name CardPicker
extends Control
## 超規卡 (C11): the pick at the start of a round. Three (or four) cards side by side:
## click one, or press 1–4. A reroll button deals a fresh hand (a few per match). The
## clock is the build's: run out and the host deals one at random (CardRules).

signal picked(card: String)
signal reroll()

const CARD_W := 250.0
const CARD_H := 340.0

var _row: HBoxContainer
var _head: Label
var _clock: Label
var _reroll_btn: Button
var _held: Label
var _hand: Array = []


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Counterform.GRAPHITE_DEEP, 0.62)
	shade.set_anchors_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_preset(PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(col)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 24)
	col.add_child(top)
	_head = FpUi.label("選一張超規卡", 34, Counterform.DUST_WHITE, FpUi.display())
	top.add_child(_head)
	_clock = FpUi.label("", 26, Counterform.SULFUR, FpUi.numerals())
	top.add_child(_clock)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 18)
	col.add_child(_row)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 18)
	col.add_child(foot)
	_reroll_btn = FrontEnd.action("重抽", false, 18)
	_reroll_btn.pressed.connect(func() -> void:
		_reroll_btn.disabled = true
		reroll.emit())
	foot.add_child(_reroll_btn)
	foot.add_child(FpUi.label("點一張卡，或按 1～%d" % Augments.OFFER_BEHIND, 16, Color(Counterform.DUST_WHITE, 0.7), FpUi.body()))
	_held = FpUi.label("", 15, Color(Counterform.DUST_WHITE, 0.75), FpUi.body())
	_held.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_held.custom_minimum_size = Vector2(900, 0)
	col.add_child(_held)


func show_offer(hand: Array, rerolls_left: int, held: Array, seconds: float) -> void:
	_hand = hand.duplicate()
	for c in _row.get_children():
		c.queue_free()
	for i in _hand.size():
		_row.add_child(_card_button(str(_hand[i]), i, held))
	_reroll_btn.text = "重抽（剩 %d 次）" % rerolls_left
	_reroll_btn.disabled = rerolls_left <= 0
	var counts := Augments.counts(held)
	var bits := []
	for k in ["gun", "move", "trade"]:
		bits.append("%s %d/%d" % [Augments.kind_name(k), int(counts[k]), Augments.RESONANCE_AT])
	_held.text = ("手上 %d 張　" % held.size()) + "　".join(bits) + "　（同類 3 張觸發共鳴）"
	set_time(seconds)
	visible = true


func set_time(seconds: float) -> void:
	if _clock != null:
		_clock.text = "%d" % ceili(maxf(seconds, 0.0))


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_4:
		var i := k - KEY_1
		if i < _hand.size():
			get_viewport().set_input_as_handled()
			_choose(str(_hand[i]))


func _choose(id: String) -> void:
	if not visible:
		return
	Sfx.ui(get_tree(), "tick")
	picked.emit(id)


func _card_button(id: String, index: int, held: Array) -> Control:
	var c := Augments.card(id)
	var kind := str(c.get("kind", ""))
	var tint := Augments.color(kind)
	var b := Button.new()
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Counterform.GRAPHITE_DEEP, 0.95) if state == "normal" else Color(Counterform.GRAPHITE, 0.98)
		sb.border_color = tint if state != "normal" else Color(tint, 0.55)
		sb.set_border_width_all(2 if state == "normal" else 4)
		sb.border_width_top = 10
		sb.corner_detail = 1
		sb.corner_radius_top_left = 14
		sb.corner_radius_bottom_right = 14
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _choose(id))
	b.mouse_entered.connect(func() -> void: Sfx.ui(b.get_tree(), "tick", -18.0))
	var v := VBoxContainer.new()
	v.set_anchors_preset(PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 22
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(top)
	var kind_l := FpUi.label(Augments.kind_name(kind), 15, tint, FpUi.bold())
	kind_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(kind_l)
	top.add_child(FpUi.label(str(index + 1), 18, Color(Counterform.DUST_WHITE, 0.5), FpUi.numerals()))
	v.add_child(_mouse_off(_glyph(kind, tint)))
	var name_l := FpUi.label(str(c.get("name", id)), 30, Counterform.DUST_WHITE, FpUi.display())
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_mouse_off(name_l))
	var desc := FpUi.label(str(c.get("desc", "")), 16, Color(Counterform.DUST_WHITE, 0.9), FpUi.body())
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_mouse_off(desc))
	if c.has("cost"):
		var cost := FpUi.label("代價：" + str(c.cost), 15, Color("#E07A5F"), FpUi.bold())
		cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_mouse_off(cost))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	var have := int(Augments.counts(held).get(kind, 0))
	var note := "→ 共鳴：%s" % Augments.RESONANCE[kind].name if have + 1 == Augments.RESONANCE_AT else \
		("同類第 %d 張" % (have + 1))
	var n := FpUi.label(note, 14, tint if have + 1 == Augments.RESONANCE_AT else Color(Counterform.DUST_WHITE, 0.5), FpUi.bold())
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_mouse_off(n))
	return b


static func _mouse_off(c: Control) -> Control:
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


## A simple emblem per kind: a round for guns, a chevron for moves, a scale for trades.
static func _glyph(kind: String, tint: Color) -> Control:
	var g := CardGlyph.new()
	g.kind = kind
	g.tint = tint
	g.custom_minimum_size = Vector2(0, 70)
	return g


class CardGlyph:
	extends Control
	var kind := "gun"
	var tint := Color.WHITE

	func _draw() -> void:
		var c := size / 2.0
		match kind:
			"gun":
				draw_arc(c, 28, 0, TAU, 32, tint, 3.0)
				draw_line(c + Vector2(-38, 0), c + Vector2(38, 0), tint, 2.0)
				draw_line(c + Vector2(0, -38), c + Vector2(0, 38), tint, 2.0)
				draw_circle(c, 5, tint)
			"move":
				for i in 3:
					var x := -30.0 + i * 22.0
					draw_polyline(PackedVector2Array([c + Vector2(x, -22), c + Vector2(x + 18, 0), c + Vector2(x, 22)]), Color(tint, 0.45 + i * 0.27), 4.0)
			_:
				draw_line(c + Vector2(0, -30), c + Vector2(0, 26), tint, 3.0)
				draw_line(c + Vector2(-34, -18), c + Vector2(34, -26), tint, 3.0)
				draw_arc(c + Vector2(-34, -6), 12, 0, PI, 12, tint, 3.0)
				draw_arc(c + Vector2(34, -14), 12, 0, PI, 12, tint, 3.0)
				draw_line(c + Vector2(-20, 26), c + Vector2(20, 26), tint, 3.0)
