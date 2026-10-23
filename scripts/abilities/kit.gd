class_name Kit
## The classes (C6). Every competitor carries one, with one active ability on the ability
## key (F). The guns stay free for everyone: a class is how you get into a fight, not what
## you shoot it with. Each ability opens a short window and has a counter (see each file):
##
##   anchor   勾索手  a grappling line you swing on and let go of (Anchor)
##   decoy    誘餌者  a fake runner with footsteps and fake shots (Decoy)
##   bulwark  堡壘師  a small cover panel: facing one way, a few seconds, breakable (Barricade)
##   veil     煙幕師  a smoke cloud that blocks sight for both sides (SmokeCloud)
##   ram      破門者  a charge that runs until it hits someone or something (Ram)

const IDS := ["anchor", "decoy", "bulwark", "veil", "ram"]
const DEFAULT := "anchor"

## id -> name, English tag, ability name, charges, cooldown (s), colour, one-line pitch,
## how to use it, its counter.
const INFO := {
	"anchor": {"name": "勾索手", "tag": "ANCHOR", "ability": "勾索", "charges": 1, "cooldown": 0.5,
		"color": Color("#5FA8D3"), "pitch": "自由選擇進場角度",
		"use": "按 F 射出勾索，勾到就把你往勾點拉（側向速度保留，斜著進去會繞著勾點甩）。輕按＝一路拉到底並在終點彈起；按住＝拉到放開 F 為止。再按 F 提早脫索，按跳＝放索跳，按 Q 直接衝刺。冷卻只有 0.5 秒，可以一勾接一勾。",
		"counter": "勾索和拉過去的直線路線看得到也聽得到，勾點就是終點，可以預判。"},
	"decoy": {"name": "誘餌者", "tag": "DECOY", "ability": "誘餌", "charges": 2, "cooldown": 14.0,
		"color": Color("#C792EA"), "pitch": "騙敵人看錯方向",
		"use": "按 F 放出一個誘餌，往你看的方向跑 4 秒：有腳步聲、會對空開三槍假槍。",
		"counter": "打中一發就破掉；誘餌不會跳、不會換方向，也打不到人。"},
	"bulwark": {"name": "堡壘師", "tag": "BULWARK", "ability": "護盾牆", "charges": 2, "cooldown": 20.0,
		"color": Color("#E0B04A"), "pitch": "一小段安全時間",
		"use": "按 F 在面前立起一面 4 m 寬、2.8 m 高的護盾牆（0.5 秒升起），擋子彈 8 秒或 500 傷害。可以累積兩次，連放兩面。",
		"counter": "只擋一個方向，繞到側面就沒用；打爆它、或讓破門者撞碎；不能移動。"},
	"veil": {"name": "煙幕師", "tag": "VEIL", "ability": "煙幕彈", "charges": 2, "cooldown": 18.0,
		"color": Color("#9AA5B1"), "pitch": "改變雙方的視線",
		"use": "按 F 往準心方向拋出煙幕彈，落地展開成半徑 5.5 m、高約 5 m 的煙團，持續 10 秒。",
		"counter": "雙方都看不穿；爆炸和重踩會把煙吹開 1.5 秒；煙團頂上和邊緣都能架槍。"},
	"ram": {"name": "破門者", "tag": "RAM", "ability": "衝撞", "charges": 1, "cooldown": 10.0,
		"color": Color("#E06C4A"), "pitch": "停不下來的衝撞",
		"use": "按 F 蓄力 0.12 秒後向前猛衝，直到撞到人或障礙物才停：跟著你面朝的方向轉彎，越跑越快沒有上限。撞到的人 20 傷害起跳（越快越痛）並失衡 0.5 秒；撞碎薄牆和護盾牆。再按 F 提早停下，按跳＝衝撞跳（保留速度）。",
		"counter": "往側面閃（越快轉得越慢）；蓄力有聲音；擋在牆角讓它自己撞牆。"},
}


static func info(id: String) -> Dictionary:
	return INFO.get(id, INFO[DEFAULT])


static func valid(id: String) -> String:
	return id if INFO.has(id) else DEFAULT


static func label(id: String) -> String:
	var i := info(id)
	return "%s %s" % [i.name, i.tag]


## A new ability object for class `id`, used by `user` (a Player or a Bot).
static func make(id: String, user: Node3D) -> Ability:
	var a: Ability
	match valid(id):
		"anchor": a = Anchor.new()
		"decoy": a = DecoyThrow.new()
		"bulwark": a = BulwarkDeploy.new()
		"veil": a = VeilThrow.new()
		_: a = Ram.new()
	a.kit = valid(id)
	a.user = user
	a.charges = float(info(a.kit).charges)
	return a
