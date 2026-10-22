class_name RelayPeer
extends MultiplayerPeerExtension
## Netplay through the relay server (relay/ in this repo): a MultiplayerPeer whose packets
## travel over one WebSocket to the relay, which forwards them between a room's host and
## its clients. Nobody opens a port, so players on different networks just share a
## five-letter room code. The rest of the game can't tell it from ENet.
##
##   host:   create_host(url, info)   -> `hosted` with the room code; unique id 1
##   client: create_client(url, code) -> connected like an ENet client (peer 1 = the host)
##
## Clients only ever talk to the host (SceneMultiplayer's server relay carries
## client-to-client RPCs through it, as it does on ENet). Everything arrives reliable
## and in order (it is TCP underneath).

signal hosted(code: String)
signal relay_error(message: String)

const PING_EVERY := 2.0

var code := ""
var error := ""
## Round trip to the relay, ms (-1 until measured).
var rtt_ms := -1

var _ws := WebSocketPeer.new()
var _hello := {}
var _is_host := false
var _id := 0
var _status := CONNECTION_DISCONNECTED
var _target := 0
var _mode := TRANSFER_MODE_RELIABLE
var _channel := 0
var _refuse := false
var _incoming: Array = []   # [from id, PackedByteArray]
var _peers := {}            # host: client id -> true
var _next_ping := 0


## Opens a room on the relay at `url`. `info` is what the room list shows (name, max, map).
func create_host(url: String, info: Dictionary) -> Error:
	_is_host = true
	_hello = {"op": "host", "game": Matchmaker.GAME_ID, "proto": Matchmaker.PROTOCOL, "name": info.get("name", ""), "info": info}
	return _connect(url)


## Joins the room `room_code` on the relay at `url`.
func create_client(url: String, room_code: String, player_name := "") -> Error:
	_is_host = false
	_hello = {"op": "join", "game": Matchmaker.GAME_ID, "proto": Matchmaker.PROTOCOL, "code": room_code.strip_edges().to_upper(),
		"name": player_name}
	return _connect(url)


## Host: updates what the relay's room list says about this room.
func set_info(info: Dictionary) -> void:
	if _is_host and _status == CONNECTION_CONNECTED:
		_send_json({"op": "info", "info": info})


func _connect(url: String) -> Error:
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	_ws.max_queued_packets = 4096
	var err := _ws.connect_to_url(url)
	if err != OK:
		error = "連不到中繼伺服器"
		return err
	_status = CONNECTION_CONNECTING
	return OK


func _send_json(msg: Dictionary) -> void:
	_ws.send_text(JSON.stringify(msg))


func _control(msg: Dictionary) -> void:
	match str(msg.get("op", "")):
		"hosted":
			code = str(msg.code)
			_id = 1
			_status = CONNECTION_CONNECTED
			hosted.emit(code)
		"joined":
			code = str(msg.code)
			_id = int(msg.id)
			_status = CONNECTION_CONNECTED
			peer_connected.emit(1)
		"peer_joined":
			var id := int(msg.id)
			if _refuse:
				_send_json({"op": "kick", "id": id})
				return
			_peers[id] = true
			peer_connected.emit(id)
		"peer_left":
			var id := int(msg.id)
			if _peers.erase(id):
				peer_disconnected.emit(id)
		"host_left":
			_drop()
		"pong":
			rtt_ms = int(Time.get_ticks_msec() - int(msg.get("t", 0)))
		"error":
			error = _explain(str(msg.get("message", "")))
			relay_error.emit(error)


static func _explain(message: String) -> String:
	match message:
		"no such room":
			return "找不到這間房（房間碼打錯，或房主已經關房）"
		"room full":
			return "房間滿了"
		"different game version":
			return "對方的遊戲版本跟你不一樣"
		"relay full":
			return "中繼伺服器滿了，稍後再試"
		"kicked":
			return "被房主移出房間"
	return "中繼伺服器：%s" % message


## The socket is gone: everyone we knew leaves.
func _drop() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	var was := _status
	_status = CONNECTION_DISCONNECTED
	if _is_host:
		for id in _peers.keys():
			peer_disconnected.emit(id)
		_peers.clear()
	elif was == CONNECTION_CONNECTED:
		peer_disconnected.emit(1)
	_ws.close()


# --- MultiplayerPeerExtension ------------------------------------------------------------

func _poll() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _hello.is_empty():
			_send_json(_hello)
			_hello = {}
		if Time.get_ticks_msec() >= _next_ping:
			_next_ping = Time.get_ticks_msec() + int(PING_EVERY * 1000.0)
			_send_json({"op": "ping", "t": Time.get_ticks_msec()})
	while _ws.get_available_packet_count() > 0:
		var packet := _ws.get_packet()
		if _ws.was_string_packet():
			var msg = JSON.parse_string(packet.get_string_from_utf8())
			if msg is Dictionary:
				_control(msg)
		elif packet.size() >= 4:
			_incoming.append([packet.decode_s32(0), packet.slice(4)])
	if state == WebSocketPeer.STATE_CLOSED:
		if error == "" and _status == CONNECTION_CONNECTING:
			error = "連不到中繼伺服器"
			relay_error.emit(error)
		_drop()


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	return _incoming.pop_front()[1]


func _get_packet_peer() -> int:
	return int(_incoming[0][0]) if not _incoming.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return TRANSFER_MODE_RELIABLE


func _get_packet_channel() -> int:
	return 0


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(4)
	out.encode_s32(0, _target if _is_host else 1)
	out.append_array(buffer)
	return _ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)


func _get_max_packet_size() -> int:
	return 1 << 20


func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _is_host


func _is_server_relay_supported() -> bool:
	return true


func _get_connection_status() -> ConnectionStatus:
	return _status


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _is_host and _peers.erase(peer):
		_send_json({"op": "kick", "id": peer})
		peer_disconnected.emit(peer)


func _close() -> void:
	_ws.close()
	_status = CONNECTION_DISCONNECTED
	_peers.clear()
	_incoming.clear()
