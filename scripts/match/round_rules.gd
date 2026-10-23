class_name RoundRules
extends Node
## 預算戰 BUDGET WAR (C4): the round-based mode, the CS / Valorant skeleton with the bench
## as the shop. TeamMatch runs the match (players, bots, hits, the kill feed); this node
## turns it into rounds:
##
##   build    BUILD_TIME s in your spawn zone. The bench is the shop: every frame and part
##            has a price, you pay for what you add and get SELL_BACK of what you take
##            off. No damage anywhere.
##   fight    ROUND_TIME s, one life. A round ends when a team is wiped out, when a team
##            holds the overclock zone in the middle (it opens ZONE_OPENS s before the
##            end) alone for ZONE_HOLD s, or at the time limit (more total health wins).
##   end      END_PAUSE s, then the money: WIN for the winners, LOSS (+LOSS_STEP per loss
##            in a row) for the losers. Every kill pays KILL plus SALVAGE of what the
##            victim's gun cost; an assist pays ASSIST.
##
## You keep your gun while you survive. Die and it's gone: next round starts on the
## STARTER revolver, with whatever money you have. First to `rounds` round wins (lobby
## setting) takes the match.
##
## The host owns the money and the guns (who has what): a client checks the price
## itself, equips, and asks; the host takes the money or sends the old gun back.
## Node path /root/Main/Match/Rounds on every machine.
##
## 爆破 (BombRules, C5) builds on this: the same rounds and money, other ways to win. The
## hooks it overrides are marked "(hook)".

const BUILD_TIME := 15.0
const ROUND_TIME := 100.0
const ZONE_OPENS := 40.0
const ZONE_RADIUS := 4.0
const ZONE_HOLD := 6.0
const END_PAUSE := 4.0
const START_MONEY := 800
const WIN := 1500
const LOSS := 1000
const LOSS_STEP := 400
const LOSS_STEPS := 2
const KILL := 100
const SALVAGE := 0.25
const SALVAGE_CAP := 1000
const ASSIST := 50
const MAX_MONEY := 9000
const SELL_BACK := 0.5
## A buy that left the bench just as the fight began still counts.
const BUY_GRACE := 1.0

var tm: TeamMatch
var phase := ""            # "", "build", "fight", "end"
var phase_left := 0.0
var round_no := 0
var wins := [0, 0]
## id -> money, id -> the gun it owns (host's word; clients get copies).
var money := {}
var builds := {}
var zone_open := false
## [team holding the zone or -1, seconds held]
var hold := [-1, 0.0]
var last_result := ""
var _losses := [0, 0]
var _fight_t := 0.0
var _ring: Node3D
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Rounds"
	_rng.seed = 4242


func target() -> int:
	return int(NetSession.config.get("rounds", 5))


func fighting() -> bool:
	return phase == "fight"


func can_buy() -> bool:
	return phase == "build"


func my_money() -> int:
	return int(money.get(tm.my_id, 0))


func mid_zone() -> Vector3:
	var m = tm.main.map.get("mid_zone")
	return m if m is Vector3 else Vector3.ZERO


# --- Prices ----------------------------------------------------------------------------

## What it costs to go from gun `from` to gun `to`: the price of every frame and part
## added, less SELL_BACK of everything taken off (negative = money back).
static func cost(from: Dictionary, to: Dictionary) -> int:
	var have := {}
	for id in Arsenal.ids(from):
		have[id] = int(have.get(id, 0)) + 1
	var bought := 0
	for id in Arsenal.ids(to):
		if int(have.get(id, 0)) > 0:
			have[id] = int(have[id]) - 1
		else:
			bought += Arsenal.price_of(id)
	var sold := 0
	for id in have:
		sold += Arsenal.price_of(id) * int(have[id])
	return bought - int(floor(sold * SELL_BACK))


## What a whole gun is worth (the salvage on a kill is a share of it).
static func value(build: Dictionary) -> int:
	var total := 0
	for id in Arsenal.ids(build):
		total += Arsenal.price_of(id)
	return total


## Money for the losers after `streak` losses in a row (1 = this one).
static func loss_pay(streak: int) -> int:
	return LOSS + LOSS_STEP * clampi(streak - 1, 0, LOSS_STEPS)


