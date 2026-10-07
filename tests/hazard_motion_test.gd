extends SceneTree

const CableSnag = preload("res://game/hazards/cable_snag.gd")
const LEVEL = preload("res://game/level.tscn")
const Validator = preload("res://game/level_validator.gd")
const Parser = preload("res://game/level_parser.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


# A one row strip: "#" walls in the pile row, "_" a missing floor cell under it.
func strip(row: String) -> Dictionary:
	var solids := {}
	for x: int in range(row.length()):
		if row[x] == "#":
			solids[Vector2i(x, 0)] = "floor"
		if row[x] != "_":
			solids[Vector2i(x, 1)] = "floor"
	return {"solids": solids, "width": row.length()}


func run() -> void:
	var open := CableSnag.span(strip("...................."), Vector2i(10, 0))
	check(open == Vector2(288.0, 384.0), "An open floor limits the patrol to 48 px each side: %s" % open)
	var walled := CableSnag.span(strip("........#.....#....."), Vector2i(11, 0))
	check(walled == Vector2(320.0, 416.0), "Walls limit the pile body to the free floor: %s" % walled)
	var ledge := CableSnag.span(strip(".........____......."), Vector2i(6, 0))
	check(ledge == Vector2(160.0, 256.0), "A floor edge limits the pile body: %s" % ledge)
	var pocket := CableSnag.span(strip(".......#..#........."), Vector2i(9, 0))
	check(pocket.y - pocket.x < CableSnag.MIN_SPAN, "A two cell pocket is too short to patrol: %s" % pocket)

	for slug: String in ["01-cold-aisle", "02-hot-aisle", "03-cable-jungle", "04-power-room", "05-outage-night"]:
		var level := LEVEL.instantiate()
		level.level_path = "res://levels/%s.level" % slug
		root.add_child(level)
		var piles: Array = level.entities["hazards"].filter(func(h) -> bool: return h is CableSnag)
		for pile in piles:
			var start: float = pile.position.x
			var low := start
			var high := start
			for frame: int in range(120):
				pile.advance(1.0 / 60.0)
				low = minf(low, pile.position.x)
				high = maxf(high, pile.position.x)
			check(high - low >= 32.0, "%s pile at x=%d moves within 2 s." % [slug, start])
			check(low >= pile.patrol.min_x and high <= pile.patrol.max_x and pile.patrol.min_x >= start - 48.0 and pile.patrol.max_x <= start + 48.0, "%s pile at x=%d stays inside its authored span." % [slug, start])
			pile.reset_motion()
			check(pile.position.x == start and pile.direction == 1.0, "%s pile at x=%d resets to its authored position." % [slug, start])
		check(not piles.is_empty(), slug + " has cable piles to patrol.")
		level.queue_free()
		await process_frame

	var text := FileAccess.get_file_as_string("res://tests/fixtures/controller.level")
	var parts := text.split("\n---\n")
	var rows := parts[1].split("\n")
	var stand := rows.size() - 3
	var row := rows[stand]
	var column := row.find("s")
	rows[stand] = row.substr(0, column - 1) + "#s.#" + row.substr(column + 3)
	var parser := Parser.new()
	var parsed := parser.parse(parts[0] + "\n---\n" + "\n".join(rows), "pocket.level")
	check(not parsed.is_empty(), "The pocket fixture parses: " + parser.error_message)
	var errors: Array = Validator.new().validate(parsed) if not parsed.is_empty() else []
	check("Cable pile at column %d needs at least 32 px of floor to patrol." % (column + 1) in errors, "The validator rejects a pile without room to patrol: %s" % [errors])
	print("HAZARD_MOTION_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
