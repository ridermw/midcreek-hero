extends CanvasLayer

const Health = preload("res://game/health.gd")
const SlaTimer = preload("res://game/sla_timer.gd")
const TaskSystem = preload("res://game/task_system.gd")
const FULL_COLOR := Color(0.86, 0.2, 0.2)
const EMPTY_COLOR := Color(0.25, 0.25, 0.28)
const WARNING_COLOR := Color(1.0, 0.35, 0.3)

var segments: Array[ColorRect] = []
var timer_label := Label.new()
var task_list := VBoxContainer.new()
var prompt_label := Label.new()
var message_label := Label.new()
var _timer: SlaTimer
var _tasks: TaskSystem


func _ready() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 16)
	add_child(bar)
	for i: int in range(Health.MAX_SEGMENTS):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(20, 12)
		segment.color = FULL_COLOR
		bar.add_child(segment)
		segments.append(segment)
	timer_label.position = Vector2(420, 12)
	add_child(timer_label)
	task_list.position = Vector2(16, 40)
	add_child(task_list)
	prompt_label.position = Vector2(16, 680)
	add_child(prompt_label)
	message_label.position = Vector2(360, 340)
	message_label.hide()
	add_child(message_label)


func bind(health: Health, timer: SlaTimer, tasks: TaskSystem) -> void:
	_timer = timer
	_tasks = tasks
	health.changed.connect(set_health)
	tasks.task_completed.connect(func(_id: String) -> void: refresh_tasks())
	set_health(health.segments)
	refresh_tasks()
	update_timer()


func set_health(value: int) -> void:
	for i: int in range(segments.size()):
		segments[i].color = FULL_COLOR if i < value else EMPTY_COLOR


func health_shown() -> int:
	var count := 0
	for segment: ColorRect in segments:
		if segment.color == FULL_COLOR:
			count += 1
	return count


func update_timer() -> void:
	if _timer == null:
		return
	timer_label.text = format_time(_timer.remaining)
	timer_label.modulate = WARNING_COLOR if _timer.remaining <= SlaTimer.WARNING_SECONDS else Color.WHITE


static func format_time(seconds: float) -> String:
	var total := int(ceilf(seconds))
	return "SLA %02d:%02d" % [total / 60, total % 60]


func refresh_tasks() -> void:
	for child: Node in task_list.get_children():
		task_list.remove_child(child)
		child.free()
	for entry: Dictionary in _tasks.entries():
		var label := Label.new()
		label.text = "%s %s%s" % [
			"[x]" if entry["done"] else "[ ]",
			entry["label"],
			"" if entry["required"] else " (optional)",
		]
		task_list.add_child(label)


func task_lines() -> Array[String]:
	var lines: Array[String] = []
	for child: Node in task_list.get_children():
		lines.append((child as Label).text)
	return lines


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_message(text: String) -> void:
	message_label.text = text
	message_label.show()
