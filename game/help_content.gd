extends RefCounted

const Prompt = preload("res://game/control_prompt.gd")
const CablePort = preload("res://game/entities/cable_port.gd")


static func controls(display: String) -> Array:
	var result: Array = []
	for entry: Array in [
		["move_left", "hold", "run left"], ["move_right", "hold", "run right"],
		["move_up", "hold", "climb up a ladder"], ["move_down", "hold", "climb down a ladder"],
		["jump", "press", "jump; hold for a higher jump"], ["slide", "press", "slide under low obstacles"],
		["repair", "hold", "repair or install a part; press for cables and switches"],
		["diagnose", "press", "diagnose a marked rack"], ["pause", "press", "open the pause menu"],
	]:
		result.append(Prompt.render(Prompt.make(entry[0], entry[1], entry[2]), display))
	return result


static func prop(asset: String, x: float, group := "tiles", label := "") -> Dictionary:
	return {"asset": asset, "x": x, "group": group, "label": label}


static func step(seconds: float, clip: String, from: float, to: float, props: Array, prompt: Dictionary, carry := false) -> Dictionary:
	return {"seconds": seconds, "clip": clip, "from": from, "to": to, "props": props, "prompt": prompt, "carry": carry}


static func pages() -> Array:
	var rack := [prop("rack-fault", 340)]
	var fixed := [prop("rack-ok", 340)]
	var work := Prompt.make("repair", "hold", "repair the rack")
	var done := Prompt.make("", "", "", "Task complete")
	var cable_steps := [
		step(1.2, "primary", 280, 280, [prop("cable-port", 340)], Prompt.make("repair", "press", "start reseating the cable")),
	]
	var sequence := CablePort.sequence_for("help-cable")
	for i: int in range(sequence.size()):
		cable_steps.append(step(0.8, "primary", 280, 280, [prop("cable-port", 340, "tiles", "%d / 3" % (i + 1))], Prompt.make(String(sequence[i]), "press", "reseat cable (%d of 3)" % (i + 1))))
	cable_steps.append(step(1.2, "idle", 280, 280, [prop("cable-port", 340, "tiles", "Connected")], done))
	var switches: Array = []
	for i: int in range(3):
		var props: Array = []
		for j: int in range(3):
			props.append(prop("switch-on" if j < i else "switch-off", 180.0 + j * 120, "tiles", str(j + 1)))
		if i > 0:
			switches.append(step(0.8, "run", 125.0 + (i - 1) * 120, 125.0 + i * 120, props, Prompt.make("move_right", "hold", "reach the next switch")))
		switches.append(step(1.2, "primary", 125.0 + i * 120, 125.0 + i * 120, props, Prompt.make("repair", "press", "throw switch %d" % (i + 1))))
	switches.append(step(1.2, "idle", 365, 365, [prop("switch-on", 180, "tiles", "1"), prop("switch-on", 300, "tiles", "2"), prop("switch-on", 420, "tiles", "3")], done))
	return [
		{"id": "controls", "title": "Controls", "instructions": "Keep the data hall online. Complete every required work order, then reach the exit before the SLA expires.\nOptional work improves your result. Coolant restores health; checkpoints protect progress.\nChoose Keyboard, Gamepad or Touch in Settings. This changes hints only: all input devices still work.", "steps": []},
		{"id": "repair", "title": "Repair a rack", "instructions": "1. Stand beside a red rack.\n2. Hold Repair until the work completes. Letting go cancels progress.\n3. A green rack is finished.", "steps": [
			step(1.2, "run", 60, 280, rack, Prompt.make("move_right", "hold", "approach the rack")),
			step(2.0, "primary", 280, 280, rack, work),
			step(1.2, "idle", 280, 280, fixed, done),
		]},
		{"id": "fetch", "title": "Fetch and install a part", "instructions": "1. Walk over the matching PSU or DIMM to pick it up automatically.\n2. Carry it to its marked rack. Only one part can be carried.\n3. Hold Repair to install it. A missing-part notice means you need the matching part.", "steps": [
			step(1.2, "run", 60, 180, [prop("psu", 180, "props"), prop("rack-fault", 340)], Prompt.make("move_right", "hold", "pick up the PSU")),
			step(1.2, "run", 180, 280, rack, Prompt.make("move_right", "hold", "bring the PSU to its rack"), true),
			step(2.0, "primary", 280, 280, rack, Prompt.make("repair", "hold", "install the PSU"), true),
			step(1.2, "idle", 280, 280, fixed, done),
		]},
		{"id": "diagnose_repair", "title": "Diagnose, then repair", "instructions": "1. Stand beside a diagnosis-marked rack.\n2. Press Diagnose and wait for the inspection to finish.\n3. The hint changes to Repair. Hold it until the rack is fixed.", "steps": [
			step(0.8, "secondary", 280, 280, rack, Prompt.make("diagnose", "press", "diagnose the rack")),
			step(2.0, "primary", 280, 280, rack, work),
			step(1.2, "idle", 280, 280, fixed, done),
		]},
		{"id": "reseat", "title": "Reseat a cable", "instructions": "1. Stand at a cable port and press Repair to begin.\n2. Press only the button currently shown, within one second.\n3. Complete three prompts. A wrong or late press resets the sequence; start again with Repair.", "steps": cable_steps},
		{"id": "switch", "title": "Reboot ordered switches", "instructions": "1. Find the numbered switch panels.\n2. Press Repair at switch 1, then 2, then 3.\n3. Wrong order resets the group. Start again at switch 1.", "steps": switches},
	] + expansion_pages()


