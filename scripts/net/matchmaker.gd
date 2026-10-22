class_name Matchmaker
extends Node
## Finding a game without typing IPs:
##
##   room codes   a host's address and port packed into ten letters ("K7Q2M-9XAB4"), so
##                friends share a code instead of an IP. decode() turns it back.
##   LAN beacon   a host announces its room on UDP BEACON_PORT once a second (broadcast and
##                to this machine); listen() collects the rooms it hears in `rooms`.
##   quick match  search for SEARCH seconds, join the best open room, else open one and
##                wait (others' quick match finds you).
##   relay        (C4) rooms on the relay server (relay/, RelayPeer): five-letter codes that
##                work from any network, and a list of open rooms for quick match.
##   internet     open_internet() asks the router (UPnP) to forward the game port and
##                returns the public code: the fallback when there's no relay.
##
## LAN play is peer to peer; the relay only forwards packets.

signal rooms_changed()
signal internet_done(ok: bool, code: String, message: String)
signal relay_listed(ok: bool)

const BEACON_PORT := 24681
const GAME_ID := "HAIKAI_CHAOS"
const PROTOCOL := 3
## The relay this build uses unless the settings name another (see relay/README.md).
const DEFAULT_RELAY := ""
const SEARCH := 2.5
const FORGET := 3.5
## Crockford base32: no I, L, O, U, so codes survive being read aloud or retyped.
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

## "ip:port" -> {name, ip, port, players, max, in_match, code, map, seen}
var rooms := {}
var _listen: PacketPeerUDP
var _send: PacketPeerUDP
var _beacon_t := 0.0
var _announce: Callable
var _upnp_thread: Thread
## The relay's open rooms from the last list(): code -> {code, name, players, max, map, in_match}
var relay_rooms := {}
var _list_ws: WebSocketPeer
var _list_until := 0


func _init() -> void:
	name = "Matchmaker"


# --- Room codes ------------------------------------------------------------------------

