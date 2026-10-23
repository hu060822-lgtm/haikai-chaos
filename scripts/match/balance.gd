class_name Balance
extends RefCounted
## The balance report (C5): what every gun does on paper, and (from MatchLog files) what
## it did in real matches. Paper numbers are worked out the way Weapon deals damage:
## PvP damage per hit, falloff between the derived falloff and the range, HEAD_MULT, the
## magazine and reload, charge time for charge guns. A frame is flagged when its body
## time-to-kill at 20 m is far from the median, or it is much cheaper than guns as fast.
##
##   godot --headless --path . --script res://tools/balance.gd -- [out.md]

const DISTANCES := [10.0, 20.0, 40.0]
const FAST := 0.6    # under this share of the median TTK: flagged as too strong
const SLOW := 1.8    # over this share: flagged as too weak


## Damage of one full shot (all pellets) on the body at `dist`.
static func shot_at(s: Dictionary, dist: float, mult := 1.0) -> float:
	var dmg := Weapon.pvp_damage(s) * int(s.pellets) * mult
	var falloff := float(s.falloff)
	var reach := float(s.range)
	var fx: Dictionary = s.effects
	if fx.has("long_bonus"):
		dmg *= lerpf(1.0, float(fx.long_bonus), clampf(dist / maxf(reach, 1.0), 0.0, 1.0))
	elif dist > falloff:
		dmg *= lerpf(1.0, Weapon.FALLOFF_MIN, clampf((dist - falloff) / maxf(reach - falloff, 1.0), 0.0, 1.0))
	if dist > reach * 1.5:
		return 0.0
	return dmg


static func shots_to_kill(s: Dictionary, dist: float, mult := 1.0) -> int:
	var d := shot_at(s, dist, mult)
	return 999 if d <= 0.01 else int(ceil(100.0 / d - 0.0001))


## Seconds from the first shot to the kill, every shot landing (reloads included).
static func ttk(s: Dictionary, dist: float, mult := 1.0) -> float:
	var n := shots_to_kill(s, dist, mult)
	if n >= 999:
		return INF
	var gap := 1.0 / maxf(float(s.rate), 0.05)
	if str(s.kind) == "charge":
		gap = maxf(gap, Weapon.CHARGE_TIME)
	var mag := maxi(int(s.mag), 1)
	var reloads := (n - 1) / mag
	return (n - 1 - reloads) * gap + reloads * float(s.reload)


static func row_for(build: Dictionary) -> Dictionary:
	var s := Arsenal.stats(build)
	var r := {"frame": str(build.frame), "name": Arsenal.name_of(str(build.frame)), "price": int(s.price),
		"damage": Weapon.pvp_damage(s), "pellets": int(s.pellets), "rate": float(s.rate), "mag": int(s.mag),
		"reload": float(s.reload), "range": float(s.range), "kind": str(s.kind), "weight": float(s.weight),
		"mobility": Player.mobility_of(s), "head_stk": shots_to_kill(s, 10.0, Weapon.HEAD_MULT)}
	for d in DISTANCES:
		r["stk_%d" % int(d)] = shots_to_kill(s, d)
		r["ttk_%d" % int(d)] = ttk(s, d)
	# The kill cycle: the TTK plus the wait before the next shot (so a one-shot gun that
	# fires every two seconds isn't counted as instant).
	var gap := 1.0 / maxf(float(s.rate), 0.05)
	if str(s.kind) == "charge":
		gap = maxf(gap, Weapon.CHARGE_TIME)
	r.cycle = float(r.ttk_20) + gap
	return r


## One row per frame, bare: price, damage, TTK at DISTANCES, head STK, mobility, flag.
static func frame_rows() -> Array:
	var rows := []
	for id in Arsenal.FRAMES:
		rows.append(row_for({"frame": id, "parts": {}, "tune": {}}))
	var ttks := rows.map(func(r: Dictionary) -> float: return float(r.cycle)).filter(func(v: float) -> bool: return v < INF)
	ttks.sort()
	var median: float = ttks[ttks.size() / 2] if not ttks.is_empty() else 1.0
	for r in rows:
		var t := float(r.cycle)
		var flags := []
		if t < median * FAST:
			flags.append("偏強：擊殺週期 %.2f s，中位數 %.2f s" % [t, median])
		elif t > median * SLOW:
			flags.append("偏弱：擊殺週期 %s，中位數 %.2f s" % [_secs(t), median])
		# Cheap and fast: as quick as the median for much less.
		if t <= median and t < INF and int(r.price) < 400:
			flags.append("便宜又快（$%d）" % int(r.price))
		r.flags = flags
	return rows


