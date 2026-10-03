extends Node2D

signal inspection_requested

const HeroAnimations = preload("res://game/animation_library.gd")
const Hero = preload("res://game/hero.gd")
const EnvironmentArt = preload("res://game/environment.gd")
const FaultRack = preload("res://game/fault_rack.gd")
const WORLD_WIDTH := 2560.0
const FLOOR_Y := 320.0
const VIEW_SIZE := Vector2(640, 360)
const CAMERA_DEADZONE := 40.0
const INSPECTION_RETURN_HINT := "F1: return to data hall"
const MOTION_KEYS: Array[Key] = [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_SHIFT]

var library := HeroAnimations.new()
var assets_ready: bool = false
var error_message: String = ""
var active_index: int = 0
var repair_elapsed: float = 0.0
var repairing_hero: Hero
var feedback: String = ""
var _feedback_remaining: float = 0.0
var _held_keys: Dictionary[int, bool] = {}

@onready var heroes: Array[Hero] = [$Heroes/Man, $Heroes/Woman]
@onready var environment: EnvironmentArt = $Environment
@onready var rack: FaultRack = $FaultRack
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var status_label: Label = $HUD/Top/Status
@onready var feedback_label: Label = $HUD/Top/Feedback
@onready var error_label: Label = $HUD/Error


func _ready() -> void:
	var animations_loaded := library.load_manifest()
	var environment_loaded := environment.load_art()
	if not animations_loaded or not environment_loaded:
		error_message = "\n".join([library.error_message, environment.error_message]).strip_edges()
		error_label.text = error_message + "\n\nAuthored artwork is required; no fallback is used."
		error_label.show()
		$Heroes.hide()
		rack.hide()
		status_label.text = "MIDCREEK / ARTWORK NOT READY"
		feedback_label.text = "Check the manifest and imported textures, then reload."
		return
	for hero: Hero in heroes:
		hero.configure(library)
	hero_active().set_active(true)
	assets_ready = true
	_set_feedback("R12 has a loose service coupling. Walk right to inspect it.", 5.0)
	update_camera()
	_update_hud()


func hero_active() -> Hero:
	return heroes[active_index]


func switch_hero() -> void:
	_cancel_repair("Repair cancelled: hero changed.")
	release_controls()
	hero_active().set_active(false)
	active_index = (active_index + 1) % heroes.size()
	hero_active().set_active(true)
	update_camera()
	_update_hud()


func release_controls() -> void:
	_held_keys.clear()
	if not is_node_ready():
		return
	_cancel_repair("Repair paused. Press E nearby to restart.")
	for hero: Hero in heroes:
		hero.reset_state()


func perform_action(clip: StringName) -> void:
	var hero := hero_active()
	_cancel_repair()
	_held_keys.clear()
	hero.set_motion(0.0, false)
	var in_range := rack.is_in_range(hero.global_position)
	if in_range and (clip == &"primary" or clip == &"secondary"):
		hero.sprite.flip_h = hero.global_position.x > rack.global_position.x
	if clip == &"primary" and in_range and not rack.repaired:
		repairing_hero = hero
		repair_elapsed = 0.0
		hero.start_action(clip, true)
		_set_feedback("R12: tightening service coupling...", FaultRack.REPAIR_SECONDS)
	else:
		hero.start_action(clip)
		if clip == &"primary" or clip == &"secondary":
			if not in_range:
				_set_feedback("No rack in reach. Move beside R12 for a local check.")
			elif rack.repaired:
				_set_feedback("R12: coupling secure. Status green; no further repair needed.")
			else:
				_set_feedback("R12: loose service coupling. E: tighten it (2 seconds).")
	_update_hud()


func update_camera() -> void:
	var target_x := hero_active().global_position.x
	var next_x := camera.position.x
	if target_x < next_x - CAMERA_DEADZONE:
		next_x = target_x + CAMERA_DEADZONE
	elif target_x > next_x + CAMERA_DEADZONE:
		next_x = target_x - CAMERA_DEADZONE
	camera.position = Vector2(
		clampf(roundf(next_x), VIEW_SIZE.x / 2.0, WORLD_WIDTH - VIEW_SIZE.x / 2.0),
		VIEW_SIZE.y / 2.0,
	)
	camera.force_update_scroll()
	environment.follow_camera(camera.position.x)


