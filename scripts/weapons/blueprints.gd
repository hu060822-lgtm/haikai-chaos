class_name Blueprints
## Saved gun builds (your own, and ones copied off whoever killed you), kept in
## user://blueprints.json as [{"name": String, "build": Dictionary}].

const PATH := "user://blueprints.json"
const MAX := 40


static func load_all() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Array):
		return []
	var out := []
	for e in data:
		if e is Dictionary and e.has("build") and e.has("name"):
			var b: Dictionary = e.build
			# JSON turns ints into floats and loses nothing else we use.
			out.append({"name": str(e.name), "build": Arsenal.clean(b)})
	return out


static func _save(list: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(list, "\t"))


static func add(build: Dictionary, gun_name: String) -> void:
	var list := load_all()
	list.push_front({"name": gun_name, "build": Arsenal.clean(build)})
	while list.size() > MAX:
		list.pop_back()
	_save(list)


static func remove(index: int) -> void:
	var list := load_all()
	if index >= 0 and index < list.size():
		list.remove_at(index)
		_save(list)


## True when `name` is not just the auto name of `build` (the player named it).
static func is_custom_name(build: Dictionary, gun_name: String) -> bool:
	return gun_name != "" and gun_name != GunNames.auto_name(build, Arsenal.stats(build))
