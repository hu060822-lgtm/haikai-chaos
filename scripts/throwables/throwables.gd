class_name Throwables
## Throwables (C12): what everyone carries on the belt next to the gun and the class.
## The gun stays the star; a throwable opens a short window, the same as an ability.
##
##   frag    破片手雷  bounces, blows up FUSE seconds after the pin (hold to cook it)
##   flash   閃光彈    blinds whoever is looking at it, thrower included
##   sticky  黏彈      sticks to the first thing it touches, a wall or a person
##   mine    絆雷      sticks where it lands: on a wall it draws a laser line, on a floor
##                     it waits for someone to step close; one shot pops it
##   kick    推進彈    no damage: a blast that throws bodies about (yours too). Movement tech
##
## Every life (and every round) starts with a full belt (COUNTS); the kick also comes back
## on its own (KICK_REFILL). Throw key V (or the middle mouse button), next one X; hold
## V to see the arc, let go to throw, hold aim while letting go for a short toss.

const IDS := ["frag", "flash", "sticky", "mine", "kick"]
const DEFAULT := "frag"
## How hard everything leaves the hand, m/s, plus a bit of loft; and how much of your own
## speed it takes with it (throwing from a slide throws far).
const SPEED := 22.0
const LOFT := 2.6
const CARRY := 0.75
const SHORT := 0.45
const KICK_REFILL := 10.0

## id -> name, English tag, how many per life, fuse (s), blast radius (m), damage (at the
## centre, falling off to a fifth at the edge), colour, how to use it, its counter.
const INFO := {
	"frag": {"name": "破片手雷", "tag": "FRAG", "count": 1, "fuse": 2.2, "radius": 5.5, "damage": 110.0,
		"color": Color("#D9A441"),
		"use": "按住 V 拔插銷（引信開始倒數 2.2 秒，可以「煮」雷），放開丟出。會彈牆、會滾。",
		"counter": "落地有聲音、看得到；牆會擋爆炸。跑出 5.5 m 就只剩擦傷。"},
	"flash": {"name": "閃光彈", "tag": "FLASH", "count": 2, "fuse": 1.1, "radius": 30.0, "damage": 0.0,
		"color": Color("#E9E4D4"),
		"use": "丟出 1.1 秒後爆閃：看著它的人（不分敵我，包括你自己）白畫面最多 2.4 秒。",
		"counter": "轉頭背對它就只會白一下；牆和轉角完全擋得住。"},
	"sticky": {"name": "黏彈", "tag": "STICKY", "count": 1, "fuse": 1.4, "radius": 3.4, "damage": 125.0,
		"color": Color("#7FC86B"),
		"use": "碰到的第一個東西就黏上去（牆、地板、人），1.4 秒後爆炸。",
		"counter": "飛得比較慢、範圍小；被黏到就往隊友反方向跑。"},
	"mine": {"name": "絆雷", "tag": "TRIP", "count": 1, "fuse": 1.0, "radius": 3.6, "damage": 100.0,
		"color": Color("#E0533D"),
		"use": "黏在落點：在牆上會拉出一條雷射，敵人穿過就爆；在地上則等敵人靠近 2.2 m。1 秒後上膛，留到回合結束。",
		"counter": "會閃紅燈、雷射看得到；開一槍就打掉它；可以跳過或滑過雷射底下。"},
	"kick": {"name": "推進彈", "tag": "KICK", "count": 2, "fuse": 1.4, "radius": 5.0, "damage": 0.0,
		"color": Color("#5FA8D3"),
		"use": "碰到東西就炸（最晚 1.4 秒），不傷人，但把範圍內所有人（包括你）往外炸飛。丟腳下＝推進跳。每 10 秒補一顆。",
		"counter": "沒有傷害；被炸飛時一樣能開槍、衝刺、蹬牆。"},
}


static func info(id: String) -> Dictionary:
	return INFO.get(id, INFO[DEFAULT])


static func valid(id: String) -> String:
	return id if INFO.has(id) else DEFAULT


## The most one blast of `id` can do to one person (for the host's judge).
static func max_damage(id: String) -> float:
	return float(info(id).damage)


## A full belt: id -> count.
static func full() -> Dictionary:
	var out := {}
	for id in IDS:
		out[id] = int(INFO[id].count)
	return out
