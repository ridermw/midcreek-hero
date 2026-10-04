extends Control

const UiKit = preload("res://game/menus/ui_kit.gd")

var main: Node
var stars: int = 0


func build(owner_main: Node, data: Dictionary) -> void:
	main = owner_main
	stars = int(data["result"]["stars"])
	var result: Dictionary = data["result"]
	var level_id: String = data["level_id"]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.column(self)
	box.add_child(UiKit.label("Work order complete", 32))
	box.add_child(UiKit.label(main.level_name(level_id), 22, UiKit.MUTED_COLOR))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for star: int in range(3):
		row.add_child(UiKit.icon(main.art.texture("ui", "star-on" if star < stars else "star-off"), 3))
	box.add_child(row)
	var seconds := int(ceilf(float(result["elapsed"])))
	box.add_child(UiKit.label("Time %d:%02d   Hits %d" % [seconds / 60, seconds % 60, int(result["hits"])], 22))
	if int(result["optional_total"]) > 0:
		box.add_child(
			UiKit.label("Optional work: %d of %d" % [int(result["optional_done"]), int(result["optional_total"])], 20)
		)
	var buttons: Array = []
	var next_id: String = main.next_playable(level_id)
	if not next_id.is_empty():
		var next := UiKit.button("Next work order", main.art)
		next.pressed.connect(main.start_level.bind(next_id))
		box.add_child(next)
		buttons.append(next)
	var retry := UiKit.button("Retry", main.art)
	retry.pressed.connect(main.start_level.bind(level_id))
	box.add_child(retry)
	buttons.append(retry)
	var back := UiKit.button("Level select", main.art)
	back.pressed.connect(func() -> void: main.go_to("level_select"))
	box.add_child(back)
	buttons.append(back)
	UiKit.link_focus(buttons)
