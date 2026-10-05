extends SceneTree

const SOURCE_DIRECTORIES: Array[String] = [
	"res://docs/evidence",
	"res://art/cel-shift/animations/generated",
	"res://art/cel-shift/animations/previews",
	"res://art/cel-shift/environment/generated",
	"res://art/cel-shift/tiles/generated",
	"res://art/cel-shift/hazards/generated",
	"res://art/cel-shift/props/generated",
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
	"res://art/cel-shift/ui/frames/title/00.png",
	"res://art/cel-shift/ui/icon.png",
	"res://art/cel-shift/animations/frames/woman-midcreek/slide/00.png",
]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	var animations = load("res://game/animation_library.gd").new()
	check(animations.load_manifest(), "Every declared animation frame loads from the export: " + animations.error_message)
	var sprites = load("res://game/sprite_library.gd").new()
	check(sprites.load_all(), "Every declared gameplay sprite loads from the export: " + sprites.error_message)
	check(sprites.load_group("work"), "Every declared work sprite loads from the export: " + sprites.error_message)
	var viewer_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/cel-shift/sprites/manifest.json"))
	if viewer_manifest is Dictionary and viewer_manifest.get("variants") is Dictionary:
		for variant: String in viewer_manifest["variants"]:
			for entry: Dictionary in viewer_manifest["variants"][variant]["frames"]:
				var path := "res://art/cel-shift/sprites/" + String(entry["file"])
				check(load(path) is Texture2D, "Declared viewer texture loads: " + path)
	else:
		check(false, "The viewer manifest declares runtime variants.")
	var backgrounds = load("res://game/background_set.gd").new()
	var environment_root := "res://art/cel-shift/environment/"
	for directory: String in DirAccess.get_directories_at(environment_root):
		if not FileAccess.file_exists(environment_root + directory + "/manifest.json"):
			continue
		check(backgrounds.load_set(directory), "Declared environment loads: " + directory + ": " + backgrounds.error_message)
	for file: String in DirAccess.get_files_at("res://levels"):
		if not file.ends_with(".level"):
			continue
		var parser = load("res://game/level_parser.gd").new()
		var definition: Dictionary = parser.parse(FileAccess.get_file_as_string("res://levels/" + file), file)
		check(not definition.is_empty(), "Exported level parses: " + file)
		if not definition.is_empty():
			check(backgrounds.load_set(definition["header"]["background"]), "Level environment is included: " + file)
			if not file.begins_with("00-"):
				var route := "res://levels/routes/" + file.trim_suffix(".level") + ".route.json"
				check(FileAccess.file_exists(route), "Playable level route is included: " + route)
	var audio = load("res://game/audio_director.gd")
	for path: String in audio.MUSIC.values():
		check(load(path) is AudioStreamOggVorbis, "Declared music stream has the runtime type: " + path)
	for path: String in audio.SFX.values():
		check(load(path) is AudioStream, "Declared audio stream loads: " + path)
	check_source_tree("res://art/cel-shift")
	for group: String in ["animations", "tiles", "hazards", "props", "ui", "work"]:
		var palette := "res://art/cel-shift/%s/palette.png" % group
		check(not ResourceLoader.exists(palette), "Build palette stays outside the download: " + palette)
	for path: String in [
		"res://docs/evidence/animation-cadence/before.json",
		"res://docs/evidence/animation-cadence/after.json",
		"res://tests/route_budgets.json",
	]:
		check(not FileAccess.file_exists(path), "Diagnostic data stays outside the download: " + path)
	check(not ResourceLoader.exists("res://tests/animation_probe.gd"), "The native capture probe is excluded.")
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
	check(FileAccess.file_exists("res://levels/01-cold-aisle.level"), "Level 1 is included.")
	check(FileAccess.file_exists("res://levels/routes/01-cold-aisle.route.json"), "The level 1 route is included.")
	check(ResourceLoader.exists("res://game/main.tscn"), "The main scene is included.")
	check(ResourceLoader.exists("res://audio/music/level1.ogg"), "Level 1 music is included.")
	check(FileAccess.file_exists("res://levels/02-hot-aisle.level"), "Level 2 is included.")
	check(FileAccess.file_exists("res://levels/03-cable-jungle.level"), "Level 3 is included.")
	check(FileAccess.file_exists("res://levels/04-power-room.level"), "Level 4 is included.")
	check(FileAccess.file_exists("res://levels/05-outage-night.level"), "Level 5 is included.")
	check(FileAccess.file_exists("res://levels/06-cooling-gallery.level"), "Cooling Gallery is included.")
	check(ResourceLoader.exists("res://audio/music/level5.ogg"), "Level 5 music is included.")
	for texture: String in [
		"res://art/cel-shift/environment/hot-aisle/far.png",
		"res://art/cel-shift/environment/outage-night/equipment.png",
		"res://art/cel-shift/hazards/frames/heat-vent/00.png",
		"res://art/cel-shift/props/frames/dimm/00.png",
	]:
		check(ResourceLoader.exists(texture), "Runtime texture is included: " + texture)
	check(not DirAccess.dir_exists_absolute("res://art/cel-shift/environment/hot-aisle/generated"), "Background sources are excluded.")
	check(FileAccess.file_exists("res://audio/sources.json"), "Audio provenance is included.")
	check(ResourceLoader.exists("res://audio/sfx/jump.wav") or ResourceLoader.exists("res://audio/sfx/jump.ogg"), "The jump sound is included.")
	for group: String in ["tiles", "hazards", "props", "ui"]:
		check(
			FileAccess.file_exists("res://art/cel-shift/%s/manifest.json" % group),
			"Sprite manifest is included: " + group,
		)
	print("EXPORT_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_source_tree(path: String) -> void:
	for directory: String in DirAccess.get_directories_at(path):
		check(directory not in ["generated", "prompts", "previews", "sheets"], "Source directory is absent: " + path.path_join(directory))
		check_source_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		check(
			not file.ends_with(".metadata.json") and not file.ends_with(".mock.md")
			and file not in ["catalog.json", "palette.png", "preview.png", "preview.html"],
			"Source file is absent: " + path.path_join(file),
		)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
