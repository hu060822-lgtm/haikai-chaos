class_name Augments
extends RefCounted
## 超規卡 OVERRULE (C11): the cards of the card mode (CardRules). A card breaks one rule of
## the game for whoever holds it, for the rest of the match. Three kinds:
##
##   gun    槍卡    changes how the gun's rounds behave (bounce, pierce, chain, burn...)
##   move   身法卡  ties the gun to the movement (wall jumps load rounds, faster legs...)
##   trade  交易卡  a big upside with a price written on the card (glass, can't aim...)
##
## Three cards of one kind light that kind's 共鳴 (RESONANCE), an extra effect on top.
##
## A card is data: stat multipliers ("x"), effects ("fx", the same effect words the parts
## use, plus a few card-only ones Player and Bot read: tough, mobility, spring,
## walljump_feed, extra_dash, no_aim) and, on trade cards, the price ("down_x",
## "down_fx"). The cards ride inside the build ("cards": [ids]), so Arsenal.stats gives
## every machine (the shooter, the host's referee, the victim) the same numbers.

const MAX_CARDS := 10
const OFFER := 3
## The team that lost the round before picks from one card more.
const OFFER_BEHIND := 4
const RESONANCE_AT := 3

const KINDS := {
	"gun": {"name": "槍卡", "color": Color("#D9774F")},
	"move": {"name": "身法卡", "color": Color("#7FB7A8")},
	"trade": {"name": "交易卡", "color": Color("#C9A43A")},
}

const RESONANCE := {
	"gun": {"name": "異形化", "desc": "傷害 ×1.15，子彈穿過人體，再多反彈一次"},
	"move": {"name": "無重力", "desc": "移動 ×1.1，多一格衝刺，每次命中都把空中蹬牆次數補滿"},
	"trade": {"name": "債務重組", "desc": "所有交易卡的代價減半（不能瞄準、自爆之類的直接取消）"},
}

## Effects that add up across cards (the rest: the bigger one wins, like parts).
const ADD_FX := ["ricochet", "chain", "tough", "extra_dash", "walljump_feed"]
## Effects that multiply across cards (start at 1.0).
const MUL_FX := ["mobility", "spring"]

