extends Control

const UiKit = preload("res://game/menus/ui_kit.gd")

var main: Node
var buttons: Dictionary = {}


func build(owner_main: Node) -> void:
	main = owner_main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.column(self)
	box.add_child(UiKit.label("Work orders", 30))
	var ordered: Array = []
	for level_id: String in main.level_ids():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var unlocked: bool = main.save.is_unlocked(level_id)
		var title := "%s  %s" % [level_id, main.level_name(level_id)] if unlocked else "%s  Locked" % level_id
		var play := UiKit.button(title, main.art)
		play.custom_minimum_size = Vector2(420, 56)
		play.disabled = not unlocked
		play.pressed.connect(main.start_level.bind(level_id))
		row.add_child(play)
		for star: int in range(3):
			var icon_name := "star-on" if star < main.save.stars(level_id) else "star-off"
			row.add_child(UiKit.icon(main.art.texture("ui", icon_name), 1))
		box.add_child(row)
		buttons[level_id] = play
		ordered.append(play)
	var back := UiKit.button("Back", main.art)
	back.pressed.connect(func() -> void: main.go_to("character_select"))
	box.add_child(back)
	ordered.append(back)
	UiKit.link_focus(ordered)