static func kill_pay(victim_build: Dictionary) -> int:
	return KILL + mini(int(value(victim_build) * SALVAGE), SALVAGE_CAP)


## The bench's line while you shop: "資金 $1600　這次改裝 $540　剩 $1060".
func budget_line(from: Dictionary, to: Dictionary) -> String:
	var have := my_money()
	var c := cost(from, to)
	if c == 0:
		return "資金 $%d　（加零件付全價，拆下來的退一半）" % have
	if c < 0:
		return "資金 $%d　賣掉零件 +$%d　→ $%d" % [have, -c, have - c]
	if c > have:
		return "資金 $%d　這次改裝 $%d　錢不夠！" % [have, c]
	return "資金 $%d　這次改裝 $%d　剩 $%d" % [have, c, have - c]


# --- Rounds (host) ---------------------------------------------------------------------

## The match begins (TeamMatch._go, on every machine): the host starts round one.
func start() -> void:
	if not tm.net.is_host():
		return
	for id in tm.entities:
		money[id] = START_MONEY
		builds[id] = Arsenal.STARTER.duplicate(true)
	_next_round()


func _next_round() -> void:
	round_no += 1
	_before_round()
	for id in tm.entities:
		if not money.has(id):
			money[id] = START_MONEY
		if not builds.has(id):
			builds[id] = Arsenal.STARTER.duplicate(true)
	for b in tm.bots():
		_bot_shop(b)
	_round_start.rpc(round_no, wins, money, builds)


## Bots shop too: a few random guns, the best one they can pay for.
func _bot_shop(bot: Bot) -> void:
	var have := int(money.get(bot.id, START_MONEY))
	var current: Dictionary = builds.get(bot.id, Arsenal.STARTER)
	var best := current
	var best_value := value(current)
	for i in 6:
		var b := GunNames.random_build(_rng)
		var c := cost(current, b)
		if c <= have and value(b) > best_value:
			best = b
			best_value = value(b)
	money[bot.id] = have - cost(current, best)
	builds[bot.id] = best


@rpc("authority", "call_local", "reliable")
func _round_start(n: int, new_wins: Array, new_money: Dictionary, new_builds: Dictionary) -> void:
	round_no = n
	wins = new_wins.duplicate()
	money = new_money.duplicate()
	builds = new_builds.duplicate(true)
	phase = "build"
	phase_left = BUILD_TIME
	zone_open = false
	hold = [-1, 0.0]
	_show_ring(false)
	tm.scores = wins.duplicate()
	var main := tm.main
	main.death.hide_death()
	# Everyone back at their team's spawn, with the gun they own.
	var mine: Dictionary = builds.get(tm.my_id, Arsenal.STARTER)
	if Weapon.version_of(mine) != tm.player.weapon.version or not tm.player.alive:
		tm.player.equip(mine, GunNames.auto_name(mine, Arsenal.stats(mine)))
	tm.player.spawn_at(tm.spawn_point(tm.player.team, _slot(tm.my_id)))
	tm._announce_spawn()
	tm.player.input_enabled = not main.bench.visible and not main.settings_menu.visible
	if tm.player.input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if tm.net.is_host():
		var i := 0
		for b in tm.bots():
			var xf := tm.spawn_point(b.team, 3 + i)
			var keep: String = b.display_name
			b.spawn(xf.origin, 1000 + n * 31 + i)
			b.display_name = keep
			b.arm(builds.get(b.id, Arsenal.STARTER))
			b.frozen = true
			b.passive = tm.bots_passive
			tm.versions[b.id] = b.weapon.version
			tm._spawned.rpc(b.id, xf.origin, b.rotation.y, b.weapon.build, b.weapon.name)
			i += 1
	main.hud.show_hint("第 %d 回合　備戰 %d 秒：Tab 打開工作台買零件（資金 $%d）" % [n, int(BUILD_TIME), my_money()], 5.0)
	_round_began()
	tm.score_changed.emit()


## (hook) Host, before a round's money and guns go out.
func _before_round() -> void:
	pass


## (hook) Every machine, once a round's start has been applied.
func _round_began() -> void:
	pass


