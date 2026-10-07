extends Node2D

var mobile_input: RefCounted

signal finished(result: Dictionary)
signal sound(sound_name: String)

const REPAIR_TICK_SECONDS := 0.4
const DIAGNOSE_SECONDS := 0.8
const FATAL_REACTION_SECONDS := 0.5
const PART_LABELS := {"psu": "PSU", "dimm": "DIMM"}
const DARK_COLOR := Color(0.3, 0.32, 0.4)
const FLICKER_COLOR := Color(0.12, 0.12, 0.18)
const FLICKER_SECONDS := 1.2
const ControlPrompt = preload("res://game/control_prompt.gd")
const WorkInventory = preload("res://game/tasks/work_inventory.gd")
const WorkSchema = preload("res://game/tasks/work_schema.gd")

const Health = preload("res://game/health.gd")
const SlaTimer = preload("res://game/sla_timer.gd")
const TaskSystem = preload("res://game/task_system.gd")
const CheckpointManager = preload("res://game/checkpoint_manager.gd")
const LevelParser = preload("res://game/level_parser.gd")
const LevelValidator = preload("res://game/level_validator.gd")
const LevelBuilder = preload("res://game/level_builder.gd")
const InputSetup = preload("res://game/input_setup.gd")
const Score = preload("res://game/score.gd")
const Player = preload("res://game/player.gd")
const Hud = preload("res://game/hud.gd")
const CablePort = preload("res://game/entities/cable_port.gd")
const Feel = preload("res://game/feel.gd")
const SparkArc = preload("res://game/hazards/spark_arc.gd")
const SpriteLibrary = preload("res://game/sprite_library.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const BackgroundSet = preload("res://game/background_set.gd")

@export_file("*.level") var level_path: String = "res://levels/00-graybox.level"
@export_enum("man", "woman") var character: String = "man"

var health := Health.new()
var timer := SlaTimer.new()
var tasks := TaskSystem.new()
var checkpoints := CheckpointManager.new()
var art := SpriteLibrary.new()
var animations := HeroAnimations.new()
var level: Dictionary = {}
var entities: Dictionary = {}
var error_message: String = ""
var completed: bool = false
var respawns: int = 0
var use_action_override: bool = false
var action_override: Dictionary = {}
var _respawn_pending: bool = false
var _fatal_remaining := 0.0
var _repair_tick: float = 0.0
var carried_part: String = ""
var work_inventory := WorkInventory.new()
var _diagnose_remaining: float = 0.0
var _switch_error_remaining: float = 0.0
var _previous_actions: Dictionary = {}
var _pressed_actions: Dictionary = {}
var darkness: CanvasModulate
var hit_stop_remaining: float = 0.0
var pending_presses: Dictionary = {}
var _replayed_presses: Dictionary = {}
var shake_remaining: float = 0.0
var _shake_rng := RandomNumberGenerator.new()
var _flicker_times: Array = []
var _flicker_rng := RandomNumberGenerator.new()
var _clock: float = 0.0

@onready var solids: Node2D = $World/Solids
@onready var entity_root: Node2D = $World/Entities
@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	player.mobile_input = mobile_input
	InputSetup.install()
	if not load_level(level_path):
		hud.show_message(error_message)
		player.set_physics_process(false)
		set_physics_process(false)


func load_level(path: String) -> bool:
	if not FileAccess.file_exists(path):
		error_message = "Level file not found: " + path
		return false
	var parser := LevelParser.new()
	level = parser.parse(FileAccess.get_file_as_string(path), path)
	if level.is_empty():
		error_message = parser.error_message
		return false
	var problems := LevelValidator.new().validate(level)
	if not problems.is_empty():
		error_message = "%s: %s" % [path, "\n".join(PackedStringArray(problems))]
		return false
	if not art.load_all():
		error_message = art.error_message
		return false
	if level["header"]["tasks"].any(func(task: Dictionary) -> bool: return task["type"] in WorkSchema.TYPES) or level["hazards"].any(func(hazard: Dictionary) -> bool: return hazard["kind"] == "fire"):
		if not art.load_group("work"):
			error_message = art.error_message
			return false
	if not animations.load_manifest():
		error_message = animations.error_message
		return false
	if not _build_background(String(level["header"]["background"])):
		return false
	player.character = character
	player.configure(animations)
	if level["header"].get("darkness", false):
		_build_darkness()
	var builder := LevelBuilder.new()
	builder.art = art
	builder.inventory = work_inventory
	builder.build_solids(level, solids)
	entities = builder.build_entities(level, entity_root)
	if entities.is_empty():
		error_message = "%s: %s" % [path, builder.error_message]
		return false
	for hazard in entities["hazards"]:
		if hazard is SparkArc:
			hazard.sparked.connect(sound.emit.bind("spark"))
	for task: Dictionary in level["header"]["tasks"]:
		tasks.add_task(task["id"], task["type"], task["required"], task.get("label", ""))
	health.died.connect(_request_respawn)
	timer.expired.connect(_request_respawn)
	timer.warning.connect(sound.emit.bind("timer_warning"))
	player.sound.connect(sound.emit)
	player.respawn(LevelBuilder.cell_to_world(level["player_start"]))
	timer.start(float(level["header"]["sla_seconds"]))
	checkpoints.begin(player.position, timer, tasks, capture_state())
	hud.art = art
	for segment: TextureRect in hud.segments:
		segment.texture = art.texture("ui", "health-full")
		segment.custom_minimum_size = segment.texture.get_size() * 2
	hud.bind(health, timer, tasks)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = level["width"] * LevelBuilder.TILE
	camera.limit_bottom = level["height"] * LevelBuilder.TILE
	camera.position = player.position
	return true


func flicker_schedule(count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(level["header"]["name"]))
	var times: Array = []
	var at := 0.0
	for i: int in range(count):
		at += rng.randf_range(6.0, 9.0)
		times.append(at)
	return times


func _build_darkness() -> void:
	darkness = CanvasModulate.new()
	darkness.name = "Darkness"
	darkness.color = DARK_COLOR
	add_child(darkness)
	var light := PointLight2D.new()
	light.name = "Flashlight"
	var gradient := GradientTexture2D.new()
	gradient.width = 320
	gradient.height = 320
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(1.0, 0.5)
	var colors := Gradient.new()
	colors.set_color(0, Color(1, 1, 1, 1))
	colors.set_color(1, Color(1, 1, 1, 0))
	gradient.gradient = colors
	light.texture = gradient
	light.energy = 1.1
	light.position = Vector2(0, -40)
	player.add_child(light)
	_flicker_times.clear()


func flicker_active_at(time: float) -> bool:
	if _flicker_times.is_empty() or (_flicker_times.size() == 2 and time < _flicker_times[0]):
		# Earlier queries replay the seed rather than retaining the full history.
		_flicker_rng.seed = hash(String(level["header"]["name"]))
		_flicker_times = [_flicker_rng.randf_range(6.0, 9.0)]
	while _flicker_times.back() <= time:
		var next: float = _flicker_times.back() + _flicker_rng.randf_range(6.0, 9.0)
		if _flicker_times.size() == 2:
			_flicker_times.pop_front()
		_flicker_times.append(next)
	var start: float = _flicker_times[0]
	return time >= start and time < start + FLICKER_SECONDS


func _update_darkness(delta: float) -> void:
	if darkness == null:
		return
	_clock += delta
	darkness.color = FLICKER_COLOR if flicker_active_at(_clock) else DARK_COLOR


func _update_shake(delta: float) -> void:
	if shake_remaining <= 0.0:
		camera.offset = Vector2.ZERO
		return
	shake_remaining = maxf(shake_remaining - delta, 0.0)
	camera.offset = Feel.shake_offset(Feel.SHAKE_SECONDS - shake_remaining, _shake_rng) if shake_remaining > 0.0 else Vector2.ZERO


func _sparks(at: Vector2) -> void:
	$World.add_child(Feel.spark_burst(at + Vector2(0, -60)))


func _build_background(background: String) -> bool:
	var definition := BackgroundSet.new()
	if not definition.load_set(background):
		error_message = definition.error_message
		return false
	var floor_y := float(level["height"] * LevelBuilder.TILE)
	if _requires_background_size_contract() and not definition.validate_level_height(floor_y):
		error_message = definition.error_message
		return false
	var z := -10 * (definition.layers.size() + 1)
	for layer: Dictionary in definition.layers:
		var texture: Texture2D = layer["texture"]
		var background_scale: float = layer["scale"]
		var parallax := Parallax2D.new()
		parallax.name = layer["name"]
		parallax.scroll_scale = Vector2(layer["scroll"], 1.0)
		parallax.repeat_size = Vector2(texture.get_width() * background_scale, 0)
		parallax.repeat_times = 3
		parallax.z_index = z
		parallax.modulate = layer["tint"]
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * background_scale
		sprite.position = Vector2(0, floor_y - texture.get_height() * background_scale)
		parallax.add_child(sprite)
		$World.add_child(parallax)
		$World.move_child(parallax, 0)
		z += 10
	return true


func _requires_background_size_contract() -> bool:
	return level["source"].begins_with("res://levels/") and not level["source"].get_file().begins_with("00-")


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if completed:
		return
	if _fatal_remaining > 0.0:
		_fatal_remaining = maxf(0.0, _fatal_remaining - delta)
		if is_zero_approx(_fatal_remaining):
			_fatal_remaining = 0.0
			_respawn()
			hud.update_timer()
			camera.position = player.position
		return
	var body := player.hit_rect()
	for hazard in entities["hazards"]:
		if "fatal" in hazard and hazard.fatal and hazard.active and hazard.hit_rect().intersects(body):
			_begin_fatal_death()
			return
	_sample_actions()
	_update_darkness(delta)
	_update_shake(delta)
	if hit_stop_remaining > 0.0:
		hit_stop_remaining -= delta
		for action: StringName in [&"repair", &"diagnose", &"jump"]:
			if _action_pressed(action):
				pending_presses[action] = true
		if hit_stop_remaining <= 0.0:
			freeze_world(false)
		return
	# Presses kept during hit stop count for one step only, so a stale press cannot fire later.
	_replayed_presses = pending_presses
	pending_presses = {}
	_switch_error_remaining = maxf(0.0, _switch_error_remaining - delta)
	timer.tick(delta)
	health.tick(delta)
	for hazard in entities["hazards"]:
		hazard.advance(delta)
		if hazard.active and hazard.hit_rect().intersects(body) and health.damage():
			player.hurt()
			sound.emit("hit")
			hit_stop_remaining = Feel.HIT_STOP_SECONDS
			shake_remaining = Feel.SHAKE_SECONDS
			freeze_world(true)
	if _out_of_bounds():
		_request_respawn()
	if _respawn_pending:
		_respawn()
		hud.update_timer()
		camera.position = player.position
		return
	for pickup in entities["coolant"]:
		var can_heal := health.segments > 0 and health.segments < Health.MAX_SEGMENTS
		if not pickup.taken and can_heal and pickup.hit_rect().intersects(body):
			pickup.take()
			health.heal()
			sound.emit("heal")
	var feet := player.position
	for i: int in range(entities["checkpoints"].size()):
		var node = entities["checkpoints"][i]
		if node.in_range(feet) and checkpoints.activate(i, node.position, timer, tasks, capture_state()):
			node.set_reached()
			sound.emit("checkpoint")
	for part in entities["parts"]:
		if not part.taken and carried_part.is_empty() and work_inventory.carried.is_empty() and part.hit_rect().intersects(body):
			part.take()
			carried_part = part.task_id
			hud.set_carry("Carrying " + PART_LABELS[part.kind])
			sound.emit("pickup")
	var cell := Vector2i(floori(feet.x / LevelBuilder.TILE), floori((feet.y - 1.0) / LevelBuilder.TILE))
	player.on_ladder = cell in level["ladders"]
	if entities["work"].is_empty():
		if not _update_switches(feet) and not _update_ports(delta, feet):
			_update_repair(delta, feet)
		_show_switch_prompt(feet)
	else:
		_update_work_interaction(delta, feet)
	var door = entities["exit"]
	if tasks.required_done() and not door.open:
		sound.emit("door_open")
	door.set_open(tasks.required_done())
	if door.open and door.in_range(feet):
		_finish()
		return
	hud.update_timer()
	camera.position = player.position


func _out_of_bounds() -> bool:
	var width := float(level["width"] * LevelBuilder.TILE)
	var height := float(level["height"] * LevelBuilder.TILE)
	var feet := player.position
	return feet.y > height + 64.0 or feet.x < -64.0 or feet.x > width + 64.0


func capture_state() -> Dictionary:
	var state := {"carried_part": carried_part, "work_inventory": work_inventory.capture_state()}
	for group: String in ["racks", "parts", "ports", "switches", "coolant", "work", "work_resources", "liquids"]:
		var states: Array = []
		for node in entities[group]:
			states.append(node.capture_state())
		state[group] = states
	return state


func restore_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	carried_part = String(state["carried_part"])
	work_inventory.restore_state(state["work_inventory"])
	var label := ""
	for part in entities["parts"]:
		if part.task_id == carried_part:
			label = "Carrying " + PART_LABELS[part.kind]
	hud.set_carry(label)
	_diagnose_remaining = 0.0
	_switch_error_remaining = 0.0
	hud.set_prompt(ControlPrompt.make())
	for group: String in ["racks", "parts", "ports", "switches", "coolant", "work", "work_resources", "liquids"]:
		for i: int in range(entities[group].size()):
			entities[group][i].restore_state(state[group][i])
	for station in entities["work"]:
		station.apply_effects()
	_refresh_work_sources()


func _refresh_work_sources() -> void:
	for source in entities["work_resources"]:
		source.queue_redraw()
	if not work_inventory.carried.is_empty():
		hud.set_carry("Carrying %s (%s)" % [work_inventory.items[work_inventory.carried], work_inventory.carried])
	elif carried_part.is_empty():
		hud.set_carry("")


func _update_work_interaction(delta: float, feet: Vector2) -> void:
	for station in entities["work"]:
		station.queue_redraw()
	# Legacy targets keep their priority, but a selected target never falls through.
	for panel in entities["switches"]:
		if not tasks.is_done(panel.task_id) and not panel.on and panel.in_range(feet):
			_cancel_work()
			_update_switches(feet)
			_show_switch_prompt(feet)
			return
	for port in entities["ports"]:
		if not port.done and (port.state == "active" or port.in_range(feet)):
			_cancel_work()
			_update_ports(delta, feet)
			return
	for rack in entities["racks"]:
		if not rack.done and rack.in_range(feet):
			_cancel_work()
			_update_repair(delta, feet)
			return
	var target = null
	var site := -1
	var source_target = null
	var distance := INF
	for station in entities["work"]:
		if station.order.done:
			continue
		var candidate: int = station.site_in_range(feet)
		if candidate >= 0 and feet.distance_squared_to(station.sites[candidate]) < distance:
			target = station
			site = candidate
			distance = feet.distance_squared_to(station.sites[candidate])
	for source in entities["work_resources"]:
		if source.available() and source.in_range(feet) and feet.distance_squared_to(source.position) < distance:
			source_target = source
			distance = feet.distance_squared_to(source.position)
	player.locked = false
	player.action = &""
	for rack in entities["racks"]:
		rack.cancel()
	for station in entities["work"]:
		if station != target or source_target != null:
			station.order.cancel()
	if source_target != null:
		if not carried_part.is_empty():
			hud.set_prompt(ControlPrompt.make("", "", "", "Deliver the carried part first"))
			return
		var kind: String = source_target.order.definition["resources"][source_target.index]["kind"]
		var verb := "Refill extinguisher" if source_target.is_refill() else "Collect " + kind
		if not work_inventory.carried.is_empty() and not source_target.is_refill():
			verb = "Return carried item and collect " + kind
		hud.set_prompt(ControlPrompt.make("repair", "press", verb))
		if _action_pressed(&"repair"):
			source_target.order.collect(source_target.index)
			_refresh_work_sources()
			sound.emit("pickup")
		return
	if target == null:
		hud.set_prompt(_level_prompt(feet))
		return
	var result: Dictionary = target.order.step(site, _action_held(&"repair"), _action_pressed(&"repair"), _action_held(&"diagnose"), _action_pressed(&"diagnose"), delta)
	player.locked = result["locked"]
	player.action = result["action"]
	hud.set_prompt(result["prompt"])
	target.apply_effects()
	_refresh_work_sources()
	if result["completed"] and tasks.complete(target.order.definition["id"]):
		sound.emit("repair_done")


func _cancel_work() -> void:
	for station in entities["work"]:
		station.order.cancel()


func _action_held(action: StringName) -> bool:
	if use_action_override:
		return bool(action_override.get(action, false))
	return Input.is_action_pressed(action) or (mobile_input != null and mobile_input.held(action))


func _sample_actions() -> void:
	for action: StringName in [&"repair", &"diagnose", &"jump"]:
		var held := _action_held(action)
		_pressed_actions[action] = held and not _previous_actions.get(action, false)
		_previous_actions[action] = held


func freeze_world(value: bool) -> void:
	player.frozen = value
	player.sprite.speed_scale = 0.0 if value else 1.0
	for lift in entities.get("lifts", []):
		lift.set_physics_process(not value)


func _action_pressed(action: StringName) -> bool:
	if _replayed_presses.has(action):
		return true
	if use_action_override:
		return _pressed_actions.get(action, false)
	return Input.is_action_just_pressed(action) or (mobile_input != null and mobile_input.pressed(action))


func _update_switches(feet: Vector2) -> bool:
	var panel = null
	for candidate in entities["switches"]:
		if not tasks.is_done(candidate.task_id) and candidate.in_range(feet):
			panel = candidate
			break
	if panel == null:
		return false
	player.locked = false
	player.action = &""
	var group: Array = entities["switches"].filter(func(p) -> bool: return p.task_id == panel.task_id)
	var next := 1
	for other in group:
		if other.on:
			next = maxi(next, other.order + 1)
	if not _action_pressed(&"repair") or panel.on:
		return false
	if panel.order != next:
		for other in group:
			other.set_on(false)
		sound.emit("timer_warning")
		_switch_error_remaining = 1.0
		return true
	_switch_error_remaining = 0.0
	panel.set_on(true)
	hud.set_prompt(ControlPrompt.make())
	sound.emit("switch")
	if next == group.size():
		tasks.complete(panel.task_id)
		sound.emit("repair_done")
	return true


func _show_switch_prompt(feet: Vector2) -> void:
	if player.locked:
		return
	if _switch_error_remaining > 0.0:
		hud.set_prompt(ControlPrompt.make("", "", "", "Wrong order. Start again at switch 1"))
		return
	for panel in entities["switches"]:
		if not tasks.is_done(panel.task_id) and panel.in_range(feet) and not panel.on:
			hud.set_prompt(ControlPrompt.make("repair", "press", "Throw switch %d" % panel.order))
			return


func _update_ports(delta: float, feet: Vector2) -> bool:
	var port = null
	for candidate in entities["ports"]:
		if not candidate.done and (candidate.state == "active" or candidate.in_range(feet)):
			port = candidate
			break
	if port == null:
		return false
	if port.state == "idle":
		if not port.in_range(feet):
			return false
		player.locked = false
		player.action = &""
		hud.set_prompt(ControlPrompt.make("repair", "press", "reseat the cable"))
		if _action_pressed(&"repair"):
			port.begin()
			player.locked = true
			player.action = &"primary"
			hud.set_prompt(ControlPrompt.make(String(port.current_button()), "press", "reseat cable (1 of 3)"))
			sound.emit("menu_move")
		return true
	player.locked = true
	player.action = &"primary"
	var consumed_button := false
	for button: StringName in CablePort.BUTTONS:
		if _action_pressed(button):
			consumed_button = true
			var result: String = port.press(button)
			if result == "done":
				tasks.complete(port.task_id)
				sound.emit("repair_done")
			elif result == "ok":
				sound.emit("repair_tick")
			else:
				sound.emit("timer_warning")
				player.locked = false
				player.action = &""
			break
	if not consumed_button and port.state == "active" and port.advance(delta):
		sound.emit("timer_warning")
		player.locked = false
		player.action = &""
	if port.state == "active":
		hud.set_prompt(ControlPrompt.make(String(port.current_button()), "press", "reseat cable (%d of 3)" % (port.step + 1)))
	elif not port.done:
		hud.set_prompt(ControlPrompt.make("repair", "press", "reseat the cable"))
	else:
		hud.set_prompt(ControlPrompt.make())
	return true


func _part_label(rack) -> String:
	return PART_LABELS.get(rack.part_kind, "part")


func _update_repair(delta: float, feet: Vector2) -> void:
	var target = null
	for rack in entities["racks"]:
		if not rack.done and rack.in_range(feet):
			target = rack
			break
	for rack in entities["racks"]:
		if rack != target:
			rack.cancel()
	if _diagnose_remaining > 0.0:
		_diagnose_remaining -= delta
		player.locked = true
		player.action = &"secondary"
		hud.set_prompt(ControlPrompt.make("", "", "", "Diagnosing..."))
		return
	if target != null and target.kind == "diagnose_repair" and not target.diagnosed and _action_pressed(&"diagnose"):
		target.diagnosed = true
		target.queue_redraw()
		_diagnose_remaining = DIAGNOSE_SECONDS
		player.locked = true
		player.action = &"secondary"
		hud.set_prompt(ControlPrompt.make("", "", "", "Diagnosing..."))
		sound.emit("diagnose")
		return
	var blocked := ""
	if target != null and target.kind == "diagnose_repair" and not target.diagnosed:
		blocked = "Diagnose first"
	elif target != null and target.kind == "fetch" and carried_part != target.task_id:
		blocked = "Bring the %s to this rack" % _part_label(target)
	var holding: bool = target != null and blocked.is_empty() and _action_held(&"repair")
	player.locked = holding
	player.action = &"primary" if holding else &""
	if target == null:
		hud.set_prompt(_level_prompt(feet))
	elif not blocked.is_empty():
		target.cancel()
		hud.set_prompt(ControlPrompt.make("diagnose", "press", "diagnose", blocked) if target.kind == "diagnose_repair" else ControlPrompt.make("", "", "", blocked))
	elif not holding:
		target.cancel()
		var verb := "install the %s" % _part_label(target) if target.kind == "fetch" else "repair"
		hud.set_prompt(ControlPrompt.make("repair", "hold", verb))
	else:
		var verb := "install the %s" % _part_label(target) if target.kind == "fetch" else "repair"
		hud.set_prompt(ControlPrompt.make("repair", "hold", verb, "Working...", true))
		_repair_tick -= delta
		if _repair_tick <= 0.0:
			_repair_tick = REPAIR_TICK_SECONDS
			sound.emit("repair_tick")
		if target.work(delta):
			if target.kind == "fetch":
				carried_part = ""
				hud.set_carry("")
				sound.emit("deliver")
			else:
				sound.emit("repair_done")
			_sparks(target.position)
			_complete_if_all_racks_done(target.task_id)
			hud.set_prompt(ControlPrompt.make())


func _level_prompt(feet: Vector2) -> Dictionary:
	var column := int(floorf(feet.x / LevelBuilder.TILE))
	for prompt: Dictionary in level["header"].get("prompts", []):
		if absi(column - int(prompt["x"])) <= 3:
			var task_id: String = prompt.get("task", "")
			if not task_id.is_empty():
				if tasks.is_done(task_id):
					continue
				if prompt["action"] == "diagnose":
					var diagnosed := false
					for rack in entities["racks"]:
						if rack.task_id == task_id and rack.diagnosed:
							diagnosed = true
					if diagnosed:
						continue
				var switched := false
				for panel in entities["switches"]:
					if panel.task_id == task_id and panel.on:
						switched = true
				if switched:
					continue
			return ControlPrompt.make(prompt["action"], prompt["intent"], prompt["text"], prompt["status"], _action_held(StringName(prompt["action"])) if not prompt["action"].is_empty() else false)
	return ControlPrompt.make()


func _complete_if_all_racks_done(task_id: String) -> void:
	for rack in entities["racks"]:
		if rack.task_id == task_id and not rack.done:
			return
	tasks.complete(task_id)


func _request_respawn() -> void:
	if _fatal_remaining <= 0.0:
		_respawn_pending = true


func _begin_fatal_death() -> void:
	if player.dead:
		return
	_fatal_remaining = FATAL_REACTION_SECONDS
	_respawn_pending = false
	hit_stop_remaining = 0.0
	shake_remaining = 0.0
	camera.offset = Vector2.ZERO
	freeze_world(true)
	player.dead = true
	player.locked = true
	player.velocity = Vector2.ZERO
	player.motor.reset()
	player.hurt_remaining = FATAL_REACTION_SECONDS
	player.sprite.speed_scale = 1.0
	player.update_animation()
	player.sprite.play(&"reaction")
	player.sprite.set_frame_and_progress(0, 0.0)
	health.fatal_damage()
	sound.emit("hit")
	hud.set_prompt(ControlPrompt.make("", "", "", "Electrified liquid"))


func _respawn() -> void:
	# Respawn order:
	#   checkpoints.restore()  -> timer, completed tasks, spawn point
	#   restore_state()        -> task progress and effects (fire, liquid, power)
	#   reset_motion()         -> hazards and lifts return to authored safe states;
	#                             a hazard disabled by restored progress stays disabled
	#   player.respawn()       -> health refill, transient input cleared
	var fatal := player.dead
	_respawn_pending = false
	sound.emit("fail")
	respawns += 1
	var spawn := checkpoints.restore(timer, tasks)
	restore_state(checkpoints.level_state)
	for node in entities["hazards"] + entities["lifts"]:
		node.reset_motion()
	player.respawn(spawn)
	health.refill()
	if fatal:
		pending_presses.clear()
		_replayed_presses.clear()
		_previous_actions.clear()
		_pressed_actions.clear()
		action_override.clear()
		_repair_tick = 0.0
		if mobile_input != null:
			mobile_input.clear()
		player.locked = false
		player.action = &""
		freeze_world(false)
		player.update_animation()
	hud.refresh_tasks()


func _finish() -> void:
	completed = true
	hud.set_prompt(ControlPrompt.make())
	timer.stop()
	player.locked = true
	var par := float(level["header"]["par_seconds"])
	var result := {
		"elapsed": timer.elapsed,
		"sla_seconds": float(level["header"]["sla_seconds"]),
		"hits": health.hits_taken,
		"respawns": respawns,
		"stars": Score.stars(timer.elapsed, par, health.hits_taken),
		"optional_done": 0,
		"optional_total": 0,
	}
	for entry: Dictionary in tasks.entries():
		if not entry["required"]:
			result["optional_total"] += 1
			if entry["done"]:
				result["optional_done"] += 1
	sound.emit("win")
	hud.show_message("Level complete. Stars: %d" % result["stars"])
	hud.show_stars(result["stars"])
	finished.emit(result)
