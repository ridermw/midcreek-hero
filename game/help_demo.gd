extends Control

var steps: Array = []
var frames: SpriteFrames
var art: RefCounted
var reduced_motion := false
var clock := 0.0


func configure(page: Dictionary, owner_main: Node) -> void:
	steps = page["steps"]
	art = owner_main.art
	frames = owner_main.animations.variants[StringName(owner_main.save.character + "-midcreek")]
	custom_minimum_size = Vector2(520, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if OS.has_feature("web"):
		reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))


func duration() -> float:
	var total := 0.0
	for phase: Dictionary in steps:
		total += phase["seconds"]
	return total


func snapshot(seconds: float, static_motion := false) -> Dictionary:
	var remaining := fposmod(seconds, duration()) if not static_motion else 0.0
	for i: int in range(steps.size()):
		var phase: Dictionary = steps[i]
		if remaining < phase["seconds"]:
			var clip := StringName(phase["clip"])
			var frame := int(remaining * frames.get_animation_speed(clip)) % frames.get_frame_count(clip)
			return {"step": i, "frame": "%s:%d" % [clip, frame], "x": lerpf(phase["from"], phase["to"], remaining / phase["seconds"])}
		remaining -= phase["seconds"]
	return {}


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	if steps.is_empty():
		return
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	draw_line(Vector2(16, 163), Vector2(504, 163), Color(0.3, 0.4, 0.45), 2)
	var sample := snapshot(clock, reduced_motion)
	var phase: Dictionary = steps[sample["step"]]
	for object: Dictionary in phase["props"]:
		var texture: Texture2D = art.texture(object["group"], object["asset"])
		var dimensions := texture.get_size() * 1.35
		draw_texture_rect(texture, Rect2(Vector2(object["x"] - dimensions.x / 2, 162 - dimensions.y), dimensions), false)
		if not object["label"].is_empty():
			draw_string(ThemeDB.fallback_font, Vector2(object["x"] - 12, 20), object["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var split: PackedStringArray = sample["frame"].split(":")
	draw_texture_rect(frames.get_frame_texture(StringName(split[0]), int(split[1])), Rect2(sample["x"] - 62.4, 51.6, 124.8, 124.8), false)
	if phase["carry"]:
		draw_texture_rect(art.texture("props", "psu"), Rect2(sample["x"] + 22, 106, 22, 22), false)


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.08)
	style.set_corner_radius_all(10)
	return style