const CARDS := {
	# --- 槍卡 -------------------------------------------------------------------------
	"bounce_rounds": {"name": "撞牆不死", "kind": "gun", "desc": "子彈撞到牆會再反彈兩次",
		"fx": {"ricochet": 2}},
	"needle": {"name": "一路穿到底", "kind": "gun", "desc": "子彈穿過人體繼續飛，穿透 ×1.5",
		"x": {"pen": 1.5}, "fx": {"pierce": true}},
	"arc_link": {"name": "導電彈", "kind": "gun", "desc": "命中後電弧跳到附近兩個人身上（半傷）",
		"fx": {"chain": 2}},
	"crackers": {"name": "鞭炮彈頭", "kind": "gun", "desc": "子彈落點會炸開（半徑 1.6 m），單發傷害 ×0.8",
		"x": {"damage": 0.8}, "fx": {"explode": 1.6}},
	"sniffer": {"name": "嗅覺晶片", "kind": "gun", "desc": "準星 6 度內看得到的敵人，子彈自己轉彎過去",
		"fx": {"homing": 6.0}},
	"stutter": {"name": "口吃", "kind": "gun", "desc": "每一槍 0.2 秒後在原地再開一次（半傷，不耗彈）",
		"fx": {"echo": 0.5}},
	"free_third": {"name": "第三發免費", "kind": "gun", "desc": "每三發有一發不扣彈匣",
		"fx": {"ghost": 3}},
	"deep_pockets": {"name": "雙倍口袋", "kind": "gun", "desc": "彈匣與備彈 ×2",
		"x": {"mag": 2.0, "reserve": 2.0}},
	"quick_hands": {"name": "快手", "kind": "gun", "desc": "換彈時間 ×0.5",
		"x": {"reload": 0.5}},
	"hair_trigger": {"name": "神經扳機", "kind": "gun", "desc": "射速 ×1.35，後座 ×1.2",
		"x": {"rate": 1.35, "recoil": 1.2}},
	"verdict": {"name": "判決", "kind": "gun", "desc": "爆頭 ×3，打身體 ×0.75",
		"fx": {"headhunter": true}},
	"embers": {"name": "餘燼", "kind": "gun", "desc": "命中會讓人燒 3 秒",
		"fx": {"burn": 3.0}},
	"tattle": {"name": "告密彈", "kind": "gun", "desc": "被你打中的人 4 秒內隔牆可見",
		"fx": {"mark": 4.0}},
	"wake": {"name": "送行", "kind": "gun", "desc": "殺掉的人原地爆炸（半徑 4 m）",
		"fx": {"kill_explode": 4.0}},
	"tithe": {"name": "什一稅", "kind": "gun", "desc": "造成傷害的 25% 補回自己的血",
		"fx": {"leech": 0.25}},
	"rhythm": {"name": "節拍器", "kind": "gun", "desc": "連續命中每次傷害 +8%（最多五層），沒打中就歸零",
		"fx": {"streak": 0.08}},
	"split": {"name": "分裂彈", "kind": "gun", "desc": "每一發變兩顆彈丸，每顆傷害 ×0.6",
		"x": {"pellets": 2.0, "damage": 0.6, "spread": 1.3}},
	"magnet": {"name": "磁鐵彈", "kind": "gun", "desc": "打中的人被往你這邊拉",
		"fx": {"knock": -3.0}},
	# --- 身法卡 -----------------------------------------------------------------------
	"wall_loader": {"name": "蹬牆上膛", "kind": "move", "desc": "每次蹬牆跳，塞 3 發子彈進彈匣",
		"fx": {"walljump_feed": 3}},
	"slide_loader": {"name": "滑鏟上膛", "kind": "move", "desc": "滑鏟的瞬間彈匣直接裝滿",
		"fx": {"slide_reload": true}},
	"dash_loader": {"name": "衝刺上膛", "kind": "move", "desc": "每次衝刺補半個彈匣",
		"fx": {"dash_feed": 0.5}},
	"wall_drip": {"name": "牆跑滴彈", "kind": "move", "desc": "牆跑時每 0.25 秒補一發",
		"fx": {"wall_feed": 0.25}},
	"featherweight": {"name": "羽量級", "kind": "move", "desc": "所有移動速度 ×1.15",
		"fx": {"mobility": 1.15}},
	"third_dash": {"name": "第三格衝刺", "kind": "move", "desc": "衝刺多一格",
		"fx": {"extra_dash": 1}},
	"kite": {"name": "風箏", "kind": "move", "desc": "空中瞄準時幾乎不往下掉",
		"fx": {"glide": 0.25}},
	"skyshot": {"name": "空對地", "kind": "move", "desc": "腳不著地時傷害 ×1.35",
		"fx": {"air_bonus": 1.35}},
	"velocity_tax": {"name": "速度稅", "kind": "move", "desc": "跑得越快打得越痛（最高 ×1.6）",
		"fx": {"speed_bonus": 0.6}},
	"hit_charge": {"name": "命中充電", "kind": "move", "desc": "每次命中充 1/4 格衝刺",
		"fx": {"hit_dash": 0.25}},
	"reset": {"name": "重置", "kind": "move", "desc": "擊殺後衝刺全滿，命中補滿空中蹬牆次數",
		"fx": {"kill_dash": true, "kick_refill": true}},
	"adrenaline": {"name": "腎上腺", "kind": "move", "desc": "命中後 1.5 秒跑得更快",
		"fx": {"rush": 1.5}},
	"recoil_jet": {"name": "後座噴射", "kind": "move", "desc": "每一槍把你往反方向推（可以拿來飛）",
		"fx": {"recoil_push": 4.0}},
	"zipline": {"name": "滑索彈", "kind": "move", "desc": "子彈打到哪，你就被拉過去一點",
		"fx": {"grapple": 6.0}},
	"spring_legs": {"name": "彈簧腿", "kind": "move", "desc": "跳躍與蹬牆跳的高度 ×1.3",
		"fx": {"spring": 1.3}},
	# --- 交易卡 -----------------------------------------------------------------------
	"glass_cannon": {"name": "玻璃大砲", "kind": "trade", "desc": "傷害 ×1.6",
		"cost": "受到的傷害也 ×1.6", "fx": {"glass": 1.6}},
	"coin_flip": {"name": "擲硬幣", "kind": "trade", "desc": "射速 ×1.25",
		"cost": "每發傷害隨機 ×0.4～×2.2", "x": {"rate": 1.25}, "down_fx": {"gamble": true}},
	"last_word": {"name": "遺言", "kind": "trade", "desc": "彈匣最後一發傷害 ×3",
		"cost": "彈匣 ×0.6", "fx": {"last_round": 3.0}, "down_x": {"mag": 0.6}},
	"tank": {"name": "鐵皮", "kind": "trade", "desc": "受到的傷害 ×0.65",
		"cost": "移動速度 ×0.82", "fx": {"tough": 0.35}, "down_fx": {"mobility": 0.82}},
	"cornered": {"name": "困獸", "kind": "trade", "desc": "血量低於 40 時傷害 ×1.8",
		"cost": "受到的傷害 ×1.15", "fx": {"low_hp": 1.8}, "down_fx": {"tough": -0.15}},
	"cold_open": {"name": "冷開場", "kind": "trade", "desc": "停火 2 秒後的第一槍傷害 ×2.5",
		"cost": "射速 ×0.75", "fx": {"first_shot": 2.5}, "down_x": {"rate": 0.75}},
	"brute": {"name": "莽夫", "kind": "trade", "desc": "傷害 ×1.5",
		"cost": "不能瞄準（只能腰射）", "x": {"damage": 1.5}, "down_fx": {"no_aim": true}},
	"nobody": {"name": "無名氏", "kind": "trade", "desc": "擊殺列只顯示「？？？」，傷害 ×1.1",
		"cost": "備彈 ×0.5", "x": {"damage": 1.1}, "fx": {"anonymous": true}, "down_x": {"reserve": 0.5}},
	"furnace": {"name": "鍋爐", "kind": "trade", "desc": "槍越燙傷害越高（最高 ×2）",
		"cost": "每發 +5% 熱量，會過熱", "fx": {"heat_bonus": 1.0}, "down_x": {"cooling": 0.7}, "down_add": {"heat": 0.05}},
	"parting_gift": {"name": "臨別贈禮", "kind": "trade", "desc": "換彈時把舊彈匣丟出去爆炸",
		"cost": "換彈時間 ×1.4", "fx": {"mag_bomb": 3.5}, "down_x": {"reload": 1.4}},
	"pain_loader": {"name": "痛覺供彈", "kind": "trade", "desc": "每受 10 點傷害補一發子彈",
		"cost": "受到的傷害 ×1.2", "fx": {"pain_feed": true}, "down_fx": {"tough": -0.2}},
	"wind_up": {"name": "暖機", "kind": "trade", "desc": "連射時射速一路爬到 ×2",
		"cost": "散布 ×1.3", "fx": {"spool": 1.0}, "down_x": {"spread": 1.3, "moa": 1.3}},
	"firehose": {"name": "消防水管", "kind": "trade", "desc": "射速 ×2.2，彈匣 ×1.5",
		"cost": "每發傷害 ×0.7，換彈時間 ×2", "x": {"rate": 2.2, "mag": 1.5}, "down_x": {"damage": 0.7, "reload": 2.0}},
	"one_and_done": {"name": "一發入魂", "kind": "trade", "desc": "傷害 ×2.6，換彈 ×0.6",
		"cost": "彈匣只剩 1 發", "x": {"damage": 2.6, "reload": 0.6}, "down_x": {"mag": 0.01}},
}


