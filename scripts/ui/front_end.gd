class_name FrontEnd
extends Control
## The front end: title / main menu, the practice map picker, custom rooms (create, join
## by code, rooms found on the LAN), and quick match (search, join, or open a room and
## wait). The map behind it is live; MenuCamera drifts around it. The lobby itself is
## Lobby (its own screen); this hands over to it once you're in a room.

signal practice_chosen(map_id: String)
signal settings_requested()

const VERSION := "C8 原型"
const PRACTICE := [
	["folded", "折疊工廠", "FOLDED WORKS　混凝土模組測試設施：三層大廳當中路，外圍長廊通往 A／B 點"],
	["dream", "夢核之家", "DREAM HOME　記憶裡太大的房子：粉彩房間、沒有水的泳池、走不完的走廊"],
	["yard", "斷層貨場", "FAULT YARD　貨櫃場與兩座倉庫：開闊中路、長廊、隧道、工頭辦公室"],
	["testament", "最後的遺訓", "THE LAST TESTAMENT　被軍方接管的大教堂：中殿、唱詩班迴廊、告解室、祭壇、地下墓室（灰盒）"],
	["lab", "移動測試場", "MOVEMENT LAB　三條計時路線與自由練習區：滑鏟、牆跑、踢牆、重踩彈跳"],
]

var main: Main
var net: NetSession
var lobby: Lobby

var _pages := {}
var _page := ""
var _name_edit: LineEdit
var _code_edit: LineEdit
var _rooms_box: VBoxContainer
var _custom_status: Label
var _mm_title: Label
var _mm_status: Label
var _mm_ring: SearchRing
var _mm_t := 0.0
var _mm_state := ""      # "", "search", "joining", "hosting"
var _relay_state := ""   # quick match: "", "asking", "ok", "down"
var _list_t := 0.0


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	theme = FpUi.theme()


func _ready() -> void:
	var shade := Shade.new()
	shade.set_anchors_preset(PRESET_FULL_RECT)
	add_child(shade)
	_pages.home = _home()
	_pages.practice = _practice()
	_pages.custom = _custom()
	_pages.search = _matchmaking()
	for p in _pages.values():
		add_child(p)
	add_child(_top_bar())
	show_page("home")
	net.matchmaker.rooms_changed.connect(_fill_rooms)
	net.matchmaker.relay_listed.connect(func(ok: bool) -> void:
		if _relay_state == "asking":
			_relay_state = "ok" if ok else "down")
	net.roster_changed.connect(_on_roster)
	net.status_changed.connect(func(t: String) -> void:
		if _custom_status:
			_custom_status.text = t
		if _mm_state != "" and _mm_status:
			_mm_status.text = t)


func show_page(id: String) -> void:
	_page = id
	for k in _pages:
		_pages[k].visible = k == id
	if id == "custom":
		net.matchmaker.listen()
		net.matchmaker.list_relay()
		_list_t = 4.0
		_fill_rooms()
	elif id != "search":
		net.matchmaker.stop_listening()
	visible = true


# --- Pieces ------------------------------------------------------------------------------

static func heading(text: String, size := 54) -> Label:
	var l := FpUi.label(text, size, Counterform.DUST_WHITE, FpUi.display())
	return Hud._shadowed(l, 2)


## A big menu entry: title and a one-line subtitle, left aligned; hover slides it right and
## lights the accent bar.
static func menu_entry(title: String, sub: String, size := 30) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(460, 64 if sub != "" else 50)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.0 if state == "normal" else (0.08 if state == "hover" else 0.14))
		sb.border_width_left = 0 if state == "normal" else 4
		sb.border_color = Counterform.OXIDE_ORANGE.lightened(0.15)
		sb.content_margin_left = 16 if state == "normal" else 26
		sb.content_margin_top = 4
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", -2)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 18
	col.offset_top = 6
	b.add_child(col)
	var t := FpUi.label(title, size, Counterform.DUST_WHITE, FpUi.display())
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	if sub != "":
		var s := FpUi.label(sub, 14, Color(Counterform.DUST_WHITE, 0.55), FpUi.body())
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(s)
	b.mouse_entered.connect(func() -> void:
		col.create_tween().tween_property(col, "offset_left", 30.0, 0.1)
		Sfx.ui(b.get_tree(), "tick", -16.0))
	b.mouse_exited.connect(func() -> void: col.create_tween().tween_property(col, "offset_left", 18.0, 0.12))
	return b


