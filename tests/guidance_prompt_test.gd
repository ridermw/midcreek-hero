extends SceneTree

const LEVEL := preload("res://game/level.tscn")
const Hud = preload("res://game/hud.gd")
const Parser = preload("res://game/level_parser.gd")
var checks := 0
var failures := 0
var level: Node


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var hud: Node = Hud.new()
	root.add_child(hud)
	check(hud.has_method("prompt_model"), "HUD exposes one structured prompt model.")
	if hud.has_method("prompt_model"):
		hud.set_prompt({"action": "repair", "intent": "hold", "text": "repair", "status": ""})
		check(visible_prompt_text(hud) == "E Hold", "Live hold guidance shows only the keycap and Hold indicator.")
		check(hud.prompt_label.accessibility_description == "Hold E to repair", "Live compact hints retain the full accessible purpose.")
		hud.set_prompt({"action": "jump", "intent": "press", "text": "jump cables", "status": ""})
		check(visible_prompt_text(hud) == "Space", "Live press guidance shows only its graphical key, not redundant prose.")
		hud.set_prompt({"action": "repair", "intent": "hold", "text": "repair", "status": ""})
		check(hud.prompt_model()["graphic"] == {"shape": "keycap", "label": "E"}, "Keyboard prompt has one graphical keycap.")
		hud.control_display = "gamepad"
		check(hud.prompt_model()["graphic"] == {"shape": "button", "label": "X"}, "Gamepad preference resolves the same action to X.")
		hud.control_display = "touch"
		check(hud.prompt_model()["description"] == "Hold Repair to repair", "Touch uses an action name rather than keyboard prose replacement.")
		hud.set_prompt({"action": "", "intent": "", "text": "", "status": "Bring the PSU"})
		check(hud.prompt_model()["action"] == "" and hud.prompt_model()["description"] == "Bring the PSU", "Status is independent and has no action cue.")
		check(visible_prompt_text(hud) == "Bring the PSU", "Nonaction status stays visible in the live HUD.")
		await fixture("hot_aisle")
		for rack: Node in level.entities["racks"]:
			level.level["header"]["prompts"] = [{"x": floori(rack.position.x / 32.0), "task": rack.task_id, "action": "diagnose" if rack.kind == "diagnose_repair" else "repair", "intent": "press" if rack.kind == "diagnose_repair" else "hold", "text": "work on this rack", "status": ""}]
			level.player.position = rack.position
			level.step(0.01)
			if rack.kind == "fetch":
				check(level.hud.prompt_model()["action"] == "" and level.hud.prompt_model()["status"].contains("PSU"), "Missing part preserves its notice, not a misleading repair cue.")
			if rack.kind == "diagnose_repair":
				check(level.hud.prompt_model()["action"] == "diagnose" and level.hud.prompt_model()["intent"] == "press", "Diagnosis comes before repair.")
				level.action_override = {"diagnose": true}
				level.step(0.01)
				check(level.hud.prompt_model()["action"] == "" and level.hud.prompt_model()["status"] == "Diagnosing...", "Diagnosis in flight shows status only.")
				level.action_override = {}
				level.step(0.9)
				level.step(0.01)
				check(level.hud.prompt_model()["action"] == "repair" and level.hud.prompt_model()["intent"] == "hold", "Finished diagnosis offers just hold repair.")
				level.player.position.x += 64
				level.step(0.01)
				check(level.hud.prompt_model()["action"] != "diagnose", "Leaving a diagnosed rack cannot resurrect its authored diagnose cue.")
				level.player.position = rack.position
			level.carried_part = rack.task_id
			level.action_override = {"repair": true}
			level.step(0.01)
			check(level.hud.prompt_model()["held"], "Held repair keeps its cue steady.")
			level.step(3.0)
			check(level.hud.prompt_model()["action"] == "", "Rack completion immediately removes its cue.")
			level.action_override = {}
			level.step(0.01)
			check(level.hud.prompt_model()["action"] == "", "Authored task guidance cannot resurrect a completed rack cue.")
		await fixture("cable_jungle")
		var port: Node = level.entities["ports"][0]
		level.player.position = port.position
		level.level["header"]["prompts"] = [{"x": floori(port.position.x / 32.0), "task": port.task_id, "action": "repair", "intent": "press", "text": "reseat the cable", "status": ""}]
		level.step(0.01)
		check(level.hud.prompt_model()["action"] == "repair", "Idle cable starts with repair.")
		tap("repair")
		for action: StringName in port.sequence_for(port.task_id):
			check(level.hud.prompt_model()["action"] == String(action) and level.hud.prompt_model()["intent"] == "press", "Cable exposes only its current sequence action.")
			tap(String(action), false)
		check(level.hud.prompt_model()["action"] == "", "Cable completion immediately clears the last button.")
		level.action_override = {}
		level.step(0.01)
		check(level.hud.prompt_model()["action"] == "", "Authored cable guidance remains clear after completion.")
		await fixture("power_room")
		var panels: Array = level.entities["switches"]
		level.player.position = panels[1].position
		level.step(0.01)
		check(level.hud.prompt_model()["action"] == "repair" and level.hud.prompt_model()["intent"] == "press", "Switch has press intent.")
		tap("repair")
		check(level.hud.prompt_model()["action"] == "" and level.hud.prompt_model()["status"].contains("Wrong order"), "Wrong-order status stays visible without a misleading action.")
		level.level["header"]["prompts"] = [{"x": floori(panels[0].position.x / 32.0), "task": panels[0].task_id, "action": "repair", "intent": "press", "text": "throw switch 1", "status": ""}]
		level.player.position = panels[0].position
		tap("repair")
		check(level.hud.prompt_model()["action"] == "", "Throwing switch 1 does not resurrect a spatial switch-1 cue.")
		level._finish()
		check(level.hud.prompt_model()["action"] == "", "Finishing clears guidance.")
		level.free()
	var parser := Parser.new()
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/controller.level")
	var data: Dictionary = JSON.parse_string(raw.split("\n---\n")[0])
	data["prompts"] = [{"x": 1, "action": "self_destruct", "intent": "press", "text": "Do it", "status": ""}]
	check(parser.parse(JSON.stringify(data) + "\n---\n" + raw.split("\n---\n")[1], "test").is_empty(), "Authored unknown actions are rejected, not inferred from prose.")
	data["prompts"][0]["action"] = "repair"
	data["prompts"][0]["intent"] = "mash"
	check(parser.parse(JSON.stringify(data) + "\n---\n" + raw.split("\n---\n")[1], "test").is_empty(), "Authored invalid intent is rejected.")
	data["prompts"][0]["intent"] = "hold"
	data["prompts"][0]["task"] = "missing"
	check(parser.parse(JSON.stringify(data) + "\n---\n" + raw.split("\n---\n")[1], "test").is_empty(), "Authored task references must exist.")
	hud.free()
	print("GUIDANCE_PROMPT_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func fixture(name: String) -> void:
	if is_instance_valid(level):
		level.free()
	level = LEVEL.instantiate()
	level.level_path = "res://tests/fixtures/" + name + ".level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.use_action_override = true
	await process_frame


func tap(action: String, release_after := true) -> void:
	level.action_override = {}
	level.step(0.01)
	level.action_override = {action: true}
	level.step(0.01)
	if release_after:
		level.action_override = {}
		level.step(0.01)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)


func visible_prompt_text(hud: Node) -> String:
	var text: Array[String] = []
	for node: Node in hud.prompt_row.get_children():
		if node is Label and node.visible and not node.text.is_empty():
			text.append(node.text)
	return " ".join(text)