static func valid(id: String) -> bool:
	return CARDS.has(id)


static func card(id: String) -> Dictionary:
	return CARDS.get(id, {})


static func kind_of(id: String) -> String:
	return str(card(id).get("kind", ""))


static func kind_name(kind: String) -> String:
	return str(KINDS.get(kind, {}).get("name", kind))


static func color(kind: String) -> Color:
	return KINDS.get(kind, {}).get("color", Color.WHITE)


## Only real cards, each once, at most MAX_CARDS, in the order held.
static func clean(list: Variant) -> Array:
	var out := []
	if not (list is Array):
		return out
	for id in list:
		var s := str(id)
		if valid(s) and not s in out and out.size() < MAX_CARDS:
			out.append(s)
	return out


## kind -> how many of `cards` are that kind.
static func counts(cards: Array) -> Dictionary:
	var c := {"gun": 0, "move": 0, "trade": 0}
	for id in cards:
		var k := kind_of(str(id))
		if c.has(k):
			c[k] += 1
	return c


## The kinds whose resonance is lit.
static func resonances(cards: Array) -> Array:
	var out := []
	var c := counts(cards)
	for k in ["gun", "move", "trade"]:
		if int(c[k]) >= RESONANCE_AT:
			out.append(k)
	return out


## Puts `cards` on a build (a copy); an empty list takes them off.
static func stamp(build: Dictionary, cards: Array) -> Dictionary:
	var b := build.duplicate(true)
	var c := clean(cards)
	if c.is_empty():
		b.erase("cards")
	else:
		b.cards = c
	return b