## (hook) Every machine, every tick of a running round (after the clock).
func _local_tick(_delta: float) -> void:
	pass


## (hook) Host, every tick of the fight: the overclock zone and the time limit.
func _fight_tick(delta: float) -> void:
	if not zone_open and phase_left <= ZONE_OPENS:
		_phase.rpc("fight", phase_left, true)
	if zone_open:
		_zone_tick(delta)
	if phase_left <= 0.0:
		var hp := [0.0, 0.0]
		for id in tm.entities:
			var e = tm.entities[id]
			if e != null and is_instance_valid(e) and e.alive:
				hp[int(e.team)] += float(e.health)
		var w := -1 if absf(hp[0] - hp[1]) < 0.5 else (0 if hp[0] > hp[1] else 1)
		_round_over(w, "時間到：剩下的血量比較多" if w >= 0 else "時間到：平手")


## (hook) Host, after a death in the fight: `alive` is the living count per team.
func _after_death(victim_team: int, alive: Array) -> void:
	if alive[victim_team] == 0:
		var w := 1 - victim_team
		_round_over(w if alive[w] > 0 else -1, "%s 全滅" % NetSession.TEAM_NAMES[victim_team])


## (hook) Every machine, when a round has been decided.
func _round_ended() -> void:
	pass


## (hook) Extra words for the HUD line.
func _note(_parts: Array) -> void:
	pass


## A stable spawn slot per player so a team doesn't stack on one point.
func _slot(id: String) -> int:
	var ids := tm.entities.keys()
	ids.sort()
	return ids.find(id)


func _physics_process(delta: float) -> void:
	if phase == "" or tm.over:
		return
	phase_left = maxf(phase_left - delta, 0.0)
	tm.time_left = phase_left
	if phase == "build":
		_hold_in_zone()
		var bench: Bench = tm.main.bench
		if bench.visible and phase_left < 0.4:
			bench.close()
	_local_tick(delta)
	if not tm.net.is_host():
		return
	match phase:
		"build":
			if phase_left <= 0.0:
				_phase.rpc("fight", ROUND_TIME, false)
		"fight":
			_fight_t += delta
			_fight_tick(delta)
		"end":
			if phase_left <= 0.0:
				if wins[0] >= target() or wins[1] >= target():
					phase = ""
					tm._end.rpc(0 if wins[0] > wins[1] else 1, wins)
				else:
					_next_round()


## During the build, nobody leaves their spawn zone.
func _hold_in_zone() -> void:
	var p := tm.player
	if not p.alive:
		return
	var at: Vector3 = tm.main.map.team_zones[p.team]
	var d := p.global_position - at
	var flat := Vector2(d.x, d.z)
	var r := TeamMatch.ZONE_RADIUS - 0.4
	if flat.length() > r:
		flat = flat.normalized() * r
		p.global_position = Vector3(at.x + flat.x, p.global_position.y, at.z + flat.y)
		p.velocity.x = 0.0
		p.velocity.z = 0.0


@rpc("authority", "call_local", "reliable")
func _phase(new_phase: String, seconds: float, zone: bool) -> void:
	var was := phase
	phase = new_phase
	phase_left = seconds
	if new_phase == "fight" and was == "build":
		_fight_t = 0.0
		if tm.main.bench.visible:
			tm.main.bench.close()
		for b in tm.bots():
			b.frozen = false
		tm.main.hud.callout("開打", "第 %d 回合" % round_no, Counterform.SULFUR)
	if zone and not zone_open:
		zone_open = true
		_show_ring(true)
		tm.main.hud.show_hint("中央超頻區開了：只有你們隊站在裡面 %d 秒就贏下這回合" % int(ZONE_HOLD), 5.0)
	tm.score_changed.emit()


