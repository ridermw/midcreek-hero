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

- [x] Add checks for collection, blocked placement, wrong order, completion,
  duplicate collection, and checkpoint restoration at each stage.
- [x] Observe failure before implementation:
  `tools/godot_test.sh tests/cable_work_test.gd CABLE_WORK_TEST`.
- [x] Implement only the specified state transitions. Snapshot all mutable
  fields and return a fresh dictionary.
- [x] Repeat the focused test. Verify old task/checkpoint tests remain green.
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

## Task 2: Rack assembly

Create `game/tasks/rack_work.gd` and `tests/rack_work_test.gd`.
Use `install(component: String) -> String` and
`test_work(delta: float) -> String`. Chassis precedes power supply and memory;
the other two components can arrive in either order. Test for 1.5 seconds.
`cancel()` clears only test timing. Snapshot installed components and tested
state with a copied array.

```gdscript
check(rack.install("dimm") == "needs_chassis", "Install chassis first.")
check(rack.install("chassis") == "installed", "Install chassis.")
check(rack.test_work(3.0) == "missing_components", "All components are needed.")
```

- [x] Write and observe the failing rack test.
- [x] Implement assembly and rollback.
- [x] Run `tools/godot_test.sh tests/rack_work_test.gd RACK_WORK_TEST`.
- [x] Include the unit in independent review before committing.

## Task 3: Fire suppression

Create `game/tasks/fire_work.gd` and `tests/fire_work_test.gd`.
`refill()` equips the extinguisher and restores 2 seconds of charge.
`suppress(delta: float) -> String` reduces an initial intensity of 3.
Clamp consumption to available charge and remaining intensity.
Snapshot equipment, charge, and intensity together.

```gdscript
fire.refill()
check(fire.suppress(9.0) == "empty", "Cannot consume unavailable charge.")
check(is_equal_approx(fire.intensity, 1.0), "One refill cannot finish a fire.")
fire.refill()
check(fire.suppress(1.0) == "done", "Refill permits completion.")
```

- [x] Write and observe the failing suppression test.
- [x] Implement charge and partial suppression.
- [x] Run `tools/godot_test.sh tests/fire_work_test.gd FIRE_WORK_TEST`.
- [x] Include the unit in independent review before committing.

## Task 4: Cooling restoration

Create `game/tasks/cooling_work.gd`; test in `tests/service_work_test.gd`.
`diagnose()` identifies the fault. `open_valve()` requires diagnosis.
`install_filter()` requires the valve. Each returns a String outcome.
`verify(delta: float) -> String` requires the filter and needs a continuous
1.5 second hold. `cancel()` discards only verification timing.
Snapshot diagnosed, valve_open, filter_installed, and running flags.

```gdscript
check(cooling.install_filter() == "needs_valve", "Cannot install before valve.")
check(cooling.diagnose() == "diagnosed", "Diagnosis records the fault.")
check(cooling.open_valve() == "opened", "Diagnosis permits valve operation.")
```

- [x] Write and observe blocked and partial rollback failures.
- [x] Implement the four explicit stages.
- [x] Run `tools/godot_test.sh tests/service_work_test.gd SERVICE_WORK_TEST`.
- [x] Include the unit in independent review before committing.

## Task 5: Leak containment

Create `game/tasks/leak_work.gd`; test in `tests/service_work_test.gd`.
`close_valve()` isolates the leak. `install_seal()` requires isolation.
`drain(delta: float) -> String` requires the seal and retains partial drainage
over interruptions. Three seconds empties the leak. Snapshot valve_closed,
seal_installed, and drained_seconds. Completion derives from drained_seconds.

```gdscript
check(leak.install_seal() == "needs_valve", "Seal requires isolation.")
check(leak.drain(9.0) == "needs_seal", "Cannot drain an unsealed leak.")
```

- [x] Write and observe blocked, interrupted, and restored failures.
- [x] Implement isolation, seal, and retained drainage.
- [x] Run `tools/godot_test.sh tests/service_work_test.gd SERVICE_WORK_TEST`.
- [x] Include the unit in independent review before committing.

## Task 6: Power restoration

Create `game/tasks/power_work.gd`; test in `tests/service_work_test.gd`.
`isolate()` precedes `install_fuse()`. `test_continuity(delta: float) -> String`
requires the fuse and a continuous 1.5 second hold. `energize()` requires
successful continuity. `cancel()` clears only incomplete test timing.
Snapshot isolated, fuse_installed, continuity_passed, and energized flags.

```gdscript
check(power.install_fuse() == "needs_isolation", "No live fuse replacement.")
check(power.energize() == "needs_continuity", "Untested branch stays off.")
```

- [x] Write and observe prerequisite and rollback failures.
- [x] Implement isolation, fuse, continuity, and energize.
- [x] Run `tools/godot_test.sh tests/service_work_test.gd SERVICE_WORK_TEST`.
- [x] Include the unit in independent review before committing.

Only after these state checks, integrate scene entities, art, parser validation,
and one fully playable level. These checks alone do not complete a level.

## Integration boundaries

The three service units share one test script to keep the focused command
small. State units are not a polymorphic interaction interface. Their scene
adapters call `cancel()` only for rack, cooling, and power continuous holds.
Cable placement, fire suppression, and drainage have no transient hold state.
Do not call a nonexistent cancellation method on those units.
Timed methods return `invalid_delta` for negative or nonfinite time.
Snapshots are trusted internal checkpoints restored to the same authored task,
not external saves or snapshots from a task with a different point count.

The existing campaign owner supplies fatal liquid and death recovery.
This session supplies new work aggregation and applies effects before
`reset_motion()`. Do not edit the same `_respawn` block before that merge.
The existing integration owner monitors PRs and merges only after exact head
checks and five minutes of review quiet.
