extends RefCounted

const ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down", "jump", "repair", "diagnose", "slide"
]

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
	if step.has("until_y"):
		var target := float(step["until_y"])
		var direction := -1.0 if "move_up" in held else 1.0
		if (level.player.position.y - target) * direction >= 0.0:
			_advance()
			apply(level, delta)
			return
		_set_input(level, held, first and "jump" in held)
		_step_time += delta
		_step_frames += 1
		if _step_time > float(step["max_seconds"]):
			failed = true
			error_message = "Route step %d did not reach y=%.0f within %.1f s (y=%.0f)." % [
				index + 1, float(step["until_y"]), float(step["max_seconds"]), level.player.position.y
			]
		return
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
	var vertical := 0.0
	if "move_up" in held:
		vertical -= 1.0
	if "move_down" in held:
		vertical += 1.0
	var input := {"direction": direction, "vertical": vertical}
	if "jump" in held:
		input["jump_held"] = true
		if press_jump:
			input["jump_pressed"] = true
	if "slide" in held:
		input["slide_pressed"] = true
	level.player.input_override = input
	var actions := {}
	for action: String in ["repair", "diagnose", "jump"]:
		if action in held:
			actions[StringName(action)] = true
	level.action_override = actions


func _validate(step: Variant) -> String:
	if not step is Dictionary:
		return "must be an object."
	var kinds := 0
	for kind: String in ["hold", "tap", "wait"]:
		if step.has(kind):
			kinds += 1
	if kinds != 1:
		return "needs exactly one of hold, tap, or wait."
	var allowed: Array = ["tap"] if step.has("tap") else ["wait"]
	if step.has("hold"):
		allowed = ["hold", "until_x", "max_seconds"] if step.has("until_x") else ["hold", "seconds"]
		if step.has("until_y") and not step.has("until_x"):
			allowed = ["hold", "until_y", "max_seconds"]
	for key: Variant in step:
		if key not in allowed:
			return "unsupported field '%s'." % key
	if step.has("tap"):
		return "" if step["tap"] is String and String(step["tap"]) in ACTIONS else "unknown tap action."
	if step.has("wait"):
		return "" if _is_duration(step["wait"]) else "wait needs a finite duration of 0 or more."
	if not step["hold"] is Array:
		return "hold needs an action list."
	for action: Variant in step["hold"]:
		if not action is String or String(action) not in ACTIONS:
			return "unknown action '%s'." % action
	if step.has("until_y"):
		if step.has("seconds") or step.has("until_x"):
			return "hold cannot combine until_y with seconds or until_x."
		var target: Variant = step["until_y"]
		if not ((target is float or target is int) and is_finite(float(target))):
			return "until_y must be a finite number."
		if not _is_duration(step.get("max_seconds")) or float(step["max_seconds"]) <= 0.0:
			return "until_y needs a positive max_seconds."
		if ("move_up" in step["hold"]) == ("move_down" in step["hold"]):
			return "until_y needs exactly one of move_up or move_down."
		return ""
	if step.has("until_x"):
		var value: Variant = step["until_x"]
		if not ((value is float or value is int) and is_finite(float(value))):
			return "until_x must be a finite number."
		if not _is_duration(step.get("max_seconds")) or float(step["max_seconds"]) <= 0.0:
			return "until_x needs a positive max_seconds."
		if ("move_left" in step["hold"]) == ("move_right" in step["hold"]):
			return "until_x needs exactly one of move_left or move_right."
		return ""
	return "" if _is_duration(step.get("seconds")) else "hold needs seconds of 0 or more, or until_x or until_y with max_seconds."


static func _is_duration(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0
