extends Node2D

const ART_ROOT := "res://art/cel-shift/environment/layers/"
const LAYERS: Array[String] = ["far", "equipment", "floor"]
const CHUNK_WIDTH := 640
const CHUNKS := 4
const FLOOR_TOP := 300
const FAR_SCROLL := 0.16

var error_message: String = ""
var far_layer: Node2D


func load_art() -> bool:
	var textures: Array[Texture2D] = []
	for layer: String in LAYERS:
		var path := ART_ROOT + layer + ".png"
		if not ResourceLoader.exists(path):
			return _fail("Pending artwork: missing or unimported environment layer.\n" + path)
		var texture := load(path) as Texture2D
		var expected_size := Vector2(640, 96 if layer == "floor" else 360)
		if texture == null or texture.get_size() != expected_size:
			return _fail(
				(
					"Environment layer %s must be %dx%d."
					% [
						layer,
						int(expected_size.x),
						int(expected_size.y),
					]
				)
			)
		textures.append(texture)
	for index: int in range(LAYERS.size()):
		var layer_node := Node2D.new()
		layer_node.name = LAYERS[index].capitalize()
		layer_node.z_index = -30 + index * 10
		add_child(layer_node)
		if index == 0:
			far_layer = layer_node
		for chunk: int in range(CHUNKS):
			var tile := Sprite2D.new()
			tile.name = "Chunk%d" % chunk
			tile.texture = textures[index]
			tile.centered = false
			tile.position = Vector2(chunk * CHUNK_WIDTH, FLOOR_TOP if index == 2 else 0)
			tile.flip_h = index != 2 and chunk % 2 == 1
			layer_node.add_child(tile)
	return true


func follow_camera(camera_x: float) -> void:
	if far_layer != null:
		far_layer.position.x = roundf((camera_x - 320.0) * (1.0 - FAR_SCROLL))


func _fail(message: String) -> bool:
	error_message = message
	push_error(message)
	return false
