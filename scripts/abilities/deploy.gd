class_name Deploy
## Everything class abilities put into the world (C6): smoke clouds, decoys, barricades, and
## the map's breakable panels. In a team match every machine builds the same objects: the
## user's machine asks TeamMatch to send the deploy to everyone (itself included), and hits
## on an object (a shot on a barricade, a decoy popped, a panel rammed) travel the same way
## as events, so the object breaks everywhere at once. Offline (practice) it all happens
## here directly.
##
## Objects are kept by uid ("<owner id>:<n>", or "w:<n>" for the map's panels).

## The running TeamMatch, or null offline.
static var net: Node = null
## The local player's team, for ally/enemy colours.
static var viewer_team := 0
static var _objects := {}
static var _n := 0
## uid -> the node that threw / deployed it, for what this machine made itself (C12: the
## thrower's machine is the one that deals a grenade's damage).
static var _users := {}


## Starts a new map: forget everything from the last one.
static func clear() -> void:
	_objects.clear()
	_users.clear()
	_n = 0
	net = null


static func register(uid: String, node: Node) -> void:
	_objects[uid] = node


static func find(uid: String) -> Node:
	var n = _objects.get(uid)
	return n if n != null and is_instance_valid(n) else null


static func owner_id(user: Node) -> String:
	if net != null:
		var id: String = net.id_of(user)
		if id != "":
			return id
	return "local"


## A deploy from `user` on this machine: builds it here, and everywhere in a match.
static func spawn(kind: String, user: Node3D, data: Dictionary) -> void:
	var who := owner_id(user)
	_n += 1
	var uid := "%s:%d" % [who, _n]
	data.team = int(user.get("team"))
	_users[uid] = user
	if net != null:
		net.deploy_out(kind, uid, who, data)
	else:
		create(user.get_tree().current_scene, kind, uid, who, data)


static func create(root: Node, kind: String, uid: String, who: String, data: Dictionary) -> Node:
	if root == null or find(uid) != null:
		return null
	var n: Node3D
	match kind:
		"smoke":
			n = SmokeCloud.new()
		"decoy":
			n = Decoy.new()
		"barricade":
			n = Barricade.new()
		"throw":
			n = Grenade.new()
		_:
			return null
	n.set("uid", uid)
	n.set("owner_id", who)
	n.set("team", int(data.get("team", 0)))
	n.call("setup", data)
	if _users.has(uid) and "user" in n:
		n.set("user", _users[uid])
		_users.erase(uid)
	root.add_child(n)
	register(uid, n)
	return n


## Something happened to object `uid` on this machine (it was shot, rammed, popped).
static func event(uid: String, what: String, amount := 0.0) -> void:
	if net != null:
		net.deploy_event_out(uid, what, amount)
	else:
		apply(uid, what, amount)


static func apply(uid: String, what: String, amount: float) -> void:
	var n := find(uid)
	if n != null and n.has_method("on_event"):
		n.on_event(what, amount)


## Something only the owner's machine knows about object `uid` (C12: a sticky caught a
## person, a mine went off), sent from that machine to every machine (itself included).
static func sync(uid: String, data: Dictionary) -> void:
	if net != null:
		net.deploy_sync_out(uid, data)
	else:
		apply_sync(uid, data)


static func apply_sync(uid: String, data: Dictionary) -> void:
	var n := find(uid)
	if n != null and n.has_method("on_sync"):
		n.on_sync(data)


## The match id of a node ("" offline or unknown), and back.
static func id_of(node: Node) -> String:
	if node == null:
		return ""
	if net != null:
		return net.id_of(node)
	return str(node.get_instance_id())


static func node_of(id: String) -> Node3D:
	if id == "":
		return null
	if net != null:
		var e = net.entities.get(id)
		return e if e is Node3D and is_instance_valid(e) else null
	var o := instance_from_id(int(id)) if id.is_valid_int() else null
	return o as Node3D


## Whether this machine runs the bots (offline, or the host).
static func runs_bots() -> bool:
	return net == null or net.net.is_host()


## A short visual for the others (a grappling line, a charge): only remote avatars draw it.
static func fx(user: Node, what: String, data: Dictionary) -> void:
	if net != null:
		net.ability_fx_out(owner_id(user), what, data)


## A new round: smoke, decoys and barricades go, the map's panels come back.
static func reset_round() -> void:
	for uid in _objects.keys():
		var n = _objects[uid]
		if n == null or not is_instance_valid(n):
			_objects.erase(uid)
			continue
		if n.has_method("restore"):
			n.restore()
		else:
			n.queue_free()
			_objects.erase(uid)


## An explosion or a slam on this machine: blows smoke thin everywhere.
static func blow(at: Vector3, radius: float) -> void:
	if net != null:
		net.blow_out(at, radius)
	else:
		blast(at, radius)


## Explosions and slams blow smoke apart for a moment (here only).
static func blast(at: Vector3, radius: float) -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		PhysicsFx.blast(loop as SceneTree, at, radius)
	for n in _objects.values():
		if is_instance_valid(n) and n is SmokeCloud:
			n.blow(at, radius)


## True when something drawn by abilities (smoke) hides `b` from `a`.
static func sight_blocked(a: Vector3, b: Vector3) -> bool:
	for n in _objects.values():
		if is_instance_valid(n) and n is SmokeCloud and n.blocks(a, b):
			return true
	return false


## The smoke at `p`, 0..1 (1 = deep inside a full cloud), for the screen overlay.
static func smoke_at(p: Vector3) -> float:
	var best := 0.0
	for n in _objects.values():
		if is_instance_valid(n) and n is SmokeCloud:
			best = maxf(best, n.density_at(p))
	return best


static func objects() -> Array:
	var out := []
	for n in _objects.values():
		if n != null and is_instance_valid(n):
			out.append(n)
	return out
