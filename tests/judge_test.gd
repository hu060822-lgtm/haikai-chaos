extends SceneTree
## The host's hit referee on its own (HitJudge): lag compensation keeps a hit on where
## the victim was a moment ago, and throws out hits that are too far, too strong, too
## many, from the wrong place, or through a wall.
##   godot --headless --path . --script res://tests/judge_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _hit(from: Vector3, point: Vector3, damage := 20.0) -> Dictionary:
	return {"damage": damage, "point": point, "dir": (point - from).normalized(), "distance": from.distance_to(point)}


func _init() -> void:
	var gun := {"frame": "carbine", "parts": {}, "tune": {}}
	if not Arsenal.FRAMES.has("carbine"):
		gun.frame = Arsenal.FRAMES.keys()[3]
	var open_air := func(_a: Vector3, _b: Vector3) -> bool: return false
	var wall := func(_a: Vector3, _b: Vector3) -> bool: return true
	var j := HitJudge.new()
	j.set_rtt(2, 0.12)
	var now := 100.0
	# The victim runs along +x at 10 m/s; the shooter stands at the origin.
	for i in 61:
		var t := now - 1.0 + i / 60.0
		j.record("b0", Vector3(10.0 * (t - now), 0, -20), t)
		j.record("p2", Vector3.ZERO, t)
	var eye := Vector3(0, 1.5, 0)
	var then := Vector3(-2.0, 1.0, -20)   # where it was 0.2 s ago
	check(j.judge("p2", 2, "b0", _hit(eye, then), gun, now, open_air) == "", "a hit where the victim was 0.2 s ago stands (ping 120 ms)")
	var long_ago := Vector3(-8.0, 1.0, -20)   # 0.8 s ago: past the rewind
	check(j.judge("p2", 2, "b0", _hit(eye, long_ago), gun, now, open_air) != "", "a hit where it was 0.8 s ago is thrown out (%s)" % j.last_reason)
	check(j.judge("p2", 2, "b0", _hit(eye, Vector3(0, 1, -40)), gun, now, open_air) != "", "a hit 20 m behind the victim is thrown out")
	check(j.judge("p2", 2, "b0", _hit(eye, then, 5000.0), gun, now, open_air) != "", "a hit past the gun's damage is thrown out")
	var far_eye := Vector3(0, 1.5, 15)
	check(j.judge("p2", 2, "b0", _hit(far_eye, then), gun, now, open_air) != "", "a shot from where the shooter wasn't is thrown out (%s)" % j.last_reason)
	check(j.judge("p2", 2, "b0", _hit(eye, then), gun, now, wall) != "", "a straight shot through solid wall is thrown out")
	var through := _hit(eye, then)
	through.through_wall = true
	check(j.judge("p2", 2, "b0", through, gun, now, wall) == "", "a wallbang (the gun's penetration said so) stands")
	# Fire rate: a flood of hits in one instant runs the bucket dry.
	var j2 := HitJudge.new()
	for i in 10:
		j2.record("b0", Vector3(0, 0, -20), now - 0.1 * i)
		j2.record("p2", Vector3.ZERO, now - 0.1 * i)
	var passed := 0
	for i in 200:
		if j2.judge("p2", 2, "b0", _hit(eye, Vector3(0, 1, -20)), gun, now, open_air) == "":
			passed += 1
	check(passed < 30, "200 hits at once: only a few shots' worth stand (%d)" % passed)
	var later := 0
	for i in 20:
		if j2.judge("p2", 2, "b0", _hit(eye, Vector3(0, 1, -20)), gun, now + 2.0 + i * 0.5, open_air) == "":
			later += 1
	check(later == 20, "hits at a human rate keep standing (%d of 20)" % later)
	# A respawn wipes the old trail.
	j2.record("b0", Vector3(0, 0, 25), now + 13.0)
	check(j2.judge("p2", 2, "b0", _hit(eye, Vector3(0, 1, -20)), gun, now + 13.0, open_air) != "", "after a respawn, hits on the old spot are thrown out")
	# The health ledger.
	var l := HitJudge.new()
	l.spawned("p3")
	for i in 3:
		l.took("p3", 30.0, {}, {"damage": 30.0}, now)
	check(not l.overdue("p3", now + 5.0), "90 damage: still alive by the ledger")
	l.took("p3", 30.0, {}, {"damage": 30.0}, now)
	check(not l.overdue("p3", now + 1.0), "120 damage: not overdue yet (grace %.0f s)" % HitJudge.OVERDUE)
	check(l.overdue("p3", now + HitJudge.OVERDUE + 0.1), "120 damage and still alive after the grace: overdue")
	l.spawned("p3")
	check(not l.overdue("p3", now + 10.0), "a respawn clears it")
	for i in 4:
		l.took("p3", 30.0, {"guard": 0.5}, {"damage": 30.0}, now)
	check(not l.overdue("p3", now + 10.0), "a guard part is counted at its best (120 hits, 60 counted)")
	l.spawned("p4")
	for i in 4:
		l.took("p4", 30.0, {}, {"damage": 30.0}, now)
	l.healed("p4", 40.0)
	check(not l.overdue("p4", now + 10.0), "a heal back above zero clears it")
	print("JUDGE TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
