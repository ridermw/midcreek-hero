extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	if not check(ResourceLoader.exists("res://game/audio_director.gd"), "Director exists."):
		finish()
		return
	var director: Node = load("res://game/audio_director.gd").new()
	root.add_child(director)
	if check(director.has_method("play_music"), "Music lookup is available."):
		check(not director.play_music("unknown"), "Unknown music returns false.")
	if check(director.has_method("play_sfx"), "SFX lookup is available."):
		check(not director.play_sfx("unknown"), "Unknown SFX returns false.")
	test_catalog(director)
	test_buses()
	test_unlock(director)
	test_input_unlock(director)
	await test_music_crossfade(director)
	test_sfx_pool(director)
	test_volume(director)
	director.free()
	await create_timer(0.1).timeout
	finish()


func test_catalog(director: Node) -> void:
	var constants: Dictionary = director.get_script().get_script_constant_map()
	var music: Dictionary = constants.get("MUSIC", {})
	var effects: Dictionary = constants.get("SFX", {})
	for track: String in ["title", "results", "level1", "level2", "level3", "level4", "level5"]:
		check(music.has(track), "Music catalog includes " + track)
	for sound: String in [
		"jump", "land", "hit", "heal", "repair_tick", "repair_done", "checkpoint",
		"door_open", "timer_warning", "fail", "win", "pickup", "deliver", "diagnose",
		"switch", "spark", "menu_move", "menu_select",
	]:
		check(effects.has(sound), "SFX catalog includes " + sound)
	for catalog: Dictionary in [music, effects]:
		for path: String in catalog.values():
			check(ResourceLoader.exists(path), "Audio resource exists: " + path)


func test_buses() -> void:
	check(ResourceLoader.exists("res://default_bus_layout.tres"), "Default bus layout exists.")
	for bus: String in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		if check(index >= 0, bus + " bus is loaded automatically."):
			if bus != "Master":
				check(AudioServer.get_bus_send(index) == "Master", bus + " sends to Master.")


func test_unlock(director: Node) -> void:
	if not check(director.get("unlocked") is bool, "Director exposes its unlock state."):
		return
	check(director.unlocked == not OS.has_feature("web"), "Only web starts locked.")
	director.unlocked = false
	check(director.play_music("title"), "Locked music request succeeds.")
	check(director.pending_music == "title", "Locked request is queued.")
	check(director.current_music == "", "Locked request does not start music.")
	check(director.play_music("level1"), "A newer locked request succeeds.")
	check(not director.play_music("unknown"), "Unknown request still fails while locked.")
	check(director.pending_music == "level1", "Only the newest valid request is queued.")
	if not check(director.has_method("unlock"), "Unlock is available."):
		return
	director.unlock()
	check(director.unlocked, "Unlock enables audio.")
	check(director.pending_music == "", "Unlock consumes the pending request.")
	check(director.current_music == "level1", "Unlock starts the pending music.")
	check(not director.play_music("unknown"), "Unknown request fails after unlock.")
	check(director.current_music == "level1", "Unknown request preserves current music.")


func test_input_unlock(director: Node) -> void:
	if not check(director.has_method("_input"), "Director handles input gestures."):
		return
	for event: InputEvent in [
		InputEventKey.new(), InputEventMouseButton.new(), InputEventJoypadButton.new(),
	]:
		director.unlocked = false
		director.play_music("title")
		director._input(event)
		check(not director.unlocked, "Button release does not unlock audio.")
		event.pressed = true
		director._input(event)
		check(director.unlocked, "Button press unlocks audio.")
		check(director.current_music == "title", "Gesture starts the queued music.")
	director.unlocked = false
	director._input(InputEventMouseMotion.new())
	director._input(InputEventJoypadMotion.new())
	var echo := InputEventKey.new()
	echo.pressed = true
	echo.echo = true
	director._input(echo)
	check(not director.unlocked, "Motion and key repeats do not unlock audio.")
	director.unlock()


func players_on(director: Node, bus: String) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child: Node in director.get_children():
		if child is AudioStreamPlayer and child.bus == bus:
			players.append(child)
	return players


