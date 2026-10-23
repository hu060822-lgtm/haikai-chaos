extends SceneTree
## Character overhaul, Phase 3: films the athlete replaying recorded move flows
## (motion/record.gd) in the motion arena, from a following side camera, 30 frames a
## second, with the move state and speed in the corner. Frames go to <out>/<flow>/,
## then ffmpeg makes <out>/<flow>.mp4 (tools/motion/film.sh does both).
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/motion/film.gd -- <rec_dir> <out_dir> [flows...]

const Arena := preload("res://tools/motion/arena.gd")
const CAMS := {
	"locomotion": Vector3(3.4, 1.5, 0.8), "slide": Vector3(3.2, 1.1, 0.5), "wallrun": Vector3(3.6, 1.9, 2.4),
	"dash": Vector3(3.4, 1.5, 0.8), "stomp": Vector3(4.5, 1.2, 4.5), "climb": Vector3(4.2, 1.8, 2.6), "fall": Vector3(4.0, 1.4, 4.0),
}

var cam: Camera3D
var label: Label


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rec := args[0]
	var out := args[1]
	var which: Array = args.slice(2) if args.size() > 2 else CAMS.keys()
	Settings.look = Faultprint.COUNTERFORM
	Faultprint.set_look(Settings.look)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	_light(world)
	Arena.build(world)
	cam = Camera3D.new()
	cam.fov = 55
	world.add_child(cam)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("#F4F1EA"))
	label.add_theme_color_override("font_outline_color", Color("#1C1E20"))
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)
	await process_frame
	for f in which:
		var file := FileAccess.open("%s/%s.json" % [rec, f], FileAccess.READ)
		if file == null:
			continue
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		DirAccess.make_dir_recursive_absolute("%s/%s" % [out, f])
		await _film(world, f, data.frames, "%s/%s" % [out, f])
	quit()


func _film(world: Node3D, flow: String, frames: Array, dir: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := CompetitorModel.build(Color("#E8506A"), true, rng) as AthleteRig
	world.add_child(a)
	a.steps = false
	a.hold(GunModels.build({"frame": "carbine", "parts": {}, "tune": {}}))
	var offset: Vector3 = CAMS.get(flow, Vector3(4, 1.6, 1))
	var follow := Vector3.ZERO
	var shot := 0
	for i in frames.size():
		var fr: Dictionary = frames[i]
		var p := Vector3(fr.p[0], fr.p[1], fr.p[2])
		a.global_transform = Transform3D(Basis(Vector3.UP, float(fr.yaw)), p)
		var wall := Vector3(fr.wall[0], fr.wall[1], fr.wall[2])
		a.animate(1.0 / 60.0, {"vel": Vector3(fr.v[0], fr.v[1], fr.v[2]), "floor": fr.floor, "move": int(fr.move),
			"crouch": float(fr.crouch), "pitch": float(fr.pitch), "wall": wall if int(fr.move) in [3, 4] else Vector3.ZERO,
			"event": fr.event})
		if i == 0:
			follow = p
		follow = follow.lerp(p, 0.25)
		if i % 2 == 1:
			cam.look_at_from_position(follow + offset, follow + Vector3(0, 0.9, 0), Vector3.UP)
			cam.make_current()
			var speed := Vector2(fr.v[0], fr.v[2]).length()
			label.text = "%s   %-8s %4.1f m/s   %s" % [flow.to_upper(), AthleteMotion.NAMES[int(fr.move)], speed, fr.event]
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/%04d.png" % [dir, shot])
			shot += 1
	a.queue_free()
	print("filmed %s: %d frames" % [flow, shot])


func _light(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#B9B4AA")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C8CCD0")
	env.ambient_light_energy = 0.4
	env.tonemap_exposure = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -140, 0)
	key.light_energy = 0.85
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 40, 0)
	rim.light_energy = 0.5
	rim.light_color = Color("#D8E4FF")
	world.add_child(rim)
