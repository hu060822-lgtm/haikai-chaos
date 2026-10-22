class_name Main
extends Node3D
## The prototype: FOLDED WORKS with you, three sparring bots and a firing range, or the
## MOVEMENT LAB with its timed routes, or (phase C2) a networked team match, 改版死鬥, on
## FOLDED WORKS ("tdm", run by TeamMatch). Tab opens the bench, dying shows who got you
## with what, F4 opens the movement debug panel.

const BOTS := 3
const BOT_RESPAWN := 4.0

## Which map the next load builds ("folded", "lab" or "tdm"), whether to skip the title,
## and whether to open the netplay lobby on it (coming back from a match).
static var map_id := "folded"
## True when the next load is a networked team match (on map_id).
static var team_mode := false
static var skip_title := false
static var open_lobby := false
static var title_message := ""

var map: Node3D
var lab: MovementLab
var move_debug: MoveDebug
var settings_menu: SettingsMenu
var player: Player
var hud: Hud
var bench: Bench
var death: DeathScreen
var net: NetSession
var team_match: TeamMatch
var lobby: Lobby
var results: Control
var front_end: FrontEnd
var scoreboard: Scoreboard
var _menu_cam: Camera3D
var _menu_t := 0.0
var _tab_down := -1.0
var bots: Array[Bot] = []
var _ui: CanvasLayer
var _title: Control
var _pending_build := {}
var _pending_name := ""
var _bots_passive := false
var _seed := 1


func _ready() -> void:
	Settings.load_all()
	InputSetup.register()
	FpUi.install()
	Music.setup_buses()
	net = NetSession.new()
	add_child(net)
	var tdm := team_mode and NetSession.active
	team_mode = tdm
	if map_id == "lab":
		lab = MovementLab.new()
		map = lab
	elif map_id == "dream":
		map = DreamHome.new()
	else:
		map = FoldedWorks.new()
	add_child(map)
	SafeZone.clear()
	SafeZone.repel = false
	if not lab and not tdm:
		SafeZone.add(map.player_spawn.origin, 6.0, 0)
		SafeZone.draw(map, 0)
	for xf in ([] if tdm else map.range_targets):
		var t := RangeTarget.new()
		add_child(t)
		t.global_transform = xf
	player = Player.new()
	add_child(player)
	var start := Blueprints.load_all()
	if not start.is_empty():
		player.equip(start[0].build, start[0].name)
	player.spawn_at(map.player_spawn)
	player.died.connect(_on_player_died)
	player.hit_confirmed.connect(_on_hit_confirmed)
	player.damaged.connect(_on_player_damaged)
	for i in (BOTS if not map.bot_spawns.is_empty() and not tdm else 0):
		var bot := Bot.new()
		bot.target = player
		bot.waypoints = map.waypoints
		add_child(bot)
		bot.spawn(map.bot_spawns[i % map.bot_spawns.size()], _next_seed())
		bot.died.connect(_on_bot_died)
		bots.append(bot)
	_ui = CanvasLayer.new()
	add_child(_ui)
	hud = Hud.new()
	hud.player = player
	_ui.add_child(hud)
	move_debug = MoveDebug.new()
	move_debug.player = player
	_ui.add_child(move_debug)
	bench = Bench.new()
	bench.closed.connect(_on_bench_closed)
	_ui.add_child(bench)
	death = DeathScreen.new()
	death.respawn_requested.connect(_respawn)
	death.copy_requested.connect(func(b: Dictionary, n: String) -> void:
		Blueprints.add(b, n)
		_pending_build = b
		_pending_name = n)
	_ui.add_child(death)
	settings_menu = SettingsMenu.new()
	settings_menu.closed.connect(_on_settings_closed)
	scoreboard = Scoreboard.new()
	_ui.add_child(scoreboard)
	lobby = Lobby.new()
	lobby.net = net
	lobby.closed.connect(func() -> void:
		front_end.show_page("home")
		Music.play(get_tree(), "lobby"))
	_ui.add_child(lobby)
	front_end = FrontEnd.new()
	front_end.main = self
	front_end.net = net
	front_end.lobby = lobby
	front_end.practice_chosen.connect(_choose_map)
	front_end.settings_requested.connect(func() -> void: settings_menu.open())
	_title = front_end
	_ui.add_child(front_end)
	_menu_cam = Camera3D.new()
	_menu_cam.fov = 70.0
	_menu_cam.far = 500.0
	add_child(_menu_cam)
	_ui.add_child(settings_menu)
	player.input_enabled = false
	hud.visible = false
	if tdm:
		team_match = TeamMatch.new()
		team_match.main = self
		add_child(team_match)
		hud.team_match = team_match
		scoreboard.team_match = team_match
		if team_match.rules != null:
			var rules := team_match.rules
			bench.budget_text = func(from: Dictionary, to: Dictionary) -> String: return rules.budget_line(from, to)
	if title_message != "":
		hud.show_hint(title_message, 5.0)
		title_message = ""
	if skip_title:
		skip_title = false
		_start.call_deferred()
	else:
		_menu_cam.make_current()
		Music.play(get_tree(), "lobby")
		if open_lobby:
			open_lobby = false
			_open_lobby.call_deferred()