func test_music_crossfade(director: Node) -> void:
	var players := players_on(director, "Music")
	if not check(players.size() == 2, "Music uses exactly two players on its bus."):
		return
	director.unlocked = true
	director.play_music("level1")
	await create_timer(0.6).timeout
	var outgoing: AudioStreamPlayer
	for player: AudioStreamPlayer in players:
		if player.playing:
			outgoing = player
	if not check(outgoing != null, "Unlocked music actually plays."):
		return
	check(outgoing.stream is AudioStreamOggVorbis and outgoing.stream.loop, "Music loops.")
	check(is_equal_approx(outgoing.volume_linear, 1.0), "Music reaches full volume.")
	check(director.play_music("results"), "Music can change tracks.")
	var incoming: AudioStreamPlayer = players[1] if players[0] == outgoing else players[0]
	check(incoming.playing and outgoing.playing, "Both players overlap during the crossfade.")
	check(is_zero_approx(incoming.volume_linear), "Incoming track starts silent.")
	await create_timer(0.25).timeout
	check(incoming.volume_linear > 0.2 and incoming.volume_linear < 0.9, "Incoming fades in.")
	check(outgoing.volume_linear > 0.1 and outgoing.volume_linear < 0.8, "Outgoing fades out.")
	await create_timer(0.35).timeout
	check(not outgoing.playing, "Outgoing player stops after the half second fade.")
	check(incoming.playing and is_equal_approx(incoming.volume_linear, 1.0), "Incoming settles.")
	check(incoming.stream.loop, "Replacement music loops too.")
	var position := incoming.get_playback_position()
	check(director.play_music("results"), "Repeated music requests succeed.")
	check(incoming.get_playback_position() >= position, "Same track does not restart.")
	director.play_music("level2")
	await create_timer(0.1).timeout
	director.play_music("level3")
	director.play_music("level5")
	await create_timer(0.6).timeout
	var playing := 0
	for player: AudioStreamPlayer in players:
		if player.playing:
			playing += 1
			check(player.stream.resource_path == "res://audio/music/level5.ogg",
				"Rapid requests settle on the latest track.")
	check(playing == 1, "Interrupted fades do not leave a second track playing.")
	check(players_on(director, "Music").size() == 2, "Crossfades reuse both music players.")


func test_sfx_pool(director: Node) -> void:
	var players := players_on(director, "SFX")
	if not check(players.size() == 8, "SFX preallocates eight players on its bus."):
		return
	director.unlocked = false
	check(director.play_sfx("jump"), "Locked SFX recognizes a valid name.")
	for player: AudioStreamPlayer in players:
		check(not player.playing, "Locked SFX does not start audio.")
	director.unlock()
	for index: int in range(8):
		check(director.play_sfx("heal"), "A free SFX voice starts.")
		check(players[index].playing, "Concurrent effects use separate voices.")
	check(director.play_sfx("hit"), "A saturated pool still accepts an effect.")
	check(players[0].stream.resource_path == "res://audio/sfx/hit.wav",
		"A full pool reuses its oldest voice.")
	director.play_sfx("jump")
	check(players[1].stream.resource_path == "res://audio/sfx/jump.wav",
		"The next reuse chooses the next oldest voice.")
	players[5].stop()
	director.play_sfx("land")
	check(players[5].stream.resource_path == "res://audio/sfx/land.wav",
		"A free voice is preferred to interrupting a busy one.")
	for index: int in range(40):
		check(director.play_sfx("repair_tick"), "Repeated repair SFX succeeds.")
	check(players_on(director, "SFX").size() == 8, "SFX pool never exceeds eight players.")
	check(not director.play_sfx("unknown"), "Invalid SFX remains a quiet false.")


func test_volume(director: Node) -> void:
	if not check(director.has_method("set_bus_volume"), "Bus volume control exists."):
		return
	var music := AudioServer.get_bus_index("Music")
	var effects := AudioServer.get_bus_index("SFX")
	director.set_bus_volume("Music", 0.5)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music)), 0.5),
		"Linear volume is converted correctly.")
	check(is_zero_approx(AudioServer.get_bus_volume_db(effects)), "Music volume leaves SFX alone.")
	director.set_bus_volume("Music", 0.0)
	check(AudioServer.is_bus_mute(music) or AudioServer.get_bus_volume_db(music) <= -80.0,
		"Zero volume silences the bus.")
	director.set_bus_volume("Music", -2.0)
	check(AudioServer.is_bus_mute(music) or AudioServer.get_bus_volume_db(music) <= -80.0,
		"Negative volume safely clamps to silence.")
	director.set_bus_volume("Music", 2.0)
	check(not AudioServer.is_bus_mute(music), "Raising volume unmutes the bus.")
	check(is_zero_approx(AudioServer.get_bus_volume_db(music)), "Volume is capped at unity.")
	director.set_bus_volume("Music", NAN)
	director.set_bus_volume("Music", INF)
	director.set_bus_volume("missing_bus", 0.2)
	check(is_zero_approx(AudioServer.get_bus_volume_db(music)), "Invalid controls preserve volume.")


func finish() -> void:
	print("AUDIO_DIRECTOR_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)
	return condition
