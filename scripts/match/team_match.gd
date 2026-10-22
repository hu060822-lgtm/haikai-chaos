class_name TeamMatch
extends Node
## 改版死鬥 PATCH WAR: C2's team mode, over the network. Two teams on a team map (FOLDED
## WORKS or DREAM HOME: the map gives each team's zone and spawn points); the
## host fills empty slots with bots. First team to the score limit (or ahead when time
## runs out) wins. What makes it its own mode is how kills score, all of it about the
## gun-modding pillar:
##
##   freshness   every exact build is a "version". A version's first two kills by you are
##               worth 3, the next two 2, then 1 ("版本疲乏"). Change anything on the gun
##               and it's a new version, worth 3 again, so the bench is part of the fight.
##   style       a kill with a move tag (wall run, slide, air, slam...) is +1.
##   the answer  once a version has META_KILLS kills across the match it is announced as
##               "版本答案" (the meta). Anyone carrying it is seen through walls by everyone,
##               and killing a carrier is +META_BONUS. The game patches what dominates:
##               ride the meta and be hunted, or mod away from it.
##   safe zones  each team's spawn (SafeZone): no damage in or out; the bench always opens
##               there, elsewhere only out of combat (Player.can_mod).
##
## Networking: every machine simulates its own player and sends its state SEND_RATE apart;
## the host simulates the bots. Others are Avatars. A hit is decided by the shooter and
## sent to the victim's owner (send_hit), who applies it and announces a death to all.
## The host keeps the score. Node path /root/Main/Match on every machine.
##
## config.mode "rounds" plays 預算戰 instead: rounds with one life and a part-buying
## economy, run by a RoundRules child (`rules`); the scoring above is off.

signal score_changed()

const RESPAWN := 4.0
## Not back in by then (looking at the killer's gun)? In you go.
const AUTO_RESPAWN := 9.0
const SEND_RATE := 0.05
const ZONE_RADIUS := 6.0
const FRESH := [3, 3, 2, 2, 1]
const STYLE_BONUS := 1
const META_KILLS := 4
const META_BONUS := 3
const BOT_DAMAGE := 0.7
const ASSIST_DAMAGE := 25.0   # damage on a victim that makes you share the kill (+1 personal)
const MAX_HIT := 600.0        # one hit over this is a bad packet, not a gun
const LOAD_TIMEOUT := 8.0
const BOT_NAMES := ["灰板", "模具", "套色", "網點", "鉚釘", "楔形", "印版", "斷層", "鋼架", "骨白"]

var main: Main
var net: NetSession
var player: Player
## id -> node: "p<peer>" players (our Player or an Avatar), "b<n>" bots (Bot on the host,
## Avatar elsewhere).
var entities := {}
var scores := [0, 0]
var time_left := 0.0
var running := false
var over := false
var meta_version := 0
var meta_gun := ""
var bots_passive := false
var my_id := ""
var versions := {}        # id -> version of the gun it carries
## id -> {kills, deaths, points} for the scoreboard (kills and deaths counted on every
## machine from the death messages; points from the host's score messages).
var stats := {}
var _version_kills := {}  # version -> kills in this match
var _fresh := {}          # "killer|version" -> kills
var _send_t := 0.0
var _loaded := {}
var _wait := 0.0
var _dead_for := 0.0
var _respawn_queued := false
var _bot_seed := 17
var _dmg_log := {}        # victim id -> {attacker id: damage}, on the victim's owner, cleared on death
## 預算戰 (config.mode "rounds"), else null.
var rules: RoundRules


func _init() -> void:
	name = "Match"


func _ready() -> void:
	net = main.net
	player = main.player
	my_id = "p%d" % net.my_id()
	entities[my_id] = player
	player.team = net.my_team()
	player.display_name = str(NetSession.roster.get(net.my_id(), {}).get("name", NetSession.my_name))
	time_left = float(NetSession.config.get("minutes", 8)) * 60.0
	if str(NetSession.config.get("mode", "patch")) == "rounds":
		rules = RoundRules.new()
		rules.tm = self
		add_child(rules)
	SafeZone.clear()
	SafeZone.repel = true
	for t in 2:
		SafeZone.add(main.map.team_zones[t], ZONE_RADIUS, t)
	SafeZone.draw(main.map, player.team)
	player.died.connect(_on_local_died)
	player.shot_traced.connect(func(from: Vector3, tos: PackedVector3Array) -> void: _send_fx(my_id, tos))
	player.weapon_changed.connect(_on_local_loadout)
	player.spawn_at(spawn_point(player.team, 0))
	versions[my_id] = player.weapon.version
	for peer in NetSession.roster:
		if int(peer) == net.my_id():
			continue
		var info: Dictionary = NetSession.roster[peer]
		_add_avatar("p%d" % int(peer), int(info.team), str(info.name))
	if net.is_host():
		_make_bots()
		_loaded[1] = true
	else:
		_ready_here.rpc_id(1)
	player.input_enabled = false
	main.hud.show_hint("等其他玩家載入…", 10.0)


