class_name GunNames
## Names for guns nobody named. The name is what the kill feed and death screen show, so it
## should say what the gun does: "沉默的三管霰彈" tells you more than "shotgun #4".

const FRAME_SHORT := {
	"revolver": "左輪", "service_pistol": "手槍", "heavy_pistol": "大口徑", "machine_pistol": "衝鋒手槍",
	"smg": "衝鋒槍", "pdw": "個防武器", "carbine": "卡賓", "ak": "AK", "bullpup": "無托", "battle_rifle": "戰鬥步槍",
	"dmr": "精準步槍", "rifle": "栓動", "lever_action": "槓桿", "lmg": "機槍", "anti_materiel": "反器材",
	"shotgun": "霰彈", "double_barrel": "雙管", "auto_shotgun": "連發霰彈", "sawed_off": "短管霰彈",
	"nail_gun": "釘槍", "crossbow": "十字弩", "flamethrower": "噴火器", "tesla": "線圈", "harpoon": "魚叉",
	"railgun": "電磁砲", "duck_launcher": "鴨砲", "saw_launcher": "鋸片砲", "bubble_gun": "泡泡槍",
	"jump_shotgun": "推進霰彈", "gyrojet": "火箭手槍", "minigun": "六管", "quad_barrel": "四管", "punt_gun": "巨砲",
	"pneumatic_lance": "穿刺槍", "ricochet_smg": "跳彈衝鋒", "glass_revolver": "玻璃左輪", "tuning_fork": "音叉",
	"anchor_gun": "錨鉤",
	"vector_smg": "減後座", "scout_rifle": "偵察", "silent_rifle": "微聲",
}


## The two strongest traits of the stats, as adjectives, in front of the frame's short name.
static func auto_name(build: Dictionary, stats: Dictionary) -> String:
	var traits := []
	var e: Dictionary = stats.effects
	if e.has("explode"):
		traits.append([5.0, "爆裂"])
	if e.has("burn"):
		traits.append([4.0, "燃燒"])
	if e.has("chain"):
		traits.append([4.0, "連鎖"])
	if e.get("pierce", false):
		traits.append([3.5, "貫穿"])
	if e.has("knock"):
		traits.append([3.0, "衝擊"])
	if e.has("slow") or e.has("stun"):
		traits.append([3.0, "麻痺"])
	if e.get("suppressed", false):
		traits.append([3.2, "沉默"])
	if e.has("recoil_push") and float(e.recoil_push) >= 2.0:
		traits.append([3.3, "火箭跳"])
	if e.has("grapple"):
		traits.append([3.3, "飛鉤"])
	if e.has("ricochet"):
		traits.append([3.1, "跳彈"])
	if e.has("leech"):
		traits.append([3.6, "吸血"])
	if e.get("gamble", false):
		traits.append([3.0, "賭命"])
	if e.get("headhunter", false):
		traits.append([3.0, "獵頭"])
	if e.has("air_bonus"):
		traits.append([2.9, "空戰"])
	if e.has("speed_bonus"):
		traits.append([2.9, "疾風"])
	if e.get("kill_refill", false) or e.get("kill_dash", false):
		traits.append([2.7, "連殺"])
	if e.has("last_round"):
		traits.append([2.7, "遺言"])
	if int(stats.pellets) > 8:
		traits.append([3.0, "暴雨"])
	if float(stats.rate) >= 12.0:
		traits.append([2.8, "狂躁"])
	if Weapon.pvp_damage(stats) >= 70.0 and int(stats.pellets) == 1:
		traits.append([3.4, "重錘"])
	if float(stats.zoom) >= 3.0:
		traits.append([2.6, "鷹眼"])
	if float(stats.weight) >= 9.0:
		traits.append([2.5, "鋼鐵"])
	elif float(stats.weight) <= 1.6:
		traits.append([2.4, "羽量"])
	if int(stats.mag) >= 60:
		traits.append([2.2, "無盡"])
	if float(stats.ergo) >= 85.0:
		traits.append([1.8, "順手"])
	if float(stats.recoil) <= 1.2:
		traits.append([1.6, "穩定"])
	traits.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	var name: String = FRAME_SHORT.get(build.get("frame", ""), Arsenal.name_of(build.get("frame", "")))
	if traits.size() >= 2:
		return "%s%s的%s" % [traits[1][1], traits[0][1], name]
	if traits.size() == 1:
		return "%s的%s" % [traits[0][1], name]
	return "制式" + name


## A random build: a random frame and a random part in most of its open slots. Used by bots
## and by the bench's dice button. Same seed, same gun.
static func random_build(rng: RandomNumberGenerator, frames := []) -> Dictionary:
	var pool: Array = frames if not frames.is_empty() else Arsenal.FRAMES.keys()
	var build := {"frame": pool[rng.randi() % pool.size()], "parts": {}, "tune": {}}
	for pass_i in 3:
		for slot in Arsenal.open_slots(build):
			if build.parts.has(slot) or rng.randf() > 0.62:
				continue
			var options := Arsenal.parts_for(build, slot)
			if options.is_empty():
				continue
			build.parts[slot] = options[rng.randi() % options.size()]
			build = Arsenal.clean(build)
	return Arsenal.clean(build)
