extends CanvasLayer

const Health = preload("res://game/health.gd")
const SlaTimer = preload("res://game/sla_timer.gd")
const TaskSystem = preload("res://game/task_system.gd")
const Feel = preload("res://game/feel.gd")
const ControlPrompt = preload("res://game/control_prompt.gd")
const ControlGraphic = preload("res://game/control_graphic.gd")
const WARNING_COLOR := Color(1.0, 0.35, 0.3)

var segments: Array[TextureRect] = []
var star_icons: Array[TextureRect] = []
var star_row := HBoxContainer.new()
var art: RefCounted
var timer_label := Label.new()
var task_list := VBoxContainer.new()
var prompt_label := Label.new()
var prompt_graphic := ControlGraphic.new()
var hold_label := Label.new()
var prompt_row := HBoxContainer.new()
var prompt: Dictionary = ControlPrompt.make()
var control_display := "keyboard":
	set(value):
		control_display = value
		_refresh_prompt()
var _prompt_description := ""
var message_label := Label.new()
var carry_label := Label.new()
var _timer: SlaTimer
var _tasks: TaskSystem


func _ready() -> void:
	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.color = Color(0.04, 0.07, 0.1, 0.72)
	panel.position = Vector2(8, 8)
	panel.size = Vector2(300, 140)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 16)
	add_child(bar)
	for i: int in range(Health.MAX_SEGMENTS):
		var segment := _icon("health-full", 2)
		bar.add_child(segment)
		segments.append(segment)
	timer_label.position = Vector2(200, 14)
	add_child(timer_label)
	var task_column := VBoxContainer.new()
	task_column.position = Vector2(16, 40)
	task_column.add_theme_constant_override("separation", 8)
	task_column.resized.connect(func() -> void:
		panel.size = Vector2(
			maxf(300.0, task_column.position.x + task_column.size.x),
			maxf(140.0, task_column.position.y + task_column.size.y),
		)
	)
	add_child(task_column)
	task_column.add_child(task_list)
	prompt_row.position = Vector2(16, 660)
	prompt_row.add_theme_constant_override("separation", 12)
	add_child(prompt_row)
	prompt_row.add_child(prompt_graphic)
	hold_label.text = "Hold"
	prompt_row.add_child(hold_label)
	prompt_row.add_child(prompt_label)
	prompt_label.custom_minimum_size.x = 790
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	star_row.position = Vector2(400, 380)
	add_child(star_row)
	_refresh_prompt()
	carry_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	task_column.add_child(carry_label)
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


func _icon(icon_name: String, scale_factor: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if art != null:
		icon.texture = art.texture("ui", icon_name)
		icon.custom_minimum_size = icon.texture.get_size() * scale_factor
	else:
		icon.custom_minimum_size = Vector2(12, 12) * scale_factor
	return icon


func set_health(value: int) -> void:
	if art == null:
		return
	for i: int in range(segments.size()):
		segments[i].texture = art.texture("ui", "health-full" if i < value else "health-empty")


func health_shown() -> int:
	var count := 0
	for segment: TextureRect in segments:
		if art != null and segment.texture == art.texture("ui", "health-full"):
			count += 1
	return count


func update_timer() -> void:
	if _timer == null:
		return
	timer_label.text = format_time(_timer.remaining)
	var color := WARNING_COLOR if _timer.remaining <= SlaTimer.WARNING_SECONDS else Color.WHITE
	color.a = Feel.timer_pulse(_timer.remaining, Time.get_ticks_msec() / 1000.0)
	timer_label.modulate = color


static func format_time(seconds: float) -> String:
	var total := int(ceilf(seconds))
	return "SLA %02d:%02d" % [total / 60, total % 60]


func refresh_tasks() -> void:
	for child: Node in task_list.get_children():
		task_list.remove_child(child)
		child.free()
	for entry: Dictionary in _tasks.entries():
		var row := HBoxContainer.new()
		row.add_child(_icon("task-done" if entry["done"] else "task-open", 2))
		var label := Label.new()
		label.text = "%s%s" % [entry["label"], "" if entry["required"] else " (optional)"]
		row.set_meta("done", entry["done"])
		row.add_child(label)
		task_list.add_child(row)


func task_lines() -> Array[String]:
	var lines: Array[String] = []
	for row: Node in task_list.get_children():
		lines.append("%s %s" % ["[x]" if row.get_meta("done") else "[ ]", (row.get_child(1) as Label).text])
	return lines


func task_icon(index: int) -> Texture2D:
	return (task_list.get_child(index).get_child(0) as TextureRect).texture


func show_stars(count: int) -> void:
	if star_row.get_parent() == null:
		star_row.position = Vector2(400, 380)
		add_child(star_row)
	for icon: TextureRect in star_icons:
		star_row.remove_child(icon)
		icon.free()
	star_icons.clear()
	for i: int in range(3):
		var icon := _icon("star-on" if i < count else "star-off", 3)
		star_row.add_child(icon)
		star_icons.append(icon)


func set_carry(text: String) -> void:
	carry_label.text = text


func set_prompt(value: Dictionary) -> void:
	if prompt == value:
		return
	prompt = value.duplicate()
	_refresh_prompt()


func prompt_model() -> Dictionary:
	return ControlPrompt.render(prompt, control_display)


func _refresh_prompt() -> void:
	var model := prompt_model()
	prompt_graphic.show_model(model)
	hold_label.visible = not model["action"].is_empty() and model["intent"] == "hold"
	if model["description"] != _prompt_description:
		_prompt_description = model["description"]
		prompt_label.text = model["status"]
		prompt_label.accessibility_description = _prompt_description
		prompt_row.accessibility_description = _prompt_description


func show_message(text: String) -> void:
	message_label.text = text
	message_label.show()