func spawn_point(team: int, index := -1) -> Transform3D:
	var points: Array = main.map.team_spawns[team]
	var at: Vector3 = points[index % points.size()] if index >= 0 else points[randi() % points.size()]
	return Transform3D(Basis(Vector3.UP, 0.0 if team == 0 else PI), at)


func _add_avatar(id: String, team: int, display: String) -> Avatar:
	var a := Avatar.new()
	a.setup(id, team, display, team == player.team)
	a.match_node = self
	main.add_child(a)
	a.die()
	entities[id] = a
	return a


func _make_bots() -> void:
	if not NetSession.config.get("bots", true):
		return
	var size := int(NetSession.config.get("team_size", 4))
	var humans := [0, 0]
	for peer in NetSession.roster:
		humans[int(NetSession.roster[peer].team)] += 1
	var n := 0
	for team in 2:
		for i in maxi(size - humans[team], 0):
			var bot := Bot.new()
			bot.id = "b%d" % n
			bot.team = team
			bot.tint_ally = team == player.team
			bot.waypoints = main.map.waypoints
			bot.damage_mult = BOT_DAMAGE
			bot.passive = bots_passive
			main.add_child(bot)
			_bot_seed += 7919
			bot.spawn(spawn_point(team, humans[team] + i).origin, _bot_seed)
			bot.display_name = "%s-%02d" % [BOT_NAMES[n % BOT_NAMES.size()], 10 + n]
			bot.died.connect(_on_bot_died)
			bot.shot_traced.connect(func(_from: Vector3, tos: PackedVector3Array) -> void: _send_fx(bot.id, tos))
			entities[bot.id] = bot
			versions[bot.id] = bot.weapon.version
			n += 1


func bots() -> Array:
	var out := []
	for id in entities:
		if entities[id] is Bot:
			out.append(entities[id])
	return out


# --- Start -----------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _ready_here() -> void:
	if net.is_host():
		_loaded[multiplayer.get_remote_sender_id()] = true


func _process(delta: float) -> void:
	if not running and not over and net.is_host():
		_wait += delta
		var all := true
		for peer in NetSession.roster:
			all = all and _loaded.has(int(peer))
		if all or _wait > LOAD_TIMEOUT:
			var list := []
			for b in bots():
				list.append([b.id, b.team, b.display_name, b.weapon.build, b.weapon.name, b.global_position])
			_go.rpc(list, time_left)
	if not player.alive and running and rules == null:
		_dead_for += delta
		if _dead_for >= RESPAWN and (_respawn_queued or _dead_for >= AUTO_RESPAWN):
			main._respawn()
		elif main.death.visible:
			main.death.set_wait(respawn_wait(), AUTO_RESPAWN - _dead_for)


@rpc("authority", "call_local", "reliable")
func _go(bot_list: Array, seconds: float) -> void:
	if running:
		return
	running = true
	time_left = seconds
	for b in bot_list:
		var id: String = b[0]
		if not entities.has(id):
			var a := _add_avatar(id, int(b[1]), str(b[2]))
			a.set_build(b[3], b[4])
			a.respawn(b[5], 0.0 if int(b[1]) == 0 else PI)
		versions[id] = Weapon.version_of(b[3])
	player.input_enabled = not main.bench.visible and not main.settings_menu.visible
	if player.input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if rules != null:
		rules.start()
		return
	main.hud.show_hint("改版死鬥開始：%s。同一把槍越殺越不值錢，換零件就是新版本" % NetSession.TEAM_NAMES[player.team], 5.0)
	_announce_spawn()


func _announce_spawn() -> void:
	var xf := player.global_transform
	_spawned.rpc(my_id, xf.origin, player.rotation.y, player.weapon.build, player.weapon.name)


