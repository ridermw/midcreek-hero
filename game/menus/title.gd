extends Control

const UiKit = preload("res://game/menus/ui_kit.gd")

var main: Node


func build(owner_main: Node) -> void:
	main = owner_main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.column(self)
	box.add_child(UiKit.icon(main.art.texture("ui", "title"), 2))
	box.add_child(UiKit.label("Keep the data hall online.", 22, UiKit.MUTED_COLOR))
	var start := UiKit.button("Start", main.art)
	start.pressed.connect(func() -> void: main.go_to("character_select"))
	box.add_child(start)
	box.add_child(UiKit.label("Press any key or button", 18, UiKit.MUTED_COLOR))
	UiKit.link_focus([start])