static func expansion_pages() -> Array:
	var done := Prompt.make("", "", "", "Task complete")
	var valve := [prop("valve", 340, "work")]
	var cabinet := [prop("switch-off", 340)]
	return [
		{"id": "run_cable", "title": "Run a cable", "instructions": "1. Press Repair at the labeled spool source.\n2. Press Repair at the source, numbered anchors, then destination.\n3. Placed anchors remain installed. A wrong point names the next point.", "steps": [
			step(1.2, "primary", 280, 280, [prop("spool", 340, "work")], Prompt.make("repair", "press", "collect the spool")),
			step(1.2, "primary", 280, 280, cabinet, Prompt.make("repair", "press", "connect point 1")),
			step(1.2, "primary", 280, 280, cabinet, Prompt.make("repair", "press", "secure numbered anchors, then destination")),
			step(1.2, "idle", 280, 280, [prop("switch-on", 340)], done),
		]},
		{"id": "assemble_rack", "title": "Assemble a rack", "instructions": "1. Collect the labeled chassis, PSU, and DIMM one at a time.\n2. Press Repair at the rack to install each part. Chassis comes first.\n3. Hold Diagnose to test. Interrupting the test keeps installed parts.", "steps": [
			step(1.2, "primary", 280, 280, [prop("chassis", 340, "work")], Prompt.make("repair", "press", "install chassis first")),
			step(1.2, "primary", 280, 280, [prop("chassis", 340, "work"), prop("psu", 400, "props"), prop("dimm", 450, "props")], Prompt.make("repair", "press", "install the matching PSU and DIMM")),
			step(1.5, "secondary", 280, 280, [prop("rack-fault", 340)], Prompt.make("diagnose", "hold", "test assembled rack")),
			step(1.2, "idle", 280, 280, [prop("rack-ok", 340)], done),
		]},
		{"id": "extinguish_fire", "title": "Extinguish a fire", "instructions": "1. Collect the labeled extinguisher. Stay at the safe service position.\n2. Hold Repair to suppress the fire. Release keeps partial progress.\n3. When charge runs out, press Repair at its source to refill, then return.", "steps": [
			step(1.2, "primary", 280, 280, [prop("extinguisher", 340, "work")], Prompt.make("repair", "press", "collect extinguisher")),
			step(2.0, "primary", 280, 280, [prop("fire", 420, "work")], Prompt.make("repair", "hold", "suppress from the safe position")),
			step(1.2, "primary", 280, 280, [prop("extinguisher", 340, "work")], Prompt.make("repair", "press", "refill at the source")),
			step(1.2, "primary", 280, 280, [prop("fire", 420, "work")], Prompt.make("repair", "hold", "finish suppression")),
			step(1.2, "idle", 280, 280, [], done),
		]},
		{"id": "restore_cooling", "title": "Restore cooling", "instructions": "1. Collect the filter. Press Diagnose at the controller.\n2. Press Repair at the valve, then return and install the filter.\n3. Hold Repair to verify the fan. Completion disables the bound heat vent.", "steps": [
			step(1.2, "secondary", 280, 280, valve, Prompt.make("diagnose", "press", "diagnose the controller")),
			step(1.2, "primary", 280, 280, valve, Prompt.make("repair", "press", "open the local valve")),
			step(1.2, "primary", 280, 280, [prop("filter", 340, "work")], Prompt.make("repair", "press", "install filter at the controller")),
			step(1.5, "primary", 280, 280, valve, Prompt.make("repair", "hold", "start and verify the fan")),
			step(1.2, "idle", 280, 280, valve, done),
		]},
		{"id": "contain_leak", "title": "Contain a leak", "instructions": "1. Collect the seal. Press Repair to close the supply valve.\n2. Press Repair again to install the seal, then go to the drain.\n3. Hold Repair to drain. Partial drainage persists; the floor remains solid.", "steps": [
			step(1.2, "primary", 280, 280, valve, Prompt.make("repair", "press", "close leak supply")),
			step(1.2, "primary", 280, 280, [prop("seal", 340, "work")], Prompt.make("repair", "press", "install the seal")),
			step(3.0, "primary", 280, 280, valve, Prompt.make("repair", "hold", "operate the drain")),
			step(1.2, "idle", 280, 280, valve, done),
		]},
		{"id": "restore_power", "title": "Restore a power branch", "instructions": "1. Collect the fuse. Press Repair to isolate the branch.\n2. Press Repair to install the fuse. Hold Diagnose for continuity.\n3. Press Repair to energize. The green indicator confirms completion.", "steps": [
			step(1.2, "primary", 280, 280, cabinet, Prompt.make("repair", "press", "isolate the branch")),
			step(1.2, "primary", 280, 280, [prop("fuse", 340, "work")], Prompt.make("repair", "press", "install the fuse")),
			step(1.5, "secondary", 280, 280, cabinet, Prompt.make("diagnose", "hold", "test continuity")),
			step(1.2, "primary", 280, 280, cabinet, Prompt.make("repair", "press", "energize the branch")),
			step(1.2, "idle", 280, 280, [prop("switch-on", 340)], done),
		]},
	]
