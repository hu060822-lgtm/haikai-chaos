class_name BotLevel
## How a bot plays at each difficulty (C9): 簡單, 中等, 困難. Every level aims exactly the
## same (the same reaction time, aim error and damage, all in Bot._try_shoot); what changes
## is behaviour: what it notices, where it stands in a fight, when it reloads, backs off,
## takes cover, hunts, flanks and tells its team.
##
## Shared senses live here too: gunshots any bot within earshot can hear (Sfx.shot reports
## them), and each team's callouts (where an enemy was last seen, and who is fighting).

const EASY := 0
const MEDIUM := 1
const HARD := 2
const NAMES := ["簡單", "中等", "困難"]
const INFO := [
	"只看前方、聽不到槍聲；站著對槍，打空才換彈，很快就忘了你",
	"會聽槍聲找過來、追你最後出現的位置；邊打邊左右閃，殘血會後退",
	"視野廣、會聽腳邊動靜、互相報點包夾；保持槍的最佳距離，換彈和殘血先找掩體，趁你換彈壓上來",
]

## The numbers per level, by key:
##   view       how far round it looks (dot of facing vs. the direction: -1 = all round)
##   near       anyone this close is noticed whatever way it faces (m)
##   hearing    how far it hears a gunshot (m, 0 = deaf)
##   memory     how long it keeps chasing where it last saw someone (s)
##   roam       walking speed (× Bot.SPEED) when not fighting
##   strafe     sideways speed in a fight (× SPEED) and the chance of a hop
##   hold_range keeps the gun's best distance (else just closes in when out of range)
##   retreat    health under which it gives ground (0 = never)
##   cover      looks for cover to reload or heal behind (else backs straight off)
##   reload     reloads early below this fraction of the magazine when nobody's in sight
##   team       calls out sightings, hunts its team's callouts and flanks
##   punish     pushes in when the target is reloading
##   ability    how often it uses its class ability (× the base chance)
const PROFILES := [
	{"view": 0.45, "near": 3.0, "hearing": 0.0, "memory": 2.5, "roam": 0.6, "strafe": 0.2, "hop": 0.0,
		"hold_range": false, "retreat": 0.0, "cover": false, "reload": 0.0, "team": false, "punish": false,
		"ability": 0.25, "approach": 9.0},
	{"view": -0.1, "near": 6.0, "hearing": 24.0, "memory": 7.0, "roam": 0.85, "strafe": 0.7, "hop": 0.15,
		"hold_range": false, "retreat": 30.0, "cover": false, "reload": 0.5, "team": false, "punish": false,
		"ability": 1.0, "approach": 0.0},
	{"view": -0.5, "near": 12.0, "hearing": 45.0, "memory": 14.0, "roam": 0.95, "strafe": 0.85, "hop": 0.2,
		"hold_range": true, "retreat": 55.0, "cover": true, "reload": 0.6, "team": true, "punish": true,
		"ability": 1.0, "approach": 0.0},
]


static func profile(level: int) -> Dictionary:
	return PROFILES[clampi(level, 0, PROFILES.size() - 1)]


static func label(level: int) -> String:
	return NAMES[clampi(level, 0, NAMES.size() - 1)]


# --- Shared senses ----------------------------------------------------------------------

const NOISE_LIFE := 1.5
const CALLOUT_LIFE := 6.0
## Recent gunshots: [position, team, time].
static var _noises: Array = []
## Per team: the last callout, {"at": Vector3, "time": float, "by": Bot}.
static var _callouts := {}


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A gun went off at `who` (anyone in the "combatants" or "decoys" groups, or a remote
## player's avatar).
static func heard(who: Node3D) -> void:
	if who == null or not is_instance_valid(who) or not who.is_inside_tree():
		return
	var t = who.get("team")
	var n := now()
	while not _noises.is_empty() and n - float(_noises[0][2]) > NOISE_LIFE:
		_noises.pop_front()
	_noises.append([who.global_position, -1 if t == null else int(t), n])


## The nearest fresh gunshot from the other team within `radius` of `at`, or INF.
static func nearest_noise(at: Vector3, team: int, radius: float) -> Vector3:
	var best := Vector3.INF
	var best_d := radius
	var n := now()
	for e in _noises:
		if int(e[1]) == team or n - float(e[2]) > NOISE_LIFE:
			continue
		var d := at.distance_to(e[0])
		if d < best_d:
			best_d = d
			best = e[0]
	return best


static func call_out(team: int, at: Vector3, by: Node) -> void:
	_callouts[team] = {"at": at, "time": now(), "by": by}


## The team's latest callout, if fresh: {"at", "time", "by"}, else {}.
static func callout(team: int) -> Dictionary:
	var c: Dictionary = _callouts.get(team, {})
	if c.is_empty() or now() - float(c.time) > CALLOUT_LIFE:
		return {}
	return c


static func reset() -> void:
	_noises.clear()
	_callouts.clear()
