extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var path := "res://game/tasks/work_inventory.gd"
	check(ResourceLoader.exists(path), "Expansion inventory exists.")
	if not ResourceLoader.exists(path):
		finish()
		return
	var script: Script = load(path)
	var bag = script.new()
	check(bag.register_item("rack:0", "chassis") == "", "Register destination specific chassis.")
	check(bag.register_item("rack:1", "psu") == "", "Register destination specific supply.")
	check(bag.register_item("other:1", "psu") == "", "Matching kinds retain separate destinations.")
	check(not bag.register_item("rack:0", "dimm").is_empty(), "Duplicate identities are rejected.")
	check(not bag.register_item("", "seal").is_empty(), "Empty identities are rejected.")
	check(bag.take("missing") == "unknown_item", "Unknown source reports an error.")
	check(bag.take("rack:1") == "taken", "Collect a component.")
	var supply: Dictionary = bag.capture_state()
	check(bag.take("rack:1") == "already_carried", "A source cannot duplicate a carried item.")
	check(bag.consume("other:1") == "wrong_item", "The same kind cannot serve another task.")
	check(bag.take("rack:0") == "swapped", "Exchange an early supply for the required chassis.")
	check(bag.available("rack:1"), "Exchange returns the supply to its original source.")
	check(bag.consume("rack:0") == "consumed", "Only the carried destination can consume it.")
	check(not bag.available("rack:0"), "Installed component is no longer available.")
	check(bag.take("rack:0") == "consumed", "An installed component cannot be collected again.")
	var installed: Dictionary = bag.capture_state()
	bag.restore_state(supply)
	check(bag.carried == "rack:1" and bag.available("rack:0"), "Checkpoint restores inventory and undone installation together.")
	check(bag.consume("rack:1") == "consumed", "Restored carried component can be installed.")
	check(bag.take("other:1") == "taken", "Consumption frees the carrying slot.")
	bag.restore_state(installed)
	check(bag.carried.is_empty() and not bag.available("rack:0"), "Later checkpoint retains installation.")
	check(bag.available("rack:1") and bag.available("other:1"), "Later checkpoint restores unused resources.")
	check(installed["consumed"] == ["rack:0"], "Snapshots do not alias consumed item arrays.")
	finish()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("WORK_INVENTORY_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
