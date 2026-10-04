extends RefCounted

const SlaTimer = preload("res://game/sla_timer.gd")
const TaskSystem = preload("res://game/task_system.gd")

var index: int = -1
var spawn_position: Vector2 = Vector2.ZERO
var _timer_value: float = 0.0
var _completed: Array[String] = []


func begin(start: Vector2, timer: SlaTimer, tasks: TaskSystem) -> void:
	index = -1
	_store(start, timer, tasks)


func activate(checkpoint_index: int, at: Vector2, timer: SlaTimer, tasks: TaskSystem) -> bool:
	if checkpoint_index <= index:
		return false
	index = checkpoint_index
	_store(at, timer, tasks)
	return true


func restore(timer: SlaTimer, tasks: TaskSystem) -> Vector2:
	timer.restore(_timer_value)
	tasks.restore(_completed)
	return spawn_position


func _store(at: Vector2, timer: SlaTimer, tasks: TaskSystem) -> void:
	spawn_position = at
	_timer_value = timer.remaining
	_completed = tasks.completed_ids()
