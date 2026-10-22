class_name NetSession
extends Node
## Netplay (C2): one player hosts (ENet, UDP port PORT), up to 9 others join by IP. This
## node ("Net" under Main, the same path on every machine) runs the lobby: who is in,
## which team, the match settings, and the start. The connection and the lobby live in
## static vars, so they survive the scene reload into (and out of) a match.
##
##   host:   net.host()               -> roster has you on team 0
##   join:   net.join("1.2.3.4")      -> the host adds you to the smaller team
##   start:  net.start_match()        -> every machine reloads into the team match
##
## During the match TeamMatch ("Match", a sibling) carries the game traffic.

signal roster_changed()
signal status_changed(text: String)

const PORT := 24680
const MAX_CLIENTS := 9
const TEAM_NAMES := ["藍隊", "紅隊"]

static var active := false
## peer id -> {"name": String, "team": int}
static var roster := {}
static var config := {"team_size": 4, "score": 50, "minutes": 8, "bots": true, "map": "folded"}
## Maps a team match can be played on (id -> name); "random" picks one at the start.
const MAPS := {"folded": "折疊工廠", "dream": "夢核之家", "random": "隨機"}
## The room's code (LAN address) and, once UPnP worked, its internet code.
static var room_code := ""
static var internet_code := ""
static var my_name := ""
static var in_match := false
static var last_status := ""


var matchmaker: Matchmaker


func _ready() -> void:
	name = "Net"
	matchmaker = Matchmaker.new()
	add_child(matchmaker)
	if is_host():
		matchmaker.announce(_room_info)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	if my_name == "":
		my_name = "玩家%02d" % (randi() % 100)


func is_host() -> bool:
	return active and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


func my_team() -> int:
	return int(roster.get(my_id(), {}).get("team", 0))


func host(port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		_status("開房失敗（埠 %d 被占用？）" % port)
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	in_match = false
	roster = {1: {"name": my_name, "team": 0, "ready": true}}
	room_code = Matchmaker.encode(Matchmaker.lan_ip(), port)
	internet_code = ""
	matchmaker.announce(_room_info)
	_status("已開房：房間碼 %s，等別人加入" % room_code)
	roster_changed.emit()
	return OK


func join(address: String, port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_status("無法連線到 %s" % address)
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	in_match = false
	roster = {}
	_status("連線到 %s:%d…" % [address, port])
	return OK


## What the LAN beacon says about this room.
func _room_info() -> Dictionary:
	var port := PORT
	var p := multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer and p.host != null:
		port = p.host.get_local_port()
	return {"name": my_name, "port": port, "players": roster.size(), "max": MAX_CLIENTS + 1, "in_match": in_match,
		"code": room_code, "map": str(config.get("map", "folded"))}


## Joins by room code (see Matchmaker.encode).
func join_code(code: String) -> Error:
	var at := Matchmaker.decode(code)
	if at.is_empty():
		_status("房間碼不對：應該是 10 個字母或數字")
		return ERR_INVALID_PARAMETER
	return join(str(at.ip), int(at.port))


func leave() -> void:
	matchmaker.stop_announcing()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	in_match = false
	roster = {}
	_status("已離開")
	roster_changed.emit()


func _status(text: String) -> void:
	last_status = text
	status_changed.emit(text)


func _on_connected() -> void:
	_status("已連線，等房主開始")
	_hello.rpc_id(1, my_name)


func _on_failed() -> void:
	active = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_status("連線失敗")
	roster_changed.emit()


func _on_server_gone() -> void:
	active = false
	in_match = false
	roster = {}
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_status("房主斷線了")
	roster_changed.emit()
	var main := get_parent()
	if main.has_method("back_to_title"):
		main.back_to_title("房主斷線了")


func _on_peer_connected(_peer: int) -> void:
	pass


func _on_peer_disconnected(peer: int) -> void:
	if roster.has(peer):
		var who: String = roster[peer].name
		roster.erase(peer)
		_status("%s 離開了" % who)
		if is_host():
			_push_roster()
		roster_changed.emit()
	var m := get_parent().get_node_or_null("Match")
	if m != null:
		m.peer_left(peer)


## A newcomer: onto the smaller team (blue on a tie).
@rpc("any_peer", "reliable")
func _hello(player_name: String) -> void:
	if not is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	var counts := [0, 0]
	for p in roster:
		counts[int(roster[p].team)] += 1
	roster[peer] = {"name": player_name.left(16), "team": 0 if counts[0] <= counts[1] else 1, "ready": false}
	_push_roster()
	if in_match:
		# Late joiners wait in the lobby; the next match takes them.
		_status("%s 加入了（下一場上場）" % player_name)


func _push_roster() -> void:
	_roster.rpc(roster, config)
	roster_changed.emit()


@rpc("authority", "reliable")
func _roster(new_roster: Dictionary, new_config: Dictionary) -> void:
	roster = new_roster
	config = new_config
	roster_changed.emit()


## Moves `peer` to the other team (the host can move anyone; a client asks for itself).
func switch_team(peer := 0) -> void:
	if peer == 0:
		peer = my_id()
	if is_host():
		if roster.has(peer):
			roster[peer].team = 1 - int(roster[peer].team)
			_push_roster()
	else:
		_want_switch.rpc_id(1)


@rpc("any_peer", "reliable")
func _want_switch() -> void:
	if is_host():
		switch_team(multiplayer.get_remote_sender_id())


## Ready up (or not) in the lobby.
func set_ready(on: bool) -> void:
	if is_host():
		if roster.has(1):
			roster[1].ready = on
			_push_roster()
	else:
		_want_ready.rpc_id(1, on)


@rpc("any_peer", "reliable")
func _want_ready(on: bool) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if is_host() and roster.has(peer):
		roster[peer].ready = on
		_push_roster()


func all_ready() -> bool:
	for p in roster:
		if not bool(roster[p].get("ready", false)):
			return false
	return true


func set_config(key: String, value: Variant) -> void:
	if not is_host():
		return
	config[key] = value
	_push_roster()


func start_match() -> void:
	if not is_host():
		return
	var cfg := config.duplicate()
	if str(cfg.get("map", "folded")) == "random":
		var ids := MAPS.keys().filter(func(k: String) -> bool: return k != "random")
		cfg.map = ids[randi() % ids.size()]
	_begin.rpc(roster, cfg)


@rpc("authority", "call_local", "reliable")
func _begin(new_roster: Dictionary, new_config: Dictionary) -> void:
	roster = new_roster
	in_match = true
	# The lobby keeps its own choice ("random" stays random for the next match).
	var choice: String = str(config.get("map", "folded"))
	config = new_config.duplicate()
	Main.map_id = str(new_config.get("map", "folded"))
	config.map = choice if is_host() else Main.map_id
	Main.team_mode = true
	Main.skip_title = true
	get_tree().reload_current_scene.call_deferred()


## Back to the lobby on every machine (the host calls it after a match).
func end_match() -> void:
	if is_host():
		_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _to_lobby() -> void:
	in_match = false
	for p in roster:
		roster[p].ready = p == 1
	Main.map_id = "folded"
	Main.team_mode = false
	Main.skip_title = false
	Main.open_lobby = true
	get_tree().reload_current_scene.call_deferred()
