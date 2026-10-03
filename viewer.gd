extends Control

const ART_ROOT := "res://art/cel-shift/sprites/"
const VARIANTS: Array[String] = [
	"man-midcreek", "woman-midcreek", "man-hybrid", "woman-hybrid",
]

var textures: Array[Texture2D] = []
var captions: PackedStringArray = []
var current_index: int = 0

@onready var image: TextureRect = %Image
@onready var caption: Label = %Caption
@onready var hint: Label = %Hint


func _ready() -> void:
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(ART_ROOT + "manifest.json"))
	if error != OK or not parser.data is Dictionary:
		_show_error("Could not read the sprite manifest.")
		return
	var manifest: Dictionary = parser.data
	for variant: String in VARIANTS:
		for frame: Dictionary in manifest["variants"][variant]["frames"]:
			var texture := load(ART_ROOT + String(frame["file"])) as Texture2D
			if texture == null:
				_show_error("Could not load sprite: " + String(frame["file"]))
				return
			textures.append(texture)
			captions.append("%s - %s" % [
				variant.replace("midcreek", "normal").replace("-", " ").capitalize(),
				String(frame["name"]).replace("-", " ").capitalize(),
			])
	if textures.is_empty():
		_show_error("No sprites were found in the manifest.")
		return
	show_current()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			if not textures.is_empty():
				current_index = (current_index + 1) % textures.size()
				show_current()
				get_viewport().set_input_as_handled()


func show_current() -> void:
	image.texture = textures[current_index]
	caption.text = captions[current_index]
	hint.text = "%d / %d   -   Space: next image" % [current_index + 1, textures.size()]


func _show_error(message: String) -> void:
	push_error(message)
	textures.clear()
	caption.text = message
	hint.text = "Reload after checking the project assets."