func set_inspection_active(value: bool) -> void:
	release_controls()
	visible = not value
	hud.visible = not value
	camera.enabled = not value
	process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if not value and assets_ready:
		update_camera()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
	if event.echo:
		return
	if event.pressed and key == KEY_F1:
		release_controls()
		if inspection_requested.get_connections().is_empty():
			_set_feedback("Inspection route is not connected. " + INSPECTION_RETURN_HINT)
		else:
			inspection_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not assets_ready:
		return
	if key in MOTION_KEYS:
		if event.pressed:
			_held_keys[int(key)] = true
		else:
			_held_keys.erase(int(key))
		_update_motion()
	elif event.pressed:
		match key:
			KEY_TAB:
				switch_hero()
			KEY_E:
				perform_action(&"primary")
			KEY_Q:
				perform_action(&"secondary")
			KEY_R:
				perform_action(&"reaction")
			KEY_F:
				perform_action(&"signal")
			_:
				return
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_controls()


func _physics_process(delta: float) -> void:
	if not assets_ready:
		return
	rack.set_highlight(rack.is_in_range(hero_active().global_position))
	if repairing_hero == null:
		return
	if (
		repairing_hero != hero_active()
		or not rack.is_in_range(repairing_hero.global_position)
		or repairing_hero.action != &"primary"
	):
		_cancel_repair("Repair interrupted. Press E beside R12 to restart.")
		return
	repair_elapsed += delta
	rack.set_progress(repair_elapsed / FaultRack.REPAIR_SECONDS)
	if repair_elapsed >= FaultRack.REPAIR_SECONDS:
		rack.finish_repair()
		repairing_hero.cancel_action()
		repairing_hero = null
		_set_feedback("R12 repaired: coupling secure. Local status is GREEN.", 5.0)


func _process(delta: float) -> void:
	if not assets_ready:
		return
	if _feedback_remaining > 0.0:
		_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	update_camera()
	_update_hud()


func _update_motion() -> void:
	var left := _held_keys.has(KEY_A) or _held_keys.has(KEY_LEFT)
	var right := _held_keys.has(KEY_D) or _held_keys.has(KEY_RIGHT)
	var direction := float(int(right) - int(left))
	if direction != 0.0:
		_cancel_repair("Repair cancelled: moved away.")
	hero_active().set_motion(direction, _held_keys.has(KEY_SHIFT))


func _cancel_repair(message: String = "") -> void:
	if repairing_hero == null:
		return
	repairing_hero.cancel_action()
	repairing_hero = null
	repair_elapsed = 0.0
	rack.set_progress(0.0)
	if not message.is_empty():
		_set_feedback(message)


func _set_feedback(message: String, duration: float = 3.0) -> void:
	feedback = message
	_feedback_remaining = duration


func _update_hud() -> void:
	var hero := hero_active()
	status_label.text = (
		"%s MIDCREEK / %s   |   R12: %s"
		% [
			hero.character.to_upper(),
			String(hero.sprite.animation).to_upper(),
			"ONLINE" if rack.repaired else "FAULT",
		]
	)
	if repairing_hero != null:
		feedback_label.text = (
			"R12: tightening coupling... %d%%  |  Move / Tab to cancel"
			% (int(rack.progress * 100.0))
		)
	elif _feedback_remaining > 0.0:
		feedback_label.text = feedback
	elif rack.is_in_range(hero.global_position):
		feedback_label.text = (
			"R12: online. Q: verify locally."
			if rack.repaired
			else "R12: fault detected. Q: diagnose   E: repair (2s)"
		)
	else:
		var direction := "right" if hero.global_position.x < rack.global_position.x else "left"
		feedback_label.text = (
			"R12 / %s: %d px %s   |   Both crew members are on the floor."
			% [
				"ONLINE" if rack.repaired else "FAULT",
				int(absf(rack.global_position.x - hero.global_position.x)),
				direction,
			]
		)
