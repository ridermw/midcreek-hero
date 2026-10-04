extends Control

const UiKit = preload("res://game/menus/ui_kit.gd")

var main: Node


func build(owner_main: Node) -> void:
	main = owner_main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.column(self)
	box.add_child(UiKit.label("Choose your technician", 30))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	box.add_child(row)
	var buttons: Array = []
	for character: String in ["man", "woman"]:
		var card := VBoxContainer.new()
		var frames: SpriteFrames = main.animations.variants[StringName(character + "-midcreek")]
		card.add_child(UiKit.icon(frames.get_frame_texture(&"idle", 0), 1))
		var choose := UiKit.button(character.capitalize(), main.art)
		choose.custom_minimum_size = Vector2(200, 56)
		choose.pressed.connect(main.choose_character.bind(character))
		card.add_child(choose)
		row.add_child(card)
		buttons.append(choose)
	var back := UiKit.button("Back", main.art)
	back.pressed.connect(func() -> void: main.go_to("title"))
	box.add_child(back)
	buttons.append(back)
	UiKit.link_focus(buttons)
	if main.save.character == "woman":
		(buttons[1] as Button).grab_focus.call_deferred()
