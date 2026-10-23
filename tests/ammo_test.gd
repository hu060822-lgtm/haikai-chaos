extends SceneTree
## Ammo follows the calibre while every other part still fits every gun, and the bench can
## take every part off in one click (and put them back).
##   godot --headless --path . --script res://tests/ammo_test.gd

var failures := 0


func _init() -> void:
	_test_ammo()
	await _test_strip()
	print("AMMO TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _test_ammo() -> void:
	print("ammo by calibre")
	var empty := []
	var wrong := []
	for fid in Arsenal.FRAMES:
		var b := {"frame": fid, "parts": {}, "tune": {}}
		var cal := Arsenal.caliber_of(b)
		var family: String = Arsenal.CALIBERS[cal].family
		var ammo := Arsenal.parts_for(b, "ammo")
		if ammo.is_empty():
			empty.append(fid)
		for id in ammo:
			if not Arsenal.ammo_fits(cal, id):
				wrong.append("%s:%s" % [fid, id])
		# Other slots stay free.
		if Arsenal.parts_for(b, "sight").size() != Arsenal.parts_for({"frame": "carbine", "parts": {}}, "sight").size():
			wrong.append(fid + ":sights")
		if family == "shell" and ("fmj" in ammo or not "slug" in ammo):
			wrong.append(fid + ":shells")
	check(empty.is_empty(), "every gun has ammo to load %s" % [empty])
	check(wrong.is_empty(), "the bench only lists ammo that fits %s" % [wrong])
	var pistol := Arsenal.parts_for("service_pistol", "ammo")
	check("hollow_point" in pistol and not "slug" in pistol and not "explosive_bolt" in pistol and not "api_rounds" in pistol,
		"a 9mm pistol takes pistol rounds, no slugs, no crossbow bolts, no rifle-only API")
	var bow := Arsenal.parts_for("crossbow", "ammo")
	check("broadhead" in bow and not "fmj" in bow and not "slug" in bow, "a crossbow takes bolt heads only")
	check(Arsenal.parts_for("flamethrower", "ammo").all(func(id): return Arsenal.part(id).fits == ["fuel"]), "a flamethrower takes fuel only")
	check(not Arsenal.fits("service_pistol", "slug") and Arsenal.fits("carbine", "fmj"), "fits() agrees for bare frames")
	# Ammo that doesn't fit drops off when loaded or when the calibre changes.
	var bad := Arsenal.clean({"frame": "shotgun", "parts": {"ammo": "fmj"}})
	check(not bad.parts.has("ammo"), "rifle rounds in a shotgun are dropped")
	var conv := Arsenal.clean({"frame": "carbine", "parts": {"receiver": "upper_pcc", "ammo": "api_rounds"}})
	check(Arsenal.caliber_of(conv) == "9mm" and not conv.parts.has("ammo"), "a 9mm upper drops rifle-only API rounds")
	var kept := Arsenal.clean({"frame": "carbine", "parts": {"receiver": "upper_pcc", "ammo": "subsonic", "sight": "scope"}})
	check(kept.parts.get("ammo", "") == "subsonic" and kept.parts.has("sight"), "subsonic 9mm stays, other parts untouched")
	# Random builds never carry misfit ammo.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var misfit := 0
	for i in 300:
		var b := GunNames.random_build(rng)
		var a: String = b.parts.get("ammo", "")
		if a != "" and not Arsenal.ammo_fits(Arsenal.caliber_of(b), a):
			misfit += 1
	check(misfit == 0, "300 random builds, no misfit ammo")
	var looks := []
	for id in Arsenal.PARTS:
		if Arsenal.PARTS[id].slot == "ammo" and not GunModels.AMMO_LOOK.has(id):
			looks.append(id)
	check(looks.is_empty(), "every ammo has a look on the gun %s" % [looks])


func _test_strip() -> void:
	print("bench: strip everything")
	var bench := Bench.new()
	root.add_child(bench)
	await process_frame
	var full := {"frame": "carbine", "parts": {"sight": "scope", "muzzle": "suppressor", "ammo": "subsonic", "rail_l": "laser"}, "tune": {}}
	bench.open(full, "")
	var before: int = bench.build.parts.size()
	bench.strip_all()
	check(before == 4 and bench.build.parts.is_empty() and bench.build.frame == "carbine", "one press: %d parts off, bare carbine left" % before)
	bench.strip_all()
	check(bench.build.parts.size() == 4, "second press puts all %d back" % bench.build.parts.size())
	bench.strip_all()
	bench.build = Arsenal.clean({"frame": "carbine", "parts": {"sight": "red_dot"}})
	bench._refresh()
	bench.strip_all()
	check(bench.build.parts.is_empty(), "after another change, the button strips again instead of restoring")
	bench.queue_free()
