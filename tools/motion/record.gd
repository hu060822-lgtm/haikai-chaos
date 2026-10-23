extends SceneTree
## Character overhaul, Phase 3: drives the real Player through fixed move flows in the
## motion arena with a scripted pilot (fake input) and records, every physics tick, what
## the body did: position, facing, look pitch, move state, velocity, floor contact,
## crouch, the wall it was on and one-off events (wall kicks). motion/film.gd replays the
## recordings on the athlete and films them.
##   godot --headless --path . --script res://tools/motion/record.gd -- <out_dir> [flows...]

const Arena := preload("res://tools/motion/arena.gd")
const FLOWS := ["locomotion", "slide", "wallrun", "dash", "stomp", "climb", "fall"]

var player: Player
var out := "user://"
var frames: Array = []
var _last_tr := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://"
	var which: Array = args.slice(1) if args.size() > 1 else FLOWS
	Engine.physics_ticks_per_second = 60
	InputSetup.register()
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	Arena.build(scene)
	player = Player.new()
	scene.add_child(player)
	await physics_frame
	for f in which:
		await _flow(f)
	quit()


func _flow(name: String) -> void:
	release_all()
	frames = []
	await call("_" + name)
	release_all()
	var file := FileAccess.open("%s/%s.json" % [out, name], FileAccess.WRITE)
	file.store_string(JSON.stringify({"flow": name, "hz": 60, "frames": frames}))
	file.close()
	print("recorded %s: %d ticks" % [name, frames.size()])


func release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "dash", "fire", "aim"]:
		Input.action_release(a)


func press(a: String, on := true) -> void:
	if on:
		Input.action_press(a)
	else:
		Input.action_release(a)


func place(at: Vector3, yaw := 0.0) -> void:
	player.spawn_at(Transform3D(Basis(Vector3.UP, yaw), at))
	_last_tr = player.transitions.size()
	await physics_frame


## Runs `seconds` of physics, recording every tick; `each` (optional) is called first.
func run(seconds: float, each := Callable()) -> void:
	for i in int(seconds * 60.0):
		if each.is_valid():
			each.call()
		await physics_frame
		_record()


func _record() -> void:
	var ev := ""
	var why := ""
	var tr: Dictionary = player.transitions[0] if not player.transitions.is_empty() else {}
	if not tr.is_empty() and absf(float(tr.t) - player.clock) < 0.5 / 60.0:
		why = str(tr.why)
		if tr.from == tr.to:
			ev = "wall_kick"
	var p := player.global_position
	var v := player.velocity
	var n: Vector3 = player._wall_normal
	frames.append({"p": [p.x, p.y, p.z], "yaw": player.rotation.y, "pitch": player._pitch, "move": player.move,
		"v": [v.x, v.y, v.z], "floor": player.is_on_floor(), "crouch": 1.0 if player._crouching else 0.0,
		"wall": [n.x, n.y, n.z], "event": ev, "name": Player.MOVE_NAMES[player.move], "why": why})


func tap(a: String) -> void:
	press(a)
	await run(2.0 / 60.0)
	press(a, false)


# --- Flows ---------------------------------------------------------------------------------

## Stand, walk, run, sprint, stop, turn on the spot, back-pedal, strafe, crouch-walk.
func _locomotion() -> void:
	await place(Vector3(0, 0, 20))
	await run(1.0)
	press("move_forward")
	await run(1.4)
	press("sprint")
	await run(2.0)
	press("sprint", false)
	press("move_forward", false)
	await run(1.0)
	var turn := func() -> void: player.rotation.y += PI / 24.0
	await run(0.4, turn)
	await run(0.6)
	press("move_back")
	await run(1.2)
	press("move_back", false)
	press("move_right")
	await run(1.2)
	press("move_right", false)
	press("crouch")
	press("move_forward")
	await run(1.4)
	release_all()
	await run(0.8)


## Sprint, slide, slide jump, land running, slide again from the landing.
func _slide() -> void:
	await place(Vector3(0, 0, 30))
	press("move_forward")
	press("sprint")
	await run(1.6)
	press("crouch")
	await run(0.55)
	await tap("jump")
	press("crouch", false)
	await run(0.9)
	press("crouch")
	await run(0.8)
	release_all()
	await run(0.8)


## Run along the wall, jump onto it, run, jump off, land at speed.
func _wallrun() -> void:
	await place(Vector3(Arena.WALL_X + 2.4, 0, 8), 0.3)
	press("move_forward")
	press("sprint")
	await run(0.8)
	player.rotation.y = 0.0
	await tap("jump")
	press("move_left")
	await run(0.35)
	press("move_left", false)
	await run(1.0)
	press("move_right")
	await tap("jump")
	await run(0.25)
	press("move_right", false)
	await run(1.6)
	release_all()
	await run(0.6)


## Dash forward from a run, dash jump; a side dash from standing.
func _dash() -> void:
	await place(Vector3(10, 0, 30))
	press("move_forward")
	await run(0.8)
	await tap("dash")
	await run(0.12)
	await tap("jump")
	await run(1.2)
	release_all()
	await run(0.6)
	press("move_left")
	await tap("dash")
	await run(0.6)
	release_all()
	await run(0.6)


## Off the tower, a stomp: look down, crouch in the air, hit, bounce.
func _stomp() -> void:
	await place(Arena.TOWER + Vector3(-1.6, 0.1, 0), PI * 0.5)
	await run(0.4)
	press("move_forward")
	await tap("jump")
	await run(0.5)
	press("move_forward", false)
	player._pitch = deg_to_rad(-70.0)
	await tap("crouch")
	var held := 0
	for i in 120:
		await run(1.0 / 60.0)
		if player.is_on_floor():
			held += 1
			if held == 2:
				player._pitch = 0.0
				await tap("jump")
				break
	await run(1.4)
	release_all()
	await run(0.4)


## Run at the block, climb it, pull up over the top, walk on.
func _climb() -> void:
	await place(Vector3(10, 0, Arena.CLIMB_Z + 6.0))
	press("move_forward")
	await run(0.9)
	press("jump")
	await run(1.4)
	press("jump", false)
	await run(0.8)
	release_all()
	await run(0.5)


## A plain step off the tower: the high landing.
func _fall() -> void:
	await place(Arena.TOWER + Vector3(0, 0.1, 0), -PI * 0.5)
	await run(0.3)
	press("move_forward")
	await run(1.6)
	press("move_forward", false)
	await run(1.0)
