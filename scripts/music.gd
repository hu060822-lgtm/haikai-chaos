class_name Music
## The soundtrack (audio/music/, composed by tools/music/compose.py): "lobby" under the
## menus, "match" in a fight, "results" on the score screen. One player hangs off the root
## so a track carries on across scene reloads; changing track crossfades. Also owns the
## Music and SFX audio buses and their volumes (Settings.music_vol / sfx_vol).

const TRACKS := {
	"lobby": "res://audio/music/lobby.ogg",
	"match": "res://audio/music/match.ogg",
	"results": "res://audio/music/results.ogg",
}
const FADE := 1.2
const LEVEL_DB := {"lobby": -9.0, "match": -11.0, "results": -8.0}

static var current := ""
static var _player: AudioStreamPlayer
static var _old: AudioStreamPlayer


## Makes the Music and SFX buses (once) and applies the volume settings.
static func setup_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	apply_volumes()


static func apply_volumes() -> void:
	for spec in [["Music", Settings.music_vol], ["SFX", Settings.sfx_vol]]:
		var i := AudioServer.get_bus_index(spec[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(spec[1]), 0.0001)))
			AudioServer.set_bus_mute(i, float(spec[1]) <= 0.001)


## Plays `track` (crossfading from whatever is on); "" fades to silence.
static func play(tree: SceneTree, track: String) -> void:
	if track == current:
		return
	current = track
	setup_buses()
	if _old != null and is_instance_valid(_old):
		_old.queue_free()
	_old = _player if _player != null and is_instance_valid(_player) else null
	if _old != null:
		var out := _old.create_tween()
		out.tween_property(_old, "volume_db", -60.0, FADE)
		out.tween_callback(_old.queue_free)
	_player = null
	if track == "" or not TRACKS.has(track) or not ResourceLoader.exists(TRACKS[track]):
		return
	var stream: AudioStream = load(TRACKS[track])
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = "Music"
	_player.volume_db = -60.0
	tree.root.add_child.call_deferred(_player)
	_player.ready.connect(func() -> void:
		_player.play()
		_player.create_tween().tween_property(_player, "volume_db", float(LEVEL_DB.get(track, -10.0)), FADE))