## `n` cards nobody holding `held` has yet, drawn with `rng`.
static func offer(rng: RandomNumberGenerator, held: Array, n: int) -> Array:
	var pool := []
	for id in CARDS:
		if not id in held:
			pool.append(id)
	var out := []
	while out.size() < n and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


## What a bot takes from an offer: whatever brings a resonance closest, else at random.
static func bot_pick(rng: RandomNumberGenerator, held: Array, offered: Array) -> String:
	if offered.is_empty():
		return ""
	var c := counts(held)
	var best := ""
	var best_n := -1
	for id in offered:
		var n := int(c.get(kind_of(str(id)), 0))
		if n < RESONANCE_AT and n > best_n:
			best_n = n
			best = str(id)
	if best != "" and rng.randf() < 0.7:
		return best
	return str(offered[rng.randi_range(0, offered.size() - 1)])


## The cards' changes, on finished part stats (Arsenal.stats, before rounding).
static func apply(s: Dictionary, list: Variant) -> void:
	var cards := clean(list)
	s.cards = cards
	if cards.is_empty():
		return
	var lit := resonances(cards)
	var soft := "trade" in lit
	for id in cards:
		var c := card(id)
		for stat in c.get("x", {}):
			s[stat] = float(s[stat]) * float(c.x[stat])
		for stat in c.get("down_x", {}):
			var m := float(c.down_x[stat])
			s[stat] = float(s[stat]) * (lerpf(1.0, m, 0.5) if soft else m)
		for stat in c.get("down_add", {}):
			s[stat] = float(s[stat]) + float(c.down_add[stat]) * (0.5 if soft else 1.0)
		for e in c.get("fx", {}):
			_merge(s.effects, e, c.fx[e])
		for e in c.get("down_fx", {}):
			var v = c.down_fx[e]
			if soft:
				if v is bool:
					continue
				v = lerpf(1.0, float(v), 0.5) if e in MUL_FX else float(v) * 0.5
			_merge(s.effects, e, v)
	if "gun" in lit:
		s.damage = float(s.damage) * 1.15
		_merge(s.effects, "pierce", true)
		_merge(s.effects, "ricochet", 1)
	if "move" in lit:
		_merge(s.effects, "mobility", 1.1)
		_merge(s.effects, "extra_dash", 1)
		_merge(s.effects, "kick_refill", true)
	s.effects.tough = clampf(float(s.effects.get("tough", 0.0)), -0.6, 0.6)
	if is_zero_approx(float(s.effects.tough)):
		s.effects.erase("tough")
	s.resonance = lit


static func _merge(fx: Dictionary, e: String, v: Variant) -> void:
	if e in ADD_FX:
		fx[e] = (fx.get(e, 0) + v) if (v is int and fx.get(e, 0) is int) else float(fx.get(e, 0.0)) + float(v)
	elif e in MUL_FX:
		fx[e] = float(fx.get(e, 1.0)) * float(v)
	elif fx.has(e) and v is float and fx[e] is float:
		# A pull beats a shove (like the parts); otherwise the stronger wins.
		fx[e] = minf(fx[e], v) if e == "knock" and v < 0.0 else maxf(fx[e], v)
	elif fx.has(e) and e == "ghost":
		fx[e] = mini(int(fx[e]), int(v))
	else:
		fx[e] = v


## Damage taken, after the victim's own cards (tough; glass is the parts' and Player's).
static func taken(amount: float, victim_fx: Dictionary) -> float:
	return amount * (1.0 - float(victim_fx.get("tough", 0.0)))


## One line for a card: "撞牆不死（槍卡）：子彈撞到牆會再反彈兩次".
static func line(id: String) -> String:
	var c := card(id)
	var t := "%s（%s）：%s" % [c.get("name", id), kind_name(str(c.get("kind", ""))), c.get("desc", "")]
	if c.has("cost"):
		t += "　代價：%s" % c.cost
	return t