## A flat, clean action button (solid accent or ghost outline).
static func action(text: String, solid := true, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FpUi.bold())
	b.add_theme_font_size_override("font_size", size)
	var base := Counterform.OXIDE_ORANGE.lightened(0.1)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		var bg := base if solid else Color(1, 1, 1, 0.04)
		if state == "hover":
			bg = bg.lightened(0.15) if solid else Color(1, 1, 1, 0.12)
		elif state == "pressed":
			bg = bg.darkened(0.2) if solid else Color(1, 1, 1, 0.2)
		elif state == "disabled":
			bg = Color(1, 1, 1, 0.05)
		sb.bg_color = bg
		sb.border_color = Color(Counterform.DUST_WHITE, 0.25)
		sb.set_border_width_all(0 if solid else 1)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		sb.corner_detail = 1
		sb.corner_radius_bottom_right = 8
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Counterform.DUST_WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(Counterform.DUST_WHITE, 0.35))
	return b


static func card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Counterform.GRAPHITE_DEEP, 0.78)
	sb.border_color = Color(Counterform.DUST_WHITE, 0.1)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(20)
	sb.corner_detail = 1
	sb.corner_radius_top_left = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.offset_left = -560
	bar.offset_right = -40
	bar.offset_top = 30
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 10)
	var who := FpUi.label("呼號", 14, Color(Counterform.DUST_WHITE, 0.6), FpUi.bold())
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(who)
	_name_edit = LineEdit.new()
	_name_edit.text = NetSession.my_name
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(200, 38)
	_name_edit.add_theme_font_size_override("font_size", 18)
	_name_edit.text_changed.connect(func(t: String) -> void:
		NetSession.my_name = t.strip_edges() if t.strip_edges() != "" else "玩家")
	bar.add_child(_name_edit)
	return bar


func _page_root() -> Control:
	var c := Control.new()
	c.set_anchors_preset(PRESET_FULL_RECT)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


# --- Home ------------------------------------------------------------------------------

func _home() -> Control:
	var page := _page_root()
	var col := VBoxContainer.new()
	col.position = Vector2(84, 90)
	col.add_theme_constant_override("separation", 0)
	page.add_child(col)
	var logo := heading("HAIKAI: CHAOS", 96)
	col.add_child(logo)
	var tag := Hud._shadowed(FpUi.label("改槍沒有上限的高速競技射擊", 22, Counterform.SULFUR, FpUi.bold()), 1)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 54)
	col.add_child(gap)
	var entries := [
		["開始配對", "找區網裡開著的房間，沒有就開一間等人（空位補機器人）", _quick_match],
		["自訂房間", "開房分享房間碼、輸入房間碼加入、看看區網裡的房間", func() -> void: show_page("custom")],
		["練習場", "四張對戰地圖和移動測試場：陪練機器人與靶場", func() -> void: show_page("practice")],
		["設定", "靈敏度、FOV、音量、畫面、按鍵", func() -> void: settings_requested.emit()],
		["離開遊戲", "", func() -> void: get_tree().quit()],
	]
	for e in entries:
		var b := menu_entry(e[0], e[1], 30 if e[1] != "" else 24)
		b.pressed.connect(e[2])
		col.add_child(b)
	var ver := FpUi.label("%s　·　%d 種槍身　%d 個零件　·　Godot 4.3" % [VERSION, Arsenal.FRAMES.size(), Arsenal.PARTS.size()],
		13, Color(Counterform.DUST_WHITE, 0.45), FpUi.body())
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 88
	ver.offset_top = -44
	page.add_child(ver)
	return page


