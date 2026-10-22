class_name FpUi
## FAULTPRINT UI kit: chamfered panels, a bold display font, text printed with its colour
## plates slightly off register, small industrial labels. Matches the world's palette;
## game information (enemy / ally) uses Faultprint.INFO_* and always has a second cue.

static var _fonts := {}
## Enemy / ally colours can be swapped (F2) for colour-blind players.
const INFO_SETS := [
	["標準", Color("#FF2E63"), Color("#3FA7FF")],
	["紅綠色盲", Color("#FF8A00"), Color("#2F7BFF")],
	["高對比", Color("#FFE600"), Color("#FFFFFF")],
]
static var info_set := 0


static func enemy_color() -> Color:
	return INFO_SETS[info_set][1]


static func ally_color() -> Color:
	return INFO_SETS[info_set][2]


## The default font, heavier and slanted a touch, for headings and numbers.
static func display(size := 1.0) -> Font:
	var key := "d%s" % size
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.variation_embolden = 0.9 * size
		f.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.12, 1.0), Vector2.ZERO)
		f.spacing_glyph = 1
		_fonts[key] = f
	return _fonts[key]


static func bold() -> Font:
	if not _fonts.has("b"):
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.variation_embolden = 0.5
		_fonts["b"] = f
	return _fonts["b"]


## A panel with cut corners (corner_detail 1 turns rounded corners into bevels).
static func panel(bg: Color, border := Color.TRANSPARENT, cut := 10, border_w := 0) -> StyleBoxFlat:
	if Faultprint.ui_line.a > 0.0 and border_w > 0 and border == Faultprint.ui_ink:
		# Counterform: a hairline instead of an ink border, smaller cut corners.
		border = Faultprint.ui_line
		border_w = 1
		cut = mini(cut, 6)
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_detail = 1
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_left = 0
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = false
	return s


static func label(text: String, size := 16, color := Faultprint.ui_ink, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func button(text: String, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", bold())
	b.add_theme_color_override("font_color", Faultprint.ui_ink)
	b.add_theme_color_override("font_hover_color", Faultprint.CARBON)
	b.add_theme_color_override("font_pressed_color", Faultprint.ui_paper)
	b.add_theme_color_override("font_disabled_color", Faultprint.SLATE)
	b.add_theme_stylebox_override("normal", panel(Faultprint.ui_paper, Faultprint.ui_ink, 8, 2))
	b.add_theme_stylebox_override("hover", panel(Faultprint.YELLOW, Faultprint.ui_ink, 8, 2))
	b.add_theme_stylebox_override("pressed", panel(Faultprint.ui_ink, Faultprint.ui_ink, 8, 2))
	b.add_theme_stylebox_override("disabled", panel(Faultprint.ui_dust, Faultprint.SLATE, 8, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	return b


## The theme for screens with lots of controls (bench, menus).
static func theme() -> Theme:
	if _fonts.has("theme"):
		return _fonts["theme"]
	var t := Theme.new()
	t.default_font = bold()
	t.default_font_size = 16
	t.set_color("font_color", "Label", Faultprint.ui_ink)
	t.set_stylebox("panel", "PanelContainer", panel(Faultprint.ui_paper, Faultprint.ui_ink, 12, 2))
	var field := Faultprint.ui_dust if Faultprint.ui_line.a > 0.0 else Color.WHITE
	t.set_stylebox("normal", "LineEdit", panel(field, Faultprint.ui_ink, 6, 2))
	t.set_stylebox("focus", "LineEdit", panel(field, Faultprint.ui_accent, 6, 2))
	t.set_color("font_color", "LineEdit", Faultprint.ui_ink)
	t.set_color("caret_color", "LineEdit", Faultprint.ui_accent)
	var grabber := panel(Faultprint.SLATE, Color.TRANSPARENT, 2)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", panel(Faultprint.ui_accent, Color.TRANSPARENT, 2))
	t.set_stylebox("scroll", "VScrollBar", panel(Color(Faultprint.ui_dust, 0.25), Color.TRANSPARENT, 2))
	_fonts["theme"] = t
	return t


## Text printed in three plates: two colour plates a couple of pixels off, carbon on top.
class PrintText:
	extends Control
	var text := ""
	var size_px := 32
	var main := Faultprint.ui_ink
	var plate_a := Faultprint.TEAL
	var plate_b := Faultprint.ui_accent
	var offset := 2.0
	var align := HORIZONTAL_ALIGNMENT_LEFT
	var font: Font

	func _init(t := "", s := 32, c := Faultprint.ui_ink) -> void:
		if Faultprint.ui_line.a > 0.0:
			# Counterform: clean type, no off-register plates.
			plate_a = Color.TRANSPARENT
			plate_b = Color.TRANSPARENT
			offset = 0.0
		text = t
		size_px = s
		main = c
		mouse_filter = MOUSE_FILTER_IGNORE
		font = FpUi.display()

	func set_text(t: String) -> void:
		if t != text:
			text = t
			update_minimum_size()
			queue_redraw()

	func _get_minimum_size() -> Vector2:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px) + Vector2(offset * 2, 0)

	func _draw() -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var x := 0.0
		if align == HORIZONTAL_ALIGNMENT_RIGHT:
			x = size.x - w - offset
		elif align == HORIZONTAL_ALIGNMENT_CENTER:
			x = (size.x - w) / 2.0
		var base := Vector2(x, font.get_ascent(size_px) + (size.y - font.get_height(size_px)) / 2.0)
		if plate_a.a > 0.0 and Faultprint.ui_line.a == 0.0:
			draw_string(font, base + Vector2(offset, offset * 0.6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, plate_a)
		if plate_b.a > 0.0 and Faultprint.ui_line.a == 0.0:
			draw_string(font, base + Vector2(-offset * 0.7, offset), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, plate_b)
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, main)


## A printed bar: bone track, carbon fill, tick marks every tenth.
class PrintBar:
	extends Control
	var value := 1.0
	var fill := Faultprint.ui_ink
	var track := Color(Faultprint.ui_paper, 0.85)
	var ticks := 10

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		v = clampf(v, 0.0, 1.0)
		if absf(v - value) > 0.001:
			value = v
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, track)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), fill)
		for i in range(1, ticks):
			var x := size.x * i / ticks
			draw_line(Vector2(x, size.y * 0.55), Vector2(x, size.y), Faultprint.SLATE, 1.0)
		if Faultprint.ui_line.a > 0.0:
			draw_rect(r, Faultprint.ui_line, false, 1.0)
		else:
			draw_rect(r, Faultprint.ui_ink, false, 2.0)
