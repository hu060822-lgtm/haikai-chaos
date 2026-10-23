class_name BombRules
extends RoundRules
## 爆破 DEMOLITION (C5): 預算戰's rounds and money (RoundRules), with a bomb. One team
## attacks, the other defends, and they swap at half time (after `target() - 1` rounds,
## when everyone's money and guns go back to the start).
##
##   attackers  hold E (interact) PLANT_TIME s inside bomb site A or B to plant the
##              "patch drive". Planted, it goes off after FUSE s: attackers win. Wiping
##              out the defenders also wins.
##   defenders  stop the plant until time runs out, wipe the attackers out before it's
##              planted, or hold E DEFUSE_TIME s next to a planted bomb.
##
## Once the bomb is down, wiping out the attackers is not enough: it still has to be
## defused. Planting and defusing pay OBJECTIVE. The overclock zone is off.
##
## Whoever plants or defuses times it on their own machine and asks the host, which
## checks that it saw them there (alive, on the right team, near enough) before
## announcing it. The host runs the bots: attackers walk to a site and plant unless
## they've just been shot; defenders walk to a planted bomb and defuse it the same way.

const PLANT_TIME := 3.5
const DEFUSE_TIME := 6.0
const FUSE := 40.0
const SITE_RADIUS := 3.5
const DEFUSE_RANGE := 2.2
const OBJECTIVE := 300
const BLAST := 14.0
const SITE_COLOR := Color("#D9774F")

var planted := false
var bomb_at := Vector3.ZERO
var bomb_site := -1
## Local: how long the interact key has been held toward a plant or a defuse.
var _work := 0.0
var _work_kind := ""
var _bot_work := {}       # bot id -> seconds
var _bot_site := 0
var _site_marks: Array = []
var _bomb_node: Node3D


func _init() -> void:
	super()
	name = "Rounds"


func sites() -> Array:
	var s = tm.main.map.get("bomb_sites")
	return s if s is Array and not s.is_empty() else [mid_zone()]


static func site_name(i: int) -> String:
	return "AB"[i] if i >= 0 and i < 2 else "?"


## The attacking team in round `n` (team 0 first; they swap at half time).
func attackers(n := -1) -> int:
	if n < 0:
		n = round_no
	return 0 if n <= half() else 1


func half() -> int:
	return maxi(target() - 1, 1)


## Which site `pos` is in, or -1.
func site_at(pos: Vector3) -> int:
	var all := sites()
	for i in all.size():
		var d: Vector3 = pos - all[i]
		if Vector2(d.x, d.z).length() <= SITE_RADIUS and absf(d.y) < 3.0:
			return i
	return -1


# --- Round hooks -----------------------------------------------------------------------

func _before_round() -> void:
	# Half time: sides swap, everyone starts over.
	if round_no == half() + 1:
		for id in tm.entities:
			money[id] = START_MONEY
			builds[id] = Arsenal.STARTER.duplicate(true)
	_bot_site = _rng.randi() % sites().size()


func _round_began() -> void:
	planted = false
	bomb_site = -1
	_work = 0.0
	_bot_work.clear()
	_show_bomb(false)
	_show_sites()
	for b in tm.bots():
		b.objective = Vector3.INF
	var role := "進攻：到 A 或 B 點按住 E 安裝炸彈" if tm.player.team == attackers() else "防守：守住 A、B 兩點，炸彈裝了就按住 E 拆掉"
	var swap := "　交換攻守，資金重來" if round_no == half() + 1 else ""
	tm.main.hud.show_hint("第 %d 回合　%s%s" % [round_no, role, swap], 6.0)


func _round_ended() -> void:
	_work = 0.0
	for b in tm.bots():
		b.objective = Vector3.INF


func _fight_tick(delta: float) -> void:
	_bots_tick(delta)
	if phase_left > 0.0:
		return
	if planted:
		_detonate.rpc()
		_round_over(attackers(), "炸彈在 %s 點引爆" % site_name(bomb_site))
	else:
		_round_over(1 - attackers(), "時間到：炸彈沒有裝上")


func _after_death(victim_team: int, alive: Array) -> void:
	var atk := attackers()
	if alive[1 - atk] == 0:
		_round_over(atk if alive[atk] > 0 or planted else -1, "防守方全滅")
	elif alive[atk] == 0 and not planted:
		_round_over(1 - atk, "進攻方全滅")


