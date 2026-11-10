class_name CardRules
extends RoundRules
## 超規卡 OVERRULE (C11): 預算戰's rounds and money (RoundRules) with rule-breaking cards
## (Augments). Every round's build starts with a pick:
##
##   pick      OFFER cards to choose one from (OFFER_BEHIND for the team that lost the
##             round before). REROLLS fresh hands a match. Not picked when the fight
##             starts? You get one of them at random. Cards stay for the whole match, dead
##             or alive, and ride inside the gun (Augments.stamp), so the bench and the
##             referee see them too.
##   steal     a kill takes one card from the victim (one the killer doesn't have, while
##             the killer has room): the kill feed shows it under the kill.
##   resonance three cards of one kind light that kind's 共鳴.
##
## The host owns the cards: it deals the hands, takes the picks, decides the steals and
## sends everyone the whole table (_sync). Each machine puts the new cards on the guns it
## runs (its player; the host its bots) and says so with the usual loadout message.

const BUILD := 22.0
const REROLLS := 2

## id -> [card ids] (the host's word; everyone gets copies).
var cards := {}
## Host: id -> the hand it may pick from this round.
var offers := {}
## Host: id -> rerolls left.
var rerolls := {}
## Local: our hand this round (empty once picked).
var my_offer: Array = []
var my_rerolls := REROLLS
var picker: CardPicker
var strip: CardStrip
var _behind := -1
var _card_rng := RandomNumberGenerator.new()


func _init() -> void:
	super()
	name = "Rounds"
	_card_rng.seed = 7741


func _ready() -> void:
	var ui: CanvasLayer = tm.main._ui
	picker = CardPicker.new()
	picker.picked.connect(_ask_pick)
	picker.reroll.connect(_ask_reroll)
	ui.add_child(picker)
	strip = CardStrip.new()
	tm.main.hud.add_child(strip)


func _exit_tree() -> void:
	if is_instance_valid(picker):
		picker.queue_free()
	if is_instance_valid(strip):
		strip.queue_free()


func build_time() -> float:
	return BUILD


func cards_of(id: String) -> Array:
	return cards.get(id, [])


func my_cards() -> Array:
	return cards_of(tm.my_id)


## Is the picker up? (Main keeps the cursor out for it.)
func picking() -> bool:
	return is_instance_valid(picker) and picker.visible


# --- Dealing (host) --------------------------------------------------------------------

func _before_round() -> void:
	offers.clear()
	for id in tm.entities:
		if not cards.has(id):
			cards[id] = []
		if not rerolls.has(id):
			rerolls[id] = REROLLS
		var held: Array = cards[id]
		if held.size() >= Augments.MAX_CARDS:
			continue
		var n := Augments.OFFER_BEHIND if _behind >= 0 and tm.team_of(id) == _behind else Augments.OFFER
		offers[id] = Augments.offer(_card_rng, held, n)
	# Bots pick at once, so their guns go out with the new card on.
	for b in tm.bots():
		if offers.has(b.id):
			var pick := Augments.bot_pick(_card_rng, cards[b.id], offers[b.id])
			offers.erase(b.id)
			if pick != "":
				(cards[b.id] as Array).append(pick)
	for id in builds:
		builds[id] = Augments.stamp(builds[id], cards_of(id))


func _bot_shop(bot: Bot) -> void:
	super(bot)
	builds[bot.id] = Augments.stamp(builds[bot.id], cards_of(bot.id))


func start() -> void:
	if tm.net.is_host():
		for id in tm.entities:
			builds[id] = Arsenal.STARTER.duplicate(true)
	super()


func _round_began() -> void:
	if tm.net.is_host():
		_sync.rpc(cards, "", "", "")
		for id in offers:
			_send_offer(id)


func _send_offer(id: String) -> void:
	var peer := tm.owner_of(id)
	if peer == tm.net.my_id():
		_offer(offers.get(id, []), int(rerolls.get(id, 0)))
	elif peer > 0:
		_offer.rpc_id(peer, offers.get(id, []), int(rerolls.get(id, 0)))


@rpc("authority", "reliable")
func _offer(hand: Array, left: int) -> void:
	my_offer = hand.duplicate()
	my_rerolls = left
	if my_offer.is_empty():
		return
	picker.show_offer(my_offer, my_rerolls, my_cards(), phase_left)
	tm.player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Host: `id` takes `card` from its hand.
func _host_pick(id: String, card: String) -> void:
	var hand: Array = offers.get(id, [])
	if not card in hand:
		return
	offers.erase(id)
	var held: Array = cards.get(id, [])
	if card in held or held.size() >= Augments.MAX_CARDS:
		return
	held.append(card)
	cards[id] = held
	builds[id] = Augments.stamp(builds.get(id, Arsenal.STARTER), held)
	_sync.rpc(cards, "pick", id, card)


@rpc("any_peer", "reliable")
func _pick(card: String) -> void:
	if tm.net.is_host():
		_host_pick("p%d" % multiplayer.get_remote_sender_id(), card)


func _host_reroll(id: String) -> void:
	if not offers.has(id) or int(rerolls.get(id, 0)) <= 0 or phase != "build":
		return
	rerolls[id] = int(rerolls[id]) - 1
	var n := (offers[id] as Array).size()
	# A fresh hand without the cards just shown.
	var avoid: Array = (cards_of(id) as Array) + (offers[id] as Array)
	var hand := Augments.offer(_card_rng, avoid, n)
	if hand.size() < n:
		hand = Augments.offer(_card_rng, cards_of(id), n)
	offers[id] = hand
	_send_offer(id)