## One row per part: price, slot, how many frames take it, and what it does to the first
## frame that takes it bare (20 m TTK and mobility before -> after).
static func part_rows() -> Array:
	var rows := []
	for pid in Arsenal.PARTS:
		var p: Dictionary = Arsenal.PARTS[pid]
		var fits := 0
		var ref := ""
		for fid in Arsenal.FRAMES:
			if Arsenal.fits(fid, pid):
				fits += 1
				if ref == "" and Arsenal.fits_in({"frame": fid, "parts": {}, "tune": {}}, str(p.slot), pid):
					ref = fid
		var r := {"part": pid, "name": str(p.name), "slot": str(p.slot), "price": int(p.price), "fits": fits, "ref": ref}
		if ref != "":
			var bare := row_for({"frame": ref, "parts": {}, "tune": {}})
			var built := row_for({"frame": ref, "parts": {str(p.slot): pid}, "tune": {}})
			r.ttk_before = float(bare.ttk_20)
			r.ttk_after = float(built.ttk_20)
			r.mob_before = float(bare.mobility)
			r.mob_after = float(built.mobility)
		rows.append(r)
	return rows


## Real-match numbers from MatchLog files: per frame kills, deaths while holding it is not
## known (only the killer's gun is), headshot share, average kill distance; per part kills;
## buys per frame; rounds and how they ended.
static func aggregate(logs: Array, with_bots := false) -> Dictionary:
	var frames := {}
	var parts := {}
	var buys := {}
	var whys := {}
	var kills := 0
	var matches := logs.size()
	for lg in logs:
		for k in lg.get("kills", []):
			if not with_bots and (bool(k.get("killer_bot", false)) and bool(k.get("victim_bot", false))):
				continue
			var f := str(k.get("frame", ""))
			if f == "":
				continue
			kills += 1
			var e: Dictionary = frames.get(f, {"kills": 0, "heads": 0, "dist": 0.0, "walls": 0})
			e.kills += 1
			e.heads += 1 if str(k.get("zone", "")) == "head" else 0
			e.walls += 1 if bool(k.get("through_wall", false)) else 0
			e.dist += float(k.get("distance", 0.0))
			frames[f] = e
			for pid in k.get("parts", []):
				parts[str(pid)] = int(parts.get(str(pid), 0)) + 1
		for b in lg.get("buys", []):
			var f := str(b.get("frame", ""))
			buys[f] = int(buys.get(f, 0)) + 1
		for r in lg.get("rounds", []):
			var w := str(r.get("why", ""))
			whys[w] = int(whys.get(w, 0)) + 1
	return {"matches": matches, "kills": kills, "frames": frames, "parts": parts, "buys": buys, "whys": whys}


static func _secs(t: float) -> String:
	return "—" if t == INF else "%.2f s" % t


static func _num(v: float) -> String:
	return ("%.0f" % v) if absf(v - roundf(v)) < 0.05 else ("%.1f" % v)


