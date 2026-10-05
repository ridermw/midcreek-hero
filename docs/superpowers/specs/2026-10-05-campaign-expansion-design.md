# Ten additional environments

## Scope and authority

The user approved all ten environments and all six task types on October 5.
Add levels 06 through 15. Do not edit the five existing level definitions,
routes, targets, or generators. Preserve sliding and earned progress.
Routine design decisions do not need additional human approval.
Independent review, evidence, and integration gates still apply.

This document specifies intended behavior, not completed implementation.

## Approach

Add explicit task entities to the existing parser, builder, interaction, and
checkpoint pipeline. Keep task state in entities. Keep campaign progress in
SaveStore. Use the existing movement and input actions.

Do not encode new tasks as renamed repair tasks. Do not introduce a general
task scripting language. A separate game mode would duplicate loading, input,
and recovery logic and would weaken regression coverage.

New tasks use a shared interaction result: prompt, action animation, movement
lock, and completion event. Select one target before handling input. The same
target supplies the prompt. Existing task precedence remains unchanged unless
an overlapping target test proves that an additive selection adapter is needed.

## Level mapping

Each level has three checkpoints and three to six work orders. The table gives
required new work and route structure. Familiar optional work can teach the
transition without changing the six new mechanics.

| ID | Environment | Required new work | Distinct route structure |
|---|---|---|---|
| 06 | Cooling Gallery | Restore cooling, contain a leak, run a cable | Two parallel service galleries connected by ladders; return through the drained gallery |
| 07 | Operations Suite | Assemble a rack, run a cable, restore a power branch | Central assembly bay with component stores on separate floors |
| 08 | Fiber Exchange | Run two cables, assemble a rack | Cable anchors cross an upper tray route; the second cable returns through the lower exchange |
| 09 | Loading Yard | Assemble a rack, contain a leak, restore a power branch | Loading platforms, a service trench, and a covered delivery route |
| 10 | Fire Response Hall | Extinguish two fires, restore cooling | Separate equipment bays with a visible refill station between fires |
| 11 | Pump Station | Contain two leaks, restore cooling | Valve access above a continuous flooded floor; return below after drainage |
| 12 | Rooftop Air Handlers | Restore cooling, run a cable, restore a power branch | Separated rooftop equipment platforms and a lower maintenance passage |
| 13 | Generator Courtyard | Restore two power branches, extinguish a fire | Two independent generator loops feeding a central distribution cabinet |
| 14 | Facility Approach | Contain a leak, extinguish a fire, run a cable | Outdoor approach, vehicle clearance, and a raised facility entrance |
| 15 | Expansion Site | Assemble a rack, run a cable, extinguish a fire, restore cooling, contain a leak, restore a power branch | Construction floors with a staged commissioning route and visible return access |

Start with authored par/SLA pairs of 210/420 seconds for 06 through 08,
240/480 for 09 through 11, 270/540 for 12 through 14, and 360/720 for 15.
These are provisional design allowances, not measured human difficulty.
Automated route budgets remain separate. Never calculate par from bot duration.

## Task contracts

All resources belong to one task ID. Resource identity includes a component
index where a task needs multiple items. Labels identify the destination.
Only one carried item occupies the shared inventory slot. A visible source
retains a resource until the slot is free. Installation consumes the resource
only when its corresponding durable stage completes.

| Task | Objective and prerequisites | Resource and partial progress | Completion effect |
|---|---|---|---|
| Run a cable | Collect the labeled spool, connect the source, secure numbered anchors, connect the destination | One spool; placed anchors persist when interrupted; a wrong anchor reports the next location without consuming work | Draw the installed cable and light both endpoint indicators |
| Assemble a rack | Deliver chassis, power supply, and memory to the labeled rack, then test it | Three separately labeled components; each installed component persists; final test requires all three | Show assembled rack art and a green test indicator |
| Extinguish a fire | Collect an extinguisher and aim from the marked safe service position | Refillable charge; held action reduces fire intensity; release preserves intensity; refill remains accessible without crossing the fire | Disable the bound fire hazard and show the extinguished state |
| Restore cooling | Diagnose the controller, open the local valve, replace its filter, then start and verify the fan | One filter; diagnosis and valve stages persist; interrupted verification resets only its current hold | Disable the bound heat source and show operating fan feedback |
| Contain a leak | Close the supply valve, install a seal, then operate the drain | One seal; valve and seal stages persist; interrupted drainage retains measured progress | Disable only the bound liquid hazard; retain continuous floor collision |
| Restore a power branch | Isolate the branch, replace its fuse, diagnose continuity, then energize | One fuse; each completed stage persists; energize remains blocked until continuity passes | Light the bound branch indicator and enable only explicitly declared equipment |

Prompts name missing prerequisites and their locations. A blocked target still
owns its prompt and consumes no input or resource. Exit access requires every
required task. Neither an enabled elevator nor a disabled hazard may be the
only route to the resource or control that enables that effect.

### Data and runtime interfaces

New type identifiers are `run_cable`, `assemble_rack`, `extinguish_fire`,
`restore_cooling`, `contain_leak`, and `restore_power`.
Keep `TaskSystem` as the completion registry. Do not duplicate entity stages
there. Its existing `restore(done_ids)` remains sufficient for completed IDs.

New tasks use `sites`, an ordered array of integer `[column, row]` coordinates,
instead of letter anchors in `at`. Existing task schemas remain unchanged.
Resource entries use `{"kind": "<kind>", "cell": [column, row]}`.
The array index supplies stable resource identity within the task.
Every cell must be within the grid, nonsolid, and reachable by the static
validator. Reject duplicate sites within one task and ambiguous coincident
sites across tasks. Reuse room art, not an interactive station, across tasks.

