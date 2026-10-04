extends Control

const UiKit = preload("res://game/menus/ui_kit.gd")

var main: Node


func build(owner_main: Node) -> void:
	main = owner_main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.column(self)
	box.add_child(UiKit.label("Settings", 30))
	var focusables: Array = []
	for entry: Array in [["Music", "music_volume"], ["Sound effects", "sfx_volume"]]:
		box.add_child(UiKit.label(entry[0], 22, UiKit.MUTED_COLOR))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(main.save.settings[entry[1]])
		slider.custom_minimum_size = Vector2(320, 32)
		slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_ALL
		var key: String = entry[1]
		slider.value_changed.connect(func(value: float) -> void: main.set_volume(key, value))
		box.add_child(slider)
		focusables.append(slider)
	var back := UiKit.button("Back", main.art)
	back.pressed.connect(func() -> void: main.go_to("title"))
	box.add_child(back)
	focusables.append(back)
	for i: int in range(focusables.size()):
		var current: Control = focusables[i]
		current.focus_neighbor_top = current.get_path_to(focusables[(i - 1 + focusables.size()) % focusables.size()])
		current.focus_neighbor_bottom = current.get_path_to(focusables[(i + 1) % focusables.size()])
	(focusables[0] as Control).grab_focus.call_deferred()
