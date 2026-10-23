class_name Decoy
extends CharacterBody3D
## DECOY's runner (C6): a copy of its owner (same body, same gun) that sprints the way
## the owner was looking for LIFE seconds, footsteps and all, and fires FAKE_SHOTS into the
## air halfway (sound and tracers, no damage). Bots take it for a real enemy and shoot at
## it; players have to read it.
##
## Counter: one hit of anything pops it (everywhere: Deploy event "pop"). It never jumps,
## never turns except along a wall, can't hurt anyone, and bumps into nothing alive.
## Its own team sees it see-through, with a label.

const SPEED := 8.4
const GRAVITY := 21.0
const LIFE := 4.0
const FAKE_SHOTS := [1.3, 1.55, 1.8]

var uid := ""
var owner_id := ""
var team := 0
var alive := true
var marked := 0.0
var display_name := "?"
var move := 0
var dir := Vector3.FORWARD
var build := {}
var t := 0.0
var _model: CompetitorRig
var _gun: Node3D
var _shots := 0
var _rng := RandomNumberGenerator.new()


func setup(data: Dictionary) -> void:
	var d: Vector3 = data.get("dir", Vector3.FORWARD)
	d.y = 0.0
	dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	build = data.get("build", {})
	display_name = str(data.get("name", "?"))
	position = data.get("at", Vector3.ZERO)
	_rng.seed = hash(uid)


func _ready() -> void:
	add_to_group("deployables")
	add_to_group("decoys")
	add_to_group("hittable")
	collision_layer = 0
	collision_mask = Geo.WORLD | Geo.BOUNDS
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	for spec in [["head", Vector3(0, 1.62, 0), Vector3(0.36, 0.36, 0.36)], ["body", Vector3(0, 1.1, 0), Vector3(0.5, 0.7, 0.32)],
			["legs", Vector3(0, 0.4, 0), Vector3(0.42, 0.8, 0.3)]]:
		var area := Area3D.new()
		area.collision_layer = Geo.HITBOX
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("target", self)
		area.set_meta("zone", spec[0])
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[2]
		cs.shape = box
		area.position = spec[1]
		area.add_child(cs)
		add_child(area)
	var ally := team == Deploy.viewer_team
	_model = CompetitorModel.build(FpUi.ally_color() if ally else Faultprint.INFO_ENEMY, not ally, _rng)
	add_child(_model)
	if not build.is_empty():
		_gun = GunModels.build(build)
		_model.find_child("GunHand", true, false).add_child(_gun)
	if ally:
		# Our own decoy: see-through, and labelled, so nobody on the team falls for it.
		for m in _model.find_children("*", "GeometryInstance3D", true, false):
			(m as GeometryInstance3D).transparency = 0.55
		var tag := Label3D.new()
		tag.text = "誘餌"
		tag.font_size = 48
		tag.pixel_size = 0.006
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Kit.info("decoy").color
		tag.no_depth_test = true
		tag.position = Vector3(0, 2.25, 0)
		add_child(tag)
	look_at(global_position + dir, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	t += delta
	marked = maxf(marked - delta, 0.0)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	# Along a wall it hit: keep running the way the wall lets it.
	if is_on_wall():
		var n := get_wall_normal()
		n.y = 0.0
		var along := dir - n * dir.dot(n)
		if along.length() > 0.2:
			dir = along.normalized()
			look_at(global_position + dir, Vector3.UP)
	if _model != null:
		_model.pose(delta, velocity, is_on_floor(), 0.0, false, 0, 0.0)
	if _shots < FAKE_SHOTS.size() and t >= float(FAKE_SHOTS[_shots]):
		_shots += 1
		_fake_shot()
	if t >= LIFE:
		_vanish(false)


## Sound and a tracer like a real shot, into the air ahead: nothing is hit.
func _fake_shot() -> void:
	var klass := PrintFx.weapon_class(Arsenal.stats(build)) if not build.is_empty() else "rapid"
	var from := _gun.to_global(_gun.get_meta("muzzle", Vector3.ZERO)) if _gun != null else global_position + Vector3(0, 1.4, 0)
	var aim := (dir + Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(0.15, 0.3), 0)).normalized()
	PrintFx.tracer(get_tree().current_scene, from, from + aim * 40.0, klass)
	if _gun != null:
		PrintFx.muzzle(_gun, _gun.get_meta("muzzle", Vector3.ZERO), klass, 1.2)
	Sfx.shot(self, klass, false)


func flat_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func exclusions() -> Array:
	return []


func take_hit(info: Dictionary) -> bool:
	if not alive:
		return false
	info.blocked = true
	if int(info.get("team", -1)) == team:
		return false
	Deploy.event(uid, "pop")
	return false


func on_event(what: String, _amount: float) -> void:
	if what == "pop" and alive:
		_vanish(true)


func _vanish(popped: bool) -> void:
	alive = false
	PrintFx.takedown(get_tree().current_scene, global_position + Vector3(0, 0.9, 0), Kit.info("decoy").color)
	if popped:
		Sfx.play(self, "decoy_pop", -4.0)
		var tag := Label3D.new()
		tag.text = "誘餌"
		tag.font_size = 64
		tag.pixel_size = 0.006
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Kit.info("decoy").color
		tag.no_depth_test = true
		get_tree().current_scene.add_child(tag)
		tag.global_position = global_position + Vector3(0, 1.8, 0)
		var tw := tag.create_tween()
		tw.tween_property(tag, "position:y", tag.position.y + 0.8, 0.9)
		tw.parallel().tween_property(tag, "modulate:a", 0.0, 0.9)
		tw.tween_callback(tag.queue_free)
	queue_free()