func _next_seed() -> int:
	_seed += 7919
	return _seed


func _choose_map(id: String) -> void:
	if id == map_id:
		_start()
		return
	map_id = id
	skip_title = true
	get_tree().reload_current_scene()


func _open_lobby() -> void:
	_title.visible = false
	lobby.open()


## The menu camera drifts slowly around the map behind the front end and lobby.
func _process(delta: float) -> void:
	if _menu_cam == null or not _menu_cam.current:
		return
	_menu_t += delta
	var a := _menu_t * 0.05
	var r := 20.0
	var centre := Vector3(0, 1.5, 0)
	_menu_cam.global_position = centre + Vector3(sin(a) * r, 15.0 + sin(_menu_t * 0.13) * 1.5, cos(a) * r)
	_menu_cam.look_at(centre + Vector3(sin(a + 0.6) * 4.0, 0, cos(a + 0.6) * 4.0), Vector3.UP)


## Back to the title from anywhere (the host left, or you quit a match), offline.
func back_to_title(message := "") -> void:
	if NetSession.active:
		net.leave()
	map_id = "folded"
	team_mode = false
	skip_title = false
	open_lobby = message == ""
	title_message = message
	get_tree().reload_current_scene.call_deferred()


## The end of a team match: who won, the final score; back to the lobby in 10 s.
func show_results(winner: int, final: Array, my_team: int) -> void:
	if bench.visible:
		bench.close()
	player.input_enabled = false
	death.hide_death()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Music.play(get_tree(), "results")
	results = Control.new()
	results.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(Counterform.GRAPHITE_DEEP, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	results.add_child(shade)
	var won := winner == my_team
	var head := "平手" if winner < 0 else ("勝利" if won else "落敗")
	var color := Counterform.DUST_WHITE if winner < 0 else (Counterform.SULFUR if won else FpUi.enemy_color())
	var big := Hud._shadowed(FpUi.label(head, 120, color, FpUi.display()), 3)
	big.anchor_left = 0.5
	big.anchor_right = 0.5
	big.offset_left = -400
	big.offset_right = 400
	big.offset_top = 30
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results.add_child(big)
	var line := Hud._shadowed(FpUi.label("%s %d ： %d %s　·　你 %d 殺 %d 死" % [NetSession.TEAM_NAMES[0], final[0], final[1],
		NetSession.TEAM_NAMES[1], hud.kills, hud.deaths], 24, Counterform.DUST_WHITE, FpUi.bold()), 1)
	line.anchor_left = 0.5
	line.anchor_right = 0.5
	line.offset_left = -500
	line.offset_right = 500
	line.offset_top = 180
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results.add_child(line)
	var best := team_match.mvp()
	if not best.is_empty():
		var mvp := Hud._shadowed(FpUi.label("MVP　%s　%d 分　%d 殺 %d 助 %d 死" % [best.name, best.points, best.kills,
			best.assists, best.deaths], 20, Counterform.SULFUR, FpUi.bold()), 1)
		mvp.anchor_left = 0.5
		mvp.anchor_right = 0.5
		mvp.offset_left = -500
		mvp.offset_right = 500
		mvp.offset_top = 214
		mvp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		results.add_child(mvp)
	var board := Scoreboard.new()
	board.team_match = team_match
	board.visible = true
	board.offset_top = 150
	results.add_child(board)
	var foot := HBoxContainer.new()
	foot.anchor_left = 0.5
	foot.anchor_right = 0.5
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = -300
	foot.offset_right = 300
	foot.offset_top = -80
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	results.add_child(foot)
	foot.add_child(Hud._shadowed(FpUi.label("十秒後回到大廳", 18, Color(Counterform.DUST_WHITE, 0.7), FpUi.body()), 1))
	if net.is_host():
		var now := FrontEnd.action("現在回到大廳", true, 20)
		now.pressed.connect(net.end_match)
		foot.add_child(now)
	_ui.add_child(results)


func _start() -> void:
	_title.visible = false
	lobby.visible = false
	hud.visible = true
	player.camera.make_current()
	Music.play(get_tree(), "match")
	player.input_enabled = team_match == null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if team_match:
		return
	if lab:
		hud.show_hint("移動測試場：穿過起點門開始計時　T 回到起點　F4 除錯面板", 6.0)
	else:
		hud.show_hint("Tab 打開改槍工作台　F1 操作說明　F4 移動除錯", 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if _title.visible:
		return
	if event.is_action_pressed("help"):
		hud.toggle_help()
	elif event.is_action_pressed("info_colors"):
		FpUi.info_set = (FpUi.info_set + 1) % FpUi.INFO_SETS.size()
		hud.show_hint("敵我顏色：" + FpUi.INFO_SETS[FpUi.info_set][0])
	elif event.is_action_pressed("bot_toggle") and team_match == null:
		_bots_passive = not _bots_passive
		for b in bots:
			b.passive = _bots_passive
		hud.show_hint("機器人開火：" + ("關" if _bots_passive else "開"))
	elif event.is_action_pressed("move_debug"):
		move_debug.toggle()
	elif event.is_action_pressed("camera_fx"):
		CameraFx.cycle()
		hud.show_hint("鏡頭效果：" + CameraFx.level_name())
	elif event.is_action_pressed("tick_rate"):
		hud.show_hint("物理頻率：%d Hz" % MoveDebug.cycle_ticks())
	elif event.is_action_pressed("route_reset") and lab and player.alive:
		lab.restart()
	elif event.is_action_pressed("bench") and team_match != null and not bench.visible:
		# A team match: hold Tab for the scoreboard, tap it for the bench.
		get_viewport().set_input_as_handled()
		_tab_down = Time.get_ticks_msec() / 1000.0
		scoreboard.visible = true
		scoreboard.modulate.a = 0.0
		scoreboard.create_tween().tween_property(scoreboard, "modulate:a", 1.0, 0.12).set_delay(0.18)
	elif event.is_action_released("bench") and _tab_down >= 0.0:
		var held := Time.get_ticks_msec() / 1000.0 - _tab_down
		_tab_down = -1.0
		scoreboard.visible = false
		if held < 0.22 and player.alive and not bench.visible:
			_try_bench()
	elif event.is_action_pressed("bench") and player.alive and not bench.visible:
		get_viewport().set_input_as_handled()
		_try_bench()
	elif event.is_action_pressed("pause") and not bench.visible and not death.visible and not settings_menu.visible:
		player.input_enabled = false
		settings_menu.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and player.input_enabled and not settings_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _try_bench() -> void:
	if team_match != null and team_match.rules != null:
		if not team_match.rules.can_buy():
			hud.show_hint("預算戰：只有每回合開頭的備戰時間能改槍")
			return
		bench.open(player.weapon.build, player.weapon.name, false)
		player.input_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if not player.can_mod():
		hud.show_hint("戰鬥中不能改槍：%.1f 秒沒有交火，或回到重生區" % player.combat_left)
		return
	bench.open(player.weapon.build, player.weapon.name, not SafeZone.is_safe(player.global_position, player.team))
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().set_input_as_handled()


func _on_settings_closed() -> void:
	if _title.visible:
		return
	player.input_enabled = player.alive
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_bench_closed(build: Dictionary, gun_name: String) -> void:
	if team_match != null and team_match.rules != null:
		team_match.rules.request_buy(build, gun_name)
	else:
		player.equip(build, gun_name)
		hud.show_hint("%s　重量 %.1f kg　機動性 %d%%" % [gun_name, player.weapon.stats.weight, roundi(player.mobility * 100)])
	player.input_enabled = player.alive
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


const STREAK_WINDOW := 4.0
const STREAK_NAMES := ["擊殺", "雙殺", "三殺", "四殺", "暴走"]
## Hitstop on a kill (practice only: a network match never pauses anyone's simulation).
const HITSTOP := 0.06
var _streak := 0
var _streak_at := -100.0


func _on_hit_confirmed(info: Dictionary, killed: bool) -> void:
	var head: bool = info.get("zone", "") == "head"
	hud.hit_marker(head, killed, info)
	Sfx.ui(get_tree(), "kill" if killed else ("head" if head else "hit"))
	if not killed or info.get("target") == player:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_streak = _streak + 1 if now - _streak_at < STREAK_WINDOW else 1
	_streak_at = now
	var title: String = STREAK_NAMES[mini(_streak - 1, STREAK_NAMES.size() - 1)]
	if _streak == 1 and head:
		title = "爆頭擊殺"
	hud.callout(title, "", Counterform.DUST_WHITE if _streak < 2 else Counterform.SULFUR)
	player.kill_punch(1.0 + 0.25 * minf(_streak - 1, 3))
	if team_match == null:
		Engine.time_scale = 0.12
		get_tree().create_timer(HITSTOP, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _on_player_damaged(info: Dictionary) -> void:
	if bench.visible and info.get("attacker") != player:
		bench.close()
		hud.show_hint("遭到攻擊：工作台關上了（改好的部分已經裝上）", 3.0)
	if info.get("attacker") != player:
		hud.damage_from(-(info.dir as Vector3))


func _tags(info: Dictionary) -> Array:
	var tags := []
	if info.get("zone", "") == "head":
		tags.append("爆頭")
	if info.get("through_wall", false):
		tags.append("穿牆")
	tags.append_array(info.get("moves", []))
	return tags


func _on_bot_died(bot: Bot, info: Dictionary) -> void:
	if team_match:
		return
	var by_you: bool = info.get("attacker") == player
	if by_you:
		hud.kills += 1
	var killer: String = info.get("attacker_name", "?")
	hud.feed.add_kill(killer, 0 if by_you else 1, info.get("gun_name", "?"), info.get("build", {}), _tags(info),
		bot.display_name, 1, by_you)
	get_tree().create_timer(BOT_RESPAWN).timeout.connect(func() -> void:
		var spots: Array = map.bot_spawns.duplicate()
		spots.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return a.distance_to(player.global_position) > b.distance_to(player.global_position))
		bot.spawn(spots[randi() % 2], _next_seed())
		bot.passive = _bots_passive)


func _on_player_died(info: Dictionary) -> void:
	hud.deaths += 1
	player.input_enabled = false
	var killer: String = info.get("attacker_name", "?")
	var side := 0 if info.get("attacker") == player else 1
	if team_match == null:
		hud.feed.add_kill(killer, side, info.get("gun_name", "?"), info.get("build", {}), _tags(info), player.display_name, 0, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dealt: float = player.damage_dealt.get(killer, 0.0)
	var taken: float = player.damage_taken.get(killer, 0.0)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if player.alive:
			return
		death.show_death(info, dealt, taken)
		if team_match != null and team_match.rules != null:
			death.set_note("這回合只有一條命：等下一回合"))


func _respawn() -> void:
	if team_match:
		if team_match.over or team_match.rules != null:
			return
		if team_match.respawn_wait() > 0.0:
			team_match.respawn_local()
			death.set_wait(team_match.respawn_wait())
			return
	death.hide_death()
	if not _pending_build.is_empty():
		player.equip(_pending_build, _pending_name)
		_pending_build = {}
	if lab:
		lab.restart()
	elif team_match:
		team_match.respawn_local()
	else:
		player.spawn_at(map.player_spawn)
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
