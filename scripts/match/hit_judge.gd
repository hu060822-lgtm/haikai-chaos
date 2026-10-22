class_name HitJudge
extends RefCounted
## The host's referee for hits (C4). A client still finds its hits itself (it shot at
## what it saw, so a hit on screen is a hit: no leading targets by your ping), but every
## hit then goes to the host, which rewinds and checks it before anyone takes damage:
##
##   who      the sender owns the shooter, the shooter is alive, the victim is alive and
##            on the other team
##   where    the victim really was near the hit point at some moment between "now" and
##            "now minus the shooter's ping, the avatar delay and WINDOW" (lag
##            compensation: the host keeps everyone's last KEEP seconds of positions)
##   from     the shot came from about where the shooter was, and (for straight shots
##            that didn't go through a wall) nothing solid was between the two
##   how much no more damage than the shooter's real gun can do in one hit, and no more
##            hits than its fire rate allows (a bucket of hits that refills at that rate)
##
## Only what passes is passed on to the victim's owner. Plain data and math here so the
## rules can be tested on their own; TeamMatch feeds it positions and pings.

const KEEP := 1.2
const WINDOW := 0.25
## Pings past this aren't rewound further: a laggy shooter shoots where things are now.
const MAX_REWIND := 0.5
const DEFAULT_RTT := 0.15
## How far from the victim's body line a hit point may be (hitbox + movement slack), m.
const HIT_SLACK := 1.3
## A blast's centre can be this far from its victim.
const BLAST_REACH := 9.0
## How far the shot's origin may be from the shooter's eye.
const ORIGIN_SLACK := 3.5
const EYE := 1.5
## A jump this long between two samples is a respawn, not movement.
const TELEPORT := 12.0

## id -> [[t, Vector3], ...] oldest first
var history := {}
## peer -> round trip, s
var rtt := {}
## shooter id -> [tokens, last t]
var _buckets := {}
## Why the last hit was thrown out ("" = it passed); for tests and the debug panel.
var last_reason := ""
var rejected := 0


func record(id: String, pos: Vector3, now: float) -> void:
	var h: Array = history.get(id, [])
	if not h.is_empty() and (h[-1][1] as Vector3).distance_to(pos) > TELEPORT:
		h.clear()   # respawned: no hits on the old spot
	h.append([now, pos])
	while h.size() > 2 and now - float(h[0][0]) > KEEP:
		h.pop_front()
	history[id] = h


## A dead or respawned entity: forget where it was (no hits on its old spot).
func forget(id: String) -> void:
	history.erase(id)


func set_rtt(peer: int, seconds: float) -> void:
	var old := float(rtt.get(peer, seconds))
	rtt[peer] = lerpf(old, seconds, 0.3)


func rewind_of(peer: int) -> float:
	return minf(float(rtt.get(peer, DEFAULT_RTT)), MAX_REWIND) + Avatar.INTERP + WINDOW


## Where `id` was between t0 and t1 (plus the samples just outside, so a gap between two
## samples still counts).
func positions(id: String, t0: float, t1: float) -> Array:
	var h: Array = history.get(id, [])
	var out := []
	for i in h.size():
		var t := float(h[i][0])
		var next_in := i + 1 < h.size() and float(h[i + 1][0]) >= t0
		if (t >= t0 and t <= t1) or (t < t0 and next_in):
			out.append(h[i][1])
	if out.is_empty() and not h.is_empty():
		out.append(h[-1][1])
	return out


static func _to_line(p: Vector3, base: Vector3) -> float:
	var a := base + Vector3(0, 0.1, 0)
	var b := base + Vector3(0, 1.8, 0)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## The judgement on one hit. `shooter_peer` is the machine that fired, `build` the gun the
## host knows the shooter carries, `blocked` a Callable(from, to) -> bool for walls.
## Returns "" when the hit stands, else the reason it doesn't.
func judge(shooter_id: String, shooter_peer: int, victim_id: String, wire: Dictionary, build: Dictionary, now: float,
		blocked: Callable) -> String:
	last_reason = _judge(shooter_id, shooter_peer, victim_id, wire, build, now, blocked)
	if last_reason != "":
		rejected += 1
	return last_reason


func _judge(shooter_id: String, shooter_peer: int, victim_id: String, wire: Dictionary, build: Dictionary, now: float,
		blocked: Callable) -> String:
	if build.is_empty():
		return "unknown gun"
	var stats := Arsenal.stats(build)
	var dmg := float(wire.get("damage", 0.0))
	var cap := maxf(Weapon.pvp_damage(stats) * Weapon.HEAD_MULT * 3.0, Weapon.KILL_BLAST * 2.0) + 5.0
	if dmg < 0.0 or dmg > cap:
		return "damage %.0f over the gun's %.0f" % [dmg, cap]
	if not _spend(shooter_id, stats, now):
		return "more hits than the fire rate allows"
	var point: Variant = wire.get("point")
	if not (point is Vector3):
		return "no hit point"
	var t0 := now - rewind_of(shooter_peer)
	var near := INF
	for p in positions(victim_id, t0, now):
		near = minf(near, _to_line(point, p))
	var dist := float(wire.get("distance", 0.0))
	var blast: bool = dist < 0.5 or bool(wire.get("blast", false)) or bool(wire.get("chained", false))
	if near > (BLAST_REACH if blast else HIT_SLACK):
		return "the victim wasn't there (%.1f m off)" % near
	if blast:
		return ""
	var dir: Variant = wire.get("dir")
	if not (dir is Vector3) or (dir as Vector3).length() < 0.5:
		return "no direction"
	var origin: Vector3 = point - (dir as Vector3).normalized() * dist
	if dist > float(stats.range) * 1.6 + 10.0:
		return "farther than the gun reaches"
	var from_near := INF
	for p in positions(shooter_id, t0, now):
		from_near = minf(from_near, origin.distance_to(p + Vector3(0, EYE, 0)))
	var fx: Dictionary = stats.effects
	var bendy := str(stats.kind) in ["bounce", "lob", "arc"] or fx.has("ricochet") or fx.has("homing") or fx.has("echo")
	if from_near > ORIGIN_SLACK and not bendy:
		return "the shot didn't start at the shooter (%.1f m off)" % from_near
	if not bendy and not wire.get("through_wall", false) and dist > 1.0:
		var d := (dir as Vector3).normalized()
		if blocked.call(origin + d * 0.3, point - d * 0.2):
			return "a wall in the way"
	return ""


## The hit bucket: holds a few shots' worth of hits, refills at the gun's rate.
func _spend(shooter_id: String, stats: Dictionary, now: float) -> bool:
	var per_shot := maxi(int(stats.get("pellets", 1)), 1)
	var fx: Dictionary = stats.effects
	if fx.has("chain") or fx.has("explode") or fx.has("echo") or str(stats.kind) in ["cone", "arc", "lob"]:
		per_shot *= 4
	var cap := float(per_shot * 4 + 4)
	var refill := float(stats.rate) * per_shot * 1.5 + 2.0
	var b: Array = _buckets.get(shooter_id, [cap, now])
	var tokens := minf(cap, float(b[0]) + (now - float(b[1])) * refill)
	if tokens < 1.0:
		_buckets[shooter_id] = [tokens, now]
		return false
	_buckets[shooter_id] = [tokens - 1.0, now]
	return true
