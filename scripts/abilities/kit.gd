class_name Kit
## The classes (C6). Every competitor carries one, with one active ability on the ability
## key (F). The guns stay free for everyone: a class is how you get into a fight, not what
## you shoot it with. Each ability opens a short window and has a counter (see each file):
##
##   anchor   勾索手  a grappling line you swing on and let go of (Anchor)
##   decoy    誘餌者  a fake runner with footsteps and fake shots (Decoy)
##   bulwark  堡壘師  a small cover panel: facing one way, a few seconds, breakable (Barricade)
##   veil     煙幕師  a smoke cloud that blocks sight for both sides (SmokeCloud)
##   ram      破門者  a short shoulder charge through thin panels and people (Ram)

const IDS := ["anchor", "decoy", "bulwark", "veil", "ram"]
const DEFAULT := "anchor"

## id -> name, English tag, ability name, charges, cooldown (s), colour, one-line pitch,
## how to use it, its counter.
const INFO := {
	"anchor": {"name": "勾索手", "tag": "ANCHOR", "ability": "勾索", "charges": 1, "cooldown": 7.0,
		"color": Color("#5FA8D3"), "pitch": "自由選擇進場角度",
		"use": "按住 F 射出勾索並收索（拉過去），輕按 F 則勾住後用固定長度擺盪；方向鍵加速擺盪，放開 F（或再按一次）脫索並保留全部速度，勾著時按跳＝放索跳，按 Q 直接衝刺。",
		"counter": "勾索飛行和收索的路線看得到也聽得到，落點可以預判。"},
	"decoy": {"name": "誘餌者", "tag": "DECOY", "ability": "誘餌", "charges": 2, "cooldown": 14.0,
		"color": Color("#C792EA"), "pitch": "騙敵人看錯方向",
		"use": "按 F 放出一個誘餌，往你看的方向跑 4 秒：有腳步聲、會對空開三槍假槍。",
		"counter": "打中一發就破掉；誘餌不會跳、不會換方向，也打不到人。"},
	"bulwark": {"name": "堡壘師", "tag": "BULWARK", "ability": "護盾板", "charges": 1, "cooldown": 22.0,
		"color": Color("#E0B04A"), "pitch": "一小段安全時間",
		"use": "按 F 在面前 2 m 立起一片 2.2 m 寬的護盾板（0.5 秒升起），擋子彈 7 秒或 350 傷害。",
		"counter": "只擋一個方向，繞到側面就沒用；打爆它、或讓破門者撞碎；不能移動。"},
	"veil": {"name": "煙幕師", "tag": "VEIL", "ability": "煙幕彈", "charges": 2, "cooldown": 18.0,
		"color": Color("#9AA5B1"), "pitch": "改變雙方的視線",
		"use": "按 F 往準心方向拋出煙幕彈，落地展開成半徑 5.5 m、高約 5 m 的煙團，持續 10 秒。",
		"counter": "雙方都看不穿；爆炸和重踩會把煙吹開 1.5 秒；煙團頂上和邊緣都能架槍。"},
	"ram": {"name": "破門者", "tag": "RAM", "ability": "肩撞", "charges": 1, "cooldown": 10.0,
		"color": Color("#E06C4A"), "pitch": "撞開窄口",
		"use": "按 F 蓄力 0.12 秒後向前肩撞約 6 m：撞碎薄牆和護盾板，撞到的人 20 傷害並失衡 0.5 秒（準心散、被迫放開瞄準）。",
		"counter": "保持距離、往側面閃；蓄力有聲音，衝出去就不能轉向。"},
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
