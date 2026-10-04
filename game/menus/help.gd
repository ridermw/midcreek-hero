extends Control

const UiKit = preload("res://game/menus/ui_kit.gd")
const Content = preload("res://game/help_content.gd")
const Demo = preload("res://game/help_demo.gd")
const Graphic = preload("res://game/control_graphic.gd")
const Prompt = preload("res://game/control_prompt.gd")
var main: Node
var page_index := 0
var pages := Content.pages()
var demo: Control
var _column: VBoxContainer
var _cue: Label
var _graphic: Label
var _last_step := -1


func build(owner_main: Node) -> void:
	main = owner_main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_page()


func page_count() -> int:
	return pages.size()


func next_page() -> void:
	page_index = (page_index + 1) % pages.size()
	_show_page()


func previous_page() -> void:
	page_index = (page_index - 1 + pages.size()) % pages.size()
	_show_page()


func _show_page() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	demo = null
	_last_step = -1
	_column = UiKit.column(self)
	_column.add_theme_constant_override("separation", 8)
	_column.add_child(UiKit.label("How to Play · %d / %d" % [page_index + 1, pages.size()], 22, UiKit.MUTED_COLOR))
	var page: Dictionary = pages[page_index]
	_column.add_child(UiKit.label(page["title"], 30))
	if page["id"] == "controls":
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 18)
		_column.add_child(grid)
		for model: Dictionary in Content.controls(main.control_display()):
			var row := HBoxContainer.new()
			var icon := Graphic.new()
			icon.show_model(model.merged({"pulse": false}, true))
			row.add_child(icon)
			var label := UiKit.label(model["description"], 16)
			label.custom_minimum_size.x = 305
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(label)
			grid.add_child(row)
	else:
		demo = Demo.new()
		demo.configure(page, main)
		demo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_column.add_child(demo)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 44
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_graphic = Graphic.new()
		_cue = UiKit.label("", 18)
		row.add_child(_graphic)
		row.add_child(_cue)
		_column.add_child(row)
	var instructions := UiKit.label(page["instructions"], 18, UiKit.MUTED_COLOR)
	instructions.custom_minimum_size.x = 760
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(instructions)
	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	var buttons: Array = []
	for entry: Array in [["Previous", previous_page], ["Next", next_page], ["Back", main.close_help]]:
		var button := UiKit.button(entry[0], main.art)
		button.custom_minimum_size = Vector2(170, 48)
		button.pressed.connect(entry[1])
		button.pressed.connect(main.play_sfx.bind("menu_select"))
		navigation.add_child(button)
		buttons.append(button)
	_column.add_child(navigation)
	for i: int in range(buttons.size()):
		var button: Button = buttons[i]
		button.focus_neighbor_left = button.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		button.focus_neighbor_right = button.get_path_to(buttons[(i + 1) % buttons.size()])
	(buttons[0] as Button).grab_focus()
	main.mobile.revision += 1


func _process(_delta: float) -> void:
	if demo == null:
		return
	var current: Dictionary = demo.snapshot(demo.clock, demo.reduced_motion)
	if current["step"] == _last_step:
		return
	_last_step = current["step"]
	var model := Prompt.render(demo.steps[_last_step]["prompt"], main.control_display())
	_graphic.show_model(model)
	_cue.text = model["description"]
	_cue.accessibility_description = model["description"]


func browser_model() -> Dictionary:
	var page: Dictionary = pages[page_index]
	return {
		"id": page["id"], "title": page["title"], "page": page_index + 1, "count": pages.size(),
		"instructions": page["instructions"],
		"controls": Content.controls(main.control_display()) if page["id"] == "controls" else [],
		"demo": demo.browser_model() if demo != null else {},
	}