# --- Per tick --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not running:
		return
	if rules == null:
		time_left = maxf(time_left - delta, 0.0)
	# The meta's carriers are seen by everyone (renewed while they hold it).
	if meta_version != 0:
		if player.alive and player.weapon.version == meta_version:
			player.marked = maxf(player.marked, 0.5)
		for b in bots():
			if b.alive and b.weapon.version == meta_version:
				b.marked = maxf(b.marked, 0.5)
	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = SEND_RATE
		if player.alive:
			_state.rpc(my_id, player.global_position, player.rotation.y, player._pitch, int(player.move), player.velocity,
				player.health, player.marked)
		if net.is_host():
			var list := []
			for b in bots():
				if b.alive:
					list.append([b.id, b.global_position, b.rotation.y, int(b.move), b.velocity, b.health, b.marked])
			if not list.is_empty():
				_bot_states.rpc(list)
	if net.is_host() and not over and time_left <= 0.0 and rules == null:
		var winner := -1 if scores[0] == scores[1] else (0 if scores[0] > scores[1] else 1)
		_end.rpc(winner, scores)


@rpc("any_peer", "unreliable_ordered")
func _state(id: String, pos: Vector3, yaw: float, pitch: float, move: int, vel: Vector3, hp: float, marked: float) -> void:
	if id != "p%d" % multiplayer.get_remote_sender_id():
		return
	var a = entities.get(id)
	if a is Avatar and a.alive:
		a.push_state(pos, yaw, pitch, move, vel, hp, marked)


@rpc("authority", "unreliable_ordered")
func _bot_states(list: Array) -> void:
	for s in list:
		var a = entities.get(s[0])
		if a is Avatar and a.alive:
			a.push_state(s[1], s[2], 0.0, s[3], s[4], s[5], s[6])


# --- Shots and hits --------------------------------------------------------------------

func _send_fx(id: String, tos: PackedVector3Array) -> void:
	if running and not tos.is_empty():
		_fx.rpc(id, tos)


@rpc("any_peer", "unreliable")
func _fx(id: String, tos: PackedVector3Array) -> void:
	var a = entities.get(id)
	if not (a is Avatar) or not a.alive:
		return
	var from: Vector3 = a.muzzle()
	var klass := PrintFx.weapon_class(Arsenal.stats(a.build)) if not a.build.is_empty() else "rapid"
	for to in tos:
		PrintFx.tracer(main, from, to, klass)
	Sfx.shot(a, klass, false)


func owner_of(id: String) -> int:
	return int(id.substr(1)) if id.begins_with("p") else 1


func id_of(node: Object) -> String:
	if node == null:
		return ""
	for id in entities:
		if entities[id] == node:
			return id
	return ""


## A hit decided on this machine for `victim_id`: to its owner (or straight in, if ours).
func send_hit(victim_id: String, info: Dictionary) -> void:
	var wire := to_wire(info)
	var owner := owner_of(victim_id)
	if owner == net.my_id():
		_apply_hit(victim_id, wire)
	else:
		_hit.rpc_id(owner, victim_id, wire)


@rpc("any_peer", "reliable")
func _hit(victim_id: String, wire: Dictionary) -> void:
	if owner_of(victim_id) != net.my_id():
		return
	# Only the machine that owns the shooter may say it hit: no hits forged in someone
	# else's name, none from teammates, none past any gun's damage. A dead shooter's last bullets still count (trades).
	var attacker_id := str(wire.get("attacker_id", ""))
	if owner_of(attacker_id) != multiplayer.get_remote_sender_id():
		return
	var shooter = entities.get(attacker_id)
	if shooter == null or team_of(attacker_id) == team_of(victim_id):
		return
	if float(wire.get("damage", 0.0)) > MAX_HIT:
		return
	_apply_hit(victim_id, wire)


func _apply_hit(victim_id: String, wire: Dictionary) -> void:
	var v = entities.get(victim_id)
	if v == null or v is Avatar or not v.alive:
		return
	if rules != null and not rules.fighting():
		return
	var attacker_id := str(wire.get("attacker_id", ""))
	if attacker_id != "" and attacker_id != victim_id:
		var dealt: Dictionary = _dmg_log.get(victim_id, {})
		dealt[attacker_id] = float(dealt.get(attacker_id, 0.0)) + float(wire.get("damage", 0.0))
		_dmg_log[victim_id] = dealt
	v.take_hit(from_wire(wire))


## Hit info for the wire: the attacker becomes its id, nodes are dropped.
func to_wire(info: Dictionary) -> Dictionary:
	var w := {}
	for k in info:
		var value = info[k]
		if value is Object:
			continue
		w[k] = value
	w.attacker_id = id_of(info.get("attacker"))
	return w


func from_wire(wire: Dictionary) -> Dictionary:
	var info := wire.duplicate(true)
	info.attacker = entities.get(str(wire.get("attacker_id", "")))
	return info


# --- Deaths, respawns, loadouts --------------------------------------------------------

func _on_local_died(info: Dictionary) -> void:
	_dead_for = 0.0
	_respawn_queued = false
	_died.rpc(my_id, _with_assists(my_id, to_wire(info)))