Cable sites are source, one or more securing points, and destination.
One `spool` resource is required. Rack has one assembly site and exactly
`chassis`, `psu`, and `dimm` resources. Fire has one safe service site and one
`extinguisher` resource; its resource source also serves as its refill station.
Cooling has controller and valve sites, plus one `filter` resource.
Leak has valve and drain sites, plus one `seal` resource.
Power has one cabinet site and one `fuse` resource.
Rack testing and power stages reuse their own site rather than separate anchors.
Each fire has its own refill station in the shared refill area.

Effects use `effect_cells`, an array of hazard grid coordinates. The builder
resolves these to exact hazard instances. Reject absent hazards, duplicate
bindings, and wrong hazard kinds. Fire binds fire, cooling binds heat vents,
and leak binds liquid. A task may not disable another task's hazard.
Power initially controls its cabinet indicators, not required elevator access.
This avoids introducing an unnecessary equipment dependency system.

Each new task entity exposes `capture_state() -> Dictionary`,
`restore_state(state: Dictionary) -> void`, and
`apply_effects() -> void`. The level captures the `work` and `work_resources`
groups plus the owner's new `liquids` group. Task state is authoritative for
bound effects; restoring tasks reapplies those effects before motion reset.
Ordinary unbound hazards retain their current behavior.

Use `repair` for work and `diagnose` for tests. Add no input actions.
Task input returns a structured result rather than directly changing the HUD.
Use the existing ControlPrompt model for keyboard, gamepad, and touch.
Fire and drain preserve incremental work; interrupted rack tests, continuity
tests, and fan verification discard only the unfinished timed stage.

Do not add a second movement solver to validate dependencies. Use conservative
static cell checks for malformed placements, then require real physics routes
that reach each prerequisite while its effect remains disabled. Checkpoint
replay must complete the same route from every saved partial state.

## Checkpoint and effect ordering

Capture carried resource, source availability, installed components, durable
task stages, charge, intensity, and drainage progress. Deep copy the snapshot.
Restore completed task IDs and entity state first. Reapply hazard and equipment
effects from restored task state. Then reset motion to authored safe states.
Clear transient action timing, target selection, and feedback last.

Saved partial work must agree with its visuals, inventory, and effects.
Restoring an earlier checkpoint returns resources consumed after that checkpoint.
Restoring a later checkpoint must not recreate installed resources.
Refill sources remain available so charge depletion cannot block completion.

The existing campaign owner owns fatal liquid, death priority, player input
reset, and shared motion recovery. Integrate that work only after review and
merge. New liquid is opt in. No existing pit becomes fatal liquid.

## Assets and export

Use ordered environment manifests with texture path, scroll factor, tint,
coverage mode, and draw order. Load only the active environment.
Preserve the existing five backgrounds and their rendering parameters.
Reuse approved sprites and audio where their appearance fits the new object.
Generate missing environment and task art through the existing MockUI pipeline.
Retain source prompts, generator records, and normalization provenance.
Missing required art must stop production loading with a visible error.

The release download cap remains 53477376 bytes. The recorded baseline is
52800035 bytes, leaving 677341 bytes. Measure new exports before committing
to additional textures. Use small reusable environment elements and shared
paths rather than ten duplicated texture sets. If required art exceeds the
cap, report measured bytes and the visual tradeoff. Do not raise the cap.
Measure shared texture reuse first, then fewer unique layers if needed.
Do not count recoloring or replacing an environment with unrelated scenery as
successful delivery. A budget overrun remains a blocker if reuse breaks the
approved environment identity.

## Campaign compatibility

Retain version 1 saves and all existing fields. A valid saved completion of
05 unlocks 06 during load. Merely unlocking 05 does not unlock 06.
Records with at least one star establish completion, including legacy partial
records without a time. Preserve character, settings, stars, optional work,
and best times. Saving and loading migration twice must produce the same state.

Extend progression through 15. Level 15 has no next level. Show a scrollable
level list with keyboard, gamepad, and touch access to every unlocked entry.
Do not publish selectable entries until their level files and runtime assets
exist. Verify the results screen and campaign completion behavior.
Each level file must enter the repository with its route, independent route
budget, assets, and export assertions in the same reviewed increment.
Until then, author drafts only in test fixtures or session artifacts.
Wrap the level rows in a ScrollContainer and scroll to the focused row.
Test the last row with both keyboard and gamepad focus, plus touch scrolling.

The shared `game/level.gd:_respawn` change follows the fatal primitive merge.
It must restore progress and effects before motion and player placement.

## Delivery and evidence

First deliver task state units and tests without changing playable content.
Then deliver the environment manifest adapter and the first complete new level.
Deliver later environments in groups of at most three after their mechanics
and assets are available. Extend reachable progression only with shipped levels.

Before each implementation, observe a focused failing regression.
Before each push, obtain independent review and resolve material findings.
After each push, request Copilot review. The existing integration owner monitors
and merges; this session must not create a second monitor.

Each playable increment needs native and browser captures, both heroes where
their behavior differs, real physics completion without hits or respawns,
and completion after replay from every checkpoint. Cover task interruption,
blocked input, partial resource use, and effect rollback separately.
Run all five original routes before shared runtime integration.
Verify exported runtime assets, excluded source files, and measured download.
Wait at least five minutes after the latest push, review, or comment, then
recheck exact head gates before integration. Check the main deployment after it.
