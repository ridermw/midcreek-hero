extends SceneTree

const World = preload("res://game/world.gd")
const Hero = preload("res://game/hero.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const FaultRack = preload("res://game/fault_rack.gd")
const WORLD_SCENE := preload("res://game/world.tscn")
const ACTION_KEYS: Array[Key] = [KEY_E, KEY_Q, KEY_R, KEY_F]
const ACTION_CLIPS: Array[StringName] = [&"primary", &"secondary", &"reaction", &"signal"]
const EXPECTED_VARIANTS: Array[StringName] = [&"man-midcreek", &"woman-midcreek"]
const EXPECTED_COUNTS: Array[int] = [6, 8, 8, 6, 8, 4, 6]

var checks: int = 0
var failures: int = 0
var inspection_requests: int = 0
var world: World
var viewport: SubViewport


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = WORLD_SCENE.instantiate() as World
	viewport.add_child(world)
	await physics_steps(3)
	check(world.assets_ready, "Authored animation and environment assets load.")
	if not world.assets_ready:
		check(not world.error_message.is_empty(), "Missing assets have an explicit error.")
		check(world.error_label.visible, "The asset failure is visible; no static fallback.")
		_finish()
		return
	_test_initial_world()
	await _test_animation_contract()
	await _test_movement()
	await _test_switches()
	await _test_actions()
	await _test_repair()
	await _test_camera()
	await _test_inspection_and_focus()
	_test_hud()
	world.queue_free()
	await process_frame
	viewport.queue_free()
	_finish()


func _test_initial_world() -> void:
	check(world.heroes.size() == 2, "Both crew members exist.")
	check(world.hero_active() == world.heroes[0], "The man is initially active.")
	check(is_equal_approx(world.heroes[0].position.x, 160.0), "Man starts at x=160.")
	check(is_equal_approx(world.heroes[1].position.x, 250.0), "Woman starts at x=250.")
	for hero: Hero in world.heroes:
		check(hero.is_visible_in_tree(), "Both heroes are visible.")
		check(hero.scale == Vector2.ONE, "Both heroes use the same standard pixel scale.")
		check(hero.sprite.scale == Vector2.ONE, "Authored frames are not resized.")
		check(hero.sprite.position == Vector2(0, -80), "Sprite uses the contracted foot pivot.")
		check(hero.is_on_floor(), "Real CharacterBody2D rests on the collision floor.")
		check(absf(hero.position.y - World.FLOOR_Y) < 0.2, "Feet rest at y=320.")
		check(hero.sprite.animation == &"idle", "Both heroes start in animated idle.")
		check(hero.sprite.is_playing(), "Idle animation actually plays.")
	check(not world.heroes[1].active, "The inactive hero is not controllable.")
	check(world.environment.get_child_count() == 3, "Three required art layers are loaded.")
	for layer: Node in world.environment.get_children():
		check(layer.get_child_count() == 4, "Environment art repeats over four screens.")
	check(world.rack.status_color == FaultRack.FAULT_COLOR, "Rack starts red.")
	check(world.rack.status_label.text.contains("FAULT"), "Rack fault is visibly labelled.")
	check(not world.rack.repaired, "Rack starts faulted.")


func _test_animation_contract() -> void:
	var seen_paths: Dictionary[String, bool] = {}
	var probes: Array[AnimatedSprite2D] = []
	var longest_frame: float = 0.0
	check(world.library.variants.size() == 2, "Only the two normal hero variants load.")
	check(
		HeroAnimations.VARIANTS == EXPECTED_VARIANTS, "Runtime declares only the two normal heroes."
	)
	for variant: StringName in EXPECTED_VARIANTS:
		var frames: SpriteFrames = world.library.variants[variant]
		check(frames.get_animation_names().size() == 7, "%s has seven clips." % variant)
		for index: int in range(HeroAnimations.CLIPS.size()):
			var clip: StringName = HeroAnimations.CLIPS[index]
			var context := "%s/%s" % [variant, clip]
			check(frames.has_animation(clip), context + " exists.")
			check(
				frames.get_frame_count(clip) == EXPECTED_COUNTS[index],
				context + " has authored count."
			)
			check(frames.get_animation_loop(clip) == (index < 3), context + " has correct looping.")
			check(frames.get_animation_speed(clip) > 0.0, context + " has positive fps.")
			longest_frame = maxf(longest_frame, 1.0 / frames.get_animation_speed(clip))
			for frame: int in range(frames.get_frame_count(clip)):
				var texture := frames.get_frame_texture(clip, frame)
				check(texture != null, context + " texture exists.")
				if texture == null:
					continue
				check(texture.get_size() == Vector2(208, 208), context + " cell is 208x208.")
				check(not texture.resource_path.is_empty(), context + " loads a real resource.")
				check(not seen_paths.has(texture.resource_path), context + " path is unique.")
				seen_paths[texture.resource_path] = true
			var probe := AnimatedSprite2D.new()
			probe.sprite_frames = frames
			probe.name = String(variant) + "_" + String(clip)
			probe.visible = false
			probe.set_meta("advanced", false)
			probe.frame_changed.connect(_record_advance.bind(probe))
			viewport.add_child(probe)
			probe.play(clip)
			probes.append(probe)
	await create_timer(minf(longest_frame * 1.6, 3.0)).timeout
	check(probes.size() == 14, "Both normal heroes provide seven authored clips each.")
	for probe: AnimatedSprite2D in probes:
		check(bool(probe.get_meta("advanced")), "%s advances a real frame over time." % probe.name)
		probe.queue_free()
	check(seen_paths.size() == 92, "All 92 authored frame paths are distinct.")


func _test_movement() -> void:
	var hero := world.hero_active()
	var inactive_x := world.heroes[1].position.x
	var start_x := hero.position.x
	press(KEY_D)
	await physics_steps(15)
	var walk_distance := hero.position.x - start_x
	var expected_walk := Hero.WALK_SPEED * 15.0 / float(Engine.physics_ticks_per_second)
	check(absf(walk_distance - expected_walk) < 2.5, "D walks at approximately 60 px/s.")
	check(hero.sprite.animation == &"walk", "Walking selects the authored walk clip.")
	check(not hero.sprite.flip_h, "Walking right faces right.")
	check(world.heroes[1].position.x == inactive_x, "Inactive hero never follows movement input.")
	press(KEY_SHIFT)
	start_x = hero.position.x
	await physics_steps(15)
	var run_distance := hero.position.x - start_x
	var expected_run := Hero.RUN_SPEED * 15.0 / float(Engine.physics_ticks_per_second)
	check(absf(run_distance - expected_run) < 3.0, "Shift runs at approximately 110 px/s.")
	check(run_distance > walk_distance * 1.5, "Run input moves faster than walk.")
	check(hero.sprite.animation == &"run", "Running selects the authored run clip.")
	check(
		hero.sprite.global_position.is_equal_approx(hero.sprite.global_position.round()),
		"Moving sprite stays on integer pixels without quantizing physical speed.",
	)
	press(KEY_SHIFT, false)
	await physics_steps(2)
	check(hero.sprite.animation == &"walk", "Releasing Shift returns to walking.")
	press(KEY_D, false)
	await physics_steps(2)
	start_x = hero.position.x
	await physics_steps(5)
	check(hero.position.x == start_x, "Key release stops horizontal movement.")
	check(hero.sprite.animation == &"idle", "Key release returns to animated idle.")
	press(KEY_LEFT)
	await physics_steps(5)
	check(hero.position.x < start_x and hero.sprite.flip_h, "Left arrow walks and faces left.")
	press(KEY_LEFT, false)
	start_x = hero.position.x
	press(KEY_RIGHT)
	await physics_steps(5)
	check(hero.position.x > start_x, "Right arrow walks right.")
	press(KEY_RIGHT, false)
	start_x = hero.position.x
	press(KEY_A)
	await physics_steps(5)
	check(hero.position.x < start_x, "A walks left.")
	press(KEY_A, false)
	press(KEY_D)
	press(KEY_RIGHT)
	press(KEY_D, false)
	await physics_steps(2)
	check(hero.velocity.x > 0.0, "Releasing one right key keeps the other held key active.")
	press(KEY_RIGHT, false)
	press(KEY_A)
	press(KEY_D)
	await physics_steps(2)
	check(hero.velocity.x == 0.0, "Opposing directions cancel.")
	world.release_controls()
	hero.position.x = Hero.MIN_X + 1.0
	press(KEY_A)
	await physics_steps(8)
	check(hero.position.x >= Hero.MIN_X, "Left world boundary clamps the body.")
	check(hero.position.x <= Hero.MIN_X + 0.2, "Left boundary is reachable.")
	press(KEY_A, false)
	hero.position.x = Hero.MAX_X - 1.0
	press(KEY_D)
	await physics_steps(8)
	check(hero.position.x <= Hero.MAX_X, "Right world boundary clamps the body.")
	check(hero.position.x >= Hero.MAX_X - 0.2, "Right boundary is reachable.")
	world.release_controls()
	hero.position.x = 160.0
	await physics_steps(2)


func _test_switches() -> void:
	var old_hero := world.hero_active()
	press(KEY_D)
	await physics_steps(3)
	tap(KEY_TAB)
	var new_hero := world.hero_active()
	var old_x := old_hero.position.x
	check(new_hero != old_hero and new_hero.character == "woman", "Tab changes active hero.")
	check(not old_hero.active and new_hero.active, "Exactly the selected hero is active.")
	check(not old_hero.marker.visible and new_hero.marker.visible, "Marker follows selection.")
	await physics_steps(5)
	check(old_hero.position.x == old_x, "Switching cancels held movement on the old hero.")
	check(old_hero.sprite.animation == &"idle", "Inactive hero idles after switching.")
	check(new_hero.sprite.animation == &"idle", "Held motion is not inherited by the new hero.")
	press(KEY_TAB, true, true)
	check(world.hero_active() == new_hero, "Repeated Tab does not switch twice.")
	old_hero.start_action(&"signal")
	check(old_hero.action.is_empty(), "Inactive hero cannot start an action.")
	check(new_hero.variant_name() == &"woman-midcreek", "Selected woman uses her normal variant.")
	check(
		new_hero.sprite.sprite_frames == world.library.variants[&"woman-midcreek"],
		"Selected woman uses her authored animation resource.",
	)
	tap(KEY_F)
	check(new_hero.action == &"signal", "Signal starts before the hero-switch check.")
	tap(KEY_TAB)
	check(new_hero.action.is_empty(), "Hero switch clears an unfinished action.")
	check(new_hero.sprite.animation == &"idle", "Switched-away hero is immediately idle.")


func _test_actions() -> void:
	for character_index: int in range(2):
		if world.active_index != character_index:
			tap(KEY_TAB)
		var hero := world.hero_active()
		hero.position.x = 160.0 + float(character_index) * 90.0
		for index: int in range(ACTION_KEYS.size()):
			var clip: StringName = ACTION_CLIPS[index]
			var context := "%s/%s" % [hero.variant_name(), clip]
			tap(ACTION_KEYS[index])
			check(hero.action == clip, context + " starts through its keyboard binding.")
			check(hero.sprite.animation == clip, context + " plays the authored clip.")
			check(not hero.sustained_primary, context + " is one-shot outside repair range.")
			await create_timer(hero.clip_duration(clip) + 0.3).timeout
			check(hero.action.is_empty(), context + " completes without sticking.")
			check(hero.sprite.animation == &"idle", context + " returns to idle.")
			check(hero.sprite.is_playing(), context + " resumes animated idle.")
			check(not world.rack.repaired, "Remote tool actions never repair the rack.")
	_test_hud()


func _test_repair() -> void:
	var hero := world.hero_active()
	hero.position.x = world.rack.position.x - FaultRack.INTERACTION_RANGE - 24.0
	await physics_steps(2)
	tap(KEY_Q)
	check(world.feedback.contains("No rack in reach"), "Remote diagnostic reports no local target.")
	tap(KEY_E)
	await physics_steps(5)
	check(world.repairing_hero == null, "Primary outside range cannot start repair.")
	check(
		not world.rack.repaired and world.rack.progress == 0.0, "Distance gate keeps rack faulted."
	)
	hero.position.x = world.rack.position.x - 45.0
	await physics_steps(2)
	check(world.rack.highlighted, "Nearby rack is visibly highlighted.")
	tap(KEY_Q)
	check(
		world.feedback.contains("loose service coupling"), "Local diagnostic identifies the fault."
	)
	check(world.feedback.contains("E:"), "Diagnostic gives a meaningful next action.")
	tap(KEY_E)
	await physics_steps(12)
	check(world.repairing_hero == hero, "Primary near the rack starts repair.")
	check(world.rack.progress > 0.0 and world.rack.progress < 1.0, "Repair visibly progresses.")
	check(not world.rack.repaired, "Repair is not an instantaneous status change.")
	tap(KEY_TAB)
	check(world.repairing_hero == null and world.rack.progress == 0.0, "Tab cancels repair safely.")
	check(hero.sprite.animation == &"idle", "Cancelled repair leaves the old hero idle.")
	check(
		hero.action.is_empty() and not hero.sustained_primary, "Hero switch clears repair action."
	)
	tap(KEY_TAB)
	tap(KEY_E)
	await physics_steps(6)
	press(KEY_A)
	await physics_steps(3)
	check(world.repairing_hero == null and world.rack.progress == 0.0, "Movement cancels repair.")
	press(KEY_A, false)
	tap(KEY_E)
	await physics_steps(6)
	hero.position.x = world.rack.position.x - FaultRack.INTERACTION_RANGE - 10.0
	await physics_steps(2)
	check(world.repairing_hero == null, "Repair also enforces distance during interaction.")
	await create_timer(FaultRack.REPAIR_SECONDS + 0.15).timeout
	check(not world.rack.repaired, "Cancelled repairs have no delayed completion callback.")
	hero.position.x = world.rack.position.x - 45.0
	await physics_steps(2)
	tap(KEY_E)
	var hold_time := minf(hero.clip_duration(&"primary") + 0.15, 1.7)
	await create_timer(hold_time).timeout
	check(hero.action == &"primary" and hero.sustained_primary, "Normal repair sustains primary.")
	check(hero.sprite.is_playing(), "Sustained repair keeps authored animation playing.")
	check(not world.rack.repaired, "Rack stays red before the two-second repair finishes.")
	check(world.feedback_label.text.contains("%"), "HUD displays computed repair progress.")
	await create_timer(FaultRack.REPAIR_SECONDS - hold_time + 0.2).timeout
	check(world.rack.repaired, "Two seconds of uninterrupted local repair fixes the rack.")
	check(world.rack.progress == 1.0, "Successful repair leaves a full progress marker.")
	check(world.rack.status_color == FaultRack.ONLINE_COLOR, "Repair changes red status to green.")
	check(
		world.rack.status_label.text.contains("ONLINE"), "Rack visibly labels the repaired state."
	)
	check(world.rack.status_label.is_visible_in_tree(), "Repaired rack label remains visible.")
	check(world.feedback.contains("GREEN"), "Repair completion has clear HUD feedback.")
	check(
		world.repairing_hero == null and hero.action.is_empty(),
		"Repair completion releases action."
	)
	check(hero.sprite.animation == &"idle", "Completed repair returns the hero to idle.")
	check(
		not hero.sprite.sprite_frames.get_animation_loop(&"primary"),
		"Repair never mutates the shared one-shot primary clip.",
	)
	tap(KEY_Q)
	check(
		world.feedback.contains("coupling secure"), "Diagnostics reflect the repaired local state."
	)
	tap(KEY_E)
	check(world.repairing_hero == null, "Primary does not restart an already completed repair.")
	check(
		world.rack.repaired and world.rack.progress == 1.0,
		"Repeated action preserves green status."
	)
	world.release_controls()


func _test_camera() -> void:
	var hero := world.hero_active()
	for x: float in [Hero.MIN_X, 1000.25, Hero.MAX_X]:
		hero.position.x = x
		await physics_steps(2)
		world.update_camera()
		var center := world.camera.get_screen_center_position()
		check(center.x >= 320.0 and center.x <= 2240.0, "Camera stays horizontally in world.")
		check(is_equal_approx(center.y, 180.0), "Camera never exposes above or below the hall.")
		check(world.camera.position == world.camera.position.round(), "Camera uses integer pixels.")
		check(
			world.environment.far_layer.position == world.environment.far_layer.position.round(),
			"Far parallax stays on integer pixels.",
		)
	check(world.camera.position.x == 2240.0, "Camera reaches but does not exceed the far boundary.")
	hero.position.x = 1000.0
	world.update_camera()
	var camera_x := world.camera.position.x
	hero.position.x = camera_x + World.CAMERA_DEADZONE - 4.0
	world.update_camera()
	check(world.camera.position.x == camera_x, "Small movements inside the deadzone do not scroll.")
	hero.position.x = camera_x + World.CAMERA_DEADZONE + 12.0
	world.update_camera()
	check(world.camera.position.x == camera_x + 12.0, "Camera follows beyond the deadzone.")
	hero.position.x = Hero.MIN_X
	world.update_camera()
	check(world.camera.position.x == 320.0, "Camera reaches but does not exceed the near boundary.")
	check(
		world.camera.limit_left == 0 and world.camera.limit_right == 2560,
		"Camera limits match width."
	)
	check(
		world.camera.limit_top == 0 and world.camera.limit_bottom == 360,
		"Camera limits match height."
	)


func _test_inspection_and_focus() -> void:
	var hero := world.hero_active()
	hero.position.x = 400.0
	press(KEY_D)
	press(KEY_SHIFT)
	await physics_steps(3)
	world.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await physics_steps(2)
	var stopped_x := hero.position.x
	await physics_steps(5)
	check(hero.position.x == stopped_x, "Focus loss releases held motion without requiring keyup.")
	check(hero.sprite.animation == &"idle", "Focus loss restores animated idle.")
	check(
		hero.motion_direction == 0.0 and not hero.running, "Focus loss clears all movement flags."
	)
	world.inspection_requested.connect(_inspection_requested)
	press(KEY_D)
	tap(KEY_F1)
	check(inspection_requests == 1, "F1 emits the parent inspection routing signal exactly once.")
	check(hero.motion_direction == 0.0, "Entering inspection releases motion.")
	world.set_inspection_active(true)
	check(not world.visible and not world.hud.visible, "Inspection can hide both world and HUD.")
	check(not world.camera.enabled, "Inspection releases the world camera.")
	check(world.process_mode == Node.PROCESS_MODE_DISABLED, "Inspection suspends the simulation.")
	await create_timer(0.1).timeout
	world.set_inspection_active(false)
	check(
		world.visible and world.hud.visible and world.camera.enabled, "Return restores the world."
	)
	check(world.rack.repaired, "Inspection return preserves rack state.")
	check(World.INSPECTION_RETURN_HINT.contains("F1"), "Parent has an explicit return hint.")
	press(KEY_D)
	await physics_steps(3)
	check(hero.position.x > stopped_x, "Movement works again after inspection return.")
	press(KEY_D, false)
	await physics_steps(2)


func _test_hud() -> void:
	for label: Label in [
		world.status_label,
		world.feedback_label,
		world.get_node("HUD/Bottom/Controls"),
	]:
		check(label.get_minimum_size().x <= 620.0, "%s fits the native HUD width." % label.name)
		check(
			label.position == label.position.round(), "%s is placed on crisp pixels." % label.name
		)
	check(not world.error_label.visible, "Successful loading does not leave an error overlay.")


func _record_advance(probe: AnimatedSprite2D) -> void:
	if probe.frame > 0:
		probe.set_meta("advanced", true)


func _inspection_requested() -> void:
	inspection_requests += 1


func physics_steps(count: int) -> void:
	for index: int in range(count):
		await physics_frame
	await process_frame


func tap(key: Key) -> void:
	press(key)
	press(key, false)


func press(key: Key, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	world._unhandled_key_input(event)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _finish() -> void:
	print("WORLD_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