func _note(parts: Array) -> void:
	parts.append("進攻" if tm.player.team == attackers() else "防守")
	if planted:
		parts.append("炸彈在 %s 點" % site_name(bomb_site))


# --- Planting and defusing (local) -------------------------------------------------------

func _local_tick(delta: float) -> void:
	var p := tm.player
	var want := ""
	if phase == "fight" and p.alive and p.input_enabled and Input.is_action_pressed("interact"):
		if p.team == attackers() and not planted and site_at(p.global_position) >= 0 and p.is_on_floor():
			want = "plant"
		elif p.team != attackers() and planted and p.global_position.distance_to(bomb_at) <= DEFUSE_RANGE:
			want = "defuse"
	if want != _work_kind:
		_work = 0.0
		_work_kind = want
	if want == "":
		return
	_work += delta
	var need := PLANT_TIME if want == "plant" else DEFUSE_TIME
	tm.main.hud.show_hint("%s %d%%" % ["安裝炸彈中…" if want == "plant" else "拆除中…", roundi(minf(_work / need, 1.0) * 100)], 0.25)
	if _work >= need:
		_work = -999.0   # one ask per hold
		if want == "plant":
			if tm.net.is_host():
				_plant_by(tm.my_id, site_at(p.global_position), p.global_position)
			else:
				_want_plant.rpc_id(1, site_at(p.global_position), p.global_position)
		else:
			if tm.net.is_host():
				_defuse_by(tm.my_id)
			else:
				_want_defuse.rpc_id(1)


@rpc("any_peer", "reliable")
func _want_plant(site: int, at: Vector3) -> void:
	if tm.net.is_host():
		_plant_by("p%d" % multiplayer.get_remote_sender_id(), site, at)


@rpc("any_peer", "reliable")
func _want_defuse() -> void:
	if tm.net.is_host():
		_defuse_by("p%d" % multiplayer.get_remote_sender_id())


## Host: `id` says it planted at `site`. True when it stands.
func _plant_by(id: String, site: int, at: Vector3) -> bool:
	var e = tm.entities.get(id)
	if phase != "fight" or planted or e == null or not e.alive or tm.team_of(id) != attackers():
		return false
	# Where the host sees them must agree (a little slack for lag).
	var seen: Vector3 = (e as Node3D).global_position
	if site_at(seen) != site and seen.distance_to(sites()[site] if site >= 0 else seen) > SITE_RADIUS + 2.5:
		return false
	if site < 0 or at.distance_to(seen) > 3.0:
		return false
	money[id] = mini(int(money.get(id, 0)) + OBJECTIVE, MAX_MONEY)
	_bomb_planted.rpc(site, at, id, money)
	return true


func _defuse_by(id: String) -> bool:
	var e = tm.entities.get(id)
	if phase != "fight" or not planted or e == null or not e.alive or tm.team_of(id) == attackers():
		return false
	if (e as Node3D).global_position.distance_to(bomb_at) > DEFUSE_RANGE + 1.5:
		return false
	money[id] = mini(int(money.get(id, 0)) + OBJECTIVE, MAX_MONEY)
	_bomb_defused.rpc(id, money)
	_round_over(1 - attackers(), "%s 拆掉了炸彈" % tm._name_of(id))
	return true


@rpc("authority", "call_local", "reliable")
func _bomb_planted(site: int, at: Vector3, by: String, new_money: Dictionary) -> void:
	planted = true
	bomb_site = site
	bomb_at = at
	money = new_money
	phase_left = FUSE
	_work = 0.0
	_show_bomb(true)
	var ours := tm.player.team == attackers()
	tm.main.hud.callout("炸彈已安裝", "%s 點　%s　%d 秒後引爆" % [site_name(site), tm._name_of(by), int(FUSE)],
		Counterform.SULFUR if ours else FpUi.enemy_color())
	if by == tm.my_id:
		tm.main.hud.show_hint("安裝成功 +$%d" % OBJECTIVE, 3.0)
	tm.score_changed.emit()