# --- Practice --------------------------------------------------------------------------

func _practice() -> Control:
	var page := _page_root()
	var col := VBoxContainer.new()
	col.position = Vector2(84, 90)
	col.add_theme_constant_override("separation", 6)
	page.add_child(col)
	col.add_child(heading("練習場", 64))
	col.add_child(Hud._shadowed(FpUi.label("一個人練槍、練身法。Tab 改槍，F3 讓機器人停火。", 18, Color(Counterform.DUST_WHITE, 0.75), FpUi.body()), 1))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)
	for p in PRACTICE:
		var b := menu_entry(p[1], p[2], 30)
		b.custom_minimum_size.x = 700
		var id: String = p[0]
		b.pressed.connect(func() -> void: practice_chosen.emit(id))
		col.add_child(b)
	var back := menu_entry("← 返回", "", 22)
	back.pressed.connect(func() -> void: show_page("home"))
	col.add_child(back)
	return page


# --- Custom rooms ----------------------------------------------------------------------

func _custom() -> Control:
	var page := _page_root()
	var col := VBoxContainer.new()
	col.position = Vector2(84, 90)
	col.custom_minimum_size = Vector2(1100, 0)
	col.add_theme_constant_override("separation", 14)
	page.add_child(col)
	col.add_child(heading("自訂房間", 64))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	# Create.
	var make := card()
	make.custom_minimum_size = Vector2(340, 250)
	row.add_child(make)
	var mk := VBoxContainer.new()
	mk.add_theme_constant_override("separation", 10)
	make.add_child(mk)
	mk.add_child(FpUi.label("開一間房", 24, Counterform.DUST_WHITE, FpUi.display()))
	var mk_note := FpUi.label(("開好後會給你五個字的房間碼，朋友在任何網路都能用它加入，不用設定路由器。" if Matchmaker.has_relay()
		else "開好後會給你房間碼，傳給朋友就能加入。區網裡的人也會自動看到你的房間。"), 15,
		Color(Counterform.DUST_WHITE, 0.7), FpUi.body())
	mk_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mk_note.custom_minimum_size = Vector2(300, 0)
	mk.add_child(mk_note)
	var host := action("開房")
	host.pressed.connect(func() -> void:
		var err := net.host_relay() if Matchmaker.has_relay() else net.host()
		if err == OK:
			_enter_lobby())
	mk.add_child(host)
	if Matchmaker.has_relay():
		var lan_host := action("只在區網開房", false, 15)
		lan_host.tooltip_text = "不經過中繼伺服器：延遲最低，但只有同一個網路（或虛擬區網）的人能加入"
		lan_host.pressed.connect(func() -> void:
			if net.host() == OK:
				_enter_lobby())
		mk.add_child(lan_host)
	# Join by code.
	var join := card()
	join.custom_minimum_size = Vector2(340, 250)
	row.add_child(join)
	var jn := VBoxContainer.new()
	jn.add_theme_constant_override("separation", 10)
	join.add_child(jn)
	jn.add_child(FpUi.label("用房間碼加入", 24, Counterform.DUST_WHITE, FpUi.display()))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "XXXXX"
	_code_edit.custom_minimum_size = Vector2(300, 52)
	_code_edit.add_theme_font_override("font", FpUi.numerals())
	_code_edit.add_theme_font_size_override("font_size", 32)
	_code_edit.max_length = 14
	jn.add_child(_code_edit)
	var go := action("加入")
	go.pressed.connect(func() -> void:
		var code := _code_edit.text.strip_edges()
		if code.count(".") == 3:
			net.join(code.split(":")[0], int(code.split(":")[1]) if code.contains(":") else NetSession.PORT)
		else:
			net.join_code(code))
	jn.add_child(go)
	var ip_note := FpUi.label("五個字＝中繼房間；十個字＝區網房間；也可以直接輸入 IP", 13, Color(Counterform.DUST_WHITE, 0.5), FpUi.body())
	jn.add_child(ip_note)
	# LAN rooms.
	var lan := card()
	lan.custom_minimum_size = Vector2(400, 250)
	row.add_child(lan)
	var ln := VBoxContainer.new()
	ln.add_theme_constant_override("separation", 8)
	lan.add_child(ln)
	ln.add_child(FpUi.label("開著的房間", 24, Counterform.DUST_WHITE, FpUi.display()))
	_rooms_box = VBoxContainer.new()
	_rooms_box.add_theme_constant_override("separation", 6)
	ln.add_child(_rooms_box)
	_custom_status = FpUi.label("", 16, Counterform.SULFUR, FpUi.bold())
	col.add_child(_custom_status)
	var back := menu_entry("← 返回", "", 22)
	back.pressed.connect(func() -> void:
		if NetSession.active and not net.is_host() and NetSession.roster.is_empty():
			net.leave()
		show_page("home"))
	col.add_child(back)
	return page


