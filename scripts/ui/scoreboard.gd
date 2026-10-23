class_name Scoreboard
extends Control
## The team-match scoreboard (hold Tab; also on the results screen): both teams, each
## player's points, kills, deaths and ping, the best player first. Your row is lit.

var team_match: TeamMatch
var _box: VBoxContainer
var _title: Label


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	var card := FrontEnd.card()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -470
	card.offset_right = 470
	# Hangs from a fixed top edge and grows down with the rows, so no empty tail.
	card.offset_top = -280
	card.offset_bottom = -280
	card.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(card)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	card.add_child(_box)


func _process(_delta: float) -> void:
	if visible:
		refresh()


func refresh() -> void:
	if team_match == null or _box == null:
		return
	for c in _box.get_children():
		c.queue_free()
	var tm := team_match
	var head := HBoxContainer.new()
	_box.add_child(head)
	var map_name: String = NetSession.MAPS.get(Main.map_id, Main.map_id)
	var rounds := tm.rules != null
	var t := FpUi.label("%s　%s" % [NetSession.MODES.get(str(NetSession.config.get("mode", "patch")), "改版死鬥"), map_name], 24, Counterform.DUST_WHITE, FpUi.display())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(FpUi.label(tm.score_text(), 20, Counterform.DUST_WHITE, FpUi.numerals()))
	for team in [tm.player.team, 1 - tm.player.team]:
		var color := FpUi.ally_color() if team == tm.player.team else FpUi.enemy_color()
		var th := HBoxContainer.new()
		_box.add_child(th)
		var name_l := FpUi.label("%s　%d" % [NetSession.TEAM_NAMES[team], tm.scores[team]], 22, color, FpUi.display())
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.add_child(name_l)
		for col in ["資金" if rounds else "分數", "擊殺", "助攻", "陣亡", "延遲"]:
			var l := FpUi.label(col, 13, Color(Counterform.DUST_WHITE, 0.5), FpUi.bold())
			l.custom_minimum_size = Vector2(80, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			th.add_child(l)
		var rows := []
		for id in tm.entities:
			var e = tm.entities[id]
			if e == null or not is_instance_valid(e) or int(e.team) != team:
				continue
			var s: Dictionary = tm.stats.get(id, {})
			var first: Variant = int(s.get("points", 0))
			if rounds:
				# Money: your own team's only (the other team's buys are theirs to know).
				first = "$%d" % int(tm.rules.money.get(id, 0)) if team == tm.player.team else "—"
			rows.append([id, str(e.display_name), first, int(s.get("kills", 0)), int(s.get("assists", 0)), int(s.get("deaths", 0))])
		if rounds:
			rows.sort_custom(func(a: Array, b: Array) -> bool: return a[3] > b[3] or (a[3] == b[3] and a[5] < b[5]))
		else:
			rows.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2] or (a[2] == b[2] and a[3] > b[3]))
		for r in rows:
			_box.add_child(_row(r, r[0] == tm.my_id, color))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		_box.add_child(gap)


func _row(r: Array, you: bool, color: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.22) if you else Color(1, 1, 1, 0.04)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	p.add_child(h)
	var bot := str(r[0]).begins_with("b")
	var n := FpUi.label(str(r[1]) + ("　機器人" if bot else ""), 18, Counterform.DUST_WHITE, FpUi.bold())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var ping := "—" if bot else _ping(str(r[0]))
	for v in [str(r[2]), str(r[3]), str(r[4]), str(r[5]), ping]:
		var l := FpUi.label(v, 18, Counterform.DUST_WHITE, FpUi.numerals())
		l.custom_minimum_size = Vector2(80, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return p


## Round trip to that player, where this machine can know it (the host knows everyone's;
## a client knows its own and the host's).
func _ping(id: String) -> String:
	var mp := team_match.multiplayer.multiplayer_peer
	var peer := int(id.substr(1))
	# The host pings everyone and shares the table (TeamMatch.pings).
	if team_match.pings.has(peer):
		return str(int(team_match.pings[peer]))
	if mp is RelayPeer:
		# Through the relay this machine only knows its own round trip (to the relay).
		var rtt := (mp as RelayPeer).rtt_ms
		return str(rtt) if peer == team_match.multiplayer.get_unique_id() and rtt >= 0 else "—"
	if not (mp is ENetMultiplayerPeer):
		return "—"
	var me := team_match.multiplayer.get_unique_id()
	var target := 1 if (peer == me and me != 1) else peer
	if me != 1 and target != 1:
		return "—"
	if target == me:
		return "0"
	var pp := (mp as ENetMultiplayerPeer).get_peer(target)
	if pp == null:
		return "—"
	return str(int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)))
