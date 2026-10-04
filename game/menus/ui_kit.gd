extends RefCounted

const SpriteLibrary = preload("res://game/sprite_library.gd")
const TEXT_COLOR := Color(0.92, 0.96, 0.98)
const MUTED_COLOR := Color(0.55, 0.6, 0.66)


static func button(text: String, art: SpriteLibrary) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(320, 64)
	result.focus_mode = Control.FOCUS_ALL
	result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.add_theme_font_size_override("font_size", 24)
	result.add_theme_color_override("font_color", TEXT_COLOR)
	result.add_theme_color_override("font_focus_color", Color(0.75, 1.0, 0.3))
	result.add_theme_color_override("font_disabled_color", MUTED_COLOR)
	var texture := art.texture("ui", "button") if art.has("ui", "button") else null
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		if texture == null:
			continue
		var box := StyleBoxTexture.new()
		box.texture = texture
		box.texture_margin_left = 6
		box.texture_margin_right = 6
		box.texture_margin_top = 6
		box.texture_margin_bottom = 6
		if state == "focus":
			box.modulate_color = Color(1.25, 1.25, 1.0)
		elif state == "disabled":
			box.modulate_color = Color(0.5, 0.5, 0.55)
		result.add_theme_stylebox_override(state, box)
	return result


static func label(text: String, size: int = 24, color: Color = TEXT_COLOR) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


static func icon(texture: Texture2D, scale_factor: int) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = texture.get_size() * scale_factor
	return result


static func column(parent: Control) -> VBoxContainer:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.11)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	return box


static func link_focus(buttons: Array) -> void:
	var enabled: Array = buttons.filter(func(b: Button) -> bool: return not b.disabled)
	for i: int in range(enabled.size()):
		var current: Button = enabled[i]
		current.focus_neighbor_top = current.get_path_to(enabled[(i - 1 + enabled.size()) % enabled.size()])
		current.focus_neighbor_bottom = current.get_path_to(enabled[(i + 1) % enabled.size()])
	if not enabled.is_empty():
		(enabled[0] as Button).grab_focus.call_deferred()
