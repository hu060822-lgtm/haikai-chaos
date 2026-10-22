class_name KillFeed
extends VBoxContainer
## Top-right kill feed. Each line: killer, a picture of the gun and its name, tags (爆頭,
## 穿牆, 牆跑, 滑鏟, 空中…), victim. Names are coloured by side AND the line has a
## marker shape (▼ enemy, ● you / ally), so colour is never the only cue.

const LIFE := 6.0
const MAX_LINES := 6


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 4)
	mouse_filter = MOUSE_FILTER_IGNORE


## killer_side / victim_side: 0 = you or ally, 1 = enemy.
func add_kill(killer: String, killer_side: int, gun_name: String, build: Dictionary, tags: Array,
		victim: String, victim_side: int, involves_you := false) -> void:
	var row := PanelContainer.new()
	var bg := Color(Faultprint.ui_paper, 0.9) if not involves_you else Color(Faultprint.YELLOW, 0.92)
	# On your own (yellow) line the text stays dark ink in every look.
	var ink := Faultprint.CARBON if involves_you else Faultprint.ui_ink
	row.add_theme_stylebox_override("panel", FpUi.panel(bg, ink, 8, 2))
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	h.add_child(_name(killer, killer_side, ink))
	if not build.is_empty():
		var pic := TextureRect.new()
		pic.texture = GunThumb.texture(get_tree(), build, Vector2i(150, 54))
		pic.custom_minimum_size = Vector2(110, 40)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(pic)
	var gun := FpUi.label(gun_name, 14, ink, FpUi.bold())
	h.add_child(gun)
	for t in tags:
		var tag := FpUi.label(" %s " % t, 12, Faultprint.ui_paper, FpUi.bold())
		var tag_box := PanelContainer.new()
		var sb := FpUi.panel(Faultprint.ui_accent if t == "爆頭" else Faultprint.ui_ink, Color.TRANSPARENT, 4)
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		tag_box.add_theme_stylebox_override("panel", sb)
		tag_box.add_child(tag)
		tag_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tag_box)
	h.add_child(FpUi.label("→", 16, ink, FpUi.bold()))
	h.add_child(_name(victim, victim_side, ink))
	add_child(row)
	move_child(row, 0)
	while get_child_count() > MAX_LINES:
		var last := get_child(get_child_count() - 1)
		remove_child(last)
		last.queue_free()
	var t := row.create_tween()
	t.tween_interval(LIFE)
	t.tween_property(row, "modulate:a", 0.0, 0.4)
	t.tween_callback(row.queue_free)


func _name(text: String, side: int, ink: Color) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var color := FpUi.enemy_color() if side == 1 else FpUi.ally_color()
	var shape := FpUi.label("▼" if side == 1 else "●", 13, color, FpUi.bold())
	shape.add_theme_color_override("font_outline_color", Faultprint.CARBON)
	shape.add_theme_constant_override("outline_size", 4)
	box.add_child(shape)
	var l := FpUi.label(text, 17, ink, FpUi.display(0.7))
	box.add_child(l)
	return box