## IPv4 + port -> "XXXXX-XXXXX" (48 bits in 10 base-32 digits).
static func encode(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var value := 0
	for p in parts:
		value = (value << 8) | (int(p) & 0xFF)
	value = (value << 16) | (port & 0xFFFF)
	var digits := ""
	for i in 10:
		digits = ALPHABET[value & 31] + digits
		value >>= 5
	return digits.substr(0, 5) + "-" + digits.substr(5)


## "XXXXX-XXXXX" -> {"ip": ..., "port": ...}, or {} if it isn't a code.
static func decode(code: String) -> Dictionary:
	var clean := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	clean = clean.replace("O", "0").replace("I", "1").replace("L", "1")
	if clean.length() != 10:
		return {}
	var value := 0
	for c in clean:
		var d := ALPHABET.find(c)
		if d < 0:
			return {}
		value = (value << 5) | d
	var port := value & 0xFFFF
	value >>= 16
	var ip := "%d.%d.%d.%d" % [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]
	if port == 0:
		return {}
	return {"ip": ip, "port": port}


## This machine's LAN address (private range first), else loopback.
static func lan_ip() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or _is_172_private(a):
			return a
		if best == "":
			best = a
	return best if best != "" else "127.0.0.1"


static func _is_172_private(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var second := int(a.split(".")[1])
	return second >= 16 and second <= 31


# --- Relay -------------------------------------------------------------------------

## The relay server to use: the settings, a --relay=URL launch argument, or the default.
static func relay_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--relay="):
			return a.substr(8)
	if Settings.relay_url.strip_edges() != "":
		return Settings.relay_url.strip_edges()
	return DEFAULT_RELAY


static func has_relay() -> bool:
	return relay_url() != ""


## Asks the relay for its open rooms; relay_listed(ok) when the answer (or a timeout) comes.
func list_relay() -> void:
	if not has_relay() or _list_ws != null:
		return
	_list_ws = WebSocketPeer.new()
	if _list_ws.connect_to_url(relay_url()) != OK:
		_list_ws = null
		relay_listed.emit(false)
		return
	_list_until = Time.get_ticks_msec() + 4000


func _poll_list() -> void:
	_list_ws.poll()
	var state := _list_ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and _list_until > 0:
		_list_ws.send_text(JSON.stringify({"op": "list", "game": GAME_ID, "proto": PROTOCOL}))
		_list_until = -(Time.get_ticks_msec() + 4000)
	while _list_ws.get_available_packet_count() > 0:
		var msg = JSON.parse_string(_list_ws.get_packet().get_string_from_utf8())
		if msg is Dictionary and msg.get("op") == "rooms":
			relay_rooms.clear()
			for r in msg.get("rooms", []):
				r.relay = true
				relay_rooms[str(r.code)] = r
			_list_ws.close()
			_list_ws = null
			relay_listed.emit(true)
			rooms_changed.emit()
			return
	if state == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() > absi(_list_until):
		_list_ws.close()
		_list_ws = null
		relay_listed.emit(false)


# --- LAN beacon ------------------------------------------------------------------------

## Starts announcing: `info` is called each second for the room's details.
func announce(info: Callable) -> void:
	_announce = info
	if _send == null:
		_send = PacketPeerUDP.new()
		_send.set_broadcast_enabled(true)
	_beacon_t = 0.0


func stop_announcing() -> void:
	_announce = Callable()


## Starts listening for rooms (false if the beacon port is taken on this machine).
func listen() -> bool:
	if _listen != null:
		return true
	_listen = PacketPeerUDP.new()
	if _listen.bind(BEACON_PORT, "*") != OK:
		_listen = null
		return false
	rooms.clear()
	return true


func stop_listening() -> void:
	if _listen != null:
		_listen.close()
		_listen = null


func _process(delta: float) -> void:
	if _list_ws != null:
		_poll_list()
	if _announce.is_valid():
		_beacon_t -= delta
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			var info: Dictionary = _announce.call()
			info.game = GAME_ID
			info.v = PROTOCOL
			var packet := JSON.stringify(info).to_utf8_buffer()
			for target in ["255.255.255.255", "127.0.0.1"]:
				_send.set_dest_address(target, BEACON_PORT)
				_send.put_packet(packet)
	if _listen != null:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var data := _listen.get_packet()
			var from := _listen.get_packet_ip()
			var info = JSON.parse_string(data.get_string_from_utf8())
			if not (info is Dictionary) or info.get("game") != GAME_ID or int(info.get("v", 0)) != PROTOCOL:
				continue
			if from.begins_with("127.") and lan_ip() != "127.0.0.1":
				from = "127.0.0.1"
			info.ip = from
			info.seen = Time.get_ticks_msec() / 1000.0
			var key := "%s:%d" % [from, int(info.get("port", 0))]
			changed = changed or not rooms.has(key)
			rooms[key] = info
		var now := Time.get_ticks_msec() / 1000.0
		for key in rooms.keys():
			if now - float(rooms[key].seen) > FORGET:
				rooms.erase(key)
				changed = true
		if changed:
			rooms_changed.emit()


## The open room quick match should join: not full, not mid-match first, most players;
## a LAN room beats a relay room (lower ping).
func best_room() -> Dictionary:
	var best := {}
	var best_score := -1.0
	for r in rooms.values() + relay_rooms.values():
		if int(r.get("players", 0)) >= int(r.get("max", 10)):
			continue
		var score := float(r.get("players", 0)) + (0.0 if r.get("in_match", false) else 100.0) + (0.0 if r.get("relay", false) else 50.0)
		if score > best_score:
			best_score = score
			best = r
	return best


# --- Internet (UPnP) -------------------------------------------------------------------

## Asks the router to forward `port` (UDP) here, in a thread; emits internet_done with the
## public code, or a message saying why not.
func open_internet(port: int) -> void:
	if _upnp_thread != null and _upnp_thread.is_alive():
		return
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(port: int) -> void:
	var upnp := UPNP.new()
	var err := upnp.discover(2000, 2)
	if err != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		internet_done.emit.call_deferred(false, "", "找不到支援 UPnP 的路由器：請在路由器上手動轉送 UDP %d，或用區網／虛擬區網" % port)
		return
	var result := upnp.add_port_mapping(port, port, "HAIKAI CHAOS", "UDP")
	var ip := upnp.query_external_address()
	if result != UPNP.UPNP_RESULT_SUCCESS or ip == "":
		internet_done.emit.call_deferred(false, "", "路由器拒絕開放埠 %d（UPnP 錯誤 %d）" % [port, result])
		return
	internet_done.emit.call_deferred(true, encode(ip, port), "已開放網路連線：外部位址 %s" % ip)


func _exit_tree() -> void:
	stop_listening()
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
