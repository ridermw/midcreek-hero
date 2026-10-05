extends RefCounted

const TYPES := ["run_cable", "assemble_rack", "extinguish_fire", "restore_cooling", "contain_leak", "restore_power"]
const RESOURCE_KINDS := {
	"run_cable": ["spool"], "assemble_rack": ["chassis", "psu", "dimm"],
	"extinguish_fire": ["extinguisher"], "restore_cooling": ["filter"],
	"contain_leak": ["seal"], "restore_power": ["fuse"],
}
const SITE_COUNTS := {"assemble_rack": 1, "extinguish_fire": 1, "restore_cooling": 2, "contain_leak": 2, "restore_power": 1}
const EFFECT_KINDS := {"extinguish_fire": "fire", "restore_cooling": "heat_vent", "contain_leak": "electrified_liquid"}


static func validate(task: Dictionary, level: Dictionary) -> String:
	var kind: Variant = task.get("type")
	if kind not in TYPES:
		return "Unknown expansion task type."
	var sites: Variant = task.get("sites")
	if not sites is Array:
		return "Task sites must be an ordered array."
	if kind == "run_cable":
		if sites.size() < 3:
			return "Cable needs a source, a securing point, and a destination."
	elif sites.size() != SITE_COUNTS[kind]:
		return "Wrong site count for " + kind
	var occupied := {}
	for value: Variant in sites:
		var error := _placement(value, level, occupied)
		if not error.is_empty():
			return error
	var resources: Variant = task.get("resources")
	if not resources is Array or resources.size() != RESOURCE_KINDS[kind].size():
		return "Task resources must match its required component count."
	var expected: Array = RESOURCE_KINDS[kind].duplicate()
	for resource: Variant in resources:
		if not resource is Dictionary or resource.get("kind") not in expected:
			return "Task resource kind is missing, duplicated, or invalid."
		expected.erase(resource["kind"])
		var error := _placement(resource.get("cell"), level, occupied)
		if not error.is_empty():
			return error
	var effects: Variant = task.get("effect_cells", [])
	if not effects is Array:
		return "Task effect_cells must be an array."
	if not EFFECT_KINDS.has(kind):
		return "" if effects.is_empty() else "This task cannot bind hazards."
	if effects.is_empty():
		return "Task needs at least one bound hazard."
	var bound := {}
	for value: Variant in effects:
		if not valid_cell(value, level):
			return "Effect cell must be an integer coordinate within the grid."
		var cell := Vector2i(value[0], value[1])
		if bound.has(cell) or occupied.has(cell):
			return "Effect cells cannot repeat or occupy an interaction site."
		bound[cell] = true
		var found := false
		for hazard: Dictionary in level["hazards"]:
			if hazard["cell"] == cell and hazard["kind"] == EFFECT_KINDS[kind]:
				found = true
		if not found:
			return "Effect cell must identify a matching hazard."
	return ""


static func valid_cell(value: Variant, level: Dictionary) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for coordinate: Variant in value:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or floorf(float(coordinate)) != float(coordinate):
			return false
	return value[0] >= 0 and value[0] < level["width"] and value[1] >= 0 and value[1] < level["height"]


static func _placement(value: Variant, level: Dictionary, occupied: Dictionary) -> String:
	if not valid_cell(value, level):
		return "Work placement must be an integer coordinate within the grid."
	var cell := Vector2i(value[0], value[1])
	if level["solids"].has(cell):
		return "Work placement cannot occupy solid terrain."
	if occupied.has(cell):
		return "Work sites and resources must have distinct cells."
	occupied[cell] = true
	return ""
