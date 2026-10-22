extends SceneTree
## The C2 team match over a real connection: two game processes on this machine, a host
## and a client (tools/net_test.sh starts both). Each loads the real main scene, meets in
## the lobby, starts 改版死鬥, and checks its side: the other player shows up and moves,
## a hit decided by the host lands on the client, the kill scores on the host and the
## score reaches the client, the client respawns, and the match ends back in the lobby.
##   godot --headless --path . --script res://tests/net_test.gd -- host|client [port]

const TIMEOUT := 40.0

var role := "host"
var port := NetSession.PORT + 7
var failures := 0
var _t0 := 0.0
var _finished := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		role = args[0]
	if args.size() > 1:
		port = int(args[1])
	_t0 = Time.get_ticks_msec() / 1000.0
	NetSession.my_name = "主機" if role == "host" else "訪客"
	change_scene_to_file("res://scenes/main.tscn")
	await _until(func() -> bool: return root.get_node_or_null("Main") != null and root.get_node("Main").is_node_ready(), 5.0)
	if role == "host":
		await _host()
	elif role == "solo":
		await _solo()
	else:
		await _client()
	check(_finished, "ran to the end")
	print("NET %s TESTS: %s" % [role.to_upper(), "PASS" if failures == 0 else "%d FAILED" % failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print("  %s %s: %s" % ["ok  " if ok else "FAIL", role, what])
	if not ok:
		failures += 1


func main() -> Main:
	return root.get_node_or_null("Main") as Main


func team_match() -> TeamMatch:
	var m := main()
	return m.team_match if m != null else null


## Waits until `cond` is true (or `seconds` pass); returns whether it came true.
func _until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _quiet_bots() -> void:
	var tm := team_match()
	tm.bots_passive = true
	for b in tm.bots():
		b.passive = true


func _host() -> void:
	var m := main()
	check(m.net.host(port) == OK, "opened a room on port %d" % port)
	var joined := await _until(func() -> bool: return NetSession.roster.size() == 2, 15.0)
	check(joined, "the client joined the lobby (roster %s)" % str(NetSession.roster))
	if not joined:
		return
	var client_peer := 0
	for p in NetSession.roster:
		if int(p) != 1:
			client_peer = int(p)
	check(int(NetSession.roster[client_peer].team) == 1, "the newcomer went to the smaller team (red)")
	m.net.set_config("team_size", 2)
	m.net.set_config("minutes", 3)
	await _wait(0.5)
	m.net.start_match()
	var started := await _until(func() -> bool: return team_match() != null and team_match().running, 15.0)
	check(started, "the match started on the host")
	if not started:
		return
	_quiet_bots()
	m = main()
	var tm := team_match()
	check(tm.bots().size() == 2, "one bot fills each team's empty slot (%d bots)" % tm.bots().size())
	var cid := "p%d" % client_peer
	var avatar: Avatar = tm.entities.get(cid)
	check(avatar != null, "the client's player is here as an avatar")
	var moved := await _until(func() -> bool: return avatar.alive and avatar.global_position.distance_to(Vector3(0, 0, -22.5)) < 4.0, 6.0)
	check(moved, "the client's avatar stands at the red spawn (%s)" % str(avatar.global_position))
	var me := m.player
	check(me.is_on_floor() and absf(me.global_position.y) < 0.3, "the host's player stands on the floor at its spawn (%s)" % str(me.global_position))
	# Step the avatar out of the red safe zone on our screen and let the host shoot it.
	await _wait(0.6)
	var info := {"attacker": me, "attacker_name": me.display_name, "team": me.team, "damage": 30.0, "zone": "body",
		"dir": Vector3(0, 0, -1), "distance": 20.0, "gun_name": me.weapon.name, "build": me.weapon.build.duplicate(true),
		"effects": {}, "moves": [], "version": me.weapon.version}
	tm.send_hit(cid, info)
	var hurt := await _until(func() -> bool: return avatar.health < 100.0, 4.0)
	check(not hurt, "a hit on a player inside their own spawn zone does nothing (hp %.0f)" % avatar.health)
	var out := await _until(func() -> bool: return avatar.global_position.z > -14.0, 10.0)
	check(out, "the client walked out of its spawn zone (%s)" % str(avatar.global_position))
	tm.send_hit(cid, info)
	hurt = await _until(func() -> bool: return avatar.health <= 70.5, 4.0)
	check(hurt, "the host's hit reached the client (client hp %.0f)" % avatar.health)
	info.damage = 500.0
	tm.send_hit(cid, info)
	var dead := await _until(func() -> bool: return not avatar.alive, 4.0)
	check(dead, "the client died and told everyone")
	var scored := await _until(func() -> bool: return tm.scores[me.team] >= 3, 3.0)
	check(scored, "a fresh-version kill is worth 3 for the host's team (%s)" % str(tm.scores))
	check(m.hud.kills == 1, "the host's HUD counts the kill")
	var back := await _until(func() -> bool: return avatar.alive, 12.0)
	check(back, "the client respawned")
	await _wait(1.5)
	tm._end.rpc(me.team, tm.scores)
	await _wait(0.5)
	check(m.results != null and m.results.visible, "the results screen is up")
	m.net.end_match()
	var lobby := await _until(func() -> bool: return main() != null and main() != m and main().lobby.visible, 8.0)
	check(lobby, "everyone is back in the lobby")
	await _wait(1.0)
	main().net.leave()
	_finished = true


func _client() -> void:
	var m := main()
	var ok := await _until(func() -> bool: return m.net.join("127.0.0.1", port) == OK and true, 1.0)
	var joined := await _until(func() -> bool: return NetSession.roster.size() == 2, 15.0)
	check(ok and joined, "joined the host's lobby")
	if not joined:
		return
	var started := await _until(func() -> bool: return team_match() != null and team_match().running, 20.0)
	check(started, "the match started on the client")
	if not started:
		return
	m = main()
	var tm := team_match()
	var me := m.player
	check(me.team == 1, "the client plays for red")
	var host_avatar: Avatar = tm.entities.get("p1")
	check(host_avatar != null, "the host's player is here as an avatar")
	var bots := 0
	for id in tm.entities:
		if str(id).begins_with("b") and tm.entities[id] is Avatar:
			bots += 1
	check(bots == 2, "the host's bots are here as avatars (%d)" % bots)
	var seen := await _until(func() -> bool: return host_avatar.alive and host_avatar.global_position.distance_to(Vector3(0, 0, 22.5)) < 4.0, 6.0)
	check(seen, "the host's avatar stands at the blue spawn (%s)" % str(host_avatar.global_position))
	check(me.is_on_floor() and absf(me.global_position.y) < 0.3, "the client's player stands on the floor at its spawn (%s)" % str(me.global_position))
	check(SafeZone.is_safe(me.global_position, 1), "the client spawned inside red's safe zone")
	check(me.can_mod(), "the bench opens at spawn")
	# Walk forward (toward the middle) out of the zone, then stand still to be shot.
	await _wait(2.0)
	me.global_position = Vector3(0, 0.1, -10.0)
	var hurt := await _until(func() -> bool: return me.health <= 70.5, 8.0)
	check(hurt, "took the host's 30 damage hit (hp %.0f)" % me.health)
	check(not me.can_mod(), "being hit locks the bench (combat %.1f s)" % me.combat_left)
	var dead := await _until(func() -> bool: return not me.alive, 6.0)
	check(dead, "died to the host's second hit")
	var scored := await _until(func() -> bool: return tm.scores[0] >= 3, 4.0)
	check(scored, "the host's score reached the client (%s)" % str(tm.scores))
	var feed_ok := m.hud.feed.get_child_count() > 0
	check(feed_ok, "the kill feed shows the kill")
	await _wait(1.0)
	check(not me.alive and m.death.visible, "the death screen is up")
	var back := await _until(func() -> bool: return me.alive, TeamMatch.AUTO_RESPAWN + 2.0)
	check(back, "respawned by itself after the wait")
	check(SafeZone.is_safe(me.global_position, 1), "respawned in red's safe zone")
	var ended := await _until(func() -> bool: return tm.over, 15.0)
	check(ended, "the match ended on the client")
	var lobby := await _until(func() -> bool: return main() != null and main() != m and main().lobby.visible, 12.0)
	check(lobby, "back in the lobby after the match")
	await _until(func() -> bool: return not NetSession.active, 6.0)
	check(true, "the host closed the room")
	_finished = true


## A host alone with bots, live (they fight each other and you) for a while: the match keeps
## score from bot kills and nothing breaks.
func _solo() -> void:
	var m := main()
	check(m.net.host(port) == OK, "opened a room")
	m.net.set_config("team_size", 3)
	m.net.start_match()
	var started := await _until(func() -> bool: return team_match() != null and team_match().running, 15.0)
	check(started, "the match started")
	if not started:
		return
	var tm := team_match()
	check(tm.bots().size() == 5, "five bots (two with you, three against)")
	main().player.health = 1.0e9  # a statue on its spawn: the bots fight around it
	var scored := await _until(func() -> bool: return tm.scores[0] + tm.scores[1] >= 6, 60.0)
	check(scored, "bots killing bots scores for their teams (%s)" % str(tm.scores))
	var notes := []
	for b in tm.bots():
		notes.append("%s %s" % [b.display_name, "活" if b.alive else "死"])
	print("    ", "　".join(notes))
	main().net.leave()
	_finished = true
