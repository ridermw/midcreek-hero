extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var path := "res://game/mobile_input.gd"
	check(ResourceLoader.exists(path), "Mobile input provides independent held state and physics frame edges.")
	if not ResourceLoader.exists(path):
		finish()
		return
	var input = load(path).new()
	input.set_action(&"move_right", true)
	input.set_action(&"jump", true)
	input.set_action(&"jump", false)
	input.advance()
	check(input.held(&"move_right"), "Movement remains held during a short jump tap.")
	check(input.pressed(&"jump"), "A complete tap between physics frames still jumps.")
	check(input.pressed(&"jump"), "Player and cable tasks see the same press.")
	check(not input.held(&"jump"), "A released jump does not extend jump height.")
	input.advance()
	check(not input.pressed(&"jump"), "A tap only produces one frame edge.")
	input.set_action(&"repair", true)
	input.advance()
	check(input.held(&"repair") and input.pressed(&"repair"), "Repair supports held and discrete actions.")
	input.set_action(&"repair", true)
	input.advance()
	check(not input.pressed(&"repair"), "Duplicate presses do not repeat task actions.")
	input.clear()
	check(not input.held(&"repair") and not input.held(&"move_right"), "Cancellation releases all mobile actions.")
	input.advance()
	check(not input.pressed(&"repair"), "Cancellation removes pending presses.")
	check(not input.set_action(&"unknown", true), "Unknown actions are rejected.")
	finish()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("MOBILE_INPUT_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
