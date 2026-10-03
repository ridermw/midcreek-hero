extends SceneTree

const World = preload("res://game/world.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const WORLD_SCENE := preload("res://game/world.tscn")
const FRAME := preload("res://art/cel-shift/animations/frames/man-midcreek/idle/00.png")

class WorldFixture:
	extends "res://game/world.gd"

	func _ready() -> void:
		pass

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var world := WORLD_SCENE.instantiate() as World
	world.set_script(WorldFixture)
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	for hero in world.heroes:
		var frames := SpriteFrames.new()
		for clip in HeroAnimations.CLIPS:
			frames.add_animation(clip)
			frames.add_frame(clip, FRAME)
		world.library.variants[hero.variant_name()] = frames
		hero.configure(world.library)
		hero.set_physics_process(false)
	for index: int in range(world.heroes.size()):
		world.active_index = index
		var hero := world.hero_active()
		hero.set_active(true)
		for repaired: bool in [false, true]:
			world.rack.repaired = repaired
			for offset: float in [-45.0, 45.0]:
				hero.position.x = world.rack.position.x + offset
				for clip: StringName in [&"primary", &"secondary"]:
					hero.sprite.flip_h = offset < 0.0
					world.perform_action(clip)
					check(hero.sprite.flip_h == (offset > 0.0), "Local tool action faces R12.")
					check(hero.action == clip, "Local action starts the requested clip.")
					check(
						(world.repairing_hero == hero) == (clip == &"primary" and not repaired),
						"Only primary on a faulted rack starts repair.",
					)
		for clip: StringName in [&"reaction", &"signal"]:
			hero.sprite.flip_h = false
			world.perform_action(clip)
			check(not hero.sprite.flip_h, "Non-tool action preserves facing.")
		for offset: float in [-100.0, 100.0]:
			hero.position.x = world.rack.position.x + offset
			for clip: StringName in [&"primary", &"secondary"]:
				hero.sprite.flip_h = offset < 0.0
				world.perform_action(clip)
				check(hero.sprite.flip_h == (offset < 0.0), "Remote tool action preserves facing.")
				check(world.repairing_hero == null, "Remote tool action does not start repair.")
		hero.set_active(false)
	world.queue_free()
	await process_frame
	print("LOCAL_ACTION_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
