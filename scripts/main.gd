class_name Main
extends Node3D
## The prototype: FOLDED WORKS with you, three sparring bots and a firing range, or the
## MOVEMENT LAB with its timed routes. Tab opens the bench, dying shows who got you with
## what, F4 opens the movement debug panel. No networking yet (that is phase C2).

const BOTS := 3
const BOT_RESPAWN := 4.0

## Which map the next load builds ("folded" or "lab"), and whether to skip the title.
static var map_id := "folded"
static var skip_title := false

var map: Node3D
var lab: MovementLab
var move_debug: MoveDebug
var player: Player
var hud: Hud
var bench: Bench
var death: DeathScreen
var bots: Array[Bot] = []
var _ui: CanvasLayer
var _title: Control
var _pending_build := {}
var _pending_name := ""
var _bots_passive := false
var _seed := 1


func _ready() -> void:
	InputSetup.register()
	CameraFx.load_settings()
	if map_id == "lab":
		lab = MovementLab.new()
		map = lab
	else:
		map = FoldedWorks.new()
	add_child(map)
	for xf in map.range_targets:
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
	for i in (BOTS if not map.bot_spawns.is_empty() else 0):
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
	_title = _make_title()
	_ui.add_child(_title)
	player.input_enabled = false
	hud.visible = false
	if skip_title:
		skip_title = false
		_start.call_deferred()


func _next_seed() -> int:
	_seed += 7919
	return _seed


func _make_title() -> Control:
	var t := Control.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(Faultprint.BONE, 0.9)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(shade)
	var band := Polygon2D.new()
	band.color = Faultprint.CARBON
	band.polygon = PackedVector2Array([Vector2(0, 150), Vector2(2400, 60), Vector2(2400, 300), Vector2(0, 360)])
	t.add_child(band)
	var stripe := Polygon2D.new()
	stripe.color = Faultprint.ORANGE
	stripe.polygon = PackedVector2Array([Vector2(0, 360), Vector2(2400, 300), Vector2(2400, 318), Vector2(0, 378)])
	t.add_child(stripe)
	var logo := FpUi.PrintText.new("HAIKAI: CHAOS", 110, Faultprint.BONE)
	logo.position = Vector2(70, 170)
	logo.size = Vector2(1400, 140)
	logo.offset = 5.0
	t.add_child(logo)
	var sub := FpUi.label("FAULTPRINT 斷層印刷體　｜　原型 C1：移動手感", 22, Faultprint.CARBON, FpUi.bold())
	sub.position = Vector2(76, 400)
	t.add_child(sub)
	var help := FpUi.label(Hud.HELP, 18, Faultprint.CARBON, FpUi.bold())
	help.position = Vector2(76, 450)
	t.add_child(help)
	var row := HBoxContainer.new()
	row.position = Vector2(76, 760)
	row.add_theme_constant_override("separation", 18)
	t.add_child(row)
	for spec in [["folded", "折疊工廠（對戰練習）"], ["lab", "移動測試場（計時路線）"]]:
		var go := FpUi.button(spec[1], 24)
		go.pressed.connect(_choose_map.bind(spec[0]))
		row.add_child(go)
	return t


func _choose_map(id: String) -> void:
	if id == map_id:
		_start()
		return
	map_id = id
	skip_title = true
	get_tree().reload_current_scene()


func _start() -> void:
	_title.visible = false
	hud.visible = true
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	elif event.is_action_pressed("bot_toggle"):
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
	elif event.is_action_pressed("bench") and player.alive and not bench.visible:
		bench.open(player.weapon.build, player.weapon.name)
		player.input_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and player.input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_bench_closed(build: Dictionary, gun_name: String) -> void:
	player.equip(build, gun_name)
	player.input_enabled = player.alive
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_hint("%s　重量 %.1f kg　機動性 %d%%" % [gun_name, player.weapon.stats.weight, roundi(player.mobility * 100)])


func _on_hit_confirmed(info: Dictionary, killed: bool) -> void:
	hud.hit_marker(info.get("zone", "") == "head", killed)
	Sfx.ui(get_tree(), "kill" if killed else ("head" if info.get("zone", "") == "head" else "hit"))


func _on_player_damaged(info: Dictionary) -> void:
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
	hud.feed.add_kill(killer, side, info.get("gun_name", "?"), info.get("build", {}), _tags(info), player.display_name, 0, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dealt: float = player.damage_dealt.get(killer, 0.0)
	var taken: float = player.damage_taken.get(killer, 0.0)
	get_tree().create_timer(0.6).timeout.connect(func() -> void: death.show_death(info, dealt, taken))


func _respawn() -> void:
	death.hide_death()
	if not _pending_build.is_empty():
		player.equip(_pending_build, _pending_name)
		_pending_build = {}
	if lab:
		lab.restart()
	else:
		player.spawn_at(map.player_spawn)
	player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
