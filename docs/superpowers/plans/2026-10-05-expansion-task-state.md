# Expansion task state implementation plan

> **For agentic workers:** Use `executing-plans` for inline execution. Follow
> strict regression first development. Independent review precedes each push.

**Goal:** Establish tested resource and partial progress contracts for the six
approved tasks without changing any playable level.

**Architecture:** Add one pure state unit for each distinct task mechanic.
Resources use task ID and resource index, not display names. Later scene
entities consume these units and remain responsible for art and local input.

**Tech Stack:** Godot 4.7.2, typed GDScript, existing shell test runner.

**Spec:** `docs/superpowers/specs/2026-10-05-campaign-expansion-design.md`

## Global constraints

- Preserve existing levels, routes, par, SLA, sliding, and saved stars.
- Do not edit fatal liquid, player death, or parser/builder hooks before the
  other owner's reviewed dependency merges.
- Keep the export cap at 53477376 bytes.
- Complete state work does not establish playable level completion.

## Task 1: Cable placement and resource ownership

Files: create `game/tasks/cable_work.gd` and `tests/cable_work_test.gd`.
The unit owns its spool, ordered placement index, and completion state.
It does not render, mutate TaskSystem, or handle player movement.

Interfaces:

```gdscript
func _init(points: int = 3) -> void
func collect_spool() -> bool
func place(point: int) -> String
func capture_state() -> Dictionary
func restore_state(state: Dictionary) -> void
```

`points` counts source, securing points, and destination. A spool is available
until collection. `place` returns `missing_spool`, `wrong_point`, `placed`,
`done`, or `already_done`. Placement consumes the carried spool at the source
but retains task ownership until the destination completes.

- [ ] Add checks for collection, blocked placement, wrong order, completion,
  duplicate collection, and checkpoint restoration at each stage.
- [ ] Observe failure before implementation:
  `tools/godot_test.sh tests/cable_work_test.gd CABLE_WORK_TEST`.
- [ ] Implement only the specified state transitions. Snapshot all mutable
  fields and return a fresh dictionary.
- [ ] Repeat the focused test. Verify old task/checkpoint tests remain green.
- [ ] Review and commit this unit as the first task implementation.

Core acceptance sequence:

```gdscript
var cable = CableWork.new(4)
check(cable.place(0) == "missing_spool", "Source needs its spool.")
check(cable.collect_spool(), "The spool can be collected once.")
var saved = cable.capture_state()
check(cable.place(1) == "wrong_point", "Anchors require source first.")
check(cable.place(0) == "placed", "Source starts installation.")
check(cable.place(1) == "placed", "First anchor retains progress.")
check(cable.place(2) == "placed", "Second anchor retains progress.")
check(cable.place(3) == "done", "Destination completes the cable.")
cable.restore_state(saved)
check(cable.place(0) == "placed", "Checkpoint restores carried spool.")
```

## Subsequent independent increments

Write each detailed implementation plan after the preceding unit fixes the
shared resource interface. Do not implement undefined neighboring interfaces.
The next unit installs three rack components and tests the assembled rack.
The fire unit adds refillable charge and persistent suppression.
Cooling and power use explicit ordered diagnostic and installation stages.
Leak adds persistent drainage and restored hazard effects.

Each unit needs a focused failure before code, interruption and rollback
checks, independent review, and a coherent commit. Only then integrate scene
entities, art, parser validation, and one fully playable level.

## Integration boundaries

The existing campaign owner supplies fatal liquid and death recovery.
This session supplies new work aggregation and applies effects before
`reset_motion()`. Do not edit the same `_respawn` block before that merge.
The existing integration owner monitors PRs and merges only after exact head
checks and five minutes of review quiet.