@rpc("authority", "call_local", "reliable")
func _bomb_defused(by: String, new_money: Dictionary) -> void:
	planted = false
	money = new_money
	_show_bomb(false)
	if by == tm.my_id:
		tm.main.hud.show_hint("拆除成功 +$%d" % OBJECTIVE, 3.0)
	tm.score_changed.emit()


@rpc("authority", "call_local", "reliable")
func _detonate() -> void:
	PrintFx.explosion(tm.main, bomb_at + Vector3(0, 0.5, 0), BLAST)
	planted = false
	_show_bomb(false)


# --- Bots (host) -----------------------------------------------------------------------

func _bots_tick(delta: float) -> void:
	var atk := attackers()
	for b in tm.bots():
		if not b.alive:
			continue
		var goal := Vector3.INF
		var work := ""
		if b.team == atk and planted:
			goal = bomb_at + Vector3(2.5, 0, 0)   # guard it
		elif b.team == atk:
			goal = sites()[_bot_site]
			if site_at(b.global_position) >= 0 and not b.hurt_within(1.5):
				work = "plant"
		elif b.team != atk and planted:
			goal = bomb_at
			if b.global_position.distance_to(bomb_at) <= DEFUSE_RANGE and not b.hurt_within(1.5):
				work = "defuse"
		b.objective = goal
		if work == "":
			_bot_work.erase(b.id)
			continue
		var t := float(_bot_work.get(b.id, 0.0)) + delta
		_bot_work[b.id] = t
		if work == "plant" and t >= PLANT_TIME:
			_bot_work.erase(b.id)
			_plant_by(b.id, site_at(b.global_position), b.global_position)
		elif work == "defuse" and t >= DEFUSE_TIME:
			_bot_work.erase(b.id)
			_defuse_by(b.id)
		if phase != "fight":
			return


# --- Looks -----------------------------------------------------------------------------

## The two sites: a ring on the floor and a big letter over it.
func _show_sites() -> void:
	if not _site_marks.is_empty():
		return
	var all := sites()
	for i in all.size():
		var root := Node3D.new()
		root.name = "BombSite" + site_name(i)
		tm.main.map.add_child(root)
		root.global_position = all[i] + Vector3(0, 0.04, 0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(SITE_COLOR, 0.85)
		var ring := MeshInstance3D.new()
		ring.mesh = SafeZone._ring_mesh(SITE_RADIUS - 0.25, SITE_RADIUS, 48)
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		var fill := MeshInstance3D.new()
		fill.mesh = SafeZone._ring_mesh(0.0, SITE_RADIUS - 0.25, 48)
		var mf := m.duplicate() as StandardMaterial3D
		mf.albedo_color = Color(SITE_COLOR, 0.1)
		fill.material_override = mf
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fill)
		var label := Label3D.new()
		label.text = site_name(i)
		label.font = FpUi.display()
		label.font_size = 220
		label.pixel_size = 0.01
		label.modulate = SITE_COLOR
		label.outline_size = 24
		label.outline_modulate = Color(Counterform.GRAPHITE_DEEP, 0.8)
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.position = Vector3(0, 3.6, 0)
		root.add_child(label)
		_site_marks.append(root)


## The planted patch drive: a squat box with a blinking light.
func _show_bomb(on: bool) -> void:
	if _bomb_node != null:
		_bomb_node.queue_free()
		_bomb_node = null
	if not on:
		return
	_bomb_node = Node3D.new()
	_bomb_node.name = "Bomb"
	tm.main.map.add_child(_bomb_node)
	_bomb_node.global_position = bomb_at
	var body := MeshInstance3D.new()
	body.mesh = LowPoly.chamfer_box(Vector3(0.5, 0.22, 0.34), 0.03)
	body.material_override = Counterform.material("paint", Counterform.GRAPHITE_DEEP, false)
	body.position = Vector3(0, 0.11, 0)
	_bomb_node.add_child(body)
	var light := MeshInstance3D.new()
	light.mesh = LowPoly.chamfer_box(Vector3(0.12, 0.05, 0.12), 0.01)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Counterform.OXIDE_ORANGE
	light.material_override = lm
	light.position = Vector3(0.1, 0.25, 0)
	_bomb_node.add_child(light)
	var t := light.create_tween().set_loops()
	t.tween_callback(func() -> void: light.visible = false).set_delay(0.5)
	t.tween_callback(func() -> void: light.visible = true).set_delay(0.25)
