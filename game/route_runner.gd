extends RefCounted

const ACTIONS: Array[String] = ["move_left", "move_right", "jump", "repair", "diagnose", "slide"]

var steps: Array = []
var index: int = 0
var failed: bool = false
var error_message: String = ""
var _step_time: float = 0.0
var _step_frames: int = 0


func _init(route_steps: Array) -> void:
	steps = route_steps
	for i: int in range(steps.size()):
		var problem := _validate(steps[i])
		if not problem.is_empty():
			error_message = "Route step %d: %s" % [i + 1, problem]
			failed = true
			return


func done() -> bool:
	return index >= steps.size()


func apply(level: Object, delta: float) -> void:
	level.player.use_override = true
	level.use_action_override = true
	if failed or done():
		_set_input(level, [], false)
		return
	var step: Dictionary = steps[index]
	var first := _step_frames == 0
	if step.has("tap"):
		_set_input(level, [step["tap"]], true)
		_advance()
		return
	if step.has("wait"):
		_set_input(level, [], false)
		_tick(delta, float(step["wait"]))
		return
	var held: Array = step["hold"]
	if step.has("until_x"):
		var target := float(step["until_x"])
		var direction := -1.0 if "move_left" in held else 1.0
		if (level.player.position.x - target) * direction >= 0.0:
			_advance()
			apply(level, delta)
			return
		_set_input(level, held, first and "jump" in held)
		_step_time += delta
		_step_frames += 1
		if _step_time > float(step["max_seconds"]):
			failed = true
			error_message = "Route step %d did not reach x=%.0f within %.1f s (x=%.0f)." % [
				index + 1, target, float(step["max_seconds"]), level.player.position.x
			]
		return
	_set_input(level, held, first and "jump" in held)
	_tick(delta, float(step["seconds"]))


func _tick(delta: float, seconds: float) -> void:
	_step_time += delta
	_step_frames += 1
	if _step_time >= seconds - 0.0001:
		_advance()


func _advance() -> void:
	index += 1
	_step_time = 0.0
	_step_frames = 0


func _set_input(level: Object, held: Array, press_jump: bool) -> void:
	var direction := 0.0
	if "move_left" in held:
		direction -= 1.0
	if "move_right" in held:
		direction += 1.0
	var input := {"direction": direction}
	if "jump" in held:
		input["jump_held"] = true
		if press_jump:
			input["jump_pressed"] = true
	if "slide" in held:
		input["slide_pressed"] = true
	level.player.input_override = input
	var actions := {}
	for action: String in ["repair", "diagnose"]:
		if action in held:
			actions[StringName(action)] = true
	level.action_override = actions


func _validate(step: Variant) -> String:
	if not step is Dictionary:
		return "must be an object."
	if step.has("tap"):
		return "" if String(step["tap"]) in ACTIONS else "unknown tap action."
	if step.has("wait"):
		return "" if step["wait"] is float or step["wait"] is int else "wait needs seconds."
	if not step.get("hold") is Array:
		return "needs hold, tap, or wait."
	for action: Variant in step["hold"]:
		if String(action) not in ACTIONS:
			return "unknown action '%s'." % action
	if step.has("until_x"):
		return "" if step.has("max_seconds") else "until_x needs max_seconds."
	return "" if step.has("seconds") else "hold needs seconds or until_x."
