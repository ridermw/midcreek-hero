extends RefCounted

const JUMP_REACH := {0: 4, 1: 4, 2: 3, 3: 2}
const FALL_REACH := 4
const LIFT_RISE := Vector2i(0, 3)
const MIN_TASKS := 3
const MAX_TASKS := 6
const CHECKPOINTS := 3


func validate(level: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not errors.is_empty():
		return errors
	var task_count: int = level["header"]["tasks"].size()
	if task_count < MIN_TASKS or task_count > MAX_TASKS:
		errors.append("Level needs %d to %d tasks, found %d." % [MIN_TASKS, MAX_TASKS, task_count])
	if level["checkpoints"].size() != CHECKPOINTS:
		errors.append(
			"Level needs exactly %d checkpoints, found %d." % [CHECKPOINTS, level["checkpoints"].size()]
		)
	var targets := {"player start": level["player_start"], "exit": level["exit"]}
	for anchor: String in level["anchors"]:
		targets["anchor " + anchor] = level["anchors"][anchor]
	for i: int in range(level["checkpoints"].size()):
		targets["checkpoint %d" % (i + 1)] = level["checkpoints"][i]
	for i: int in range(level["coolant"].size()):
		targets["coolant %d" % (i + 1)] = level["coolant"][i]
	var reachable := reachable_cells(level)
	for target_name: String in targets:
		var cell: Vector2i = targets[target_name]
		var where := "%s at column %d, row %d" % [target_name, cell.x + 1, cell.y + 1]
		if not is_standable(level, cell):
			errors.append(where + " is not standable.")
		elif not reachable.has(cell):
			errors.append(where + " is not reachable.")
	return errors


func is_standable(level: Dictionary, cell: Vector2i) -> bool:
	var solids: Dictionary = level["solids"]
	if solids.has(cell):
		return false
	if cell in level["ladders"] or cell in level["lifts"] or (cell + LIFT_RISE) in level["lifts"]:
		return true
	return solids.has(cell + Vector2i.DOWN)


func reachable_cells(level: Dictionary) -> Dictionary:
	var seen := {}
	var start: Vector2i = level["player_start"]
	if not is_standable(level, start):
		return seen
	seen[start] = true
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for next: Vector2i in _neighbors(level, cell):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _neighbors(level: Dictionary, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var width: int = level["width"]
	for y: int in range(level["height"]):
		var rise := cell.y - y
		var limit := FALL_REACH
		if rise > 0:
			if not JUMP_REACH.has(rise):
				continue
			limit = JUMP_REACH[rise]
		for dx: int in range(-limit, limit + 1):
			var next := Vector2i(cell.x + dx, y)
			if next != cell and next.x >= 0 and next.x < width and is_standable(level, next):
				result.append(next)
	if cell in level["lifts"]:
		result.append(cell - LIFT_RISE)
	if cell in level["ladders"]:
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
			if is_standable(level, cell + step):
				result.append(cell + step)
	return result
