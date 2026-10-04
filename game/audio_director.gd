extends Node

const MUSIC := {
	"title": "res://audio/music/title.ogg",
	"results": "res://audio/music/results.ogg",
	"level1": "res://audio/music/level1.ogg",
	"level2": "res://audio/music/level2.ogg",
	"level3": "res://audio/music/level3.ogg",
	"level4": "res://audio/music/level4.ogg",
	"level5": "res://audio/music/level5.ogg",
}
const SFX := {
	"jump": "res://audio/sfx/jump.wav",
	"land": "res://audio/sfx/land.wav",
	"hit": "res://audio/sfx/hit.wav",
	"heal": "res://audio/sfx/heal.wav",
	"repair_tick": "res://audio/sfx/repair_tick.wav",
	"repair_done": "res://audio/sfx/repair_done.wav",
	"checkpoint": "res://audio/sfx/checkpoint.wav",
	"door_open": "res://audio/sfx/door_open.wav",
	"timer_warning": "res://audio/sfx/timer_warning.wav",
	"fail": "res://audio/sfx/fail.wav",
	"win": "res://audio/sfx/win.wav",
	"pickup": "res://audio/sfx/pickup.wav",
	"deliver": "res://audio/sfx/deliver.wav",
	"diagnose": "res://audio/sfx/diagnose.wav",
	"switch": "res://audio/sfx/switch.wav",
	"spark": "res://audio/sfx/spark.wav",
	"menu_move": "res://audio/sfx/menu_move.wav",
	"menu_select": "res://audio/sfx/menu_select.wav",
}

var unlocked: bool
var pending_music: String = ""
var current_music: String = ""
var _music_players: Array[AudioStreamPlayer] = []
var _active_music: int = 0
var _crossfade: Tween
var _sfx_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	unlocked = not OS.has_feature("web")
	for index: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = &"Music"
		add_child(player)
		_music_players.append(player)
	for index: int in range(8):
		var player := AudioStreamPlayer.new()
		player.name = "SFX%d" % index
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)


func play_music(track: String) -> bool:
	if not MUSIC.has(track):
		return false
	if not unlocked:
		pending_music = track
		return true
	if current_music == track:
		return true
	var stream := load(MUSIC[track]) as AudioStreamOggVorbis
	stream.loop = true
	if _crossfade != null and _crossfade.is_valid():
		_crossfade.kill()
	var outgoing := _music_players[_active_music]
	_active_music = 1 - _active_music
	var incoming := _music_players[_active_music]
	incoming.stop()
	incoming.stream = stream
	incoming.volume_linear = 0.0
	incoming.play()
	_crossfade = create_tween().set_parallel(true)
	_crossfade.tween_property(incoming, "volume_linear", 1.0, 0.5)
	_crossfade.tween_property(outgoing, "volume_linear", 0.0, 0.5)
	_crossfade.chain().tween_callback(outgoing.stop)
	current_music = track
	return true


func play_sfx(sound: String) -> bool:
	if not SFX.has(sound):
		return false
	if not unlocked:
		return true
	var player := _sfx_players[0]
	for candidate: AudioStreamPlayer in _sfx_players:
		if not candidate.playing:
			player = candidate
			break
	player.stop()
	player.stream = load(SFX[sound]) as AudioStream
	player.play()
	# Keep voices in oldest to newest order, including reuse of a free voice.
	_sfx_players.erase(player)
	_sfx_players.append(player)
	return true


func unlock() -> void:
	unlocked = true
	if not pending_music.is_empty():
		var track := pending_music
		pending_music = ""
		play_music(track)


func _input(event: InputEvent) -> void:
	if unlocked or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		unlock()


func set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or not is_finite(linear):
		return
	var volume := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, volume == 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
