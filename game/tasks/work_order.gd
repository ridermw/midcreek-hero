extends RefCounted

const ControlPrompt = preload("res://game/control_prompt.gd")
const Inventory = preload("res://game/tasks/work_inventory.gd")
const UNITS := {
	"run_cable": preload("res://game/tasks/cable_work.gd"),
	"assemble_rack": preload("res://game/tasks/rack_work.gd"),
	"extinguish_fire": preload("res://game/tasks/fire_work.gd"),
	"restore_cooling": preload("res://game/tasks/cooling_work.gd"),
	"contain_leak": preload("res://game/tasks/leak_work.gd"),
	"restore_power": preload("res://game/tasks/power_work.gd"),
}

var definition: Dictionary
var inventory: Inventory
var unit: RefCounted
var done := false
var error_message := ""


func _init(task: Dictionary, bag: Inventory) -> void:
	definition = task.duplicate(true)
	inventory = bag
	var kind: String = task["type"]
	unit = UNITS[kind].new(task["sites"].size()) if kind == "run_cable" else UNITS[kind].new()
	for index: int in range(task["resources"].size()):
		var error := bag.register_item(resource_id(index), task["resources"][index]["kind"])
		if not error.is_empty():
			error_message = error
			return


func resource_id(index: int) -> String:
	return "%s:%d" % [definition["id"], index]


func collect(index: int) -> String:
	if index < 0 or index >= definition["resources"].size():
		return "unknown_item"
	if definition["type"] == "extinguish_fire" and unit.equipped:
		unit.refill()
		return "refilled"
	return inventory.take(resource_id(index))


func prompt(site: int) -> Dictionary:
	if site < 0 or site >= definition["sites"].size():
		return _blocked("Invalid work site.")
	if done:
		return _blocked("Work complete")
	match definition["type"]:
		"run_cable":
			if site != unit.next_point:
				return _blocked("Connect point %d first" % (unit.next_point + 1))
			if site == 0 and not _carrying("spool"):
				return _need("spool")
			return _action("repair", "press", "Connect cable point %d" % (site + 1))
		"assemble_rack":
			if "chassis" not in unit.installed and not _carrying("chassis"):
				return _need("chassis")
			for component: String in ["chassis", "psu", "dimm"]:
				if component not in unit.installed and _carrying(component):
					return _action("repair", "press", "Install " + component)
			for component: String in ["chassis", "psu", "dimm"]:
				if component not in unit.installed:
					return _need(component)
			return _action("diagnose", "hold", "Test assembled rack")
		"extinguish_fire":
			if not unit.equipped and not _carrying("extinguisher"):
				return _need("extinguisher")
			if unit.equipped and unit.charge <= 0.0:
				return _blocked("Refill extinguisher at column %d" % (definition["resources"][0]["cell"][0] + 1))
			return _action("repair", "hold", "Extinguish fire")
		"restore_cooling":
			if not unit.diagnosed:
				return _action("diagnose", "press", "Diagnose cooling") if site == 0 else _blocked("Diagnose controller at " + _where(0))
			if not unit.valve_open:
				return _action("repair", "press", "Open cooling valve") if site == 1 else _blocked("Open valve at " + _where(1))
			if site != 0:
				return _blocked("Return to controller at " + _where(0))
			if not unit.filter_installed:
				return _action("repair", "press", "Install filter") if _carrying("filter") else _need("filter")
			return _action("repair", "hold", "Start and verify fan")
		"contain_leak":
			if not unit.valve_closed:
				return _action("repair", "press", "Close leak supply") if site == 0 else _blocked("Close valve at " + _where(0))
			if not unit.seal_installed:
				if site != 0:
					return _blocked("Install seal at " + _where(0))
				return _action("repair", "press", "Install seal") if _carrying("seal") else _need("seal")
			return _action("repair", "hold", "Drain contained leak") if site == 1 else _blocked("Operate drain at " + _where(1))
		"restore_power":
			if not unit.isolated:
				return _action("repair", "press", "Isolate power branch")
			if not unit.fuse_installed:
				return _action("repair", "press", "Install fuse") if _carrying("fuse") else _need("fuse")
			if not unit.continuity_passed:
				return _action("diagnose", "hold", "Test branch continuity")
			return _action("repair", "press", "Energize power branch")
	return _blocked("Unknown work type.")


