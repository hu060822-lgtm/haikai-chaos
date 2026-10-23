extends SceneTree
## The balance report (Balance) and the match log (MatchLog): the paper numbers follow the
## damage rules, a log round-trips through a file, and the report reads it back.
##   godot --headless --path . --script res://tests/balance_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	var rows := Balance.frame_rows()
	check(rows.size() == Arsenal.FRAMES.size(), "a row for every frame (%d)" % rows.size())
	var by := {}
	for r in rows:
		by[r.frame] = r
	for fid in ["revolver", "carbine", "rifle", "shotgun"]:
		var stk := int(Weapon.STK.get(fid, 4))
		check(int(by[fid].stk_10) == stk, "%s: %d body hits up close, as its STK says (%d)" % [fid, stk, int(by[fid].stk_10)])
	check(int(by.rifle.head_stk) == 1, "a rifle kills with one headshot")
	check(float(by.carbine.ttk_10) > 0.0 and float(by.carbine.ttk_10) < 1.0, "a carbine's close TTK is under a second (%.2f)" % float(by.carbine.ttk_10))
	check(float(by.shotgun.ttk_10) == 0.0, "a shotgun's close TTK is the first shot")
	check(int(by.shotgun.stk_40) > 1, "a shotgun falls off at 40 m (%d hits)" % int(by.shotgun.stk_40))
	var parts := Balance.part_rows()
	check(parts.size() == Arsenal.PARTS.size(), "a row for every part (%d)" % parts.size())
	check(parts.filter(func(r: Dictionary) -> bool: return str(r.ref) != "").size() > Arsenal.PARTS.size() / 2, "most parts fit some bare frame")
	# A log.
	var dir := "user://balance_test_logs"
	DirAccess.make_dir_recursive_absolute(dir)
	for n in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(n))
	var lg := MatchLog.new("bomb", "folded", true)
	lg.player("p1", "我", 0, false)
	lg.player("b0", "灰板", 1, true)
	var gun := {"frame": "carbine", "parts": {"muzzle": Arsenal.parts_for("carbine", "muzzle")[0]}, "tune": {}}
	lg.kill(1, "p1", "b0", {"build": gun, "zone": "head", "distance": 21.0})
	lg.kill(1, "b0", "p1", {"build": {"frame": "revolver", "parts": {}, "tune": {}}, "zone": "body", "distance": 9.0})
	lg.kill(1, "b0", "b1", {"build": {"frame": "revolver", "parts": {}, "tune": {}}, "zone": "body", "distance": 9.0})
	lg.buy(1, "p1", gun, 900)
	lg.round_over(1, 0, "炸彈引爆")
	var path := lg.write(0, [1, 0])
	DirAccess.rename_absolute(path, dir.path_join(path.get_file()))
	var logs := MatchLog.load_all(dir)
	check(logs.size() == 1 and logs[0].kills.size() == 3, "the log reads back from its file")
	var agg := Balance.aggregate(logs)
	check(int(agg.kills) == 2, "bot-on-bot kills are left out (%d)" % int(agg.kills))
	check(int(agg.frames.carbine.heads) == 1 and int(agg.buys.carbine) == 1, "kills, headshots and buys per frame")
	var md := Balance.report(logs)
	check(md.contains("模組化卡賓槍") and md.contains("實戰數據") and md.contains("炸彈引爆"), "the report has frames, real data and round endings")
	print("BALANCE TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
