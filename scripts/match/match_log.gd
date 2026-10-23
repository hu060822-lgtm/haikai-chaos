class_name MatchLog
extends RefCounted
## The match record (C5), for balancing from real games. Every machine keeps one (each
## sees every kill); the host's also has every purchase. Written at the match's end (or
## when you leave halfway) to user://match_logs/<date>_<time>.json, which Balance reads.
##
##   {"version": 1, "mode", "map", "host", "started", "seconds", "players": {id: {name, team, bot}},
##    "kills": [{t, round, killer, victim, frame, parts, zone, distance, through_wall, moves, killer_bot, victim_bot}],
##    "buys": [{t, round, id, frame, parts, cost}], "rounds": [{n, winner, why}], "result": {winner, score}}

const DIR := "user://match_logs"
const VERSION := 1

var data := {}
var written := ""
var _t0 := 0.0


func _init(mode: String, map_id: String, host: bool) -> void:
	_t0 = Time.get_ticks_msec() / 1000.0
	data = {"version": VERSION, "mode": mode, "map": map_id, "host": host,
		"started": Time.get_datetime_string_from_system(), "seconds": 0.0,
		"players": {}, "kills": [], "buys": [], "rounds": [], "result": {}}


func _now() -> float:
	return snappedf(Time.get_ticks_msec() / 1000.0 - _t0, 0.01)


func player(id: String, display: String, team: int, bot: bool) -> void:
	data.players[id] = {"name": display, "team": team, "bot": bot}


func kill(round_no: int, killer: String, victim: String, wire: Dictionary) -> void:
	var build: Dictionary = wire.get("build", {})
	var clean := Arsenal.clean(build) if build is Dictionary and build.has("frame") else {"frame": "", "parts": {}}
	data.kills.append({"t": _now(), "round": round_no, "killer": killer, "victim": victim,
		"frame": str(clean.frame), "parts": (clean.parts as Dictionary).values(),
		"zone": str(wire.get("zone", "body")), "distance": snappedf(float(wire.get("distance", 0.0)), 0.1),
		"through_wall": bool(wire.get("through_wall", false)), "moves": wire.get("moves", []),
		"killer_bot": killer.begins_with("b"), "victim_bot": victim.begins_with("b")})


func buy(round_no: int, id: String, build: Dictionary, cost: int) -> void:
	data.buys.append({"t": _now(), "round": round_no, "id": id, "frame": str(build.frame),
		"parts": (build.parts as Dictionary).values(), "cost": cost})


func round_over(n: int, winner: int, why: String) -> void:
	data.rounds.append({"n": n, "winner": winner, "why": why})


## Writes the file (once). Returns its path, or "" when there was nothing worth keeping.
func write(winner := -1, score: Array = []) -> String:
	if written != "":
		return written
	if data.kills.is_empty() and data.rounds.is_empty():
		return ""
	data.seconds = _now()
	data.result = {"winner": winner, "score": score}
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var path := "%s/%s_%s.json" % [DIR, stamp, "host" if data.host else "peer"]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	written = path
	return path


## Every log in DIR (or `dir`), oldest first, as parsed dictionaries.
static func load_all(dir := DIR) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var names := Array(d.get_files()).filter(func(n: String) -> bool: return n.ends_with(".json"))
	names.sort()
	for n in names:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(n)))
		if parsed is Dictionary and parsed.has("kills"):
			out.append(parsed)
	return out