func step(site: int, repair_held: bool, repair_pressed: bool, diagnose_held: bool, diagnose_pressed: bool, delta: float) -> Dictionary:
	var model := prompt(site)
	var response := {"prompt": model, "locked": false, "action": &"", "completed": false, "result": ""}
	if not is_finite(delta) or delta < 0.0:
		response["result"] = "invalid_delta"
		return response
	if model["action"].is_empty():
		cancel()
		return response
	var held := repair_held if model["action"] == "repair" else diagnose_held
	var pressed := repair_pressed if model["action"] == "repair" else diagnose_pressed
	var active := held if model["intent"] == "hold" else pressed
	if not active:
		cancel()
		return response
	response["result"] = _execute(site, delta)
	response["locked"] = model["intent"] == "hold"
	response["action"] = &"primary" if model["action"] == "repair" else &"secondary"
	done = _is_complete()
	response["completed"] = done
	response["prompt"] = prompt(site)
	if not done and model["intent"] == "hold" and response["prompt"]["action"] == model["action"] and response["prompt"]["text"] == model["text"]:
		response["prompt"] = ControlPrompt.make(model["action"], "hold", model["text"], "Working...", true)
	return response


func cancel() -> void:
	if definition["type"] in ["assemble_rack", "restore_cooling", "restore_power"]:
		unit.cancel()


func capture_state() -> Dictionary:
	return unit.capture_state()


func restore_state(state: Dictionary) -> void:
	unit.restore_state(state)
	done = _is_complete()


func _execute(site: int, delta: float) -> String:
	match definition["type"]:
		"run_cable":
			if site == 0:
				unit.collect_spool()
				_consume("spool")
			return unit.place(site)
		"assemble_rack":
			for component: String in ["chassis", "psu", "dimm"]:
				if component not in unit.installed and _carrying(component):
					var outcome: String = unit.install(component)
					if outcome == "installed":
						_consume(component)
					return outcome
			return unit.test_work(delta)
		"extinguish_fire":
			if not unit.equipped:
				_consume("extinguisher")
				unit.refill()
			return unit.suppress(delta)
		"restore_cooling":
			if not unit.diagnosed:
				return unit.diagnose()
			if not unit.valve_open:
				return unit.open_valve()
			if not unit.filter_installed:
				var outcome: String = unit.install_filter()
				if outcome == "installed":
					_consume("filter")
				return outcome
			return unit.verify(delta)
		"contain_leak":
			if not unit.valve_closed:
				return unit.close_valve()
			if not unit.seal_installed:
				var outcome: String = unit.install_seal()
				if outcome == "installed":
					_consume("seal")
				return outcome
			return unit.drain(delta)
		"restore_power":
			if not unit.isolated:
				return unit.isolate()
			if not unit.fuse_installed:
				var outcome: String = unit.install_fuse()
				if outcome == "installed":
					_consume("fuse")
				return outcome
			if not unit.continuity_passed:
				return unit.test_continuity(delta)
			return unit.energize()
	return "unknown_task"


func _is_complete() -> bool:
	match definition["type"]:
		"run_cable": return unit.next_point == unit.point_count
		"assemble_rack": return unit.tested
		"extinguish_fire": return unit.intensity <= 0.0
		"restore_cooling": return unit.running
		"contain_leak": return unit.drained_seconds >= unit.DRAIN_SECONDS
		"restore_power": return unit.energized
	return false


func _carrying(kind: String) -> bool:
	for index: int in range(definition["resources"].size()):
		if definition["resources"][index]["kind"] == kind:
			return inventory.carried == resource_id(index)
	return false


func _consume(kind: String) -> void:
	for index: int in range(definition["resources"].size()):
		if definition["resources"][index]["kind"] == kind:
			var outcome := inventory.consume(resource_id(index))
			if outcome != "consumed":
				error_message = "Resource consumption failed: " + outcome
			return


func _need(kind: String) -> Dictionary:
	for resource: Dictionary in definition["resources"]:
		if resource["kind"] == kind:
			return _blocked("Bring %s from column %d" % [kind, resource["cell"][0] + 1])
	return _blocked("Missing resource definition: " + kind)


func _where(site: int) -> String:
	return "column %d" % (definition["sites"][site][0] + 1)


func _blocked(message: String) -> Dictionary:
	return ControlPrompt.make("", "", "", message)


func _action(action: String, intent: String, text: String) -> Dictionary:
	return ControlPrompt.make(action, intent, text)
