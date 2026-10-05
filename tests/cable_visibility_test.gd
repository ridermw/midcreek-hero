extends SceneTree

const Snag := preload("res://game/hazards/cable_snag.gd")
const Moving := preload("res://game/hazards/moving_snag.gd")
const Art := preload("res://game/sprite_library.gd")
const Builder := preload("res://game/level_builder.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	var art := Art.new()
	check(art.load_all(), "Production hazard textures load.")
	for entry: Array in [[Snag, "cable-snag"], [Moving, "moving-snag"]]:
		var hazard: Node2D = entry[0].new()
		hazard.position = Vector2(100, 200)
		var bounds: Rect2 = hazard.hit_rect()
		check(bounds.has_point(Vector2(125, 192)), "The enlarged cable silhouette is dangerous near its visible outer edge.")
		check(not bounds.has_point(Vector2(133, 192)), "Clear space beside the cable remains safe.")
		var constants: Dictionary = entry[0].get_script_constant_map()
		check(constants.has("ART_RECT"), "Cable draw geometry is shared with its collision regression.")
		if not constants.has("ART_RECT"):
			hazard.free()
			continue
		var draw_rect: Rect2 = constants["ART_RECT"]
		var silhouette := Rect2()
		for i: int in range(art.frame_count("hazards", entry[1])):
			var texture: Texture2D = art.texture("hazards", entry[1], i)
			var source: Rect2 = texture.get_image().get_used_rect()
			var scale := draw_rect.size / texture.get_size()
			var rendered := Rect2(hazard.position + draw_rect.position + source.position * scale, source.size * scale)
			silhouette = rendered if i == 0 else silhouette.merge(rendered)
		check(bounds == silhouette, "Damage bounds match the full authored silhouette at double pixel scale: " + entry[1])
		hazard.free()
	var parent := Node2D.new()
	var builder := Builder.new()
	builder.art = art
	for script in [Snag, Moving]:
		var node: Node2D = builder._add(parent, script.new(), Vector2i(2, 3))
		check(node.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Authored cable hazards keep nearest sampling at double scale.")
	parent.free()
	print("CABLE_VISIBILITY_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