@rpc("any_peer", "reliable")
func _reroll() -> void:
	if tm.net.is_host():
		_host_reroll("p%d" % multiplayer.get_remote_sender_id())


func _ask_pick(card: String) -> void:
	my_offer = []
	_close_picker()
	if tm.net.is_host():
		_host_pick(tm.my_id, card)
	else:
		_pick.rpc_id(1, card)


func _ask_reroll() -> void:
	if tm.net.is_host():
		_host_reroll(tm.my_id)
	else:
		_reroll.rpc_id(1)


func _close_picker() -> void:
	if picker.visible:
		picker.close()
		if tm.player.alive and not tm.main.mouse_free():
			tm.main.resume_play()


func _local_tick(_delta: float) -> void:
	if picker.visible:
		picker.set_time(phase_left if phase == "build" else 0.0)
		if phase != "build":
			# Too late: the host deals one at random (below).
			my_offer = []
			_close_picker()
	if tm.net.is_host() and phase == "fight" and not offers.is_empty():
		for id in offers.keys():
			var hand: Array = offers[id]
			if hand.is_empty():
				offers.erase(id)
			else:
				_host_pick(id, str(hand[_card_rng.randi_range(0, hand.size() - 1)]))


# --- Everyone gets the table -----------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _sync(table: Dictionary, event: String, who: String, card: String, other := "") -> void:
	var before_res := Augments.resonances(my_cards())
	cards = table.duplicate(true)
	var mine := my_cards()
	builds[tm.my_id] = Augments.stamp(builds.get(tm.my_id, tm.player.weapon.build), mine)
	var p := tm.player
	if (p.weapon.build.get("cards", []) as Array) != mine:
		p.weapon.set_cards(mine)
		p.mobility = Player.mobility_of(p.weapon.stats)
		p.weapon_changed.emit()
	if tm.net.is_host():
		for b in tm.bots():
			var bc := cards_of(b.id)
			if (b.weapon.build.get("cards", []) as Array) != bc:
				b.weapon.set_cards(bc)
				tm.versions[b.id] = b.weapon.version
				tm._loadout.rpc(b.id, b.weapon.build, b.weapon.name)
	strip.show_cards(mine)
	var hud: Hud = tm.main.hud
	match event:
		"pick":
			if who == tm.my_id:
				var c := Augments.card(card)
				hud.callout(str(c.name), Augments.kind_name(str(c.kind)), Augments.color(str(c.kind)))
		"steal":
			var c := Augments.card(card)
			hud.feed.add_steal(tm._name_of(who), 0 if tm.team_of(who) == p.team else 1, str(c.name),
				Augments.color(str(c.kind)), tm._name_of(other), 0 if tm.team_of(other) == p.team else 1,
				who == tm.my_id or other == tm.my_id)
			if who == tm.my_id:
				hud.callout("奪走【%s】" % c.name, "從 %s 身上" % tm._name_of(other), Augments.color(str(c.kind)))
			elif other == tm.my_id:
				tm.main.death.set_note("你的【%s】被 %s 奪走了" % [c.name, tm._name_of(who)])
	for k in Augments.resonances(mine):
		if not k in before_res:
			hud.callout("共鳴：%s" % Augments.RESONANCE[k].name, Augments.RESONANCE[k].desc, Augments.color(k))
	tm.score_changed.emit()


# --- Kills steal -----------------------------------------------------------------------

func on_death(victim_id: String, wire: Dictionary) -> void:
	var was_fight := phase == "fight"
	super(victim_id, wire)
	builds[victim_id] = Augments.stamp(builds.get(victim_id, Arsenal.STARTER), cards_of(victim_id))
	if not was_fight:
		return
	var killer := str(wire.get("attacker_id", ""))
	if killer == "" or killer == victim_id or tm.team_of(killer) == tm.team_of(victim_id):
		return
	var theirs: Array = cards_of(victim_id)
	var mine: Array = cards_of(killer)
	if mine.size() >= Augments.MAX_CARDS:
		return
	var can := []
	for c in theirs:
		if not c in mine:
			can.append(c)
	if can.is_empty():
		return
	var card := str(can[_card_rng.randi_range(0, can.size() - 1)])
	theirs.erase(card)
	mine.append(card)
	cards[victim_id] = theirs
	cards[killer] = mine
	builds[victim_id] = Augments.stamp(builds.get(victim_id, Arsenal.STARTER), theirs)
	builds[killer] = Augments.stamp(builds.get(killer, Arsenal.STARTER), mine)
	_sync.rpc(cards, "steal", killer, card, victim_id)


func _round_ended() -> void:
	_close_picker()


func _round_over(winner: int, why: String) -> void:
	if phase == "fight":
		_behind = 1 - winner if winner >= 0 else -1
	super(winner, why)


# --- Buying keeps the cards ------------------------------------------------------------

func request_buy(build: Dictionary, gun_name: String) -> void:
	super(Augments.stamp(build, my_cards()), gun_name)


func _take(id: String, build: Dictionary) -> bool:
	return super(id, Augments.stamp(build, cards_of(id)))


func _note(parts: Array) -> void:
	var mine := my_cards()
	if not mine.is_empty():
		parts.append("卡 %d" % mine.size())
