class_name MapGuard
extends Node
## Nobody leaves the map (C5). Every map is sealed (Layout: walls with invisible columns
## to the lid, no pulling up onto them), and this is the net under that: anyone below
## the map's lowest floor, or outside its play area, goes back to the last place they
## stood on solid floor inside it (or their spawn). Watches the local player and, on the
## machine that runs them, the bots.

const BELOW := 6.0
const OUTSIDE := 2.0
const EVERY := 0.25

var map: Node3D
var area := Rect2()
var floor_y := -2.0
var caught := 0
var _safe := {}   # instance id -> last good position
var _t := 0.0


func _init(for_map: Node3D) -> void:
	name = "MapGuard"
	map = for_map
	var a: Variant = for_map.get("play_area")
	area = a if a is Rect2 else Rect2(-80, -80, 160, 160)
	var f: Variant = for_map.get("lowest_floor")
	floor_y = float(f) if f != null else -2.0


func out_of_map(pos: Vector3) -> bool:
	return pos.y < floor_y - BELOW or not area.grow(OUTSIDE).has_point(Vector2(pos.x, pos.z))


func _physics_process(delta: float) -> void:
	_t -= delta
	var note := _t <= 0.0
	if note:
		_t = EVERY
	for body in get_tree().get_nodes_in_group("combatants"):
		if not (body is CharacterBody3D) or body is Avatar or not body.get("alive"):
			continue
		if body is Bot and not multiplayer.is_server() and multiplayer.has_multiplayer_peer():
			continue
		var b := body as CharacterBody3D
		var key := b.get_instance_id()
		if out_of_map(b.global_position):
			var back: Vector3 = _safe.get(key, map.get("player_spawn").origin if map.get("player_spawn") else Vector3.ZERO)
			b.global_position = back + Vector3(0, 0.2, 0)
			b.velocity = Vector3.ZERO
			caught += 1
			if b is Player and get_tree().current_scene is Main:
				var m := get_tree().current_scene as Main
				if m.hud != null:
					m.hud.show_hint("出界了：拉回到上一個站穩的位置", 2.0)
		elif note and b.is_on_floor():
			_safe[key] = b.global_position


## A respawn: forget where `body` last stood.
func forget(body: Node) -> void:
	_safe.erase(body.get_instance_id())