func _fill_rooms() -> void:
	if _rooms_box == null:
		return
	for c in _rooms_box.get_children():
		c.queue_free()
	var all: Array = net.matchmaker.rooms.values() + net.matchmaker.relay_rooms.values()
	if all.is_empty():
		_rooms_box.add_child(FpUi.label("找不到……（有人開房就會出現在這裡）", 15, Color(Counterform.DUST_WHITE, 0.5), FpUi.body()))
		return
	var shown := {}
	for r in all:
		# A relay room also beacons on its LAN: list it once.
		var key := str(r.get("code", "")) if r.get("relay", false) else "%s:%s" % [r.get("ip", ""), r.get("port", "")]
		if shown.has(key):
			continue
		shown[key] = true
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var map_name: String = NetSession.MAPS.get(str(r.get("map", "folded")), "?")
		var text := "%s 的房間　%d/%d　%s%s　%s" % [r.get("name", "?"), int(r.get("players", 0)), int(r.get("max", 10)), map_name,
			"　對戰中" if r.get("in_match", false) else "", "網路" if r.get("relay", false) else "區網"]
		var l := FpUi.label(text, 16, Counterform.DUST_WHITE, FpUi.bold())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
		var b := action("加入", false, 15)
		if r.get("relay", false):
			var code := str(r.code)
			b.pressed.connect(func() -> void: net.join_relay(code))
		else:
			var ip: String = r.ip
			var port := int(r.get("port", NetSession.PORT))
			b.pressed.connect(func() -> void: net.join(ip, port))
		line.add_child(b)
		_rooms_box.add_child(line)


# --- Quick match -----------------------------------------------------------------------

func _matchmaking() -> Control:
	var page := _page_root()
	_mm_ring = SearchRing.new()
	_mm_ring.set_anchors_preset(PRESET_FULL_RECT)
	page.add_child(_mm_ring)
	var col := VBoxContainer.new()
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -400
	col.offset_right = 400
	col.offset_top = 150
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 6)
	page.add_child(col)
	_mm_title = heading("搜尋對戰中", 40)
	_mm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_mm_title)
	_mm_status = Hud._shadowed(FpUi.label("", 17, Color(Counterform.DUST_WHITE, 0.8), FpUi.body()), 1)
	_mm_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_mm_status)
	var cancel := action("取消", false)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_cancel_search)
	col.add_child(cancel)
	return page


func _quick_match() -> void:
	show_page("search")
	_mm_state = "search"
	_mm_t = 0.0
	_mm_title.text = "搜尋對戰中"
	_relay_state = ""
	if Matchmaker.has_relay():
		_relay_state = "asking"
		net.matchmaker.list_relay()
	if not net.matchmaker.listen():
		_mm_status.text = "這台電腦上已經有遊戲在找房：直接開一間"
		_mm_t = Matchmaker.SEARCH
	else:
		_mm_status.text = "正在找開著的房間（區網和網路）…" if _relay_state != "" else "正在區網裡找開著的房間…"


