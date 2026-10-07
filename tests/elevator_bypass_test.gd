# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const LevelBuilder = preload("res://game/level_builder.gd")
const Lift = preload("res://game/entities/lift.gd")
const TILE := 32.0
const DT := 1.0 / 60.0
const SITES := [
	{"slug": "04-power-room", "index": 0, "col": 42, "first": 44, "last": 60},
	{"slug": "04-power-room", "index": 1, "col": 94, "first": 96, "last": 112},
	{"slug": "04-power-room", "index": 2, "col": 157, "first": 159, "last": 173},
	{"slug": "04-power-room", "index": 3, "col": 282, "first": 284, "last": 296},
	{"slug": "05-outage-night", "index": 0, "col": 59, "first": 61, "last": 75},
	{"slug": "05-outage-night", "index": 1, "col": 220, "first": 222, "last": 234},
]

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for slug: String in ["04-power-room", "05-outage-night"]:
		for hero: String in ["man", "woman"]:
			var level := make_level(slug, hero)
			disable_lifts(level)
			for site: Dictionary in SITES:
				if site["slug"] != slug:
					continue
				await expect_normal_jump_blocked(level, site, hero)
				await expect_wall_kicks_blocked(level, site, hero, 1)
				await expect_wall_kicks_blocked(level, site, hero, 3)
				await expect_nearby_platforms_blocked(level, site, hero)
			level.queue_free()
			await process_frame
	print("ELEVATOR_BYPASS_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func make_level(slug: String, hero: String) -> Node:
	var level := LEVEL.instantiate()
	level.character = hero
	level.level_path = "res://levels/%s.level" % slug
	root.add_child(level)
	check(level.error_message.is_empty(), "%s loads for %s: %s" % [slug, hero, level.error_message])
	level.player.use_override = true
	return level


func disable_lifts(level: Node) -> void:
	for lift in level.entities["lifts"]:
		lift.set_physics_process(false)
		lift.visible = false
		lift.collision_layer = 0
		lift.collision_mask = 0
		for child in lift.get_children():
			if child is CollisionShape2D:
				child.disabled = true


func reset_trial(level: Node, at: Vector2) -> void:
	level.player.respawn(at)
	level.player.input_override = {}
	level.health.refill()
	level.hit_stop_remaining = 0.0
	level.freeze_world(false)
	for hazard in level.entities["hazards"]:
		hazard.reset_motion()


func lift_for(level: Node, site: Dictionary) -> Node2D:
	return level.entities["lifts"][int(site["index"])]


func deck_top_row(level: Node, site: Dictionary) -> int:
	var solids: Dictionary = level.level["solids"]
	var x := int(site["first"])
	for y: int in range(level.level["height"] - 1):
		if not solids.has(Vector2i(x, y)) and solids.has(Vector2i(x, y + 1)):
			return y
	return int(lift_for(level, site).position.y / TILE) - Lift.RISE_TILES


func deck_feet_y(level: Node, site: Dictionary) -> float:
	return (deck_top_row(level, site) + 1) * TILE


func deck_left(site: Dictionary) -> float:
	return float(site["first"]) * TILE


func stands_on_deck(level: Node, site: Dictionary) -> bool:
	var p: Node = level.player
	return p.is_on_floor() and p.position.x >= deck_left(site) and p.position.x < (float(site["last"]) + 1.0) * TILE and absf(p.position.y - deck_feet_y(level, site)) < 4.0


func observe_no_deck(level: Node, site: Dictionary, label: String) -> bool:
	if stands_on_deck(level, site):
		check(false, label + " stands on the deck top without the lift at %s." % level.player.position)
		return false
	return true


func expect_normal_jump_blocked(level: Node, site: Dictionary, hero: String) -> void:
	var lift := lift_for(level, site)
	reset_trial(level, Vector2(deck_left(site) - 112.0, lift.base_y))
	var left_floor := false
	for frame: int in range(90):
		var input := {"direction": 1.0}
		if frame == 8:
			input["jump_pressed"] = true
		if frame >= 8 and frame < 50:
			input["jump_held"] = true
		level.player.input_override = input
		await physics_frame
		if not level.player.is_on_floor():
			left_floor = true
		if not observe_no_deck(level, site, "%s %s normal jump" % [hero, site["slug"]]):
			break
		if left_floor and level.player.is_on_floor() and frame > 12:
			break
	check(left_floor, "%s %s normal jump leaves the floor and is observed until landing or 1.5 s." % [hero, site["slug"]])


func expect_wall_kicks_blocked(level: Node, site: Dictionary, hero: String, kicks: int) -> void:
	var produced_kicks := 0
	for attempt: int in range(kicks):
		if await expect_one_wall_kick_blocked(level, site, hero, attempt + 1):
			produced_kicks += 1
	check(produced_kicks == kicks, "%s %s asserts wall contact before %d wall jump press(es)." % [hero, site["slug"], kicks])


func expect_one_wall_kick_blocked(level: Node, site: Dictionary, hero: String, attempt: int) -> bool:
	var lift := lift_for(level, site)
	reset_trial(level, Vector2(deck_left(site) - 72.0, lift.base_y))
	var jump_started := false
	var contact_before_press := false
	var produced_kick := false
	for frame: int in range(100):
		var input := {"direction": 1.0}
		if not jump_started and frame == 5:
			input["jump_pressed"] = true
			input["jump_held"] = true
			jump_started = true
		elif jump_started and not produced_kick and level.player.is_on_wall_only():
			contact_before_press = true
			input["jump_pressed"] = true
			input["jump_held"] = true
			level.player.input_override = input
			await physics_frame
			var kicked_away: bool = level.player.velocity.x < -80.0 and level.player.velocity.y < -150.0
			check(kicked_away, "%s %s wall kick %d moves away from the deck face and upward (velocity %s)." % [hero, site["slug"], attempt, level.player.velocity])
			produced_kick = true
			if not observe_no_deck(level, site, "%s %s wall kick" % [hero, site["slug"]]):
				break
			continue
		level.player.input_override = input
		await physics_frame
		if not observe_no_deck(level, site, "%s %s wall contact" % [hero, site["slug"]]):
			break
		if produced_kick and level.player.is_on_floor() and frame > 20:
			break
	check(contact_before_press, "%s %s wall kick %d starts from asserted wall contact." % [hero, site["slug"], attempt])
	return produced_kick


func expect_nearby_platforms_blocked(level: Node, site: Dictionary, hero: String) -> void:
	var cells := nearby_standable_cells(level, site)
	check(not cells.is_empty(), "%s has nearby authored standable cells for %s." % [site["slug"], hero])
	for cell: Vector2i in cells:
		await expect_cell_jump_blocked(level, site, hero, cell)


func nearby_standable_cells(level: Node, site: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var solids: Dictionary = level.level["solids"]
	var ladders: Array = level.level["ladders"]
	var lifts: Array = level.level["lifts"]
	var deck_y: int = deck_top_row(level, site)
	for y: int in range(level.level["height"]):
		for x: int in range(maxi(0, int(site["first"]) - 6), mini(level.level["width"], int(site["first"]) + 7)):
			var cell := Vector2i(x, y)
			var on_deck := y == deck_y and x >= int(site["first"]) and x <= int(site["last"])
			if on_deck or cell in lifts or solids.has(cell):
				continue
			var standable := cell in ladders or solids.has(cell + Vector2i.DOWN)
			if standable:
				result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	return result


func expect_cell_jump_blocked(level: Node, site: Dictionary, hero: String, cell: Vector2i) -> void:
	reset_trial(level, LevelBuilder.cell_to_world(cell))
	var left_floor := false
	for frame: int in range(90):
		var input := {"direction": 1.0}
		if frame == 6:
			input["jump_pressed"] = true
		if frame >= 6 and frame < 48:
			input["jump_held"] = true
		level.player.input_override = input
		await physics_frame
		if not level.player.is_on_floor():
			left_floor = true
		if not observe_no_deck(level, site, "%s %s nearby %s" % [hero, site["slug"], cell]):
			break
		if left_floor and level.player.is_on_floor() and frame > 10:
			break
	check(left_floor, "%s %s nearby cell %s runs and jumps toward the deck." % [hero, site["slug"], cell])


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)