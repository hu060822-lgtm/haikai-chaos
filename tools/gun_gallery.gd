extends SceneTree
## Gun model sheets: every frame (or a list of builds) on a neutral studio backdrop under
## a key light, a fill and a rim, twelve to a sheet, plus a few close-ups.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/gun_gallery.gd -- <out_dir>
## Env: FRAMES=a,b (only these frames), MODS=1 (also sheets of modded builds), CLOSE=a,b
## (close-ups of these frames; default a handful), SHEETS=0 (skip the bare sheets).

var out := "user://"
const COLS := 4
const ROWS := 3
const CELL := Vector2(1.25, 0.95)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	var root3 := Node3D.new()
	root.add_child(root3)
	_studio(root3)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.current = true
	await _frames(2)
	var frames: Array = Arsenal.FRAMES.keys()
	if OS.get_environment("FRAMES") != "":
		frames = OS.get_environment("FRAMES").split(",")
	var builds: Array = []
	if OS.get_environment("SHEETS") != "0":
		for f in frames:
			builds.append({"frame": f, "parts": {}, "tune": {}})
	if OS.get_environment("MODS") == "1":
		builds.append_array(_modded(frames))
	if OS.get_environment("PARTS") != "":
		builds.append_array(_showcase(OS.get_environment("PARTS").split(",")))
	var holder := Node3D.new()
	root3.add_child(holder)
	var sheet := 0
	for start in range(0, builds.size(), COLS * ROWS):
		for c in holder.get_children():
			c.free()
		var batch: Array = builds.slice(start, start + COLS * ROWS)
		for i in batch.size():
			var gun := GunModels.build(batch[i])
			var pivot := Node3D.new()
			holder.add_child(pivot)
			pivot.add_child(gun)
			var aabb := GunThumb._bounds(gun)
			var s := 1.0 / maxf(aabb.size.z, aabb.size.y * 2.0)
			gun.position = -aabb.get_center()
			pivot.scale = Vector3.ONE * s
			pivot.rotation_degrees = Vector3(0, -18, 0)
			var col := i % COLS
			var row := i / COLS
			pivot.position = Vector3(0, (ROWS - 1) * 0.5 * CELL.y - row * CELL.y, ((COLS - 1) * 0.5 - col) * CELL.x * -1.0)
			var label := Label3D.new()
			label.text = "%s  %s" % [batch[i].frame, ",".join(PackedStringArray((batch[i].parts as Dictionary).values()))]
			label.font_size = 18
			label.pixel_size = 0.0016
			label.modulate = Color(0.15, 0.15, 0.15)
			label.outline_size = 0
			holder.add_child(label)
			label.position = pivot.position + Vector3(0.3, -0.27, 0)
			label.rotation_degrees = Vector3(0, 90, 0)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(ROWS * CELL.y, COLS * CELL.x * 9.0 / 16.0) + 0.05
		cam.look_at_from_position(Vector3(6, 0.9, 0), Vector3.ZERO, Vector3.UP)
		await _frames(4)
		await _save("guns_%02d" % sheet)
		sheet += 1
	for c in holder.get_children():
		c.free()
	var close := ["service_pistol", "carbine", "ak", "rifle", "shotgun", "smg"]
	if OS.get_environment("CLOSE") != "":
		close = OS.get_environment("CLOSE").split(",")
	elif OS.get_environment("CLOSE") == "" and OS.get_environment("FRAMES") != "":
		close = frames.slice(0, 3)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28
	for f in close:
		for c in holder.get_children():
			c.free()
		var build: Dictionary = {"frame": f, "parts": {}, "tune": {}}
		if ":" in f:
			build = str_to_var(f.substr(f.find(":") + 1))
		var gun := GunModels.build(build)
		holder.add_child(gun)
		var aabb := GunThumb._bounds(gun)
		gun.position = -aabb.get_center()
		var l := maxf(aabb.size.z, 0.25)
		cam.position = Vector3(l * 1.55, l * 0.42, -l * 0.55)
		cam.look_at(Vector3(0, 0, -l * 0.05), Vector3.UP)
		await _frames(4)
		await _save("close_%s" % str(build.frame))
	quit()


## One build per part: the first frame (in a fixed order) where it fits a root slot.
func _showcase(ids: Array) -> Array:
	var out_b := []
	var order := ["carbine", "service_pistol", "shotgun", "smg", "ak", "rifle", "revolver", "crossbow"]
	for id in ids:
		var slot: String = Arsenal.part(id).get("slot", "")
		for f in order:
			var b := {"frame": f, "parts": {}, "tune": {}}
			for s in Arsenal.open_slots(b):
				if Arsenal.slot_type(s) == slot and id in Arsenal.parts_for(b, s):
					b.parts[s] = id
					break
			if not b.parts.is_empty():
				out_b.append(Arsenal.clean(b))
				break
	return out_b


## A few builds per frame with whatever fits in the main slots.
func _modded(frames: Array) -> Array:
	var out_b := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for f in frames:
		for n in 2:
			var b := {"frame": f, "parts": {}, "tune": {}}
			for slot in Arsenal.SLOTS:
				if not slot in Arsenal.open_slots(b):
					continue
				var opts := Arsenal.parts_for(b, slot)
				if opts.is_empty() or rng.randf() < 0.3:
					continue
				b.parts[slot] = opts[rng.randi() % opts.size()]
				b = Arsenal.clean(b)
			out_b.append(b)
	return out_b


func _studio(p: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#C9C3B8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#B9BEC2")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	p.add_child(we)
	for spec in [[Vector3(-35, 40, 0), Color("#FFF0DA"), 1.6], [Vector3(-10, -130, 0), Color("#B8C4CC"), 0.45],
			[Vector3(-20, 180, 0), Color("#FFFFFF"), 0.6]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = spec[0]
		l.light_color = spec[1]
		l.light_energy = spec[2]
		p.add_child(l)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)
