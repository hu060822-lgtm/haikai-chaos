class_name Melee
## Melee weapons (C13): one on everyone's belt next to the gun, the class and the
## throwables, on the melee key (Z). A swing is quick and always there, so it's the answer
## when someone lands right on top of you, comes round a corner, or you slide into them.
## Every one hits harder the faster you're moving when it lands (MOMENTUM), so the
## movement tech feeds it: a slide, a wall-run jump or a grapple straight into a swing.
##
##   knife   戰術刀    fast; from behind it kills (BACKSTAB)
##   axe     消防斧    slow and heavy; chops through doors, cover and shield walls
##   sledge  鐵鎚      knocks whoever it hits flying
##   baton   電擊棍    light, but the hit staggers and slows
##   sickle  鎖鐮      a chain: reaches twice as far and pulls them in, bleeding
##   fist    推進拳套  the swing throws you forward with it (a lunge you can chain)
##
## The choice is saved like the class (Settings.melee) and picked on the bench.

const IDS := ["knife", "axe", "sledge", "baton", "sickle", "fist"]
const DEFAULT := "knife"
## A swing's arc: targets within this cosine of where you look, and this far past `reach`
## for the body's width.
const CONE := 0.55
const BODY := 0.45
## + this much damage per m/s you're moving faster than RUN when it lands, up to MAX_BONUS.
const RUN := 6.0
const MOMENTUM := 0.04
const MAX_BONUS := 0.6
## From behind (the knife): their facing and yours this close (cosine).
const BEHIND := 0.45

## id -> name, English tag, damage, reach (m), wind-up (s, the hit lands after it),
## recovery (s, before the next swing), what it does on a hit (effects, as a gun part's),
## damage to structures, the lunge it gives you (m/s), backstab damage, colour, use, counter.
const INFO := {
	"knife": {"name": "戰術刀", "tag": "KNIFE", "damage": 45.0, "reach": 2.0, "windup": 0.08, "recover": 0.32,
		"effects": {}, "structure": 40.0, "lunge": 0.0, "backstab": 150.0, "color": Color("#C9CDD2"),
		"use": "最快的一刀（0.4 秒一下）。從背後捅＝一刀斃命。",
		"counter": "正面只有 45 傷害；別讓人繞到背後；手長的近戰武器打得到它打不到的距離。"},
	"axe": {"name": "消防斧", "tag": "AXE", "damage": 90.0, "reach": 2.4, "windup": 0.28, "recover": 0.72,
		"effects": {}, "structure": 400.0, "lunge": 0.0, "backstab": 0.0, "color": Color("#D0533A"),
		"use": "重劈 90 傷害；一斧就劈開門、劈碎掩體和護盾牆。",
		"counter": "舉斧 0.28 秒看得到；揮空後要 0.7 秒才能再揮，趁那時候打它。"},
	"sledge": {"name": "鐵鎚", "tag": "SLEDGE", "damage": 60.0, "reach": 2.3, "windup": 0.22, "recover": 0.68,
		"effects": {"knock": 7.0}, "structure": 220.0, "lunge": 0.0, "backstab": 0.0, "color": Color("#8E8A80"),
		"use": "60 傷害，把人整個敲飛（往你揮的方向，還會往上）。敲下平台、敲出煙霧都好用。",
		"counter": "被敲飛時一樣能開槍、衝刺、蹬牆；鎚子很慢。"},
	"baton": {"name": "電擊棍", "tag": "BATON", "damage": 30.0, "reach": 2.1, "windup": 0.1, "recover": 0.45,
		"effects": {"stagger": 0.6, "slow": 1.2}, "structure": 30.0, "lunge": 0.0, "backstab": 0.0, "color": Color("#5FA8D3"),
		"use": "傷害低（30），但打中就讓對方失衡 0.6 秒、減速 1.2 秒：電完再開槍。",
		"counter": "失衡很短，不會讓你完全動不了；它自己打不死人。"},
	"sickle": {"name": "鎖鐮", "tag": "SICKLE", "damage": 35.0, "reach": 4.2, "windup": 0.18, "recover": 0.7,
		"effects": {"knock": -4.0, "bleed": 2.0}, "structure": 30.0, "lunge": 0.0, "backstab": 0.0, "color": Color("#B59A5C"),
		"use": "甩出鎖鏈，4.2 m 內都打得到：35 傷害，把人往你這裡拉，還會流血 2 秒。",
		"counter": "只有一條直線，偏一點就甩空；被拉過來時直接回打它。"},
	"fist": {"name": "推進拳套", "tag": "FIST", "damage": 50.0, "reach": 2.2, "windup": 0.06, "recover": 0.6,
		"effects": {"knock": 3.0}, "structure": 60.0, "lunge": 11.0, "backstab": 0.0, "color": Color("#E0B04A"),
		"use": "出拳時噴射把你往前推（每拳 11 m/s，空中也行）：50 傷害加小擊退。可以拿來衝刺接衝刺。",
		"counter": "衝過來的路線是直的；揮空就停在你面前。"},
}


static func info(id: String) -> Dictionary:
	return INFO.get(id, INFO[DEFAULT])


static func valid(id: String) -> String:
	return id if INFO.has(id) else DEFAULT


static func label(id: String) -> String:
	var i := info(id)
	return "%s %s" % [i.name, i.tag]


## The most one swing of `id` can do (for the host's judge): the backstab, or a full-speed hit.
static func max_damage(id: String) -> float:
	var i := info(id)
	return maxf(float(i.backstab), float(i.damage) * (1.0 + MAX_BONUS))


## The farthest a swing of `id` reaches, to the middle of a body.
static func reach(id: String) -> float:
	return float(info(id).reach) + BODY


## The damage a hit does at `speed` m/s.
static func damage_at(id: String, speed: float) -> float:
	return float(info(id).damage) * (1.0 + clampf((speed - RUN) * MOMENTUM, 0.0, MAX_BONUS))
