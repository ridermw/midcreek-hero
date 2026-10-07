extends SceneTree

const CAPTURE_PROBE := preload("res://tests/animation_probe.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var valid_actions: Dictionary = CAPTURE_PROBE.parse_actions("run,idle-run")
	check(valid_actions["ok"] and valid_actions["actions"] == PackedStringArray(["run", "idle-run"]), "The native capture probe accepts known action selectors.")
	var invalid_actions: Dictionary = CAPTURE_PROBE.parse_actions("run,idle-rnu")
	check(not invalid_actions["ok"] and String(invalid_actions["error"]).contains("idle-rnu"), "The native capture probe rejects unknown action selectors.")
	print("ANIMATION_PROBE_ARGS_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