func _on_bot_died(bot: Bot, info: Dictionary) -> void:
	_died.rpc(bot.id, _with_assists(bot.id, to_wire(info)))
	if rules != null:
		return
	get_tree().create_timer(RESPAWN).timeout.connect(func() -> void:
		if over or not is_instance_valid(bot):
			return
		_bot_seed += 7919
		var xf := spawn_point(bot.team)
		var keep := bot.display_name
		bot.spawn(xf.origin, _bot_seed)
		bot.display_name = keep
		bot.passive = bots_passive
		versions[bot.id] = bot.weapon.version
		_spawned.rpc(bot.id, xf.origin, bot.rotation.y, bot.weapon.build, bot.weapon.name))


## Everyone (but the killer) who did ASSIST_DAMAGE to the victim this life shares the kill.
func _with_assists(victim_id: String, wire: Dictionary) -> Dictionary:
	var killer := str(wire.get("attacker_id", ""))
	var helpers := []
	var dealt: Dictionary = _dmg_log.get(victim_id, {})
	for id in dealt:
		if id != killer and float(dealt[id]) >= ASSIST_DAMAGE and team_of(id) != team_of(victim_id):
			helpers.append(id)
	_dmg_log.erase(victim_id)
	wire.assist_ids = helpers
	return wire