## The whole report as Markdown.
static func report(logs: Array = []) -> String:
	var out := PackedStringArray()
	out.append("# HAIKAI: CHAOS 平衡報表")
	out.append("")
	out.append("產生時間：%s。槍身 %d 把、零件 %d 個、對戰紀錄 %d 場。" % [Time.get_datetime_string_from_system(),
		Arsenal.FRAMES.size(), Arsenal.PARTS.size(), logs.size()])
	out.append("")
	out.append("擊殺時間（TTK）＝第一發到擊殺的秒數，假設每發都打中身體，含換彈。擊殺週期＝20 m TTK 加上下一發的間隔（用來比強弱，一發必殺但射很慢的槍不會被當成瞬殺）。爆頭 STK 為 10 m 打頭幾發。")
	out.append("")
	out.append("## 槍身（裸槍）")
	out.append("")
	out.append("| 槍身 | 價格 | 單發傷害 | 射速 | 彈匣 | 10 m TTK | 20 m TTK | 40 m TTK | 擊殺週期 | 身體 STK (20 m) | 爆頭 STK | 機動 | 提醒 |")
	out.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|")
	var rows := frame_rows()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.cycle) < float(b.cycle))
	for r in rows:
		var dmg := _num(float(r.damage)) + ("×%d" % int(r.pellets) if int(r.pellets) > 1 else "")
		out.append("| %s | $%d | %s | %s | %d | %s | %s | %s | %s | %s | %d | %.2f | %s |" % [r.name, int(r.price), dmg,
			_num(float(r.rate)), int(r.mag), _secs(float(r.ttk_10)), _secs(float(r.ttk_20)), _secs(float(r.ttk_40)), _secs(float(r.cycle)),
			"—" if int(r.stk_20) >= 999 else str(r.stk_20), int(r.head_stk), float(r.mobility), "；".join(r.flags)])
	out.append("")
	out.append("## 零件（裝在第一把能直接裝的槍身上，20 m TTK 與機動的變化）")
	out.append("")
	out.append("| 零件 | 槽位 | 價格 | 可裝槍身數 | 參考槍身 | 20 m TTK | 機動 |")
	out.append("|---|---|---:|---:|---|---|---|")
	var prows := part_rows()
	prows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.slot) + str(a.part) < str(b.slot) + str(b.part))
	for r in prows:
		if str(r.ref) == "":
			out.append("| %s | %s | $%d | %d | （要先裝別的零件開槽） | | |" % [r.name, Arsenal.slot_name(str(r.slot)), int(r.price), int(r.fits)])
			continue
		var t := "%s → %s" % [_secs(float(r.ttk_before)), _secs(float(r.ttk_after))] if absf(float(r.ttk_before) - float(r.ttk_after)) > 0.005 else "不變"
		var m := "%.2f → %.2f" % [float(r.mob_before), float(r.mob_after)] if absf(float(r.mob_before) - float(r.mob_after)) > 0.005 else "不變"
		out.append("| %s | %s | $%d | %d | %s | %s | %s |" % [r.name, Arsenal.slot_name(str(r.slot)), int(r.price), int(r.fits),
			Arsenal.name_of(str(r.ref)), t, m])
	out.append("")
	out.append("## 實戰數據")
	out.append("")
	if logs.is_empty():
		out.append("還沒有對戰紀錄。打完一場（或中途離開）時，遊戲會把紀錄存到 user://match_logs/，再匯出一次就會出現在這裡。")
		return "\n".join(out)
	var agg := aggregate(logs)
	out.append("%d 場、%d 次擊殺（不含機器人打機器人）。" % [int(agg.matches), int(agg.kills)])
	out.append("")
	out.append("| 槍身 | 擊殺 | 佔比 | 爆頭率 | 平均距離 | 穿牆 | 被買次數 |")
	out.append("|---|---:|---:|---:|---:|---:|---:|")
	var fk: Dictionary = agg.frames
	var ids := fk.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(fk[a].kills) > int(fk[b].kills))
	for f in ids:
		var e: Dictionary = fk[f]
		out.append("| %s | %d | %.0f%% | %.0f%% | %.1f m | %d | %d |" % [Arsenal.name_of(f), int(e.kills),
			100.0 * int(e.kills) / maxf(int(agg.kills), 1), 100.0 * int(e.heads) / maxf(int(e.kills), 1),
			float(e.dist) / maxf(int(e.kills), 1), int(e.walls), int(agg.buys.get(f, 0))])
	out.append("")
	var pk: Dictionary = agg.parts
	if not pk.is_empty():
		out.append("最常出現在擊殺槍上的零件：")
		out.append("")
		var pids := pk.keys()
		pids.sort_custom(func(a: String, b: String) -> bool: return int(pk[a]) > int(pk[b]))
		for pid in pids.slice(0, 15):
			out.append("- %s：%d 次" % [Arsenal.name_of(pid), int(pk[pid])])
		out.append("")
	var whys: Dictionary = agg.whys
	if not whys.is_empty():
		out.append("回合怎麼結束的：")
		out.append("")
		for w in whys:
			out.append("- %s：%d 次" % [w, int(whys[w])])
	return "\n".join(out)


## Writes the report to `path` (default user://balance_report.md) and returns the path.
static func export(path := "user://balance_report.md") -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(report(MatchLog.load_all()))
	f.close()
	return path
