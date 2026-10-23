class_name Arsenal
## Every weapon a scavenger can carry, and every part that bolts onto one.
## A weapon is a frame (the gun itself) plus a tree of parts, modded like a real gun on
## a gunsmith bench (Tarkov-style): the frame has root slots, and parts open more slots
## of their own (a handguard opens rails, a foregrip spot and an underbarrel spot; a
## flash hider opens a spot for a quick-detach suppressor; a threaded barrel opens a
## muzzle). Some parts block a slot (an integrally suppressed barrel has no muzzle) and
## some change the calibre (an AR upper in .300 BLK), which decides the ammo and the
## magazines that fit. A few parts can be tuned on a slider (gas, stock length, zoom).
##   build = {"frame": "carbine", "parts": {"handguard": "quad_rail", "rail_l": "flashlight"},
##            "tune": {"gas": 0.5}}
## Arsenal.stats(build) gives the finished numbers the game uses.
##
## Frames and parts are bought into the stash (GameState.stash, by id) and go into a run
## with the build: lost on death, back in the stash on extraction. The starter revolver
## is free and always there, and every scavenger also carries a knife (Player handles it),
## so nobody goes in unable to fight back.

## C7: every gun takes every part. All slots are open on every frame, any part fits its
## slot whatever the frame, tags or calibre, and nothing blocks a slot (a suppressed barrel
## still takes a muzzle device). The old fitting rules stay below for FREE_FIT = false.
## Ammo is the one exception: rounds still have to fit the chamber, so an ammo part goes
## only on a build whose calibre (after any conversion part) it names, by calibre id or
## family ("cal" pins exact calibres). See ammo_fits.
const FREE_FIT := true

## Every slot a build can have, parents before the slots they open (clean() walks this
## once, in order). A slot's type (SLOT_TYPE) is what parts name in "slot".
const SLOTS := ["receiver", "barrel", "muzzle", "silencer", "gas", "handguard", "rail_l", "rail_r",
	"foregrip", "underbarrel", "mount", "sight", "tactical", "grip", "trigger", "bolt", "spring", "charging",
	"magwell", "magazine", "ammo", "stock", "cheek", "buttpad", "sling", "gadget"]
## Slots that share a type with another (both rails take rail accessories).
const SLOT_TYPE := {"rail_l": "rail", "rail_r": "rail"}
## Names of slot types (and of the two rail slots).
const SLOT_NAMES := {
	"receiver": "機匣", "barrel": "槍管", "muzzle": "槍口", "silencer": "消音器", "gas": "導氣",
	"handguard": "護木", "rail": "導軌配件", "rail_l": "左導軌", "rail_r": "右導軌", "foregrip": "前握把",
	"underbarrel": "下掛", "mount": "副瞄座", "sight": "瞄具", "grip": "握把", "trigger": "扳機組",
	"bolt": "槍機", "charging": "拉機柄", "magazine": "彈匣", "ammo": "彈藥", "stock": "槍托",
	"buttpad": "托底", "gadget": "怪東西",
	"tactical": "上置戰術", "spring": "緩衝復進", "magwell": "彈匣井", "cheek": "托腮板", "sling": "槍背帶",
}
## The four groups the bench shows slots in.
const SLOT_GROUPS := [
	["前段", ["barrel", "muzzle", "silencer", "gas", "handguard", "rail_l", "rail_r", "foregrip", "underbarrel"]],
	["上方", ["mount", "sight", "tactical"]],
	["機匣", ["receiver", "grip", "trigger", "bolt", "spring", "charging", "magwell", "magazine", "ammo"]],
	["後段", ["stock", "cheek", "buttpad", "sling", "gadget"]],
]

## Calibres. "family" is what ammo and some parts fit by (it works like a frame tag).
const CALIBERS := {
	"9mm": {"name": "9×19mm", "family": "pistol"},
	".45": {"name": ".45 ACP", "family": "pistol"},
	".357": {"name": ".357 麥格農", "family": "pistol"},
	"5.7": {"name": "5.7×28mm", "family": "pistol"},
	"5.56": {"name": "5.56×45mm", "family": "rifle"},
	".300": {"name": ".300 BLK", "family": "rifle"},
	"7.62x39": {"name": "7.62×39mm", "family": "rifle"},
	"7.62": {"name": "7.62×51mm", "family": "rifle"},
	".338": {"name": ".338 拉普麥格農", "family": "rifle"},
	".45-70": {"name": ".45-70 政府型", "family": "rifle"},
	".50": {"name": ".50 BMG", "family": "rifle"},
	"12g": {"name": "12 號霰彈", "family": "shell"},
	"nail": {"name": "工業釘", "family": "odd"},
	"bolt": {"name": "弩箭", "family": "odd"},
	"fuel": {"name": "燃料", "family": "odd"},
	"cell": {"name": "電池", "family": "odd"},
	"duck": {"name": "橡皮鴨", "family": "odd"},
	"saw": {"name": "鋸片", "family": "odd"},
	"soap": {"name": "肥皂水", "family": "odd"},
	"4g": {"name": "4 號巨型霰彈", "family": "shell"},
	"rocket": {"name": "13mm 火箭彈", "family": "odd"},
	"air": {"name": "壓縮空氣", "family": "odd"},
	"9x39": {"name": "9×39mm 亞音速", "family": "rifle"},
}

## Fire modes a frame can have; the player cycles them (B).
const MODE_NAMES := {"semi": "半自動", "burst": "三連發", "auto": "全自動", "double": "雙管齊發"}

## Stats every frame defines (missing ones come from DEFAULTS):
##   damage      per projectile (monster health is in MonsterRoster; players have 100)
##   pellets     projectiles per shot
##   rate        shots per second (cyclic rate for auto and burst)
##   modes       fire modes, first is the default: semi, burst (3), auto, double (two at once)
##   mag         rounds before reloading; reserve = spare rounds carried in
##   reload      seconds (an empty gun takes EMPTY_RELOAD times longer: rack the action)
##   spread      degrees of random cone when hip-firing
##   moa         precision when aiming (minutes of angle; aimed cone = moa * MOA_DEGREES)
##   recoil      vertical camera kick per shot, degrees; recoil_h = sideways wobble
##   ergo        ergonomics 0-100: how fast you aim, how much the gun sways, recoil recovery
##   velocity    muzzle velocity m/s: over 340 the bullet cracks (a suppressor can't hide it),
##               faster keeps damage further out and adds penetration
##   pen         penetration 0-100: how much a hit counts against large, armoured monsters
##   range       metres; damage falls off over the last part of it (falloff)
##   noise       radius in metres monsters hear the shot from
##   flash       muzzle flash 0-100: lights the shooter up (light-sensing monsters see it)
##   zoom        field-of-view divisor while aiming
##   reliability 0-100: chance per shot of a jam is (100 - reliability) * JAM_PER_POINT
##   heat        heat added per shot (1.0 = overheated); cooling = heat lost per second
##   length      cm; weight kg; price $
##   cal         calibre (CALIBERS)
##   kind        how a shot travels: hitscan, cone (flame), arc (chain lightning), lob
##               (grenade), bounce (saw blade), charge (hold to charge, then hitscan)
##   tags        which parts fit: gun, pellet, bolt, fuel, energy, launcher, plus a few
##               frame families (ar, ak, pistol_frame, revolver, bolt_action)
##   slots       root slots; parts open more ("adds") or close some ("blocks")
##   effects     what a hit does besides damage: stun, slow, burn, bleed (seconds), pierce
##               (true: goes through everything), knock (metres), explode (radius), chain (extra
##               targets), lure (the hit spot is noisy), reveal (shows hidden monsters), bubble
##   shooter effects: light, thermal, night (night vision), laser / laser_ir, strobe,
##               bipod (still + aiming = much less recoil), canted (hip-fire through an offset
##               sight), suppressed, tracer, bayonet, ghost (every Nth shot is free)
##   organ effects (see Organs): scream, hush, acid, lullaby, web, motion_sight / squeal,
##               guard (aiming halves damage taken), fang (a knife three times as strong)
const DEFAULTS := {
	"pellets": 1, "modes": ["semi"], "moa": 6.0, "recoil_h": 1.0, "ergo": 60.0, "velocity": 400.0,
	"pen": 20.0, "flash": 50.0, "zoom": 1.2, "reliability": 92.0, "heat": 0.0, "cooling": 0.5,
	"length": 80.0, "effects": {}, "kind": "hitscan", "cal": "9mm",
}