func _zone_tick(delta: float) -> void:
	var inside := [0, 0]
	var at := mid_zone()
	for id in tm.entities:
		var e = tm.entities[id]
		if e == null or not is_instance_valid(e) or not e.alive:
			continue
		var d: Vector3 = (e as Node3D).global_position - at
		if Vector2(d.x, d.z).length() <= ZONE_RADIUS and d.y > -1.0 and d.y < 4.0:
			inside[int(e.team)] += 1
	var team := -1
	if inside[0] > 0 and inside[1] == 0:
		team = 0
	elif inside[1] > 0 and inside[0] == 0:
		team = 1
	var before: float = hold[1]
	if team < 0:
		# Contested or empty: the count stays (contested) or drains (empty).
		if inside[0] == 0 and inside[1] == 0:
			hold[1] = maxf(float(hold[1]) - delta, 0.0)
	elif team == int(hold[0]):
		hold[1] = float(hold[1]) + delta
	else:
		hold = [team, delta]
	if int(floor(float(hold[1]) * 4.0)) != int(floor(before * 4.0)):
		_hold.rpc(hold[0], hold[1])
	if float(hold[1]) >= ZONE_HOLD:
		_round_over(int(hold[0]), "%s 佔住了超頻區" % NetSession.TEAM_NAMES[int(hold[0])])


@rpc("authority", "call_local", "unreliable_ordered")
func _hold(team: int, seconds: float) -> void:
	hold = [team, seconds]


## A death (host, from TeamMatch._died): pay the killer, then see if a team is out.
func on_death(victim_id: String, wire: Dictionary) -> void:
	if phase != "fight":
		return
	var victim_team := tm.team_of(victim_id)
	var killer := str(wire.get("attacker_id", ""))
	var lost: Dictionary = builds.get(victim_id, Arsenal.STARTER)
	builds[victim_id] = Arsenal.STARTER.duplicate(true)
	var pays := {}
	if killer != "" and killer != victim_id and tm.team_of(killer) != victim_team:
		pays[killer] = kill_pay(lost)
	for helper in wire.get("assist_ids", []):
		pays[str(helper)] = int(pays.get(str(helper), 0)) + ASSIST
	for id in pays:
		money[id] = mini(int(money.get(id, 0)) + int(pays[id]), MAX_MONEY)
	_paid.rpc(money, pays, value(lost))
	var alive := [0, 0]
	for id in tm.entities:
		var e = tm.entities[id]
		if e != null and is_instance_valid(e) and e.alive:
			alive[int(e.team)] += 1
	_after_death(victim_team, alive)


@rpc("authority", "call_local", "reliable")
func _paid(new_money: Dictionary, pays: Dictionary, salvage_of: int) -> void:
	money = new_money
	if pays.has(tm.my_id):
		var got := int(pays[tm.my_id])
		var note := "擊殺 $%d　拆件 $%d" % [KILL, got - KILL] if got >= KILL else "助攻"
		tm.main.hud.callout("+$%d" % got, note, Counterform.SULFUR)
	tm.score_changed.emit()


func _round_over(winner: int, why: String) -> void:
	if phase != "fight":
		return
	if winner >= 0:
		wins[winner] += 1
		_losses[winner] = 0
		_losses[1 - winner] += 1
	for id in tm.entities:
		var team := tm.team_of(id)
		var pay := 0
		if winner < 0:
			pay = LOSS
		elif team == winner:
			pay = WIN
		else:
			pay = loss_pay(int(_losses[team]))
		money[id] = mini(int(money.get(id, 0)) + pay, MAX_MONEY)
	_round_end.rpc(winner, why, wins, money)


@rpc("authority", "call_local", "reliable")
func _round_end(winner: int, why: String, new_wins: Array, new_money: Dictionary) -> void:
	phase = "end"
	phase_left = END_PAUSE
	wins = new_wins.duplicate()
	money = new_money.duplicate()
	tm.scores = wins.duplicate()
	zone_open = false
	_show_ring(false)
	_round_ended()
	var mine := tm.player.team
	var head := "平手" if winner < 0 else ("拿下這回合" if winner == mine else "輸掉這回合")
	last_result = why
	tm.main.hud.callout(head, "%s　%d ： %d" % [why, wins[mine], wins[1 - mine]],
		Counterform.SULFUR if winner == mine else (Counterform.DUST_WHITE if winner < 0 else FpUi.enemy_color()))
	if not tm.player.alive:
		tm.main.death.set_note("下一回合重來（這把槍沒了，從左輪開始）")
	tm.score_changed.emit()


# --- Buying ----------------------------------------------------------------------------