func _cancel_search() -> void:
	_mm_state = ""
	net.matchmaker.stop_listening()
	if NetSession.active:
		net.leave()
	show_page("home")


func _process(delta: float) -> void:
	if _page == "custom" and visible:
		_list_t -= delta
		if _list_t <= 0.0:
			_list_t = 4.0
			net.matchmaker.list_relay()
	if _mm_state == "" or not visible:
		return
	_mm_t += delta
	_mm_ring.t = _mm_t
	if _mm_state == "search":
		_mm_title.text = "搜尋對戰中　%d:%02d" % [int(_mm_t) / 60, int(_mm_t) % 60]
		if _mm_t >= Matchmaker.SEARCH and _relay_state != "asking":
			var best := net.matchmaker.best_room()
			net.matchmaker.stop_listening()
			if not best.is_empty():
				_mm_state = "joining"
				_mm_title.text = "找到了：%s 的房間" % best.get("name", "?")
				if best.get("relay", false):
					net.join_relay(str(best.code))
				else:
					net.join(str(best.ip), int(best.get("port", NetSession.PORT)))
			else:
				_mm_state = "hosting"
				# Host where others can find us: on the relay when it answered, else the LAN.
				var err := net.host_relay() if _relay_state == "ok" else net.host()
				if err == OK:
					_enter_lobby()
					lobby.flash("沒有找到開著的房間：已經幫你開了一間。之後按「開始配對」的人會自動加入；也可以直接補機器人開打")
				else:
					_mm_state = ""
					_mm_status.text = "開房失敗：%s" % NetSession.last_status
	elif _mm_state == "joining" and _mm_t > Matchmaker.SEARCH + 8.0 and NetSession.roster.is_empty():
		_mm_state = ""
		net.leave()
		_mm_status.text = "連不上那間房：再試一次，或用自訂房間"


func _on_roster() -> void:
	# A join succeeded (we have the room's roster): into the lobby.
	if NetSession.active and not NetSession.roster.is_empty() and not net.is_host() and visible and _page != "":
		_enter_lobby()


func _enter_lobby() -> void:
	_mm_state = ""
	net.matchmaker.stop_listening()
	visible = false
	lobby.open()


## The front end's backdrop: dark on the left where the menu is, clear on the right.
class Shade:
	extends Control

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Edge-to-edge quads with per-vertex colour: overlapping rects band where they double up.
		var steps := 24
		for i in steps:
			var k0 := float(i) / steps
			var k1 := float(i + 1) / steps
			var c0 := Color(Counterform.GRAPHITE_DEEP, 0.82 * pow(1.0 - k0, 1.4))
			var c1 := Color(Counterform.GRAPHITE_DEEP, 0.82 * pow(1.0 - k1, 1.4))
			var x0 := size.x * 0.75 * k0
			var x1 := size.x * 0.75 * k1
			draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, size.y), Vector2(x0, size.y)]),
				PackedColorArray([c0, c1, c1, c0]))
		draw_rect(Rect2(Vector2(0, size.y - 6), Vector2(size.x, 6)), Color(Counterform.OXIDE_ORANGE, 0.85))


## Quick match: rings that pulse out from the middle while searching.
class SearchRing:
	extends Control
	var t := 0.0

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Counterform.GRAPHITE_DEEP, 0.55))
		var c := size / 2.0 + Vector2(0, -40)
		for i in 4:
			var k := fmod(t * 0.6 + i * 0.25, 1.0)
			draw_arc(c, 40.0 + k * 220.0, 0, TAU, 96, Color(Counterform.DUST_WHITE, 0.5 * (1.0 - k)), 2.0)
		var a := t * 2.4
		draw_arc(c, 60.0, a, a + 1.4, 32, Counterform.OXIDE_ORANGE.lightened(0.2), 5.0)
		draw_arc(c, 60.0, a + PI, a + PI + 1.4, 32, Counterform.SULFUR, 5.0)
		draw_circle(c, 6.0, Counterform.DUST_WHITE)