const FRAMES := {
	# --- C7 frames (Tarkov / Delta Force inspired)
	"vector_smg": {
		"name": "減後座衝鋒槍", "price": 650, "weight": 2.7, "length": 62.0, "tags": ["gun"], "cal": ".45",
		"damage": 10.0, "rate": 15.0, "modes": ["auto", "burst", "semi"], "mag": 25, "reserve": 100, "reload": 2.3,
		"spread": 3.4, "moa": 7.0, "range": 34.0, "noise": 34.0, "recoil": 0.7, "recoil_h": 0.6, "zoom": 1.25,
		"ergo": 70.0, "velocity": 290.0, "pen": 16.0, "flash": 40.0, "reliability": 90.0, "heat": 0.02, "cooling": 0.45,
		"slots": ["barrel", "muzzle", "rail_l", "rail_r", "foregrip", "sight", "grip", "trigger", "magazine", "ammo", "stock", "gadget"],
		"desc": "槍機往下滑，把後座力壓進握把下面：射速驚人、槍口幾乎不跳。近距離的絞肉機。",
	},
	"scout_rifle": {
		"name": "偵察步槍", "price": 520, "weight": 3.0, "length": 98.0, "tags": ["gun", "bolt_action"], "cal": "7.62",
		"damage": 55.0, "rate": 1.1, "mag": 10, "reserve": 30, "reload": 2.6,
		"spread": 0.8, "moa": 1.4, "range": 90.0, "noise": 52.0, "recoil": 4.8, "recoil_h": 0.5, "zoom": 1.5,
		"ergo": 66.0, "velocity": 820.0, "pen": 58.0, "flash": 45.0, "reliability": 99.0,
		"effects": {"bipod": true},
		"slots": ["barrel", "muzzle", "rail_l", "foregrip", "mount", "sight", "trigger", "bolt", "magazine", "ammo", "stock", "gadget"],
		"desc": "輕量栓動，前托藏著一副腳架。比狙擊槍輕快，跑跳中也能開一槍再走。",
	},
	"silent_rifle": {
		"name": "微聲突擊步槍", "price": 820, "weight": 2.9, "length": 87.0, "tags": ["gun"], "cal": "9x39",
		"damage": 24.0, "rate": 11.0, "modes": ["auto", "semi"], "mag": 20, "reserve": 80, "reload": 2.5,
		"spread": 3.0, "moa": 4.5, "range": 50.0, "noise": 12.0, "recoil": 2.0, "recoil_h": 1.1, "zoom": 1.3,
		"ergo": 60.0, "velocity": 295.0, "pen": 50.0, "flash": 5.0, "reliability": 88.0, "heat": 0.025, "cooling": 0.4,
		"effects": {"suppressed": true},
		"slots": ["muzzle", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging", "magazine", "ammo", "stock", "gadget"],
		"desc": "槍管整根包在消音器裡，打亞音速重彈：幾乎聽不到、看不到火光，穿透很好，掉彈很快。",
	},
	# --- Handguns
	"revolver": {
		"name": "舊警用左輪", "price": 0, "weight": 1.0, "length": 28.0, "tags": ["gun", "revolver"], "cal": ".357",
		"damage": 16.0, "rate": 2.2, "mag": 6, "reserve": 24, "reload": 2.2,
		"spread": 2.5, "moa": 6.0, "range": 40.0, "noise": 30.0, "recoil": 3.0, "recoil_h": 0.8, "zoom": 1.2,
		"ergo": 70.0, "velocity": 430.0, "pen": 25.0, "flash": 60.0, "reliability": 98.0,
		"slots": ["receiver", "barrel", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "underbarrel", "gadget"],
		"desc": "免費的，永遠拿得到。六發，準頭普通，聲音不小。轉輪槍幾乎不會卡彈。",
	},
	"service_pistol": {
		"name": "警用半自動手槍", "price": 150, "weight": 0.8, "length": 20.0, "tags": ["gun", "pistol_frame"], "cal": "9mm",
		"damage": 13.0, "rate": 4.0, "mag": 15, "reserve": 45, "reload": 1.6,
		"spread": 2.2, "moa": 7.0, "range": 35.0, "noise": 28.0, "recoil": 2.0, "recoil_h": 0.7, "zoom": 1.15,
		"ergo": 80.0, "velocity": 360.0, "pen": 20.0, "flash": 45.0, "reliability": 95.0,
		"slots": ["barrel", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "stock", "gadget"],
		"desc": "十五發的聚合物手槍。輕、快、好上手，改裝空間比你想的大。",
	},
	"heavy_pistol": {
		"name": "點四五大口徑手槍", "price": 260, "weight": 1.1, "length": 22.0, "tags": ["gun", "pistol_frame"], "cal": ".45",
		"damage": 22.0, "rate": 2.8, "mag": 7, "reserve": 28, "reload": 1.7,
		"spread": 2.4, "moa": 6.0, "range": 35.0, "noise": 32.0, "recoil": 3.6, "recoil_h": 0.9, "zoom": 1.15,
		"ergo": 72.0, "velocity": 260.0, "pen": 22.0, "flash": 40.0, "reliability": 93.0,
		"slots": ["barrel", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "stock", "gadget"],
		"desc": "一百年前的設計，一發一個大洞。子彈本來就是亞音速，配消音器非常安靜。",
	},
	"machine_pistol": {
		"name": "全自動衝鋒手槍", "price": 320, "weight": 1.1, "length": 25.0, "tags": ["gun", "pistol_frame"], "cal": "9mm",
		"damage": 10.0, "rate": 14.0, "modes": ["semi", "auto"], "mag": 20, "reserve": 60, "reload": 1.8,
		"spread": 4.5, "moa": 9.0, "range": 25.0, "noise": 30.0, "recoil": 1.6, "recoil_h": 1.6, "zoom": 1.1,
		"ergo": 75.0, "velocity": 350.0, "pen": 18.0, "flash": 50.0, "reliability": 88.0, "heat": 0.03, "cooling": 0.5,
		"slots": ["barrel", "muzzle", "rail_l", "sight", "grip", "trigger", "bolt", "magazine", "ammo", "stock", "gadget"],
		"desc": "一秒十四發，槍口亂跳。近距離把一整個彈匣倒進去。",
	},
	# --- Submachine guns
	"smg": {
		"name": "拼裝衝鋒槍", "price": 350, "weight": 2.6, "length": 60.0, "tags": ["gun"], "cal": "9mm",
		"damage": 9.0, "rate": 9.0, "modes": ["auto", "semi"], "mag": 30, "reserve": 90, "reload": 2.4,
		"spread": 4.5, "moa": 10.0, "range": 35.0, "noise": 35.0, "recoil": 1.2, "recoil_h": 1.4, "zoom": 1.25,
		"ergo": 68.0, "velocity": 380.0, "pen": 18.0, "flash": 55.0, "reliability": 82.0, "heat": 0.025, "cooling": 0.4,
		"slots": ["barrel", "muzzle", "rail_l", "rail_r", "foregrip", "underbarrel", "sight", "grip", "trigger",
			"bolt", "charging", "magazine", "ammo", "stock", "gadget"],
		"desc": "水管和縫紉機零件焊成的全自動槍。彈幕壓制，但很散，偶爾卡彈。",
	},
	"pdw": {
		"name": "個人防衛武器", "price": 600, "weight": 2.7, "length": 50.0, "tags": ["gun"], "cal": "5.7",
		"damage": 11.0, "rate": 13.0, "modes": ["auto", "semi"], "mag": 50, "reserve": 100, "reload": 2.6,
		"spread": 3.2, "moa": 6.0, "range": 45.0, "noise": 34.0, "recoil": 0.9, "recoil_h": 0.8, "zoom": 1.25,
		"ergo": 74.0, "velocity": 700.0, "pen": 45.0, "flash": 40.0, "reliability": 90.0, "heat": 0.02, "cooling": 0.5,
		"slots": ["muzzle", "rail_l", "rail_r", "foregrip", "mount", "sight", "trigger", "bolt", "magazine", "ammo", "gadget"],
		"desc": "五十發的頂裝彈匣、幾乎沒有後座。小口徑高速彈，穿透比手槍彈好得多。",
	},
	# --- Rifles
	"carbine": {
		"name": "模組化卡賓槍", "price": 700, "weight": 3.0, "length": 85.0, "tags": ["gun", "ar"], "cal": "5.56",
		"damage": 20.0, "rate": 11.0, "modes": ["semi", "auto"], "mag": 30, "reserve": 90, "reload": 2.5,
		"spread": 3.0, "moa": 3.5, "range": 70.0, "noise": 50.0, "recoil": 1.6, "recoil_h": 1.0, "zoom": 1.25,
		"ergo": 60.0, "velocity": 900.0, "pen": 40.0, "flash": 55.0, "reliability": 85.0, "heat": 0.02, "cooling": 0.45,
		"slots": ["receiver", "barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt",
			"charging", "magazine", "ammo", "stock", "gadget"],
		"desc": "什麼都裝得上的步槍。換上機匣就能改口徑，是槍匠台上最好玩的東西。",
	},
	"ak": {
		"name": "老式突擊步槍", "price": 620, "weight": 3.6, "length": 88.0, "tags": ["gun", "ak"], "cal": "7.62x39",
		"damage": 26.0, "rate": 10.0, "modes": ["auto", "semi"], "mag": 30, "reserve": 90, "reload": 2.7,
		"spread": 3.6, "moa": 5.0, "range": 60.0, "noise": 55.0, "recoil": 2.6, "recoil_h": 1.6, "zoom": 1.2,
		"ergo": 52.0, "velocity": 715.0, "pen": 45.0, "flash": 70.0, "reliability": 98.0, "heat": 0.02, "cooling": 0.4,
		"slots": ["receiver", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "泡過水、埋過土都還能打。後座大、準頭普通，但幾乎從來不卡。",
	},
	"bullpup": {
		"name": "犢牛式步槍", "price": 780, "weight": 3.4, "length": 70.0, "tags": ["gun"], "cal": "5.56",
		"damage": 19.0, "rate": 12.0, "modes": ["semi", "auto"], "mag": 30, "reserve": 90, "reload": 3.1,
		"spread": 2.8, "moa": 3.5, "range": 70.0, "noise": 50.0, "recoil": 1.5, "recoil_h": 1.1, "zoom": 1.3,
		"ergo": 66.0, "velocity": 920.0, "pen": 40.0, "flash": 50.0, "reliability": 84.0, "heat": 0.02, "cooling": 0.45,
		"slots": ["barrel", "muzzle", "gas", "rail_l", "rail_r", "foregrip", "underbarrel", "mount", "sight", "trigger",
			"bolt", "magazine", "ammo", "gadget"],
		"desc": "彈匣在握把後面：步槍的槍管、衝鋒槍的長度。換彈要摸到肩膀後面，很慢。",
	},
	"battle_rifle": {
		"name": "戰鬥步槍", "price": 900, "weight": 4.4, "length": 105.0, "tags": ["gun"], "cal": "7.62",
		"damage": 38.0, "rate": 7.0, "modes": ["semi", "auto"], "mag": 20, "reserve": 60, "reload": 2.9,
		"spread": 3.2, "moa": 2.5, "range": 85.0, "noise": 65.0, "recoil": 4.2, "recoil_h": 1.8, "zoom": 1.3,
		"ergo": 45.0, "velocity": 840.0, "pen": 60.0, "flash": 65.0, "reliability": 90.0, "heat": 0.03, "cooling": 0.4,
		"slots": ["barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "全威力步槍彈的全自動。每一發都很痛，連射就拉不住了。",
	},
	"dmr": {
		"name": "精確射手步槍", "price": 1000, "weight": 4.6, "length": 110.0, "tags": ["gun", "ar"], "cal": "7.62",
		"damage": 45.0, "rate": 3.5, "mag": 10, "reserve": 40, "reload": 2.8,
		"spread": 3.0, "moa": 1.4, "range": 110.0, "noise": 62.0, "recoil": 3.6, "recoil_h": 1.0, "zoom": 1.4,
		"ergo": 48.0, "velocity": 860.0, "pen": 62.0, "flash": 55.0, "reliability": 88.0, "heat": 0.02, "cooling": 0.5,
		"slots": ["receiver", "barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt",
			"charging", "magazine", "ammo", "stock", "gadget"],
		"desc": "半自動的狙擊槍。比栓動快，比卡賓槍準。",
	},
	"rifle": {
		"name": "栓動步槍", "price": 560, "weight": 3.8, "length": 112.0, "tags": ["gun", "bolt_action"], "cal": "7.62",
		"damage": 65.0, "rate": 0.8, "mag": 5, "reserve": 20, "reload": 3.2,
		"spread": 0.4, "moa": 1.0, "range": 100.0, "noise": 55.0, "recoil": 6.0, "recoil_h": 0.6, "zoom": 1.6,
		"ergo": 50.0, "velocity": 850.0, "pen": 65.0, "flash": 50.0, "reliability": 99.0,
		"slots": ["receiver", "barrel", "muzzle", "rail_l", "foregrip", "underbarrel", "mount", "sight", "trigger", "bolt",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "一槍一個洞。遠距離最準，近身很難用。換槍管可以改成 .338。",
	},
	"lever_action": {
		"name": "槓桿步槍", "price": 480, "weight": 3.2, "length": 95.0, "tags": ["gun", "lever"], "cal": ".45-70",
		"damage": 55.0, "rate": 1.4, "mag": 6, "reserve": 24, "reload": 3.6,
		"spread": 1.6, "moa": 3.0, "range": 70.0, "noise": 52.0, "recoil": 5.0, "recoil_h": 0.8, "zoom": 1.3,
		"ergo": 62.0, "velocity": 600.0, "pen": 50.0, "flash": 45.0, "reliability": 97.0,
		"slots": ["barrel", "rail_l", "underbarrel", "mount", "sight", "trigger", "bolt", "magazine", "ammo", "stock",
			"buttpad", "gadget"],
		"desc": "西部片裡的槍，打熊用的子彈。拉一下打一發，一顆一顆塞進彈倉。",
	},
	"lmg": {
		"name": "輕機槍", "price": 1300, "weight": 7.5, "length": 104.0, "tags": ["gun"], "cal": "5.56",
		"damage": 20.0, "rate": 12.0, "modes": ["auto"], "mag": 100, "reserve": 200, "reload": 5.5,
		"spread": 4.5, "moa": 4.0, "range": 75.0, "noise": 60.0, "recoil": 1.8, "recoil_h": 1.6, "zoom": 1.2,
		"ergo": 25.0, "velocity": 915.0, "pen": 42.0, "flash": 65.0, "reliability": 92.0, "heat": 0.012, "cooling": 0.35,
		"slots": ["barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "一百發彈鏈。非常重、非常吵，架上腳架就是一堵火牆。換彈要五秒半。",
	},
	"anti_materiel": {
		"name": "反器材步槍", "price": 1600, "weight": 13.0, "length": 145.0, "tags": ["gun", "bolt_action"], "cal": ".50",
		"damage": 180.0, "rate": 0.6, "mag": 5, "reserve": 10, "reload": 4.2,
		"spread": 4.0, "moa": 1.2, "range": 150.0, "noise": 90.0, "recoil": 12.0, "recoil_h": 2.0, "zoom": 2.2,
		"ergo": 20.0, "velocity": 880.0, "pen": 95.0, "flash": 90.0, "reliability": 92.0,
		"effects": {"pierce": true, "knock": 2.0},
		"slots": ["muzzle", "rail_l", "foregrip", "mount", "sight", "trigger", "magazine", "ammo", "stock", "buttpad", "gadget"],
		"desc": "打卡車引擎用的槍。一發能讓大型怪踉蹌，整張地圖都聽得到。十三公斤。",
	},
	# --- Shotguns
	"shotgun": {
		"name": "泵動獵槍", "price": 420, "weight": 3.4, "length": 100.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 10.0, "pellets": 8, "rate": 1.1, "mag": 5, "reserve": 20, "reload": 3.0,
		"spread": 7.0, "moa": 8.0, "range": 25.0, "noise": 60.0, "recoil": 7.0, "recoil_h": 1.5, "zoom": 1.15,
		"ergo": 58.0, "velocity": 400.0, "pen": 15.0, "flash": 70.0, "reliability": 96.0,
		"effects": {"knock": 1.2},
		"slots": ["barrel", "muzzle", "handguard", "underbarrel", "mount", "sight", "grip", "trigger", "magazine",
			"ammo", "stock", "gadget"],
		"desc": "近距離一發轟退中型怪。槍聲會引來半張地圖的東西。換獨頭彈就能打遠。",
	},
	"double_barrel": {
		"name": "雙管獵槍", "price": 300, "weight": 3.2, "length": 105.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 11.0, "pellets": 8, "rate": 3.0, "modes": ["semi", "double"], "mag": 2, "reserve": 20, "reload": 2.2,
		"spread": 7.5, "moa": 9.0, "range": 25.0, "noise": 62.0, "recoil": 7.5, "recoil_h": 1.2, "zoom": 1.15,
		"ergo": 60.0, "velocity": 400.0, "pen": 15.0, "flash": 75.0, "reliability": 99.0,
		"effects": {"knock": 1.4},
		"slots": ["barrel", "muzzle", "rail_l", "sight", "trigger", "ammo", "stock", "buttpad", "gadget"],
		"desc": "兩發。可以一發一發打，也可以兩管一起轟。折開來換彈很快。",
	},
	"auto_shotgun": {
		"name": "半自動霰彈槍", "price": 950, "weight": 4.2, "length": 100.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 9.0, "pellets": 8, "rate": 4.0, "mag": 8, "reserve": 32, "reload": 3.2,
		"spread": 7.5, "moa": 9.0, "range": 25.0, "noise": 60.0, "recoil": 5.5, "recoil_h": 2.0, "zoom": 1.15,
		"ergo": 50.0, "velocity": 390.0, "pen": 15.0, "flash": 70.0, "reliability": 80.0, "heat": 0.02, "cooling": 0.5,
		"effects": {"knock": 1.0},
		"slots": ["barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "扣一下打一發，八發連轟。用太便宜的彈藥會卡。",
	},
	"sawed_off": {
		"name": "鋸短霰彈槍", "price": 160, "weight": 1.8, "length": 45.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 11.0, "pellets": 8, "rate": 3.0, "modes": ["semi", "double"], "mag": 2, "reserve": 16, "reload": 2.0,
		"spread": 11.0, "moa": 14.0, "range": 15.0, "noise": 66.0, "recoil": 8.5, "recoil_h": 2.5, "zoom": 1.05,
		"ergo": 82.0, "velocity": 360.0, "pen": 12.0, "flash": 90.0, "reliability": 99.0,
		"effects": {"knock": 1.8},
		"slots": ["rail_l", "grip", "trigger", "ammo", "gadget"],
		"desc": "把雙管獵槍鋸掉一半。散得像一面牆，火光像一顆太陽。",
	},
	# --- Strange ones
	"nail_gun": {
		"name": "工業釘槍", "price": 220, "weight": 2.4, "length": 40.0, "tags": ["gun"], "cal": "nail",
		"damage": 7.0, "rate": 6.0, "modes": ["auto", "semi"], "mag": 40, "reserve": 120, "reload": 2.0,
		"spread": 3.0, "moa": 8.0, "range": 28.0, "noise": 12.0, "recoil": 0.8, "recoil_h": 0.6, "zoom": 1.2,
		"ergo": 65.0, "velocity": 150.0, "pen": 10.0, "flash": 0.0, "reliability": 75.0, "heat": 0.01, "cooling": 0.5,
		"effects": {"slow": 0.3},
		"slots": ["barrel", "rail_l", "underbarrel", "sight", "grip", "magazine", "ammo", "gadget"],
		"desc": "安靜的連射，釘子會讓目標慢下來一點。工地用品，常常卡釘。",
	},
	"crossbow": {
		"name": "鋼弩", "price": 300, "weight": 2.2, "length": 75.0, "tags": ["bolt"], "cal": "bolt",
		"damage": 48.0, "rate": 0.7, "mag": 1, "reserve": 15, "reload": 1.3,
		"spread": 0.5, "moa": 3.0, "range": 60.0, "noise": 4.0, "recoil": 2.0, "recoil_h": 0.4, "zoom": 1.5,
		"ergo": 60.0, "velocity": 100.0, "pen": 35.0, "flash": 0.0, "reliability": 99.0,
		"slots": ["rail_l", "foregrip", "underbarrel", "mount", "sight", "trigger", "ammo", "stock", "gadget"],
		"desc": "幾乎沒有聲音。一次一發，換箭頭可以變出各種花樣。",
	},
	"flamethrower": {
		"name": "火焰噴射器", "price": 500, "weight": 5.0, "length": 90.0, "tags": ["fuel"], "cal": "fuel", "kind": "cone",
		"damage": 5.0, "rate": 10.0, "modes": ["auto"], "mag": 80, "reserve": 80, "reload": 3.5,
		"spread": 0.0, "moa": 0.0, "range": 7.0, "noise": 15.0, "recoil": 0.0, "recoil_h": 0.0, "zoom": 1.0,
		"ergo": 40.0, "velocity": 20.0, "pen": 0.0, "flash": 100.0, "reliability": 85.0,
		"effects": {"burn": 3.0},
		"slots": ["muzzle", "rail_l", "magazine", "gadget"],
		"desc": "噴出一片火，燒到的東西會繼續燒。對鼠群特別有效。噴的時候你就是一支火把。",
	},
	"tesla": {
		"name": "特斯拉線圈槍", "price": 650, "weight": 4.0, "length": 70.0, "tags": ["energy"], "cal": "cell", "kind": "arc",
		"damage": 14.0, "rate": 3.0, "modes": ["auto"], "mag": 24, "reserve": 48, "reload": 3.0,
		"spread": 0.0, "moa": 0.0, "range": 14.0, "noise": 25.0, "recoil": 0.5, "recoil_h": 0.2, "zoom": 1.0,
		"ergo": 50.0, "velocity": 0.0, "pen": 30.0, "flash": 80.0, "reliability": 90.0, "heat": 0.05, "cooling": 0.3,
		"effects": {"stun": 0.5, "chain": 2},
		"slots": ["barrel", "rail_l", "magazine", "stock", "gadget"],
		"desc": "電弧會跳到旁邊的目標上，每一下都讓它們麻一下。連發會過熱。",
	},
	"harpoon": {
		"name": "捕鯨魚叉槍", "price": 450, "weight": 4.5, "length": 110.0, "tags": ["bolt"], "cal": "bolt",
		"damage": 80.0, "rate": 0.5, "mag": 1, "reserve": 8, "reload": 2.4,
		"spread": 0.6, "moa": 4.0, "range": 40.0, "noise": 20.0, "recoil": 5.0, "recoil_h": 0.5, "zoom": 1.3,
		"ergo": 40.0, "velocity": 80.0, "pen": 70.0, "flash": 0.0, "reliability": 99.0,
		"effects": {"pierce": true, "knock": -2.5},
		"slots": ["rail_l", "mount", "sight", "ammo", "stock", "gadget"],
		"desc": "一叉穿過一整排，還會把目標往你這邊拖。",
	},
	"railgun": {
		"name": "磁軌炮", "price": 1200, "weight": 11.0, "length": 130.0, "tags": ["energy"], "cal": "cell", "kind": "charge",
		"damage": 260.0, "rate": 0.4, "mag": 1, "reserve": 3, "reload": 4.0,
		"spread": 0.0, "moa": 0.5, "range": 120.0, "noise": 45.0, "recoil": 10.0, "recoil_h": 1.0, "zoom": 2.0,
		"ergo": 22.0, "velocity": 3000.0, "pen": 100.0, "flash": 85.0, "reliability": 94.0, "heat": 0.6, "cooling": 0.12,
		"effects": {"pierce": true, "stun": 2.0},
		"slots": ["barrel", "foregrip", "mount", "sight", "magazine", "stock", "gadget"],
		"desc": "按住充能 2 秒，一發貫穿直線上的一切。超重，子彈很少，打完要等它散熱。",
	},
	"duck_launcher": {
		"name": "爆炸鴨發射器", "price": 700, "weight": 4.2, "length": 80.0, "tags": ["launcher"], "cal": "duck", "kind": "lob",
		"damage": 90.0, "rate": 0.8, "mag": 3, "reserve": 6, "reload": 3.5,
		"spread": 1.0, "moa": 6.0, "range": 35.0, "noise": 60.0, "recoil": 6.0, "recoil_h": 1.0, "zoom": 1.1,
		"ergo": 45.0, "velocity": 40.0, "pen": 0.0, "flash": 40.0, "reliability": 95.0,
		"effects": {"explode": 4.0, "lure": true},
		"slots": ["rail_l", "mount", "sight", "magazine", "stock", "gadget"],
		"desc": "拋出一隻嘎嘎叫的橡皮鴨，把怪物引過去再炸開。也炸得到隊友。",
	},
	"saw_launcher": {
		"name": "圓鋸片發射器", "price": 480, "weight": 3.6, "length": 75.0, "tags": ["launcher"], "cal": "saw", "kind": "bounce",
		"damage": 38.0, "rate": 1.4, "mag": 8, "reserve": 16, "reload": 2.8,
		"spread": 0.8, "moa": 4.0, "range": 35.0, "noise": 22.0, "recoil": 3.0, "recoil_h": 0.8, "zoom": 1.2,
		"ergo": 52.0, "velocity": 60.0, "pen": 40.0, "flash": 0.0, "reliability": 88.0,
		"effects": {"chain": 1},
		"slots": ["rail_l", "underbarrel", "sight", "magazine", "stock", "gadget"],
		"desc": "鋸片打中牆會反彈，打中一個還會彈去下一個。",
	},
	"bubble_gun": {
		"name": "泡泡槍", "price": 260, "weight": 1.2, "length": 40.0, "tags": ["energy"], "cal": "soap",
		"damage": 2.0, "rate": 4.0, "modes": ["auto"], "mag": 50, "reserve": 100, "reload": 2.0,
		"spread": 2.0, "moa": 6.0, "range": 20.0, "noise": 6.0, "recoil": 0.2, "recoil_h": 0.2, "zoom": 1.0,
		"ergo": 85.0, "velocity": 15.0, "pen": 0.0, "flash": 0.0, "reliability": 97.0,
		"effects": {"bubble": 4.0},
		"slots": ["magazine", "rail_l", "gadget"],
		"desc": "幾乎不痛，但小怪會被包進泡泡裡飄 4 秒，中型怪要連中好幾發。",
	},
	# --- CHAOS: guns that bend the rules (movement, ricochets, grapples)
	"jump_shotgun": {
		"name": "推進霰彈槍", "price": 520, "weight": 3.8, "length": 80.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 9.0, "pellets": 10, "rate": 1.0, "mag": 4, "reserve": 16, "reload": 2.8,
		"spread": 9.0, "moa": 10.0, "range": 18.0, "noise": 60.0, "recoil": 9.0, "recoil_h": 1.6, "zoom": 1.1,
		"ergo": 52.0, "velocity": 380.0, "pen": 12.0, "flash": 80.0, "reliability": 95.0,
		"effects": {"knock": 2.0, "recoil_push": 9.0},
		"slots": ["barrel", "muzzle", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "stock", "gadget"],
		"desc": "後座力大到能把人轟上天：朝地板開一槍就是二段跳，朝牆開一槍就是衝刺。",
	},
	"gyrojet": {
		"name": "火箭手槍", "price": 480, "weight": 1.3, "length": 26.0, "tags": ["gun"], "cal": "rocket",
		"damage": 20.0, "rate": 2.0, "mag": 6, "reserve": 24, "reload": 2.4,
		"spread": 2.0, "moa": 10.0, "range": 70.0, "noise": 22.0, "recoil": 1.0, "recoil_h": 0.4, "zoom": 1.2,
		"ergo": 70.0, "velocity": 250.0, "pen": 30.0, "flash": 30.0, "reliability": 82.0,
		"effects": {"long_bonus": 2.2},
		"slots": ["barrel", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "gadget"],
		"desc": "小火箭出膛時很慢，越飛越快：近距離軟綿綿，遠距離一發比一發痛。",
	},
	"minigun": {
		"name": "手提六管機槍", "price": 1500, "weight": 14.0, "length": 95.0, "tags": ["gun"], "cal": "5.56",
		"damage": 8.0, "rate": 30.0, "modes": ["auto"], "mag": 300, "reserve": 300, "reload": 6.0,
		"spread": 5.5, "moa": 14.0, "range": 45.0, "noise": 70.0, "recoil": 0.6, "recoil_h": 2.2, "zoom": 1.05,
		"ergo": 15.0, "velocity": 900.0, "pen": 35.0, "flash": 90.0, "reliability": 90.0, "heat": 0.012, "cooling": 0.25,
		"effects": {"recoil_push": 0.18},
		"slots": ["muzzle", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "gadget"],
		"desc": "每秒三十發。重到你跑不動；在空中開火會把你一路往後推。",
	},
	"quad_barrel": {
		"name": "四管獵槍", "price": 640, "weight": 4.6, "length": 100.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 10.0, "pellets": 8, "rate": 3.0, "modes": ["semi", "double"], "mag": 4, "reserve": 20, "reload": 3.2,
		"spread": 8.0, "moa": 9.0, "range": 24.0, "noise": 64.0, "recoil": 8.0, "recoil_h": 1.3, "zoom": 1.15,
		"ergo": 50.0, "velocity": 400.0, "pen": 15.0, "flash": 80.0, "reliability": 99.0,
		"effects": {"knock": 1.6},
		"slots": ["muzzle", "rail_l", "sight", "trigger", "ammo", "stock", "buttpad", "gadget"],
		"desc": "四根管子。兩兩一起轟，兩秒內四發。換彈要很久。",
	},
	"punt_gun": {
		"name": "平底船巨砲", "price": 900, "weight": 16.0, "length": 180.0, "tags": ["gun", "pellet"], "cal": "4g",
		"damage": 6.0, "pellets": 40, "rate": 0.4, "mag": 1, "reserve": 6, "reload": 4.5,
		"spread": 11.0, "moa": 12.0, "range": 30.0, "noise": 90.0, "recoil": 16.0, "recoil_h": 2.0, "zoom": 1.05,
		"ergo": 10.0, "velocity": 350.0, "pen": 20.0, "flash": 100.0, "reliability": 97.0,
		"effects": {"knock": 6.0, "recoil_push": 16.0},
		"slots": ["rail_l", "sight", "trigger", "ammo", "stock", "gadget"],
		"desc": "本來是架在船頭打整群野鴨的。開一槍，你自己也會飛出去十公尺。",
	},
	"pneumatic_lance": {
		"name": "氣動穿刺槍", "price": 560, "weight": 3.2, "length": 85.0, "tags": ["energy"], "cal": "air", "kind": "charge",
		"damage": 70.0, "rate": 0.8, "mag": 4, "reserve": 12, "reload": 2.5,
		"spread": 0.0, "moa": 1.0, "range": 7.0, "noise": 18.0, "recoil": 3.0, "recoil_h": 0.3, "zoom": 1.0,
		"ergo": 55.0, "velocity": 120.0, "pen": 80.0, "flash": 0.0, "reliability": 96.0,
		"effects": {"pierce": true, "knock": 5.0, "grapple": 7.0},
		"slots": ["rail_l", "sight", "grip", "magazine", "stock", "gadget"],
		"desc": "蓄力刺出一根鋼釺：七公尺內貫穿一切，順便把你往命中點拉過去。",
	},
	"ricochet_smg": {
		"name": "跳彈衝鋒槍", "price": 560, "weight": 2.4, "length": 55.0, "tags": ["gun"], "cal": "9mm",
		"damage": 9.0, "rate": 13.0, "modes": ["auto", "semi"], "mag": 30, "reserve": 90, "reload": 1.9,
		"spread": 3.2, "moa": 9.0, "range": 28.0, "noise": 34.0, "recoil": 1.2, "recoil_h": 1.2, "zoom": 1.15,
		"ergo": 74.0, "velocity": 380.0, "pen": 15.0, "flash": 45.0, "reliability": 90.0,
		"effects": {"ricochet": 2},
		"slots": ["muzzle", "rail_l", "foregrip", "sight", "grip", "trigger", "bolt", "magazine", "ammo", "stock", "gadget"],
		"desc": "槍管裡的導流片讓子彈帶旋：打到牆會再彈兩次。轉角殺手。",
	},
	"glass_revolver": {
		"name": "玻璃左輪", "price": 700, "weight": 0.7, "length": 26.0, "tags": ["gun", "revolver"], "cal": ".357",
		"damage": 30.0, "rate": 1.6, "mag": 5, "reserve": 20, "reload": 2.4,
		"spread": 2.0, "moa": 3.0, "range": 45.0, "noise": 32.0, "recoil": 4.0, "recoil_h": 0.8, "zoom": 1.25,
		"ergo": 82.0, "velocity": 450.0, "pen": 25.0, "flash": 50.0, "reliability": 85.0, "heat": 0.3, "cooling": 0.22,
		"effects": {"headhunter": true},
		"slots": ["rail_l", "sight", "grip", "trigger", "magazine", "ammo", "gadget"],
		"desc": "整把用強化玻璃做的。輕、狠，頭部三倍傷害；連開三槍就燙到要等它冷。",
	},
	"tuning_fork": {
		"name": "音叉共振槍", "price": 720, "weight": 3.0, "length": 70.0, "tags": ["energy"], "cal": "cell", "kind": "arc",
		"damage": 12.0, "rate": 2.5, "modes": ["auto"], "mag": 18, "reserve": 36, "reload": 2.6,
		"spread": 0.0, "moa": 0.0, "range": 16.0, "noise": 40.0, "recoil": 0.8, "recoil_h": 0.3, "zoom": 1.0,
		"ergo": 58.0, "velocity": 0.0, "pen": 20.0, "flash": 20.0, "reliability": 95.0, "heat": 0.04, "cooling": 0.35,
		"effects": {"chain": 4, "slow": 1.0},
		"slots": ["rail_l", "sight", "grip", "magazine", "stock", "gadget"],
		"desc": "敲響一根巨大的音叉：震波在人與人之間跳躍，一次連到五個人，被震到的都會慢下來。",
	},
	"anchor_gun": {
		"name": "船錨鉤槍", "price": 540, "weight": 3.6, "length": 90.0, "tags": ["bolt"], "cal": "bolt",
		"damage": 55.0, "rate": 0.6, "mag": 1, "reserve": 10, "reload": 1.6,
		"spread": 0.4, "moa": 3.0, "range": 45.0, "noise": 20.0, "recoil": 4.0, "recoil_h": 0.4, "zoom": 1.3,
		"ergo": 50.0, "velocity": 90.0, "pen": 40.0, "flash": 0.0, "reliability": 99.0,
		"effects": {"grapple": 14.0},
		"slots": ["rail_l", "mount", "sight", "trigger", "ammo", "stock", "gadget"],
		"desc": "射出帶纜繩的船錨：打到哪裡就把你拉過去。牆、天花板、敵人都行。",
	},
}

## Parts. Keys:
##   slot     the slot type it goes in
##   fits     frame tags or calibre families it goes on ("all" for anything with that slot)
##   frames   only these frames (when given)
##   cal      only these calibres (when given; checked against the build's calibre so far)
##   adds     slots it opens; blocks = slots it closes
##   set_cal  the build's calibre becomes this
##   modes    fire modes it adds; set_modes replaces them
##   x / + / = mods applied in order ("x" multiplies a stat, "+" adds, "=" sets);
##            "effects" merges into the frame's
##   tune     a slider the player sets from -1 to 1: {"name", "lo", "hi", "x": {stat: [at -1, at +1]},
##            "+": {stat: [at -1, at +1]}, "=": {stat: [at -1, at +1]}}. At 0 an "x" is 1.0 and a "+" is 0;
##            an "=" sits halfway.
const PARTS := {
	# --- Receivers / uppers (機匣): calibre conversions and whole new backbones
	"upper_300": {"name": ".300 BLK 上機匣", "slot": "receiver", "price": 380, "weight": 0.1, "fits": ["ar"], "frames": ["carbine"],
		"set_cal": ".300", "x": {"damage": 1.25, "velocity": 0.78, "range": 0.8, "recoil": 1.15, "pen": 1.05},
		"desc": "改成 .300 BLK 口徑：更痛、射程短一點。配亞音速彈加消音器，幾乎是無聲步槍。"},
	"upper_pcc": {"name": "9mm 手槍彈上機匣", "slot": "receiver", "price": 240, "weight": -0.3, "fits": ["ar"], "frames": ["carbine"],
		"set_cal": "9mm", "x": {"damage": 0.6, "velocity": 0.42, "recoil": 0.5, "recoil_h": 0.6, "range": 0.6, "noise": 0.7,
		"pen": 0.5, "rate": 1.1, "flash": 0.7}, "+": {"reliability": 5.0, "ergo": 4.0},
		"desc": "把步槍改打手槍彈：幾乎沒有後座、比較安靜。傷害和穿透大減。"},
	"upper_light": {"name": "輕量化上機匣", "slot": "receiver", "price": 300, "weight": -0.5, "fits": ["ar"],
		"x": {"cooling": 0.8}, "+": {"ergo": 5.0}, "desc": "鏤空切削，輕半公斤。散熱差一點。"},
	"upper_billet": {"name": "整塊切削上機匣", "slot": "receiver", "price": 420, "weight": 0.2, "fits": ["ar"],
		"x": {"moa": 0.85, "recoil_h": 0.9}, "+": {"reliability": 3.0},
		"desc": "一整塊鋁錠銑出來的，零件之間沒有晃動。更準。"},
	"ak_cover": {"name": "導軌防塵蓋", "slot": "receiver", "price": 140, "weight": 0.25, "fits": ["ak"],
		"adds": ["rail_r"], "x": {"moa": 1.05}, "desc": "防塵蓋上有導軌，多一個掛配件的位置。蓋子會晃，準度略差。"},
	"ak_modern": {"name": "現代化套件", "slot": "receiver", "price": 360, "weight": 0.3, "fits": ["ak"],
		"adds": ["rail_r"], "x": {"recoil_h": 0.8, "reload": 0.9}, "+": {"ergo": 6.0},
		"desc": "大保險、新拉柄、導軌蓋一次換好。比較順手。"},
	"precision_chassis": {"name": "精準底盤", "slot": "receiver", "price": 520, "weight": 1.2, "fits": ["bolt_action"],
		"adds": ["rail_r", "buttpad"], "x": {"moa": 0.7, "recoil": 0.9}, "+": {"ergo": -4.0},
		"desc": "鋁合金底盤取代木托：非常準，多出導軌和托底的位置。"},
	"cylinder_8": {"name": "八發轉輪", "slot": "receiver", "price": 220, "weight": 0.2, "fits": ["revolver"],
		"x": {"reload": 1.1}, "+": {"mag": 2}, "desc": "加大的轉輪，八發。換彈要多塞兩顆。"},
	"cylinder_45": {"name": ".45 轉換轉輪", "slot": "receiver", "price": 200, "weight": 0.1, "fits": ["revolver"],
		"set_cal": ".45", "x": {"damage": 1.2, "velocity": 0.6, "recoil": 1.1, "pen": 0.85},
		"desc": "換成 .45 ACP 的轉輪：子彈更大顆、亞音速。配消音器很安靜。"},

	# --- Barrels (槍管)
	"long_barrel": {"name": "長槍管", "slot": "barrel", "price": 160, "weight": 0.8, "fits": ["gun"],
		"x": {"range": 1.4, "spread": 0.7, "damage": 1.1, "velocity": 1.1, "moa": 0.85, "flash": 0.8}, "+": {"length": 15.0, "ergo": -6.0},
		"desc": "更遠更準，比較重、比較長。"},
	"short_barrel": {"name": "短槍管", "slot": "barrel", "price": 90, "weight": -0.3, "fits": ["gun"],
		"x": {"spread": 1.3, "rate": 1.15, "range": 0.8, "velocity": 0.88, "flash": 1.5, "moa": 1.2}, "+": {"length": -10.0, "ergo": 6.0},
		"desc": "射得快、好轉身，但散，火光大。"},
	"threaded_barrel": {"name": "螺紋槍管", "slot": "barrel", "price": 110, "weight": 0.1, "fits": ["pistol_frame", "revolver", "lever"],
		"adds": ["muzzle"], "+": {"length": 3.0},
		"desc": "槍口車了螺紋：手槍和左輪也能裝消音器、制退器。"},
	"heavy_barrel": {"name": "重型槍管", "slot": "barrel", "price": 240, "weight": 1.2, "fits": ["gun"],
		"x": {"moa": 0.6, "cooling": 1.4, "heat": 0.75}, "+": {"ergo": -8.0},
		"desc": "管壁很厚：連射也不會飄，很耐熱。非常重。"},
	"fluted_barrel": {"name": "刻槽槍管", "slot": "barrel", "price": 260, "weight": -0.3, "fits": ["gun"],
		"x": {"moa": 0.85, "cooling": 1.3}, "+": {"ergo": 3.0}, "desc": "槍管上銑出凹槽：更輕、散熱更好、更準。"},
	"match_barrel": {"name": "比賽級槍管", "slot": "barrel", "price": 380, "weight": 0.2, "fits": ["gun"],
		"x": {"moa": 0.5, "velocity": 1.03}, "+": {"reliability": -5.0},
		"desc": "公差很小的競賽槍管，非常準。對髒污很敏感，比較容易卡。"},
	"polygonal_barrel": {"name": "多邊形膛線槍管", "slot": "barrel", "price": 200, "weight": 0.0, "fits": ["gun"],
		"x": {"velocity": 1.08, "moa": 0.9, "cooling": 1.1}, "desc": "沒有陽線的膛線：子彈更快、槍管更耐用。"},
	"integral_suppressor": {"name": "整合消音槍管", "slot": "barrel", "price": 520, "weight": 0.9, "fits": ["gun"],
		"blocks": ["muzzle"], "x": {"noise": 0.3, "velocity": 0.85, "flash": 0.1, "range": 0.85, "damage": 0.95}, "+": {"length": 12.0, "ergo": -5.0},
		"effects": {"suppressed": true}, "desc": "消音器做在槍管裡面：很安靜、沒有火光，不能再裝槍口裝置。"},
	"bbl_338": {"name": ".338 拉普槍管", "slot": "barrel", "price": 600, "weight": 0.8, "fits": ["bolt_action"], "frames": ["rifle"],
		"set_cal": ".338", "x": {"damage": 1.45, "recoil": 1.45, "noise": 1.2, "range": 1.3, "reserve": 0.75, "velocity": 1.05, "pen": 1.25, "flash": 1.3},
		"+": {"length": 10.0, "ergo": -5.0}, "desc": "改成 .338 拉普麥格農：大型怪也打得穿。後座和聲音都更兇。"},
	"rifled_slug_barrel": {"name": "膛線霰彈槍管", "slot": "barrel", "price": 180, "weight": 0.2, "fits": ["pellet"],
		"x": {"moa": 0.45, "spread": 1.2}, "desc": "霰彈槍管裡刻了膛線：獨頭彈打得很準，霰彈反而更散。"},
	"coil_barrel": {"name": "加速線圈", "slot": "barrel", "price": 260, "weight": 1.0, "fits": ["energy"],
		"x": {"damage": 1.35, "noise": 1.3, "range": 1.2, "heat": 1.3}, "desc": "電力加大：更痛、更吵、更燙。"},
	"cooling_coil": {"name": "液冷線圈", "slot": "barrel", "price": 300, "weight": 1.2, "fits": ["energy"],
		"x": {"cooling": 2.0, "heat": 0.7}, "+": {"ergo": -5.0}, "desc": "管線裡流著冷卻液：很少過熱。"},
	"nail_guide": {"name": "加長導釘管", "slot": "barrel", "price": 90, "weight": 0.3, "fits": ["gun"], "cal": ["nail"],
		"x": {"range": 1.5, "moa": 0.7, "damage": 1.15}, "desc": "釘子在管子裡跑得更久：更遠更準。"},

	# --- Muzzle devices (槍口)
	"suppressor": {"name": "螺紋消音器", "slot": "muzzle", "price": 180, "weight": 0.4, "fits": ["gun"],
		"x": {"noise": 0.35, "damage": 0.95, "flash": 0.15, "velocity": 1.02}, "+": {"length": 15.0, "ergo": -5.0},
		"effects": {"suppressed": true}, "desc": "直接鎖在槍口上。槍聲小很多（超音速彈還是會有破空聲），幾乎沒有火光。"},
	"compensator": {"name": "補償器", "slot": "muzzle", "price": 120, "weight": 0.2, "fits": ["gun"],
		"x": {"recoil_h": 0.55, "recoil": 0.85, "spread": 0.9, "flash": 1.1}, "desc": "把氣往上噴：槍口不左右跳，連射更穩。"},
	"muzzle_brake": {"name": "制動器", "slot": "muzzle", "price": 150, "weight": 0.25, "fits": ["gun"],
		"adds": ["silencer"], "x": {"recoil": 0.6, "noise": 1.25, "flash": 1.3}, "+": {"length": 6.0},
		"desc": "把氣往兩邊噴：後座小很多，但更吵、火光更大。可以掛快拆消音器。"},
	"flash_hider": {"name": "消焰器", "slot": "muzzle", "price": 90, "weight": 0.15, "fits": ["gun"],
		"adds": ["silencer"], "x": {"flash": 0.3}, "+": {"length": 5.0},
		"desc": "火光幾乎看不見，光感怪物比較難發現你開槍。可以掛快拆消音器。"},
	"thread_adapter": {"name": "螺紋轉接器", "slot": "muzzle", "price": 40, "weight": 0.05, "fits": ["gun"],
		"adds": ["silencer"], "+": {"length": 2.0}, "desc": "什麼都不做，只是讓你能掛快拆消音器。"},
	"linear_comp": {"name": "線性補償器", "slot": "muzzle", "price": 110, "weight": 0.2, "fits": ["gun"],
		"x": {"noise": 0.85, "recoil": 0.92, "flash": 0.8}, "+": {"length": 5.0},
		"desc": "把聲音和氣都往前送：你聽起來安靜一點，前面的東西聽得更清楚。"},
	"solvent_trap": {"name": "油濾土製消音器", "slot": "muzzle", "price": 60, "weight": 0.5, "fits": ["gun"],
		"x": {"noise": 0.5, "flash": 0.4, "moa": 1.3}, "+": {"reliability": -8.0, "length": 18.0, "ergo": -6.0},
		"effects": {"suppressed": true}, "desc": "汽車油濾鑽個洞鎖上去。有效，但會讓槍變髒、變不準。"},
	"bottle_can": {"name": "寶特瓶消音器", "slot": "muzzle", "price": 15, "weight": 0.05, "fits": ["gun"],
		"x": {"noise": 0.55, "moa": 1.7, "spread": 1.2}, "+": {"length": 22.0, "ergo": -3.0},
		"effects": {"suppressed": true}, "desc": "一個膠帶纏住的寶特瓶。十五塊。真的有用，只是子彈會亂飛。"},
	"choke": {"name": "收束器", "slot": "muzzle", "price": 100, "weight": 0.2, "fits": ["pellet"],
		"tune": {"name": "收束", "lo": "圓柱", "hi": "全收", "x": {"spread": [1.25, 0.45], "range": [0.9, 1.3]}},
		"x": {"spread": 0.8, "range": 1.1}, "desc": "可調收束：轉緊打得集中、打得遠；轉鬆近距離散得更開。"},
	"duckbill": {"name": "鴨嘴噴口", "slot": "muzzle", "price": 120, "weight": 0.2, "fits": ["pellet"],
		"+": {"pellets": 2}, "x": {"spread": 1.25, "damage": 0.9}, "desc": "把霰彈壓成一條橫線：一次掃到更多東西。"},
	"breacher": {"name": "破門齒", "slot": "muzzle", "price": 80, "weight": 0.2, "fits": ["pellet"],
		"x": {"flash": 1.2}, "effects": {"bayonet": true}, "desc": "鋸齒狀的槍口：抵著東西打，也能直接拿來砸（近戰兩倍）。"},
	"wide_nozzle": {"name": "寬口噴嘴", "slot": "muzzle", "price": 140, "weight": 0.3, "fits": ["fuel"],
		"x": {"range": 0.75, "damage": 1.3}, "desc": "火噴得近，但更猛。"},
	"long_nozzle": {"name": "長管噴嘴", "slot": "muzzle", "price": 160, "weight": 0.4, "fits": ["fuel"],
		"x": {"range": 1.4, "damage": 0.85}, "+": {"length": 20.0, "ergo": -5.0}, "desc": "火柱噴得更遠，不過散開的熱力少一點。"},

	# --- Quick-detach suppressors (消音器, on a flash hider / brake / adapter)
	"can_light": {"name": "輕型快拆消音器", "slot": "silencer", "price": 260, "weight": 0.35, "fits": ["gun"],
		"x": {"noise": 0.4, "flash": 0.15, "damage": 0.97}, "+": {"length": 14.0, "ergo": -5.0},
		"effects": {"suppressed": true}, "desc": "一秒拆裝。聲音小六成。"},
	"can_heavy": {"name": "重型快拆消音器", "slot": "silencer", "price": 420, "weight": 0.7, "fits": ["gun"],
		"x": {"noise": 0.22, "flash": 0.05, "velocity": 1.03, "recoil": 0.9}, "+": {"length": 22.0, "ergo": -11.0},
		"effects": {"suppressed": true}, "desc": "又長又重，但非常安靜，後座也小一點。"},
	"can_titanium": {"name": "鈦合金短消音器", "slot": "silencer", "price": 560, "weight": 0.2, "fits": ["gun"],
		"x": {"noise": 0.45, "flash": 0.2}, "+": {"length": 9.0, "ergo": -2.0},
		"effects": {"suppressed": true}, "desc": "短、輕、貴。幾乎不影響手感。"},
	"can_wet": {"name": "濕式消音器", "slot": "silencer", "price": 300, "weight": 0.5, "fits": ["gun"],
		"x": {"noise": 0.18, "flash": 0.05, "cooling": 0.7}, "+": {"length": 16.0, "ergo": -6.0, "reliability": -4.0},
		"effects": {"suppressed": true}, "desc": "裡面灌了水：最安靜的消音器。槍會變得濕熱、比較容易卡。"},

	# --- Gas (導氣)
	"adjustable_gas": {"name": "可調導氣塊", "slot": "gas", "price": 180, "weight": 0.05, "fits": ["gun"],
		"tune": {"name": "導氣量", "lo": "少", "hi": "多", "x": {"rate": [0.8, 1.2], "recoil": [0.8, 1.25]},
			"+": {"reliability": [-10.0, 6.0]}},
		"desc": "自己調導氣量：調少後座小、射速慢、比較容易卡；調多射速快、後座大、很可靠。配消音器時調少剛好。"},
	"low_profile_gas": {"name": "低矮導氣塊", "slot": "gas", "price": 80, "weight": -0.05, "fits": ["gun"],
		"+": {"ergo": 3.0}, "desc": "藏在護木裡面的小導氣塊。順手一點。"},
	"piston_kit": {"name": "活塞套件", "slot": "gas", "price": 260, "weight": 0.3, "fits": ["gun"],
		"x": {"recoil": 1.1, "cooling": 1.15}, "+": {"reliability": 14.0},
		"desc": "把直噴改成活塞：機匣不再積碳，幾乎不卡。後座稍大。"},

	# --- Handguards (護木): where most of the accessory slots come from
	"short_handguard": {"name": "短護木", "slot": "handguard", "price": 110, "weight": 0.2, "fits": ["gun"],
		"adds": ["rail_l", "foregrip"], "+": {"ergo": 6.0}, "desc": "短而輕，只有一條側軌和一個握把位置。"},
	"long_handguard": {"name": "長護木", "slot": "handguard", "price": 160, "weight": 0.35, "fits": ["gun"],
		"adds": ["rail_l", "rail_r", "foregrip", "underbarrel"], "x": {"recoil_h": 0.95}, "+": {"ergo": -1.0},
		"desc": "M-LOK 長護木：兩邊導軌、前握把和下掛都有位置。"},
	"quad_rail": {"name": "四面導軌護木", "slot": "handguard", "price": 180, "weight": 0.6, "fits": ["gun"],
		"adds": ["rail_l", "rail_r", "foregrip", "underbarrel"], "x": {"recoil": 0.95}, "+": {"ergo": -5.0},
		"desc": "四面都是皮卡汀尼導軌，硬、重、刮手。"},
	"wood_handguard": {"name": "木護木", "slot": "handguard", "price": 70, "weight": 0.25, "fits": ["gun"],
		"adds": ["underbarrel"], "+": {"ergo": 4.0}, "x": {"cooling": 0.9}, "desc": "老式木頭護木，握起來很舒服。沒有導軌。"},
	"heatshield": {"name": "散熱護木", "slot": "handguard", "price": 200, "weight": 0.3, "fits": ["gun"],
		"adds": ["rail_l", "foregrip"], "x": {"cooling": 1.5}, "desc": "滿滿的散熱孔：連射後很快冷下來。"},
	"pump_rail": {"name": "導軌泵動護木", "slot": "handguard", "price": 120, "weight": 0.3, "fits": ["pellet"],
		"adds": ["rail_l", "foregrip"], "x": {"rate": 1.08}, "desc": "泵動霰彈的護木換成帶導軌的，拉起來更快。"},

	# --- Rail accessories (導軌配件)
	"flashlight": {"name": "戰術燈", "slot": "rail", "price": 70, "weight": 0.2, "fits": "all",
		"effects": {"light": true}, "desc": "槍上的燈，跟著準心照。開著燈的你很好認。"},
	"laser": {"name": "雷射指示器", "slot": "rail", "price": 120, "weight": 0.1, "fits": "all",
		"x": {"spread": 0.7}, "effects": {"laser": true}, "desc": "不瞄準也打得準。紅點別人看得到。"},
	"laser_ir": {"name": "紅外線雷射", "slot": "rail", "price": 260, "weight": 0.15, "fits": "all",
		"x": {"spread": 0.75}, "effects": {"laser_ir": true}, "desc": "看不見的雷射：一樣讓腰射更準，但別人看不到你的點。"},
	"combo_light": {"name": "光雷二合一", "slot": "rail", "price": 220, "weight": 0.3, "fits": "all",
		"x": {"spread": 0.75}, "effects": {"light": true, "laser": true}, "desc": "燈和雷射在一個盒子裡，只佔一條軌道。"},
	"strobe_light": {"name": "爆閃戰術燈", "slot": "rail", "price": 180, "weight": 0.25, "fits": "all",
		"effects": {"light": true, "strobe": true}, "desc": "會頻閃的強光：瞄準時照到的玩家會被閃得看不清楚。怪物也會注意到你。"},
	"rail_counter": {"name": "彈數顯示器", "slot": "rail", "price": 90, "weight": 0.05, "fits": "all",
		"x": {"reload": 0.95}, "desc": "一個小螢幕告訴你彈匣裡還剩幾發。知道什麼時候該換彈，換得快一點。"},

	# --- Foregrips (前握把)
	"vertical_grip": {"name": "垂直握把", "slot": "foregrip", "price": 80, "weight": 0.15, "fits": "all",
		"x": {"recoil": 0.85}, "+": {"ergo": 2.0}, "desc": "壓得住往上跳的槍口。"},
	"angled_grip": {"name": "斜角握把", "slot": "foregrip", "price": 90, "weight": 0.1, "fits": "all",
		"x": {"recoil": 0.95, "recoil_h": 0.9}, "+": {"ergo": 8.0}, "desc": "手腕自然的角度：舉槍瞄準快很多。"},
	"stubby_grip": {"name": "短握把", "slot": "foregrip", "price": 60, "weight": 0.08, "fits": "all",
		"x": {"recoil": 0.92}, "+": {"ergo": 4.0}, "desc": "折衷：一點點穩，一點點快。"},
	"handstop": {"name": "擋手", "slot": "foregrip", "price": 40, "weight": 0.04, "fits": "all",
		"x": {"recoil_h": 0.85}, "+": {"ergo": 3.0}, "desc": "手往前頂住：槍口不左右晃。"},
	"bipod": {"name": "兩腳架", "slot": "foregrip", "price": 160, "weight": 0.5, "fits": "all",
		"x": {"recoil": 0.95}, "+": {"ergo": -6.0}, "effects": {"bipod": true},
		"desc": "站著不動瞄準時架起來：後座只剩三成，散佈也小。走動時就只是累贅。"},
	"grip_pod": {"name": "握把腳架", "slot": "foregrip", "price": 220, "weight": 0.3, "fits": "all",
		"x": {"recoil": 0.9}, "+": {"ergo": -1.0}, "effects": {"bipod": true},
		"desc": "握把底下彈出小腳架。腳架效果沒那麼好（後座剩五成），但平常也能當握把。"},

	# --- Underbarrel (下掛)
	"bayonet": {"name": "刺刀", "slot": "underbarrel", "price": 60, "weight": 0.3, "fits": "all",
		"effects": {"bayonet": true}, "desc": "近戰（V）傷害兩倍。"},
	"spike_bayonet": {"name": "三稜刺", "slot": "underbarrel", "price": 90, "weight": 0.35, "fits": "all",
		"effects": {"bayonet": true, "bleed": 3.0}, "+": {"length": 30.0, "ergo": -2.0},
		"desc": "很長的三角刺：近戰兩倍，刺到的東西會流血 3 秒。"},
	"chainsaw_bayonet": {"name": "鏈鋸刺刀", "slot": "underbarrel", "price": 280, "weight": 1.6, "fits": "all",
		"effects": {"bayonet": true, "fang": true}, "x": {"noise": 1.1}, "+": {"ergo": -10.0},
		"desc": "槍管底下的小鏈鋸：近戰三倍。很重，而且一直在嗡嗡叫。"},
	"riot_shield": {"name": "小型防彈盾", "slot": "underbarrel", "price": 320, "weight": 2.5, "fits": "all",
		"effects": {"guard": 0.25}, "x": {"spread": 1.1}, "+": {"ergo": -12.0},
		"desc": "掛在槍下的小盾：瞄準時受到的傷害少四分之一。非常礙手。"},

	# --- Offset / backup sights (副瞄座)
	"canted_dot": {"name": "偏置紅點", "slot": "mount", "price": 140, "weight": 0.1, "fits": "all",
		"x": {"spread": 0.75}, "effects": {"canted": true}, "desc": "主鏡旁邊斜裝一個紅點：不舉鏡也能打得比較準。"},
	"backup_irons": {"name": "折疊備用照門", "slot": "mount", "price": 70, "weight": 0.05, "fits": "all",
		"+": {"ergo": 3.0}, "x": {"moa": 0.95}, "desc": "主鏡起霧時還有東西可以看。順手一點。"},
	"cantilever": {"name": "懸臂鏡座", "slot": "mount", "price": 100, "weight": 0.15, "fits": "all",
		"x": {"moa": 0.92}, "+": {"ergo": -1.0}, "desc": "把主鏡往前推到剛好的位置，眼睛不用找。"},
	"riser": {"name": "增高座", "slot": "mount", "price": 60, "weight": 0.08, "fits": "all",
		"x": {"recoil": 0.95}, "+": {"ergo": 2.0}, "desc": "鏡子架高一點，抬頭就看到，脖子比較不受後座影響。"},

	# --- Sights (瞄具)
	"peep_sight": {"name": "覘孔照門", "slot": "sight", "price": 60, "weight": 0.05, "fits": "all",
		"x": {"moa": 0.85}, "=": {"zoom": 1.2}, "desc": "簡單的小孔照門。比原廠準。"},
	"red_dot": {"name": "紅點瞄具", "slot": "sight", "price": 110, "weight": 0.2, "fits": "all",
		"x": {"spread": 0.8, "moa": 0.85}, "+": {"ergo": 2.0}, "=": {"zoom": 1.35}, "desc": "瞄準時更準、更快。"},
	"pistol_dot": {"name": "手槍紅點", "slot": "sight", "price": 120, "weight": 0.05, "fits": ["pistol_frame", "revolver"],
		"x": {"moa": 0.8}, "+": {"ergo": 3.0}, "=": {"zoom": 1.25}, "desc": "滑套上的迷你紅點。手槍也能打得準。"},
	"holo": {"name": "全息瞄具", "slot": "sight", "price": 200, "weight": 0.3, "fits": "all",
		"x": {"spread": 0.75, "moa": 0.85}, "+": {"ergo": 3.0}, "=": {"zoom": 1.3}, "desc": "大窗口、兩眼睜開，近戰瞄準最快。"},
	"acog": {"name": "固定 4 倍鏡", "slot": "sight", "price": 280, "weight": 0.45, "fits": "all",
		"x": {"moa": 0.75}, "+": {"ergo": -3.0}, "=": {"zoom": 2.4}, "desc": "短而硬的四倍鏡：中距離剛好。"},
	"scope": {"name": "8 倍狙擊鏡", "slot": "sight", "price": 240, "weight": 0.5, "fits": "all",
		"x": {"spread": 0.6, "moa": 0.7}, "+": {"ergo": -6.0}, "=": {"zoom": 3.0}, "desc": "看得很遠。近距離反而難用。"},
	"variable_scope": {"name": "1-6 倍可變鏡", "slot": "sight", "price": 450, "weight": 0.6, "fits": "all",
		"x": {"moa": 0.75}, "+": {"ergo": -4.0},
		"tune": {"name": "倍率", "lo": "1 倍", "hi": "6 倍", "=": {"zoom": [1.15, 3.6]}, "+": {"ergo": [3.0, -4.0]}},
		"desc": "自己轉倍率：1 倍近戰、6 倍遠距離。"},
	"thermal": {"name": "熱成像鏡", "slot": "sight", "price": 420, "weight": 0.6, "fits": "all",
		"=": {"zoom": 1.6}, "+": {"ergo": -4.0}, "effects": {"thermal": true}, "desc": "瞄準時看得到黑暗裡和隱形的怪物。"},
	"night_vision": {"name": "夜視瞄具", "slot": "sight", "price": 380, "weight": 0.55, "fits": "all",
		"=": {"zoom": 1.5}, "+": {"ergo": -3.0}, "effects": {"night": true},
		"desc": "瞄準時整片黑暗都變成綠色的白天。看到的是地形，不是怪物身上的熱。"},

	# --- Pistol grips (握把)
	"rubber_grip": {"name": "橡膠握把", "slot": "grip", "price": 50, "weight": 0.05, "fits": "all",
		"x": {"recoil": 0.92}, "+": {"ergo": 3.0}, "desc": "不滑手，吸收一點後座。"},
	"skeleton_grip": {"name": "鏤空握把", "slot": "grip", "price": 90, "weight": -0.05, "fits": "all",
		"+": {"ergo": 6.0}, "desc": "很輕，抓起來很快。"},
	"wood_grip": {"name": "胡桃木握把", "slot": "grip", "price": 120, "weight": 0.1, "fits": "all",
		"x": {"recoil": 0.88}, "+": {"ergo": -1.0}, "desc": "沉甸甸的木頭，把槍壓得很穩。"},
	"tape_grip": {"name": "膠帶纏繞", "slot": "grip", "price": 10, "weight": 0.0, "fits": "all",
		"+": {"ergo": 2.0}, "desc": "整卷布膠帶纏上去。十塊。"},
	"stippled_grip": {"name": "燒灼防滑握把", "slot": "grip", "price": 70, "weight": 0.0, "fits": "all",
		"x": {"recoil_h": 0.9}, "+": {"ergo": 4.0}, "desc": "用烙鐵燙出顆粒：手汗也不滑。"},

	# --- Trigger groups (扳機組)
	"match_trigger": {"name": "比賽扳機", "slot": "trigger", "price": 160, "weight": 0.0, "fits": "all",
		"x": {"moa": 0.85},
		"tune": {"name": "扳機力", "lo": "輕", "hi": "重", "x": {"rate": [1.15, 0.92], "moa": [1.1, 0.88]}},
		"desc": "乾淨俐落的擊發。可以調扳機力：輕的射得快、重的打得準。"},
	"auto_sear": {"name": "全自動阻鐵", "slot": "trigger", "price": 450, "weight": 0.05, "fits": ["gun"],
		"modes": ["auto"], "+": {"reliability": -8.0}, "x": {"heat": 1.1},
		"desc": "讓半自動槍能全自動。不太合法，也不太可靠。"},
	"burst_group": {"name": "三連發扳機組", "slot": "trigger", "price": 300, "weight": 0.05, "fits": ["gun"],
		"modes": ["burst"], "x": {"recoil": 0.95}, "desc": "扣一下打三發。比全自動好控制。"},
	"binary_trigger": {"name": "二元扳機", "slot": "trigger", "price": 380, "weight": 0.05, "fits": ["gun"],
		"x": {"rate": 1.6, "spread": 1.15}, "+": {"reliability": -4.0},
		"desc": "扣下去打一發，放開再打一發。半自動快很多。"},
	"hair_trigger": {"name": "羽毛扳機", "slot": "trigger", "price": 120, "weight": 0.0, "fits": "all",
		"x": {"rate": 1.15, "spread": 1.1}, "desc": "碰一下就擊發。快，但緊張時容易打歪。"},
	"double_set": {"name": "雙扳機（預扣）", "slot": "trigger", "price": 220, "weight": 0.05, "fits": ["bolt_action", "lever", "pellet"],
		"x": {"moa": 0.7, "rate": 0.9}, "desc": "先扣後扳機上膛，前扳機一碰就發。非常準，比較慢。"},

	# --- Bolts / springs (槍機)
	"heavy_buffer": {"name": "重型緩衝器", "slot": "bolt", "price": 90, "weight": 0.1, "fits": ["gun"],
		"x": {"recoil": 0.85, "rate": 0.88}, "+": {"reliability": 2.0}, "desc": "槍機回得慢一點：射速降、後座降。"},
	"light_spring": {"name": "輕復進簧", "slot": "bolt", "price": 60, "weight": 0.0, "fits": ["gun"],
		"x": {"rate": 1.15, "recoil": 1.05}, "+": {"reliability": -6.0}, "desc": "射得更快，彈殼偶爾拋不乾淨。"},
	"heavy_spring": {"name": "強化復進簧", "slot": "bolt", "price": 60, "weight": 0.0, "fits": ["gun"],
		"x": {"rate": 0.92}, "+": {"reliability": 9.0}, "desc": "射得慢一點，但幾乎不卡。"},
	"light_bolt": {"name": "輕量槍機", "slot": "bolt", "price": 240, "weight": -0.15, "fits": ["gun"],
		"x": {"rate": 1.2, "recoil": 1.1, "recoil_h": 1.2}, "+": {"reliability": -3.0}, "desc": "槍機減重：射速快兩成，槍口更亂。"},
	"nickel_bolt": {"name": "鍍鎳槍機", "slot": "bolt", "price": 200, "weight": 0.0, "fits": ["gun"],
		"x": {"cooling": 1.1}, "+": {"reliability": 12.0}, "desc": "滑順的鍍層，髒了也照樣動。"},
	"bolt_knob": {"name": "加大拉柄球", "slot": "bolt", "price": 50, "weight": 0.03, "fits": ["bolt_action", "lever"],
		"x": {"rate": 1.25}, "desc": "大大的拉柄球：拉槍機更快。"},
	"lever_loop": {"name": "大環槓桿", "slot": "bolt", "price": 70, "weight": 0.05, "fits": ["lever"],
		"x": {"rate": 1.35}, "+": {"ergo": -2.0}, "desc": "戴手套也能甩的大環：可以單手轉槍上膛。"},

	# --- Charging handles (拉機柄)
	"ambi_charging": {"name": "雙邊拉機柄", "slot": "charging", "price": 90, "weight": 0.02, "fits": ["gun"],
		"x": {"reload": 0.92}, "+": {"ergo": 2.0}, "effects": {"quick_clear": true}, "desc": "左右手都拉得到：換彈快一點，卡彈清得快。"},
	"extended_latch": {"name": "加長拉柄卡榫", "slot": "charging", "price": 50, "weight": 0.01, "fits": ["gun"],
		"x": {"reload": 0.95}, "effects": {"quick_clear": true}, "desc": "大一點的卡榫，摸得到。卡彈清得快。"},
	"side_charging": {"name": "側拉式拉柄", "slot": "charging", "price": 150, "weight": 0.05, "fits": ["gun"],
		"x": {"reload": 0.85}, "+": {"ergo": 1.0}, "desc": "從側面拉：不用把臉離開鏡子，換彈更快。"},

	# --- Magazines (彈匣)
	"extended_mag": {"name": "擴充彈匣", "slot": "magazine", "price": 130, "weight": 0.4, "fits": ["gun", "launcher"],
		"x": {"mag": 1.6, "reload": 1.1}, "+": {"ergo": -2.0}, "desc": "子彈多一半。"},
	"drum_mag": {"name": "彈鼓", "slot": "magazine", "price": 230, "weight": 1.2, "fits": ["gun"],
		"x": {"mag": 2.5, "reload": 1.4}, "+": {"reliability": -4.0, "ergo": -6.0}, "desc": "子彈多兩倍半，換彈很慢、比較容易卡。"},
	"twin_drum": {"name": "雙彈鼓", "slot": "magazine", "price": 380, "weight": 1.8, "fits": ["rifle"],
		"x": {"mag": 3.3, "reload": 1.8}, "+": {"reliability": -10.0, "ergo": -10.0}, "desc": "一百發的蝴蝶彈鼓。很容易卡，但卡之前很爽。"},
	"quick_mag": {"name": "快拔彈匣", "slot": "magazine", "price": 150, "weight": 0.1, "fits": ["gun", "launcher"],
		"x": {"reload": 0.55}, "desc": "底部有拉環：換彈快一倍。"},
	"coupled_mag": {"name": "並聯彈匣", "slot": "magazine", "price": 120, "weight": 0.35, "fits": ["gun"],
		"x": {"reload": 0.7}, "+": {"ergo": -3.0}, "desc": "兩個彈匣綁在一起，翻過來就是滿的。"},
	"polymer_mag": {"name": "聚合物彈匣", "slot": "magazine", "price": 70, "weight": -0.15, "fits": ["gun"],
		"+": {"reliability": 3.0, "ergo": 1.0}, "desc": "輕、不生鏽，送彈很順。"},
	"casket_mag": {"name": "四排彈匣", "slot": "magazine", "price": 260, "weight": 0.6, "fits": ["gun"],
		"x": {"mag": 2.0, "reload": 1.15}, "+": {"reliability": -8.0, "ergo": -3.0}, "desc": "跟普通彈匣一樣長，子彈多一倍。彈簧很難搞。"},
	"speedloader": {"name": "快速裝填器", "slot": "magazine", "price": 80, "weight": 0.05, "fits": ["revolver"],
		"x": {"reload": 0.45}, "desc": "六顆一次塞進轉輪。"},
	"tube_extension": {"name": "延長彈倉管", "slot": "magazine", "price": 140, "weight": 0.4, "fits": ["pellet", "lever"],
		"+": {"mag": 3, "ergo": -3.0}, "desc": "管狀彈倉加長：多三發。"},
	"side_saddle": {"name": "側鞍彈架", "slot": "magazine", "price": 70, "weight": 0.3, "fits": ["pellet"],
		"x": {"reload": 0.85}, "+": {"reserve": 8}, "desc": "機匣旁邊插一排備彈，伸手就拿得到。"},
	"box_mag_conv": {"name": "盒式彈匣轉換", "slot": "magazine", "price": 300, "weight": 0.5, "fits": ["pellet"],
		"frames": ["shotgun", "auto_shotgun"], "x": {"reload": 0.5}, "+": {"mag": 1, "reliability": -6.0},
		"desc": "把霰彈槍改成插彈匣：換彈快一倍。偶爾送彈不順。"},
	"belt_box": {"name": "兩百發彈鏈箱", "slot": "magazine", "price": 420, "weight": 2.4, "fits": ["gun"], "frames": ["lmg"],
		"x": {"mag": 2.0, "reload": 1.2}, "+": {"ergo": -6.0}, "desc": "兩百發。開火開到槍管發紅。"},
	"big_tank": {"name": "大油罐", "slot": "magazine", "price": 160, "weight": 1.5, "fits": ["fuel"],
		"x": {"mag": 2.0, "reserve": 1.5}, "desc": "燃料多一倍。"},
	"capacitor": {"name": "大電容", "slot": "magazine", "price": 200, "weight": 0.8, "fits": ["energy"],
		"x": {"mag": 1.8, "reload": 0.8}, "desc": "電多、充得快。"},
	"nail_coil": {"name": "捲釘匣", "slot": "magazine", "price": 110, "weight": 0.6, "fits": ["gun"], "cal": ["nail"],
		"x": {"mag": 2.5, "reload": 1.2}, "+": {"reliability": 5.0}, "desc": "一捲兩百根的工業釘。"},

	# --- Ammo (彈藥): by calibre family
	"fmj": {"name": "全金屬被甲彈", "slot": "ammo", "price": 30, "weight": 0.0, "fits": ["pistol", "rifle"],
		"+": {"pen": 10.0, "reliability": 2.0}, "desc": "最普通的彈：穿透好一點，送彈最順。"},
	"hollow_point": {"name": "空尖彈", "slot": "ammo", "price": 90, "weight": 0.0, "fits": ["pistol", "rifle"],
		"+": {"pen": -15.0}, "effects": {"soft": true}, "desc": "對中小型怪多 40% 傷害，對大型怪很差。"},
	"ap_rounds": {"name": "穿甲彈", "slot": "ammo", "price": 160, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"damage": 0.92, "velocity": 1.05}, "+": {"pen": 35.0}, "effects": {"pierce": true, "armor": true},
		"desc": "鎢芯：打穿一排，對大型怪多 50% 傷害。"},
	"subsonic": {"name": "亞音速彈", "slot": "ammo", "price": 70, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"noise": 0.75, "damage": 0.88, "flash": 0.7, "recoil": 0.85, "range": 0.8}, "=": {"velocity": 320.0},
		"desc": "比音速慢：配消音器時沒有破空聲，真正安靜。"},
	"plus_p": {"name": "高壓彈 +P", "slot": "ammo", "price": 110, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"damage": 1.15, "velocity": 1.1, "recoil": 1.2, "flash": 1.2}, "+": {"reliability": -3.0},
		"desc": "多塞了火藥：更痛、更快，後座更大，槍磨得更兇。"},
	"tracer": {"name": "曳光彈", "slot": "ammo", "price": 60, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"spread": 0.9, "flash": 1.3}, "effects": {"tracer": true},
		"desc": "彈頭會發光：你看得到自己打到哪，所有人也看得到子彈從哪來。"},
	"match_ammo": {"name": "比賽級彈", "slot": "ammo", "price": 140, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"moa": 0.7}, "desc": "每一顆都秤過重量。非常準。"},
	"incendiary": {"name": "燃燒彈", "slot": "ammo", "price": 150, "weight": 0.0, "fits": ["pistol", "rifle", "bolt"],
		"effects": {"burn": 2.5}, "x": {"flash": 1.2}, "desc": "打中會燒起來。"},
	"api_rounds": {"name": "穿甲燃燒彈", "slot": "ammo", "price": 260, "weight": 0.0, "fits": ["rifle"],
		"+": {"pen": 30.0}, "effects": {"burn": 1.5, "armor": true}, "desc": "穿甲又會燒。貴。"},
	"shock_rounds": {"name": "電擊彈", "slot": "ammo", "price": 170, "weight": 0.0, "fits": ["pistol", "rifle", "bolt"],
		"effects": {"stun": 0.4}, "x": {"damage": 0.85}, "desc": "每一發都讓目標麻一下。"},
	"handload": {"name": "自己復裝的彈", "slot": "ammo", "price": 15, "weight": 0.0, "fits": ["pistol", "rifle", "shell"],
		"x": {"damage": 1.05, "moa": 1.15}, "+": {"reliability": -12.0}, "desc": "撿彈殼回來自己壓的。便宜、稍微猛，常常卡。"},
	"buckshot_mag": {"name": "三吋馬格南鹿彈", "slot": "ammo", "price": 80, "weight": 0.0, "fits": ["shell"],
		"x": {"damage": 1.25, "recoil": 1.4, "noise": 1.1}, "desc": "更長的霰彈：每顆彈丸更痛，肩膀也更痛。"},
	"slug": {"name": "獨頭彈", "slot": "ammo", "price": 70, "weight": 0.0, "fits": ["shell"],
		"=": {"pellets": 1}, "x": {"damage": 5.5, "spread": 0.25, "range": 2.4, "moa": 0.6}, "+": {"pen": 30.0},
		"effects": {"knock": 1.8}, "desc": "一整顆鉛彈頭：一槍很痛，打得遠。散佈幾乎沒了，要打得準。"},
	"birdshot": {"name": "鳥彈", "slot": "ammo", "price": 25, "weight": 0.0, "fits": ["shell"],
		"=": {"pellets": 18}, "x": {"damage": 0.35, "spread": 1.3, "recoil": 0.7, "range": 0.8}, "+": {"pen": -10.0},
		"desc": "一大把小鋼珠。打鼠群很好用，打大東西像在灑沙。"},
	"flechette": {"name": "鋼鏢彈", "slot": "ammo", "price": 120, "weight": 0.0, "fits": ["shell"],
		"=": {"pellets": 12}, "x": {"damage": 0.65, "spread": 0.7, "range": 1.5}, "+": {"pen": 40.0},
		"desc": "裝滿小鋼鏢：穿透很好，飛得遠。"},
	"dragon_breath": {"name": "龍息彈", "slot": "ammo", "price": 140, "weight": 0.0, "fits": ["shell"],
		"x": {"damage": 0.5, "range": 0.5, "flash": 2.0}, "effects": {"burn": 3.0, "light": true},
		"desc": "噴出一條火龍：近距離把東西點燃。整個房間都會被照亮。"},
	"rock_salt": {"name": "粗鹽彈", "slot": "ammo", "price": 60, "weight": 0.0, "fits": ["shell"],
		"effects": {"reveal": true, "slow": 1.0}, "x": {"damage": 0.6}, "desc": "不太痛，但能逼出霧行者，打到的都會變慢。"},
	"beanbag": {"name": "布袋彈", "slot": "ammo", "price": 50, "weight": 0.0, "fits": ["shell"],
		"=": {"pellets": 1}, "x": {"damage": 1.6, "spread": 0.4}, "effects": {"knock": 3.0, "stun": 0.8},
		"desc": "一包鉛砂：不太會傷人，但能把東西打退、打暈一下。"},
	"explosive_bolt": {"name": "爆裂箭頭", "slot": "ammo", "price": 200, "weight": 0.0, "fits": ["bolt"],
		"effects": {"explode": 2.5}, "x": {"reserve": 0.6}, "desc": "命中爆炸，箭變少。"},
	"net_bolt": {"name": "網箭頭", "slot": "ammo", "price": 130, "weight": 0.0, "fits": ["bolt"],
		"effects": {"slow": 4.0}, "x": {"damage": 0.4}, "desc": "把目標纏住，慢 4 秒。"},
	"broadhead": {"name": "寬刃箭頭", "slot": "ammo", "price": 100, "weight": 0.0, "fits": ["bolt"],
		"x": {"damage": 1.2}, "+": {"pen": -15.0}, "effects": {"bleed": 4.0}, "desc": "三片刀刃：傷口會一直流血。"},
	"rusty_nails": {"name": "生鏽鐵釘", "slot": "ammo", "price": 20, "weight": 0.0, "fits": ["gun"], "cal": ["nail"],
		"effects": {"bleed": 2.0}, "+": {"reliability": -5.0}, "desc": "撿來的生鏽釘：打中會流血，偶爾卡在槍裡。"},

	# --- Stocks (槍托)
	"heavy_stock": {"name": "重槍托", "slot": "stock", "price": 100, "weight": 1.0, "fits": ["gun", "bolt", "energy", "launcher"],
		"adds": ["buttpad"], "x": {"recoil": 0.6, "spread": 0.85}, "+": {"ergo": -4.0}, "desc": "穩，但重。"},
	"light_stock": {"name": "輕槍托", "slot": "stock", "price": 80, "weight": -0.5, "fits": ["gun", "bolt", "energy", "launcher"],
		"x": {"recoil": 1.2}, "+": {"ergo": 5.0}, "desc": "減重，後座大一點。"},
	"folding_stock": {"name": "摺疊槍托", "slot": "stock", "price": 120, "weight": 0.3, "fits": ["gun", "bolt", "energy"],
		"x": {"recoil": 1.1}, "+": {"length": -22.0, "ergo": 7.0}, "desc": "摺起來很短，好轉身、舉槍快。"},
	"adjustable_stock": {"name": "伸縮槍托", "slot": "stock", "price": 140, "weight": 0.4, "fits": ["gun", "bolt", "energy", "launcher"],
		"adds": ["buttpad"], "x": {"recoil": 0.8},
		"tune": {"name": "長度", "lo": "最短", "hi": "最長", "x": {"recoil": [1.15, 0.85]}, "+": {"ergo": [6.0, -5.0], "length": [-10.0, 6.0]}},
		"desc": "可以調長度：收短好轉身、舉槍快；拉長頂得穩、後座小。"},
	"precision_stock": {"name": "精準槍托", "slot": "stock", "price": 260, "weight": 1.1, "fits": ["gun", "bolt"],
		"adds": ["buttpad"], "x": {"moa": 0.85, "recoil": 0.8}, "+": {"ergo": -6.0}, "desc": "可調托腮和托底：狙擊手的槍托。"},
	"wire_stock": {"name": "鋼絲槍托", "slot": "stock", "price": 40, "weight": 0.15, "fits": ["gun"],
		"x": {"recoil": 0.9}, "+": {"ergo": 3.0}, "desc": "一根彎成槍托形狀的鐵絲。比沒有好。"},
	"pistol_brace": {"name": "手槍托架", "slot": "stock", "price": 150, "weight": 0.35, "fits": ["pistol_frame"],
		"x": {"recoil": 0.65, "moa": 0.8, "recoil_h": 0.75}, "+": {"ergo": -4.0, "length": 20.0},
		"desc": "把手槍變成小卡賓：穩很多，不再那麼好藏。"},
	"hydraulic_stock": {"name": "液壓緩衝槍托", "slot": "stock", "price": 340, "weight": 1.4, "fits": ["gun", "bolt", "energy"],
		"adds": ["buttpad"], "x": {"recoil": 0.55, "recoil_h": 0.85}, "+": {"ergo": -8.0}, "desc": "裡面有一根油壓桿：後座只剩一半。"},
	"bump_stock": {"name": "托式連發器", "slot": "stock", "price": 300, "weight": 0.5, "fits": ["gun"],
		"modes": ["auto"], "x": {"spread": 1.6, "recoil_h": 1.5}, "+": {"ergo": -3.0},
		"desc": "靠後座力自己撞扳機：半自動也能全自動亂噴，但完全打不準。"},

	# --- Butt pads / cheek risers (托底)
	"rubber_pad": {"name": "橡膠托底", "slot": "buttpad", "price": 40, "weight": 0.1, "fits": "all",
		"x": {"recoil": 0.9}, "desc": "一塊軟橡膠：肩膀舒服一點。"},
	"gel_pad": {"name": "凝膠托底", "slot": "buttpad", "price": 90, "weight": 0.2, "fits": "all",
		"x": {"recoil": 0.82}, "+": {"ergo": -1.0}, "desc": "吸收很多後座的凝膠墊。"},
	"cheek_riser": {"name": "托腮板", "slot": "buttpad", "price": 70, "weight": 0.1, "fits": "all",
		"x": {"moa": 0.9}, "+": {"ergo": 3.0}, "desc": "臉一貼上去眼睛就對準了。"},
	"ammo_sleeve": {"name": "托上彈袋", "slot": "buttpad", "price": 50, "weight": 0.25, "fits": "all",
		"x": {"reserve": 1.25}, "+": {"ergo": -1.0}, "desc": "套在槍托上的彈袋：多帶一些備彈。"},

	# --- Gadget: the strange stuff
	"vampire_charm": {"name": "吸血蝙蝠吊飾", "slot": "gadget", "price": 280, "weight": 0.1, "fits": "all",
		"effects": {"leech": 0.1}, "desc": "打怪物造成的傷害，有 10% 補回你的血。"},
	"spring_bolt": {"name": "彈簧連發機", "slot": "gadget", "price": 220, "weight": 0.4, "fits": "all",
		"x": {"rate": 1.35, "recoil": 1.5}, "desc": "射速快三成多，後座也大。"},
	"ghost_chamber": {"name": "幽靈膛室", "slot": "gadget", "price": 300, "weight": 0.2, "fits": "all",
		"effects": {"ghost": 5}, "desc": "每第 5 發不耗子彈。"},
	"lucky_cat": {"name": "招財貓吊飾", "slot": "gadget", "price": 160, "weight": 0.1, "fits": "all",
		"effects": {"bounty": true}, "desc": "殺死怪物時，牠會掉下一件東西。"},
	"echo_bell": {"name": "回聲鈴鐺", "slot": "gadget", "price": 140, "weight": 0.1, "fits": "all",
		"effects": {"lure": true}, "x": {"noise": 0.6}, "desc": "槍聲變小，但子彈打到的地方會叮噹響，把怪物引過去。"},
	"heatsink_fins": {"name": "散熱鰭片", "slot": "gadget", "price": 150, "weight": 0.3, "fits": "all",
		"x": {"cooling": 1.6}, "desc": "夾在槍上的電腦散熱片。很醜，很有用。"},
	"oil_can": {"name": "隨身油壺", "slot": "gadget", "price": 90, "weight": 0.15, "fits": "all",
		"+": {"reliability": 8.0}, "desc": "每打一個彈匣就滴兩滴：卡彈少很多。"},
	"rabbit_foot": {"name": "兔腳吊飾", "slot": "gadget", "price": 120, "weight": 0.05, "fits": "all",
		"+": {"reliability": 4.0, "ergo": 2.0}, "desc": "據說很幸運。好像真的有一點。"},

	# --- CHAOS: extreme parts. Each one changes how you play, not just the numbers.
	"corkscrew_barrel": {"name": "螺旋槍管", "slot": "barrel", "price": 340, "weight": 0.3, "fits": ["gun"],
		"effects": {"ricochet": 1}, "x": {"moa": 1.5, "damage": 0.95}, "desc": "扭成麻花的槍管：子彈出來帶著怪旋，撞牆會彈一次。"},
	"glass_barrel": {"name": "玻璃槍管", "slot": "barrel", "price": 300, "weight": -0.2, "fits": ["gun"],
		"x": {"damage": 1.3}, "+": {"reliability": -20.0}, "desc": "強化玻璃管：傷害高三成，但常常卡彈，看得到子彈在裡面跑。"},
	"telescoping_barrel": {"name": "伸縮炮管", "slot": "barrel", "price": 420, "weight": 0.9, "fits": ["gun"],
		"tune": {"name": "長度", "lo": "收起", "hi": "全伸", "x": {"range": [0.8, 1.6], "damage": [0.95, 1.15], "moa": [1.2, 0.7]},
			"+": {"ergo": [5.0, -12.0], "length": [-8.0, 30.0]}},
		"desc": "像望遠鏡一樣一節一節拉出來。收起來好轉身，全伸開來打得又遠又痛。"},
	"twin_linked": {"name": "並聯雙管", "slot": "barrel", "price": 480, "weight": 1.4, "fits": ["gun"],
		"modes": ["double"], "x": {"recoil": 1.3, "mag": 1.5}, "+": {"ergo": -6.0}, "desc": "旁邊再焊一根槍管：可以雙發齊射，彈匣也跟著變大。"},
	"organ_pipes": {"name": "管風琴槍管", "slot": "barrel", "price": 360, "weight": 1.1, "fits": ["pellet"],
		"x": {"pellets": 2.0, "damage": 0.6, "spread": 1.5, "range": 0.8}, "desc": "七根短管綁成一束，一扣就是一整面牆的彈丸。"},
	"rocket_nozzle": {"name": "反推噴嘴", "slot": "muzzle", "price": 260, "weight": 0.4, "fits": ["gun"],
		"effects": {"recoil_push": 4.0}, "x": {"recoil": 1.3, "flash": 1.5}, "desc": "把火藥氣全往前噴：每一槍都把你往後推。朝地板開槍可以把自己頂起來。"},
	"bell_mouth": {"name": "喇叭口", "slot": "muzzle", "price": 90, "weight": 0.3, "fits": ["pellet"],
		"x": {"spread": 1.6, "pellets": 1.5, "range": 0.7}, "desc": "海盜火槍那種喇叭口：散得更開、彈丸更多。"},
	"grapple_spike": {"name": "錨爪槍口", "slot": "muzzle", "price": 280, "weight": 0.5, "fits": ["gun"],
		"effects": {"grapple": 3.0}, "x": {"damage": 0.9}, "desc": "槍口焊了一圈爪子，子彈拖著細鋼索：打中哪裡都把你往那邊扯一下。"},
	"turbine_brake": {"name": "渦輪制動器", "slot": "muzzle", "price": 240, "weight": 0.5, "fits": ["gun"],
		"x": {"recoil": 0.5, "recoil_h": 1.6, "noise": 1.4, "flash": 1.4}, "desc": "會轉的制動器：往上跳的後座少一半，但槍口左右亂甩。"},
	"grappling_hook": {"name": "鉤爪發射器", "slot": "underbarrel", "price": 380, "weight": 0.9, "fits": "all",
		"effects": {"grapple": 5.0}, "+": {"ergo": -4.0}, "desc": "槍下掛一具鉤爪：每次射擊都把你往命中點拉，用來追人或爬牆。"},
	"jet_can": {"name": "推進罐", "slot": "underbarrel", "price": 300, "weight": 0.8, "fits": "all",
		"effects": {"recoil_push": 2.5}, "+": {"ergo": -3.0}, "desc": "綁在槍下的滅火器：開一槍噴一下，往反方向飛。"},
	"eagle_eye": {"name": "鷹眼鏡", "slot": "sight", "price": 420, "weight": 0.5, "fits": "all",
		"effects": {"headhunter": true}, "=": {"zoom": 2.5}, "+": {"ergo": -6.0}, "desc": "只看得見頭：爆頭三倍傷害，打身體只剩七成半。"},
	"sky_sight": {"name": "天頂瞄具", "slot": "sight", "price": 260, "weight": 0.2, "fits": "all",
		"effects": {"air_bonus": 1.25}, "=": {"zoom": 1.4}, "desc": "鏡片是斜的，只有在空中才對得準：離地時傷害加兩成五。"},
	"runner_grip": {"name": "跑者握把", "slot": "grip", "price": 220, "weight": 0.0, "fits": "all",
		"effects": {"kill_dash": true}, "+": {"ergo": 2.0}, "desc": "擊殺的瞬間衝刺立刻充滿。殺了就跑。"},
	"spur_grip": {"name": "馬刺握把", "slot": "grip", "price": 240, "weight": 0.1, "fits": "all",
		"effects": {"speed_bonus": 0.4}, "desc": "跑得越快打得越痛：全速時傷害加四成。"},
	"dead_mans_trigger": {"name": "遺言扳機", "slot": "trigger", "price": 260, "weight": 0.0, "fits": "all",
		"effects": {"last_round": 3.0}, "desc": "彈匣裡最後一發是三倍傷害。數好你的子彈。"},
	"gamble_trigger": {"name": "賭徒扳機", "slot": "trigger", "price": 77, "weight": 0.0, "fits": "all",
		"effects": {"gamble": true}, "desc": "每一發的傷害在 0.4 倍到 2.2 倍之間隨機。"},
	"overclock_trigger": {"name": "超頻扳機", "slot": "trigger", "price": 320, "weight": 0.05, "fits": ["gun", "energy"],
		"x": {"rate": 1.5, "cooling": 0.8}, "+": {"heat": 0.04, "reliability": -10.0}, "desc": "射速加五成，但槍會發燙、容易卡。"},
	"eject_bolt": {"name": "彈射槍機", "slot": "bolt", "price": 280, "weight": 0.2, "fits": ["gun"],
		"effects": {"recoil_push": 1.5}, "x": {"rate": 1.15}, "desc": "槍機往後撞得特別用力：射得快一點，每一槍都把你往後頂。"},
	"feather_bolt": {"name": "羽量槍機", "slot": "bolt", "price": 240, "weight": -0.4, "fits": ["gun"],
		"x": {"rate": 1.2, "recoil": 1.2}, "desc": "鏤空到只剩骨架的槍機：槍變輕、射得快、跳得兇。"},
	"hourglass_mag": {"name": "沙漏彈匣", "slot": "magazine", "price": 360, "weight": 0.3, "fits": ["gun"],
		"effects": {"kill_refill": true}, "x": {"mag": 0.6}, "desc": "容量少四成，但每次擊殺彈匣會自己裝滿。"},
	"jumbo_mag": {"name": "巨無霸彈匣", "slot": "magazine", "price": 300, "weight": 2.5, "fits": ["gun"],
		"x": {"mag": 3.0, "reload": 1.8}, "+": {"ergo": -10.0}, "desc": "三倍容量、長度到膝蓋的彈匣。換彈要抱著它慢慢塞。"},
	"one_shot_mag": {"name": "一發入魂", "slot": "magazine", "price": 200, "weight": -0.2, "fits": ["gun"],
		"=": {"mag": 1}, "x": {"damage": 2.2, "reload": 0.5}, "desc": "只裝得下一發，但那一發是兩倍多的傷害。"},
	"ricochet_rounds": {"name": "跳彈", "slot": "ammo", "price": 160, "weight": 0.0, "fits": ["pistol", "rifle"],
		"effects": {"ricochet": 2}, "x": {"damage": 0.85}, "desc": "軟鋼包覆的彈頭：打到牆會彈兩次。"},
	"magnet_rounds": {"name": "磁吸彈", "slot": "ammo", "price": 180, "weight": 0.0, "fits": ["pistol", "rifle", "shell"],
		"effects": {"knock": -2.0}, "x": {"damage": 0.9}, "desc": "打中的人會被往你這邊吸過來。"},
	"concussion_rounds": {"name": "震盪彈", "slot": "ammo", "price": 140, "weight": 0.0, "fits": ["pistol", "rifle"],
		"effects": {"knock": 2.5}, "x": {"damage": 0.9}, "desc": "每一發都把人往後推一大步，推下平台很好用。"},
	"vampire_rounds": {"name": "吸血彈", "slot": "ammo", "price": 260, "weight": 0.0, "fits": ["pistol", "rifle", "shell"],
		"effects": {"leech": 0.3}, "x": {"damage": 0.85}, "desc": "造成傷害的三成回到你身上。"},
	"sky_rounds": {"name": "空戰彈", "slot": "ammo", "price": 200, "weight": 0.0, "fits": ["pistol", "rifle", "shell"],
		"effects": {"air_bonus": 1.6}, "x": {"damage": 0.85}, "desc": "在地上比較弱；只要你人在空中，傷害加六成。"},
	"momentum_rounds": {"name": "動能彈", "slot": "ammo", "price": 220, "weight": 0.0, "fits": ["pistol", "rifle"],
		"effects": {"speed_bonus": 0.6}, "desc": "你跑多快，子彈就多痛：全速時傷害加六成。"},
	"cluster_rockets": {"name": "集束火箭", "slot": "ammo", "price": 240, "weight": 0.0, "fits": ["gun"], "cal": ["rocket"],
		"effects": {"explode": 1.5}, "x": {"damage": 0.7}, "desc": "火箭頭裝了小炸藥：命中會小爆炸。"},
	# Ammo for the odd calibres, so every gun has something to load.
	"galvanized_nails": {"name": "鍍鋅長釘", "slot": "ammo", "price": 60, "weight": 0.0, "fits": ["nail"],
		"x": {"damage": 1.1, "range": 1.2}, "+": {"pen": 15.0, "reliability": 4.0}, "desc": "全新的長釘：飛得直、打得深，不會卡。"},
	"napalm_gel": {"name": "凝固汽油", "slot": "ammo", "price": 160, "weight": 0.0, "fits": ["fuel"],
		"x": {"damage": 0.85, "range": 0.85}, "effects": {"burn": 5.0}, "desc": "黏稠的燃料：噴得比較近，黏在身上燒很久。"},
	"high_octane": {"name": "高辛烷燃料", "slot": "ammo", "price": 140, "weight": 0.0, "fits": ["fuel"],
		"x": {"damage": 1.2, "range": 1.25, "reserve": 0.8, "flash": 1.3}, "desc": "賽車用的燃料：火焰更猛、噴得更遠，燒得也更快。"},
	"overcharged_cell": {"name": "超頻電池", "slot": "ammo", "price": 180, "weight": 0.0, "fits": ["cell"],
		"x": {"damage": 1.2, "heat": 1.4}, "+": {"reliability": -6.0}, "desc": "拆掉保護電路的電池：更痛，也更燙，偶爾斷電。"},
	"stable_cell": {"name": "穩壓電池", "slot": "ammo", "price": 120, "weight": 0.0, "fits": ["cell"],
		"x": {"damage": 0.92, "heat": 0.65}, "+": {"reliability": 5.0}, "desc": "軍規穩壓電池：輸出平穩，比較不會過熱。"},
	"big_duck": {"name": "巨無霸橡皮鴨", "slot": "ammo", "price": 200, "weight": 0.0, "fits": ["duck"],
		"x": {"damage": 1.3, "reserve": 0.6, "velocity": 0.85}, "effects": {"explode": 5.0}, "desc": "浴缸那麼大的鴨子：爆炸更大，帶不了幾隻。"},
	"diamond_saw": {"name": "鑽石鋸片", "slot": "ammo", "price": 180, "weight": 0.0, "fits": ["saw"],
		"x": {"damage": 1.15}, "+": {"pen": 30.0}, "effects": {"bleed": 2.0}, "desc": "刃口鑲工業鑽石：切得更深，傷口會流血。"},
	"sticky_soap": {"name": "黏膠泡泡水", "slot": "ammo", "price": 90, "weight": 0.0, "fits": ["soap"],
		"effects": {"slow": 2.0}, "desc": "加了膠水的泡泡：被包住的人出來後還黏黏的，慢兩秒。"},
	"co2_cartridge": {"name": "二氧化碳鋼瓶", "slot": "ammo", "price": 110, "weight": 0.0, "fits": ["air"],
		"x": {"damage": 1.15, "recoil": 1.2, "reload": 1.15}, "desc": "高壓鋼瓶取代打氣：戳得更狠，換瓶比較慢。"},
	"spring_stock": {"name": "彈簧槍托", "slot": "stock", "price": 260, "weight": 0.6, "fits": ["gun", "bolt", "energy", "launcher"],
		"adds": ["buttpad"], "effects": {"recoil_push": 2.0}, "x": {"recoil": 0.7}, "desc": "槍托裡一根大彈簧：後座不往上跳，改成把你整個人往後彈。"},
	"counterweight_stock": {"name": "配重槍托", "slot": "stock", "price": 200, "weight": 2.5, "fits": ["gun", "bolt", "energy", "launcher"],
		"adds": ["buttpad"], "x": {"recoil": 0.4, "recoil_h": 0.5}, "+": {"ergo": -10.0}, "desc": "灌了鉛的槍托：幾乎沒有後座，但重得要命。"},
	"feather_charm": {"name": "羽毛吊飾", "slot": "gadget", "price": 180, "weight": 0.0, "fits": "all",
		"effects": {"air_bonus": 1.2}, "desc": "人在空中時傷害加兩成。"},
	"skull_charm": {"name": "骷髏吊飾", "slot": "gadget", "price": 200, "weight": 0.05, "fits": "all",
		"effects": {"kill_dash": true}, "desc": "擊殺後衝刺立刻充滿。"},
	"propeller": {"name": "竹蜻蜓", "slot": "gadget", "price": 160, "weight": -1.2, "fits": "all",
		"desc": "插在槍上一直轉的小螺旋槳。不知道為什麼，槍真的變輕了。"},
	"anchor_charm": {"name": "船錨吊飾", "slot": "gadget", "price": 120, "weight": 3.0, "fits": "all",
		"x": {"recoil": 0.6, "recoil_h": 0.6}, "desc": "掛一個真的鐵錨：槍穩得像生根，你也跑不動了。"},
	"lucky_dice": {"name": "骰子吊飾", "slot": "gadget", "price": 66, "weight": 0.05, "fits": "all",
		"effects": {"gamble": true}, "desc": "每一發的傷害擲骰決定：0.4 倍到 2.2 倍。"},

	# --- CHAOS 2: parts that hook into the rest of the game: movement feeds the gun, the
	# gun feeds movement, hits leave marks, kills leave consequences.
	"tracker_dart": {"name": "追蹤鏢發射器", "slot": "underbarrel", "price": 260, "weight": 0.5, "fits": "all",
		"effects": {"mark": 4.0}, "+": {"ergo": -3.0}, "desc": "每一發都夾帶一根小鏢：被打中的人四秒內隔著牆都看得到。"},
	"slide_loader": {"name": "滑壘上膛柄", "slot": "charging", "price": 240, "weight": 0.05, "fits": ["gun"],
		"effects": {"slide_reload": true}, "x": {"reload": 1.15}, "desc": "拉柄勾在褲管上：一滑鏟，彈匣就自己滿了。正常換彈反而比較慢。"},
	"parkour_feed": {"name": "跑酷供彈匣", "slot": "magazine", "price": 280, "weight": 0.3, "fits": ["gun"],
		"effects": {"wall_feed": 0.25}, "x": {"mag": 0.8}, "desc": "彈匣底有個小輪子：牆跑時貼著牆滾，每四分之一秒塞一發進去。"},
	"spool_trigger": {"name": "捲線扳機", "slot": "trigger", "price": 260, "weight": 0.1, "fits": ["gun", "energy"],
		"effects": {"spool": 0.9}, "desc": "按住越久射越快：一開始只有六成射速，一秒多後衝到快兩倍。"},
	"ambush_trigger": {"name": "伏擊扳機", "slot": "trigger", "price": 220, "weight": 0.0, "fits": "all",
		"effects": {"first_shot": 2.0}, "desc": "憋了兩秒沒開槍，下一發就是兩倍傷害。先開槍的人贏。"},
	"berserker_grip": {"name": "狂戰士握把", "slot": "grip", "price": 230, "weight": 0.1, "fits": "all",
		"effects": {"low_hp": 1.5}, "desc": "握把上的刺會扎手。體力低於 40 時，傷害多五成。"},
	"leech_grip": {"name": "水蛭握把", "slot": "grip", "price": 250, "weight": 0.05, "fits": "all",
		"effects": {"leech": 0.15}, "desc": "黏黏的、會動的握把。打出去的傷害有一成五回到你身上。"},
	"metronome": {"name": "節拍器", "slot": "gadget", "price": 210, "weight": 0.15, "fits": "all",
		"effects": {"streak": 0.08}, "desc": "連續打中，每一發多 8% 傷害，最多五層。打空一發就歸零。"},
	"trophy_charm": {"name": "獎盃吊飾", "slot": "gadget", "price": 240, "weight": 0.1, "fits": "all",
		"effects": {"kill_heal": 35.0}, "desc": "每次擊殺回 35 體力。"},
	"glass_heart": {"name": "玻璃心", "slot": "gadget", "price": 180, "weight": 0.05, "fits": "all",
		"effects": {"glass": 1.3}, "desc": "傷害多三成，你受到的傷害也多三成。"},
	"black_tape": {"name": "黑膠帶", "slot": "gadget", "price": 60, "weight": 0.1, "fits": "all",
		"effects": {"anonymous": true}, "desc": "整把槍纏滿黑膠帶：擊殺訊息只顯示「？？？」，被你殺的人抄不走你的槍。"},
	"stopwatch": {"name": "碼表", "slot": "gadget", "price": 150, "weight": 0.05, "fits": "all",
		"effects": {"first_shot": 1.6}, "desc": "兩秒沒開槍，下一發多六成傷害。"},
	"chicken_foot": {"name": "雞腳吊飾", "slot": "gadget", "price": 99, "weight": 0.05, "fits": "all",
		"effects": {"kick_refill": true}, "desc": "在空中打中人，就多一次踢牆，衝刺也回四分之一。"},
	"volatile_rounds": {"name": "遺爆彈", "slot": "ammo", "price": 260, "weight": 0.0, "fits": ["pistol", "rifle", "shell"],
		"effects": {"kill_explode": 3.0}, "x": {"damage": 0.9}, "desc": "被這種彈打死的人會炸開，波及身邊三公尺。"},
	"adrenaline_rounds": {"name": "腎上腺素彈", "slot": "ammo", "price": 200, "weight": 0.0, "fits": ["pistol", "rifle", "shell"],
		"effects": {"rush": 1.5}, "x": {"damage": 0.92}, "desc": "打中人的瞬間你會跑快一成五，持續一秒半。"},
	"smart_rounds": {"name": "智慧彈", "slot": "ammo", "price": 300, "weight": 0.0, "fits": ["pistol", "rifle"],
		"effects": {"homing": 5.0}, "x": {"damage": 0.85}, "desc": "準心附近五度內看得到的敵人，子彈會自己轉過去。傷害低一點。"},
	"crank_handle": {"name": "手搖充能柄", "slot": "charging", "price": 200, "weight": 0.1, "fits": ["gun"],
		"effects": {"hit_dash": 0.2}, "desc": "每打中一發，衝刺回充兩成。打得準就一直衝。"},
	"glider_stock": {"name": "滑翔翼槍托", "slot": "stock", "price": 300, "weight": 0.4, "fits": ["gun", "bolt", "energy", "launcher"],
		"adds": ["buttpad"], "effects": {"glide": 0.3}, "x": {"recoil": 1.1}, "desc": "槍托兩側摺著帆布：在空中舉槍瞄準，落下速度只剩三成。"},
	"riot_foregrip": {"name": "盾牌握把", "slot": "foregrip", "price": 260, "weight": 1.2, "fits": "all",
		"effects": {"guard": 0.35}, "+": {"ergo": -8.0}, "desc": "握把前面焊一片小鋼板：瞄準時受到的傷害少三成五。"},
	"echo_chamber": {"name": "回音膛", "slot": "bolt", "price": 340, "weight": 0.3, "fits": ["gun"],
		"effects": {"echo": 0.5}, "x": {"rate": 0.85}, "desc": "每一槍兩成秒後會再響一次，第二發免費，傷害五成。"},
	"echo_can": {"name": "回聲消音器", "slot": "silencer", "price": 300, "weight": 0.45, "fits": ["gun"],
		"effects": {"suppressed": true, "echo": 0.35}, "x": {"noise": 0.5, "damage": 0.95}, "+": {"length": 16.0, "ergo": -5.0},
		"desc": "裡面的隔板是歪的：聲音小了，卻多出一發三成五傷害的回音。"},
	"skate_bolt": {"name": "滑板槍機", "slot": "bolt", "price": 260, "weight": -0.1, "fits": ["gun"],
		"effects": {"slide_reload": true}, "x": {"rate": 1.08}, "desc": "槍機上裝了軸承：滑鏟就會自動上滿彈匣。"},
	"red_hot_barrel": {"name": "赤熱槍管", "slot": "barrel", "price": 320, "weight": 0.4, "fits": ["gun"],
		"effects": {"heat_bonus": 0.8}, "x": {"cooling": 0.7}, "+": {"heat": 0.05},
		"desc": "越打越燙：槍管全紅時傷害多八成。燙過頭就得停下來等它冷。"},
	"vent_handguard": {"name": "刺蝟散熱護木", "slot": "handguard", "price": 280, "weight": 0.7, "fits": ["gun"],
		"adds": ["rail_l", "rail_r", "foregrip", "underbarrel"], "effects": {"heat_bonus": 0.3}, "x": {"cooling": 2.0},
		"+": {"ergo": -4.0}, "desc": "插滿散熱鰭片的護木：冷得快，槍越熱打得越痛一點。"},
	"pain_feed": {"name": "痛覺供彈匣", "slot": "magazine", "price": 240, "weight": 0.2, "fits": ["gun"],
		"effects": {"pain_feed": true}, "desc": "接在你身上的管子：每受 10 點傷害，彈匣多一發。"},
	"bomb_mag": {"name": "炸彈彈匣", "slot": "magazine", "price": 260, "weight": 0.6, "fits": ["gun"],
		"effects": {"mag_bomb": 3.0}, "x": {"reload": 1.1}, "desc": "換彈時把舊彈匣往前丟：它會爆炸。"},
	"bounty_scope": {"name": "懸賞鏡", "slot": "sight", "price": 380, "weight": 0.5, "fits": "all",
		"effects": {"mark": 6.0}, "=": {"zoom": 3.0}, "+": {"ergo": -5.0}, "desc": "打中的人被標記六秒，整隊都看得到他在哪。"},
	"juggler_sight": {"name": "雜耍瞄具", "slot": "sight", "price": 240, "weight": 0.15, "fits": "all",
		"effects": {"kick_refill": true}, "=": {"zoom": 1.3}, "desc": "在空中打中人，多一次踢牆、衝刺回四分之一。"},
	"dash_feed": {"name": "衝刺供彈器", "slot": "rail", "price": 220, "weight": 0.25, "fits": "all",
		"effects": {"dash_feed": 0.4}, "desc": "側邊一個彈簧供彈器：每次衝刺，彈匣補回四成。"},
	"pogo_pad": {"name": "彈跳托底", "slot": "buttpad", "price": 160, "weight": 0.2, "fits": "all",
		"effects": {"recoil_push": 1.2}, "x": {"recoil": 0.9}, "desc": "托底裡藏一顆彈簧：每一槍把你往後頂一點。朝下開槍就是彈跳棒。"},

	# --- C7: new slot types (Tarkov / Delta Force style), every one fits every gun
	# Top tactical (上置戰術): devices on the top rail, ahead of the sight.
	"top_light": {"name": "上置戰術燈", "slot": "tactical", "price": 90, "weight": 0.15, "fits": "all",
		"effects": {"light": true}, "desc": "裝在頂部導軌上的燈，照得更遠。"},
	"top_laser": {"name": "上置雷射", "slot": "tactical", "price": 140, "weight": 0.1, "fits": "all",
		"x": {"spread": 0.8}, "effects": {"laser": true}, "desc": "頂部的雷射：腰射更集中。"},
	"rangefinder": {"name": "雷射測距儀", "slot": "tactical", "price": 200, "weight": 0.2, "fits": "all",
		"x": {"moa": 0.88, "range": 1.1}, "+": {"ergo": -2.0}, "desc": "知道距離就知道要抬多少：遠距離更準。"},
	"thermal_clip": {"name": "熱成像夾片", "slot": "tactical", "price": 420, "weight": 0.35, "fits": "all",
		"effects": {"thermal": true}, "+": {"ergo": -5.0}, "desc": "夾在瞄具前的熱成像：煙裡也看得到熱的東西。很重。"},
	"ballistic_pc": {"name": "彈道電腦", "slot": "tactical", "price": 320, "weight": 0.25, "fits": "all",
		"x": {"moa": 0.8, "recoil_h": 0.9}, "+": {"ergo": -3.0}, "desc": "小螢幕算好風偏和落點：更準，晃動更少。"},
	# Buffer and recoil spring (緩衝復進): how fast the action cycles against how hard it kicks.
	"buffer_heavy": {"name": "鎢配重緩衝器", "slot": "spring", "price": 120, "weight": 0.15, "fits": "all",
		"x": {"rate": 0.9, "recoil": 0.85}, "desc": "更重的緩衝：射速慢一點，後座軟很多。"},
	"spring_light": {"name": "競速復進簧", "slot": "spring", "price": 100, "weight": -0.05, "fits": "all",
		"x": {"rate": 1.12, "recoil": 1.1}, "+": {"reliability": -3.0}, "desc": "彈簧比較軟：射得更快，更跳，偶爾卡彈。"},
	"tuned_buffer": {"name": "可調緩衝系統", "slot": "spring", "price": 260, "weight": 0.1, "fits": "all",
		"tune": {"name": "緩衝", "lo": "快", "hi": "穩", "x": {"rate": [1.18, 0.85], "recoil": [1.15, 0.8]}},
		"desc": "旋鈕調整緩衝重量：要快還是要穩，自己選。"},
	"hydraulic_buffer": {"name": "液壓緩衝器", "slot": "spring", "price": 340, "weight": 0.3, "fits": "all",
		"x": {"recoil": 0.78, "recoil_h": 0.85, "rate": 0.95}, "desc": "油壓吸收每一下後座：很穩，比較重。"},
	"runaway_spring": {"name": "失控彈簧", "slot": "spring", "price": 180, "weight": 0.0, "fits": "all",
		"x": {"rate": 1.35, "recoil": 1.25, "heat": 1.3}, "+": {"reliability": -8.0},
		"desc": "從彈簧床拆下來的。射速瘋狂，槍也瘋狂。"},
	# Magwell (彈匣井): faster reloads, more spare rounds.
	"flared_magwell": {"name": "擴口彈匣井", "slot": "magwell", "price": 80, "weight": 0.1, "fits": "all",
		"x": {"reload": 0.85}, "desc": "開口做大：彈匣閉著眼睛也插得進去。"},
	"funnel_magwell": {"name": "比賽漏斗彈匣井", "slot": "magwell", "price": 160, "weight": 0.2, "fits": "all",
		"x": {"reload": 0.75}, "+": {"ergo": -2.0}, "desc": "射擊比賽用的大漏斗：換彈非常快，有點礙手。"},
	"ambi_release": {"name": "雙邊彈匣釋放鈕", "slot": "magwell", "price": 70, "weight": 0.02, "fits": "all",
		"x": {"reload": 0.9}, "+": {"ergo": 2.0}, "desc": "左右手都按得到：換彈快一點，也更順手。"},
	"mag_coupler": {"name": "彈匣並聯夾", "slot": "magwell", "price": 120, "weight": 0.3, "fits": "all",
		"x": {"reload": 0.85, "reserve": 1.3}, "+": {"ergo": -3.0}, "desc": "兩個彈匣夾在一起：備彈多三成，翻面就換好。"},
	# Cheek riser (托腮板): a steadier face on the stock.
	"cheek_raised": {"name": "墊高托腮塊", "slot": "cheek", "price": 60, "weight": 0.05, "fits": "all",
		"x": {"moa": 0.9}, "+": {"ergo": 2.0}, "desc": "臉貼得穩，眼睛剛好對上瞄具：更準。"},
	"cheek_leather": {"name": "皮革托腮", "slot": "cheek", "price": 50, "weight": 0.05, "fits": "all",
		"x": {"recoil": 0.95}, "+": {"ergo": 3.0}, "desc": "軟皮包著泡棉：後座打在臉上不痛。"},
	"cheek_gel": {"name": "凝膠托腮", "slot": "cheek", "price": 110, "weight": 0.1, "fits": "all",
		"x": {"recoil_h": 0.85}, "desc": "凝膠吃掉橫向的抖動。"},
	"cheek_adjust": {"name": "可調托腮", "slot": "cheek", "price": 140, "weight": 0.12, "fits": "all",
		"tune": {"name": "高度", "lo": "低", "hi": "高", "x": {"moa": [1.05, 0.82]}, "+": {"ergo": [5.0, -3.0]}},
		"desc": "高度可調：低一點舉槍快，高一點打得準。"},
	# Sling (槍背帶): how the gun hangs off you.
	"single_point": {"name": "單點背帶", "slot": "sling", "price": 40, "weight": 0.1, "fits": "all",
		"+": {"ergo": 4.0}, "desc": "掛在胸前，放手也不會掉：轉換更快。"},
	"two_point": {"name": "雙點背帶", "slot": "sling", "price": 50, "weight": 0.12, "fits": "all",
		"x": {"recoil_h": 0.9}, "+": {"ergo": 2.0}, "desc": "繃緊背帶抵著槍：橫向後座小一點。"},
	"bungee_sling": {"name": "彈力背帶", "slot": "sling", "price": 70, "weight": 0.1, "fits": "all",
		"x": {"moa": 1.05}, "+": {"ergo": 6.0}, "desc": "有彈性，槍甩來甩去都很順。準度略差。"},
	"tow_strap": {"name": "拖車吊帶", "slot": "sling", "price": 30, "weight": 0.4, "fits": "all",
		"x": {"recoil": 0.9}, "+": {"ergo": -3.0}, "desc": "黃色拖車帶，什麼都綁得住。很重，後座小一點。"},
}

const STARTER := {"frame": "revolver", "parts": {}, "tune": {}}
## Stats that are whole numbers after mods.
const INT_STATS := ["mag", "reserve", "pellets"]
## Stats kept inside 0..100.
const PERCENT_STATS := ["ergo", "pen", "flash", "reliability"]
## Aimed cone (degrees) per minute of angle. Game-scaled, not real MOA.
const MOA_DEGREES := 0.05
## Per shot chance of a jam for each point of reliability under 100.
const JAM_PER_POINT := 0.0004
## An empty gun takes this much longer to reload (rack the action).
const EMPTY_RELOAD := 1.25
## Above this muzzle velocity a bullet cracks: a suppressor only takes so much off.
const SOUND_BARRIER := 340.0
const CRACK := 1.6
## Rounds in a burst.
const BURST := 3


static func frame(id: String) -> Dictionary:
	return FRAMES.get(id, {})


static func part(id: String) -> Dictionary:
	return PARTS.get(id, {})


## The type of a slot (both rails are "rail").
static func slot_type(slot: String) -> String:
	return SLOT_TYPE.get(slot, slot)


static func slot_name(slot: String) -> String:
	return SLOT_NAMES.get(slot, slot)


## The display name of any frame or part id.
static func name_of(id: String) -> String:
	return FRAMES.get(id, PARTS.get(id, {})).get("name", id)


static func price_of(id: String) -> int:
	return FRAMES.get(id, PARTS.get(id, {})).get("price", 0)


static func caliber_name(cal: String) -> String:
	return CALIBERS.get(cal, {}).get("name", cal)


## Organs come out of monsters: they can't be bought, only owned.
static func is_organ(id: String) -> bool:
	return PARTS.get(id, {}).get("organ", false)


## Every organ part id, in the order they are listed.
static func organ_ids() -> Array[String]:
	var result: Array[String] = []
	for id in PARTS:
		if PARTS[id].get("organ", false):
			result.append(id)
	return result


## A frame stat, falling back to DEFAULTS.
static func frame_stat(frame_id: String, stat: String) -> Variant:
	return frame(frame_id).get(stat, DEFAULTS.get(stat))


## Can this part go on this frame at all (some slot of its type, tags, calibre of the bare
## frame or one a conversion part could give it)? Which slots are open depends on the
## rest of the build: use fits_in / parts_for with the build for that.
static func fits(frame_id: String, part_id: String) -> bool:
	var f := frame(frame_id)
	var p := part(part_id)
	if f.is_empty() or p.is_empty():
		return false
	if FREE_FIT:
		if p.slot != "ammo":
			return true
		for cal in _frame_calibers(frame_id):
			if ammo_fits(cal, part_id):
				return true
		return false
	if not _frame_ok(frame_id, p):
		return false
	return _tags_fit(frame_id, _frame_calibers(frame_id), p)


## Can this part go in this slot of this build, with the build as it is (other slots
## decide which slots are open and the calibre)?
static func fits_in(build: Dictionary, slot: String, part_id: String) -> bool:
	var tree := _walk(build, slot)
	return slot in tree.open and _fits_slot(build.get("frame", ""), tree.cal, slot, part_id)


## Parts that can go in one slot. `build_or_frame` is a build (open slots and calibre
## follow its parts) or a bare frame id.
static func parts_for(build_or_frame: Variant, slot: String) -> Array[String]:
	var build: Dictionary = build_or_frame if build_or_frame is Dictionary else {"frame": str(build_or_frame), "parts": {}}
	var result: Array[String] = []
	var tree := _walk(build, slot)
	if not slot in tree.open:
		return result
	for id in PARTS:
		if _fits_slot(build.get("frame", ""), tree.cal, slot, id):
			result.append(id)
	return result


## The slots this build has right now, in SLOTS order (root slots plus what parts open,
## minus what they block).
static func open_slots(build: Dictionary) -> Array[String]:
	var tree := _walk(clean(build), "")
	var result: Array[String] = []
	for slot in SLOTS:
		if slot in tree.open:
			result.append(slot)
	return result


## Every slot this frame could ever have with the right parts (root and openable).
static func possible_slots(frame_id: String) -> Array[String]:
	var f := frame(frame_id)
	var result: Array[String] = []
	if f.is_empty():
		return result
	if FREE_FIT:
		result.assign(SLOTS)
		return result
	var cals := _frame_calibers(frame_id)
	var open: Array = f.slots.duplicate()
	for slot in SLOTS:
		if not slot in open:
			continue
		for id in PARTS:
			var p: Dictionary = PARTS[id]
			if slot_type(slot) == p.slot and _tags_fit(frame_id, cals, p) and _frame_ok(frame_id, p):
				for added in p.get("adds", []):
					if not added in open:
						open.append(added)
	for slot in SLOTS:
		if slot in open:
			result.append(slot)
	return result


## The calibre this build fires.
static func caliber_of(build: Dictionary) -> String:
	return _walk(clean(build), "").cal


## Which part opened this slot ("" for a root slot of the frame).
static func opened_by(build: Dictionary, slot: String) -> String:
	build = clean(build)
	if FREE_FIT or slot in frame(build.frame).get("slots", []):
		return ""
	for s in SLOTS:
		var id: String = build.parts.get(s, "")
		if id != "" and slot in part(id).get("adds", []):
			return s
	return ""


## Drops parts that don't fit (a build loaded from an old save, a changed frame, or a
## part whose slot went away when its parent came off) and tune values for parts that
## can't be tuned, clamped to -1..1.
static func clean(build: Dictionary) -> Dictionary:
	var frame_id: String = str(build.get("frame", ""))
	if not FRAMES.has(frame_id):
		return STARTER.duplicate(true)
	var tree := _walk(build, "")
	var tune := {}
	var given_tune: Variant = build.get("tune", {})
	if given_tune is Dictionary:
		for slot in tree.parts:
			if part(tree.parts[slot]).has("tune") and given_tune.has(slot):
				tune[slot] = clampf(float(given_tune[slot]), -1.0, 1.0)
	return {"frame": frame_id, "parts": tree.parts, "tune": tune}


## Every id a build is made of (the frame first, then parts in slot order).
static func ids(build: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if FRAMES.has(build.get("frame", "")):
		result.append(build.frame)
	for slot in SLOTS:
		var part_id: String = build.get("parts", {}).get(slot, "")
		if part_id != "":
			result.append(part_id)
	return result


## The tune value of a slot in a build (0 when not set).
static func tune_of(build: Dictionary, slot: String) -> float:
	return float(build.get("tune", {}).get(slot, 0.0))


## The finished weapon: the frame's stats with every part's mods applied in slot order,
## then the derived numbers (aim time, sway, jam chance...).
static func stats(build: Dictionary) -> Dictionary:
	build = clean(build)
	var f := frame(build.frame)
	var result := DEFAULTS.duplicate(true)
	for key in f:
		result[key] = f[key]
	result = result.duplicate(true)
	result.frame = build.frame
	result.parts = build.parts.duplicate()
	result.tune = build.tune.duplicate()
	result.effects = (f.get("effects", {}) as Dictionary).duplicate()
	result.modes = (result.modes as Array).duplicate()
	result.base_noise = float(f.noise)
	var price: int = f.price
	for slot in SLOTS:
		var part_id: String = build.parts.get(slot, "")
		if part_id == "":
			continue
		var p := part(part_id)
		price += p.price
		result.weight += p.weight
		if p.has("set_cal"):
			result.cal = p.set_cal
		for stat in p.get("x", {}):
			result[stat] = result[stat] * p.x[stat]
		for stat in p.get("+", {}):
			result[stat] = result[stat] + p["+"][stat]
		for stat in p.get("=", {}):
			result[stat] = p["="][stat]
		if p.has("tune"):
			_apply_tune(result, p.tune, float(build.tune.get(slot, 0.0)))
		if p.has("set_modes"):
			result.modes = (p.set_modes as Array).duplicate()
		for mode in p.get("modes", []):
			if not mode in result.modes:
				result.modes.append(mode)
		for effect in p.get("effects", {}):
			var value = p.effects[effect]
			if result.effects.has(effect) and effect == "knock" and float(value) < 0.0:
				result.effects[effect] = value  # a pull (harpoon, dropper's arm) beats a shove
			elif result.effects.has(effect) and effect == "ghost":
				result.effects[effect] = mini(int(result.effects[effect]), int(value))
			elif result.effects.has(effect) and value is float:
				result.effects[effect] = maxf(result.effects[effect], value)
			else:
				result.effects[effect] = value
	for stat in INT_STATS:
		result[stat] = maxi(1, roundi(result[stat]))
	for stat in PERCENT_STATS:
		result[stat] = clampf(result[stat], 0.0, 100.0)
	result.weight = maxf(result.weight, 0.3)
	result.length = maxf(result.length, 15.0)
	result.price = price
	_derive(result)
	return result


## Numbers worked out from the finished stats.
##   aim_time   seconds to raise the sights; sway = degrees of drift while aiming
##   aim_spread aimed cone in degrees (from moa)
##   jam        chance per shot of a jam (heat makes it worse in play)
##   falloff    metres where damage starts falling (to FALLOFF_MIN at full range)
##   recovery   how fast the sights come back down after a kick (1.0 = normal)
##   auto       true when the default fire mode repeats (held trigger)
##   suppressed true when something quiets the shot; noise then gets the sonic crack
##   when the bullet is supersonic
static func _derive(s: Dictionary) -> void:
	var ergo: float = s.ergo
	s.aim_time = clampf(0.42 - ergo * 0.0028 + s.weight * 0.012 + maxf(s.length - 60.0, 0.0) * 0.0008, 0.1, 0.8)
	s.sway = clampf((100.0 - ergo) * 0.006 * (0.7 + s.weight * 0.06), 0.0, 1.2)
	s.aim_spread = maxf(float(s.moa) * MOA_DEGREES, 0.0)
	s.jam = maxf(100.0 - float(s.reliability), 0.0) * JAM_PER_POINT
	s.recovery = 0.6 + ergo / 100.0
	s.falloff = float(s.range) * clampf(float(s.velocity) / 1000.0 + 0.3, 0.5, 0.95)
	s.supersonic = float(s.velocity) > SOUND_BARRIER
	s.suppressed = s.effects.get("suppressed", false)
	if s.suppressed and s.supersonic and s.kind == "hitscan":
		s.noise = minf(float(s.noise) * CRACK, s.base_noise)
	s.auto = s.modes[0] == "auto"
	s.burst = BURST
	s.caliber = caliber_name(s.cal)


## Tune: t from -1 to 1. "x" goes from 1.0 at 0 to the listed value at each end, "+"
## from 0, and "=" sits halfway at 0.
static func _apply_tune(result: Dictionary, tune: Dictionary, t: float) -> void:
	t = clampf(t, -1.0, 1.0)
	for stat in tune.get("x", {}):
		var ends: Array = tune.x[stat]
		result[stat] = result[stat] * (lerpf(1.0, ends[0], -t) if t < 0.0 else lerpf(1.0, ends[1], t))
	for stat in tune.get("+", {}):
		var ends: Array = tune["+"][stat]
		result[stat] = result[stat] + (lerpf(0.0, ends[0], -t) if t < 0.0 else lerpf(0.0, ends[1], t))
	for stat in tune.get("=", {}):
		var ends: Array = tune["="][stat]
		result[stat] = lerpf(ends[0], ends[1], (t + 1.0) * 0.5)


## Walks the slot tree in SLOTS order: which slots are open, what is in them, and the
## calibre so far. When `stop_at` is a slot, the walk ends there (the calibre and open
## slots as that slot sees them) but keeps going for the "open" set's sake.
static func _walk(build: Dictionary, stop_at: String) -> Dictionary:
	var frame_id: String = str(build.get("frame", ""))
	var f := frame(frame_id)
	var open: Array = (SLOTS if FREE_FIT and not f.is_empty() else f.get("slots", [])).duplicate()
	var blocked: Array = []
	var parts := {}
	var cal: String = str(f.get("cal", DEFAULTS.cal))
	var cal_at_stop := ""
	var given: Variant = build.get("parts", {})
	if not given is Dictionary:
		given = {}
	for slot in SLOTS:
		if slot == stop_at:
			cal_at_stop = cal
		if not slot in open or slot in blocked:
			continue
		var part_id: String = str(given.get(slot, ""))
		if part_id == "" or not _fits_slot(frame_id, cal, slot, part_id):
			continue
		parts[slot] = part_id
		var p := part(part_id)
		for added in p.get("adds", []):
			if not added in open:
				open.append(added)
		if not FREE_FIT:
			for gone in p.get("blocks", []):
				blocked.append(gone)
		if p.has("set_cal"):
			cal = p.set_cal
	for gone in blocked:
		open.erase(gone)
	return {"open": open, "parts": parts, "cal": cal_at_stop if stop_at != "" else cal}


static func _fits_slot(frame_id: String, cal: String, slot: String, part_id: String) -> bool:
	var p := part(part_id)
	if p.is_empty() or p.slot != slot_type(slot):
		return false
	if FREE_FIT:
		return p.slot != "ammo" or ammo_fits(cal, part_id)
	if not _frame_ok(frame_id, p):
		return false
	if p.has("cal") and not cal in p.cal:
		return false
	return _tags_fit(frame_id, [cal], p)


## Does this ammo load into a gun of this calibre? By exact calibre when the part pins
## them ("cal"), otherwise by calibre id or family named in "fits" (pistol, rifle, shell,
## bolt...). Frame tags don't count: a crossbow bolt doesn't fit a pistol.
static func ammo_fits(cal: String, part_id: String) -> bool:
	var p := part(part_id)
	if p.get("slot", "") != "ammo":
		return false
	if p.has("cal"):
		return cal in p.cal
	if p.fits is String:
		return true
	return cal in p.fits or CALIBERS.get(cal, {}).get("family", "") in p.fits


## Ammo parts that load into this calibre.
static func ammo_for(cal: String) -> Array[String]:
	var result: Array[String] = []
	for id in PARTS:
		if PARTS[id].slot == "ammo" and ammo_fits(cal, id):
			result.append(id)
	return result


static func _frame_ok(frame_id: String, p: Dictionary) -> bool:
	return not p.has("frames") or frame_id in p.frames


## Fits by frame tag or by the calibre family of any of `cals`.
static func _tags_fit(frame_id: String, cals: Array, p: Dictionary) -> bool:
	if p.fits is String:
		return true
	var tags: Array = frame(frame_id).get("tags", [])
	for tag in p.fits:
		if tag in tags:
			return true
		for cal in cals:
			if CALIBERS.get(cal, {}).get("family", "") == tag:
				return true
	return false


## The frame's own calibre and every calibre a conversion part can give it.
static func _frame_calibers(frame_id: String) -> Array:
	var cals := [str(frame(frame_id).get("cal", DEFAULTS.cal))]
	for id in PARTS:
		var p: Dictionary = PARTS[id]
		if p.has("set_cal") and (FREE_FIT or (_frame_ok(frame_id, p) and _tags_fit(frame_id, [], p))) and not p.set_cal in cals:
			cals.append(p.set_cal)
	return cals


## A short Chinese summary line of a build's numbers, for menus.
static func summary(build: Dictionary) -> String:
	var s := stats(build)
	var pellets := "×%d" % s.pellets if s.pellets > 1 else ""
	return "%s　傷害 %d%s　射速 %.1f/秒　彈匣 %d（備彈 %d）　射程 %dm　聲音 %dm　%.1fkg" % [
		s.caliber, roundi(s.damage), pellets, s.rate, s.mag, s.reserve, roundi(s.range), roundi(s.noise), s.weight]