## Our bench closed on `build`: pay for it, or put the old gun back. The host has the
## last word (see _buy).
func request_buy(build: Dictionary, gun_name: String) -> void:
	var owned: Dictionary = builds.get(tm.my_id, Arsenal.STARTER)
	var c := cost(owned, build)
	var p := tm.player
	if c > my_money():
		p.equip(owned, GunNames.auto_name(owned, Arsenal.stats(owned)))
		tm.main.hud.show_hint("錢不夠：這次改裝要 $%d，你只有 $%d。槍沒有變" % [c, my_money()], 4.0)
		return
	p.equip(build, gun_name)
	if c != 0:
		tm.main.hud.show_hint(("付了 $%d" if c > 0 else "賣零件拿回 $%d") % absi(c) + "　剩 $%d" % (my_money() - c), 3.0)
	if tm.net.is_host():
		_take(tm.my_id, build)
	else:
		money[tm.my_id] = my_money() - c
		builds[tm.my_id] = Arsenal.clean(build)
		_buy.rpc_id(1, build)


@rpc("any_peer", "reliable")
func _buy(build: Dictionary) -> void:
	if not tm.net.is_host():
		return
	var id := "p%d" % multiplayer.get_remote_sender_id()
	if not _take(id, build):
		_refused.rpc_id(multiplayer.get_remote_sender_id(), builds.get(id, Arsenal.STARTER), money.get(id, 0))


## The host takes the money for `id`'s new gun. False when it can't (no money, too late).
func _take(id: String, build: Dictionary) -> bool:
	var clean := Arsenal.clean(build)
	var ok_time := phase == "build" or (phase == "fight" and _fight_t <= BUY_GRACE)
	var c := cost(builds.get(id, Arsenal.STARTER), clean)
	if not ok_time or c > int(money.get(id, 0)):
		return false
	money[id] = int(money.get(id, 0)) - c
	builds[id] = clean
	_paid.rpc(money, {}, 0)
	return true


@rpc("authority", "reliable")
func _refused(build: Dictionary, have: int) -> void:
	builds[tm.my_id] = build
	money[tm.my_id] = have
	tm.player.equip(build, GunNames.auto_name(build, Arsenal.stats(build)))
	tm.main.hud.show_hint("房主沒收下這次改裝（太晚或錢不夠），換回原本的槍", 4.0)


# --- Looks -----------------------------------------------------------------------------

func _show_ring(on: bool) -> void:
	if _ring != null:
		_ring.queue_free()
		_ring = null
	if not on:
		return
	_ring = Node3D.new()
	_ring.name = "OverclockZone"
	tm.main.map.add_child(_ring)
	_ring.global_position = mid_zone() + Vector3(0, 0.04, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(Counterform.SULFUR, 0.85)
	var ring := MeshInstance3D.new()
	ring.mesh = SafeZone._ring_mesh(ZONE_RADIUS - 0.3, ZONE_RADIUS, 48)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(ring)
	var fill := MeshInstance3D.new()
	fill.mesh = SafeZone._ring_mesh(0.0, ZONE_RADIUS - 0.3, 48)
	var mf := m.duplicate() as StandardMaterial3D
	mf.albedo_color = Color(Counterform.SULFUR, 0.12)
	fill.material_override = mf
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(fill)
	# A tall thin column of light so the zone reads from across the map.
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 14.0
	beam.mesh = cyl
	var mb := m.duplicate() as StandardMaterial3D
	mb.albedo_color = Color(Counterform.SULFUR, 0.45)
	beam.material_override = mb
	beam.position = Vector3(0, 7.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(beam)


## The HUD's line under the round score: phase, money, the zone.
func bar_note() -> String:
	var parts := ["第 %d 回合" % round_no]
	match phase:
		"build":
			parts.append("備戰")
		"end":
			parts.append(last_result)
	_note(parts)
	parts.append("$%d" % my_money())
	if zone_open and int(hold[0]) >= 0 and float(hold[1]) > 0.0:
		parts.append("超頻區 %s %.0f/%d" % [NetSession.TEAM_NAMES[int(hold[0])], float(hold[1]), int(ZONE_HOLD)])
	elif zone_open:
		parts.append("超頻區開放")
	return "　".join(parts)
