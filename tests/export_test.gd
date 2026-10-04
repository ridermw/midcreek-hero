extends SceneTree

const SOURCE_DIRECTORIES: Array[String] = [
	"res://art/cel-shift/animations/generated",
	"res://art/cel-shift/animations/previews",
	"res://art/cel-shift/environment/generated",
	"res://art/cel-shift/tiles/generated",
	"res://art/cel-shift/ui/generated",
]
const RUNTIME_TEXTURES: Array[String] = [
	"res://art/cel-shift/animations/frames/man-midcreek/idle/00.png",
	"res://art/cel-shift/animations/frames/man-midcreek/walk/00.png",
	"res://art/cel-shift/environment/layers/far.png",
	"res://art/cel-shift/environment/layers/equipment.png",
	"res://art/cel-shift/environment/layers/floor.png",
	"res://art/cel-shift/tiles/frames/floor/00.png",
	"res://art/cel-shift/hazards/frames/cable-snag/00.png",
	"res://art/cel-shift/props/frames/coolant/00.png",
	"res://art/cel-shift/ui/frames/health-full/00.png",
	"res://art/cel-shift/animations/frames/woman-midcreek/slide/00.png",
]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	for path: String in SOURCE_DIRECTORIES:
		check(not DirAccess.dir_exists_absolute(path), "Source artwork is excluded: " + path)
	for path: String in RUNTIME_TEXTURES:
		check(ResourceLoader.exists(path), "Runtime texture is included: " + path)
	check(
		FileAccess.file_exists("res://art/cel-shift/sprites/manifest.json"),
		"Runtime sprite manifest is included.",
	)
	check(FileAccess.file_exists("res://levels/00-graybox.level"), "Gray box level is included.")
	check(not FileAccess.file_exists("res://art/cel-shift/catalog.json"), "The prompt catalog is excluded.")
	for group: String in ["tiles", "hazards", "props", "ui"]:
		check(
			FileAccess.file_exists("res://art/cel-shift/%s/manifest.json" % group),
			"Sprite manifest is included: " + group,
		)
	print("EXPORT_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