@rpc("any_peer", "call_local", "reliable")
func _died(victim_id: String, wire: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and owner_of(victim_id) != sender and sender != net.my_id():
		return
	var victim = entities.get(victim_id)
	if victim is Avatar:
		victim.die()
	var killer_id := str(wire.get("attacker_id", ""))
	var killer_team := int(wire.get("team", -1))
	var victim_team := team_of(victim_id)
	var tags := []
	if wire.get("zone", "") == "head":
		tags.append("爆頭")
	if wire.get("through_wall", false):
		tags.append("穿牆")
	tags.append_array(wire.get("moves", []))
	var killer_name := str(wire.get("attacker_name", "?"))
	var involves_you := victim_id == my_id or killer_id == my_id
	main.hud.feed.add_kill(killer_name, 0 if killer_team == player.team else 1, str(wire.get("gun_name", "?")),
		wire.get("build", {}), tags, _name_of(victim_id), 0 if victim_team == player.team else 1, involves_you)
	if killer_id == my_id and victim_id != my_id:
		main.hud.kills += 1
	_stat(victim_id, "deaths", 1)
	if killer_id != "" and killer_id != victim_id and team_of(killer_id) != victim_team:
		_stat(killer_id, "kills", 1)
		if rules != null:
			_stat(killer_id, "points", 2)
		for helper in wire.get("assist_ids", []):
			_stat(str(helper), "assists", 1)
			_stat(str(helper), "points", 1)
			if str(helper) == my_id:
				main.hud.callout("助攻", "%s　+1" % _name_of(victim_id), Counterform.DUST_WHITE)
	if net.is_host():
		if rules != null:
			rules.on_death(victim_id, wire)
		else:
			_score_kill(victim_id, wire)


func _stat(id: String, key: String, amount: int) -> void:
	if id == "":
		return
	if not stats.has(id):
		stats[id] = {"kills": 0, "deaths": 0, "assists": 0, "points": 0}
	stats[id][key] = int(stats[id][key]) + amount


func team_of(id: String) -> int:
	var n = entities.get(id)
	return int(n.team) if n != null else -1


func _name_of(id: String) -> String:
	var n = entities.get(id)
	return str(n.display_name) if n != null else "?"


## Our player back in, at the team's spawn (RESPAWN seconds after dying, earliest).
func respawn_local() -> bool:
	if player.alive or _dead_for < RESPAWN:
		_respawn_queued = true
		return false
	_respawn_queued = false
	player.spawn_at(spawn_point(player.team))
	_announce_spawn()
	return true


func respawn_wait() -> float:
	return maxf(RESPAWN - _dead_for, 0.0)


@rpc("any_peer", "reliable")
func _spawned(id: String, pos: Vector3, yaw: float, build: Dictionary, gun_name: String) -> void:
	var a = entities.get(id)
	if a is Avatar:
		a.set_build(build, gun_name)
		a.respawn(pos, yaw)
	versions[id] = Weapon.version_of(build)


func _on_local_loadout() -> void:
	versions[my_id] = player.weapon.version
	if running:
		_loadout.rpc(my_id, player.weapon.build, player.weapon.name)


@rpc("any_peer", "reliable")
func _loadout(id: String, build: Dictionary, gun_name: String) -> void:
	var a = entities.get(id)
	if a is Avatar:
		a.set_build(build, gun_name)
	versions[id] = Weapon.version_of(build)


func peer_left(peer: int) -> void:
	var id := "p%d" % peer
	var a = entities.get(id)
	if a is Avatar:
		main.hud.show_hint("%s 離線了" % a.display_name)
		a.queue_free()
	entities.erase(id)


# --- Score -----------------------------------------------------------------------------

## Points for one kill (host only); see the class notes. Returns [points, notes].
func score_kill(killer_id: String, killer_team: int, victim_id: String, version: int, moves: Array) -> Array:
	var victim_team := team_of(victim_id)
	if killer_team < 0 or killer_team == victim_team or killer_id == "" or killer_id == victim_id:
		return [0, ""]
	var key := "%s|%d" % [killer_id, version]
	var n := int(_fresh.get(key, 0)) + 1
	_fresh[key] = n
	var pts: int = FRESH[mini(n - 1, FRESH.size() - 1)]
	var notes := ["新版本 +%d" % pts if n <= 2 else ("版本疲乏 +%d" % pts)]
	if not moves.is_empty():
		pts += STYLE_BONUS
		notes.append("身法 +%d" % STYLE_BONUS)
	if meta_version != 0 and int(versions.get(victim_id, 0)) == meta_version:
		pts += META_BONUS
		notes.append("擊破版本答案 +%d" % META_BONUS)
	_version_kills[version] = int(_version_kills.get(version, 0)) + 1
	scores[killer_team] += pts
	return [pts, "　".join(notes)]


func _score_kill(victim_id: String, wire: Dictionary) -> void:
	var killer_id := str(wire.get("attacker_id", ""))
	var version := int(wire.get("version", 0))
	var result := score_kill(killer_id, int(wire.get("team", -1)), victim_id, version, wire.get("moves", []))
	if int(result[0]) <= 0:
		return
	var new_meta := meta_version
	var new_gun := meta_gun
	if int(_version_kills.get(version, 0)) >= META_KILLS and version != meta_version:
		new_meta = version
		new_gun = str(wire.get("gun_name", "?"))
	_score.rpc(scores, new_meta, new_gun, killer_id, int(result[0]), str(result[1]))
	var limit := int(NetSession.config.get("score", 50))
	for t in 2:
		if scores[t] >= limit and not over:
			_end.rpc(t, scores)


@rpc("authority", "call_local", "reliable")
func _score(new_scores: Array, meta: int, gun: String, scorer_id: String, points: int, note: String) -> void:
	scores = new_scores
	_stat(scorer_id, "points", points)
	if scorer_id == my_id:
		main.hud.callout("+%d" % points, note, Counterform.SULFUR)
	if meta != meta_version:
		meta_version = meta
		meta_gun = gun
		main.hud.show_hint("新的版本答案：「%s」。拿著它的人，所有人都看得到" % gun, 5.0)
	score_changed.emit()


@rpc("authority", "call_local", "reliable")
func _end(winner: int, final: Array) -> void:
	if over:
		return
	over = true
	running = false
	scores = final
	player.input_enabled = false
	main.show_results(winner, final, player.team)
	if net.is_host():
		get_tree().create_timer(10.0).timeout.connect(net.end_match)


## The match's best player by personal points (kills, then fewer deaths break ties):
## {id, name, points, kills, deaths, assists}, or {} before anyone has a stat.
func mvp() -> Dictionary:
	var best := {}
	for id in stats:
		if not entities.has(id):
			continue
		var s: Dictionary = stats[id]
		var key := int(s.points) * 10000 + int(s.kills) * 100 - int(s.deaths)
		if best.is_empty() or key > int(best.key):
			best = {"key": key, "id": id, "name": _name_of(id), "points": int(s.points), "kills": int(s.kills),
				"deaths": int(s.deaths), "assists": int(s.get("assists", 0))}
	return best


## What a team plays to: round wins in 預算戰, points otherwise.
func score_limit() -> int:
	return rules.target() if rules != null else int(NetSession.config.get("score", 50))


## The small line under the HUD's score: the meta gun, or the round, phase and money.
func bar_note() -> String:
	if rules != null:
		return rules.bar_note()
	return "版本答案：" + meta_gun if meta_version != 0 else ""


## The score line for the HUD: "藍隊 23 ： 31 紅隊　7:12".
func score_text() -> String:
	var t := int(ceil(time_left))
	return "%s %d ： %d %s　%d:%02d" % [NetSession.TEAM_NAMES[0], scores[0], scores[1], NetSession.TEAM_NAMES[1], t / 60, t % 60]
