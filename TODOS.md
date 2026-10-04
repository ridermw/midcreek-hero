# Midcreek Hero remaining work

Recorded from the October 4, 2026 app direction review.
The user selected a full review and requested these six entries.
This document records decisions and prerequisites. It does not mark implementation
or verification complete.

The M0 to M7 milestones, mobile controls, graphical help, input display settings,
startup branding, climbing alignment, and full height background coverage are
already delivered. The earlier plan checkboxes do not reflect that status.
Climbing alignment does not establish smooth animation.

## Accepted implementation constraints

- Fatal liquid sets health to zero immediately, including during invulnerability.
  Show a 0.5 second death reaction, then restore the checkpoint once.
  Keep ordinary damage behavior separate.
- Keep a continuous solid floor under liquid. Draining liquid changes hazard
  state, not floor collision.
- Elevators travel continuously between two stories and pause at both landings.
  Do not add call controls.
- Restore checkpoint work and its effects. Undo later work and resource use.
  Then reset moving objects to authored safe states, not saved motion positions.
  Use separate progress restoration and motion reset methods.
- One interaction target owns both the action and its prompt. Keep task behavior
  in entities. Extract shared helpers only when selected additions need them.
- Use ordered background manifests for each environment. Preserve and extend
  the existing animation pipeline. Report missing required production art before
  gameplay; keep deliberate gray box rendering separate.
- Separate authored par and SLA values from recorded route timing checks.
  Retain current targets until player observations justify replacements.
  Preserve earned stars.
- Gate routes on completion within the SLA and an independent timing budget,
  without hits, respawns, or runtime errors. Test star calculation separately.
  Verify safe placement and real completion from every checkpoint.
- Use focused task state tests and shared input checks, followed by affected
  route integration checks. Avoid full game runs for every possible combination.
- Measure rendered motion and performance before selecting fixes. Use existing
  Godot and browser tools first, then narrow diagnostics if needed.
- Keep backgrounds loaded for the active level. Use Godot's resource cache.
  Change other artwork loading only when measurements justify it.
- Extend export checks to all declared runtime assets and source exclusions.
  Establish a measured download size budget and review intentional increases.

## 1. Diagnose hero animation smoothness

- [ ] **What:** Diagnose and correct jerky running, repairing, and climbing for
  both heroes.

**Why:** The user reports visible jerkiness in these actions. Static frame size
and alignment checks can pass while animation remains discontinuous.

**Context:** Start with `game/player.gd`, `game/animation_library.gd`,
`game/level.gd`, `tools/animation_assets.py`, and
`tests/test_asset_pipeline.py`. The earlier climbing change aligned the hard hat
within artwork frames. It did not prove smooth playback. Repair repeats the
primary action while held. Running and climbing use looping clips.

Capture sustained running, repair, and climbing for each hero in the actual game.
Separate artwork discontinuity, playback restarts, and uneven rendered timing.
Inspect adjacent frames and the transition from the last frame to the first.
Compare body and tool alignment with the actual physics position. Do not change
frame counts, animation speeds, camera smoothing, or interpolation on assumption.
Do not impose arbitrary image difference thresholds before measuring the defect.

**Acceptance:** Establish a reproducible cause. Add and observe failing
regressions that exercise that cause before production changes. Verify the
corrected motion in the exported game and in help where it reuses the clips.
Cover both heroes and all three actions. Record visual evidence separately from
automated results.

**Depends on / blocked by:** No campaign selection is required. Reproduction
and device observations must precede the choice of fix. Compare performance
before additional background layers make attribution more difficult.

### Verified increment: repair playback cadence

- [x] Preserve the reviewed backlog and verify the baseline. Main is `3f35b12`;
  no pull requests were open when implementation started.
- [x] Reproduce all six action cases with real Level 3 physics and rendering.
  The native probe runs both heroes with repeatable input and captures help.
- [x] Identify and regress the repair restart delay. The original player waits
  for a physics update after the sprite stops. Native samples measured final
  frame holds up to 114.82 ms for the man and 114.72 ms for the woman instead
  of the authored 100 ms. The boundary regression failed for both heroes.
- [x] Loop held repairs in the player's private SpriteFrames configuration.
  Repeat measurement showed no stopped repair samples. Final frame holds were
  97.95 to 102.27 ms for the man and 99.61 to 100.00 ms for the woman.
  Keep shared clips, frame counts, speeds, physics, and camera settings unchanged.
- [ ] Correct remaining artwork discontinuities and verify the exported game.
  This increment does not establish that all reported jerkiness is fixed.

Native evidence uses Godot 4.7.2, Compatibility OpenGL, and an Apple M4 Pro.
After acceleration, running advances 3 world pixels per physics tick. Climbing
advances 1.5 pixels per tick without horizontal drift. Repair position stays
fixed. Run and climb frame sequences wrap in order without unexpected restarts.
These observations do not establish performance on other devices.

The artwork has separate discontinuities. For example, the man's repair helmet
anchor moves from x=107 to x=120 texture pixels between frames 2 and 3 while the
physics position remains fixed. The man's run anchor moves from x=116 to x=125
between frames 2 and 3. Climbing retains abrupt pose changes despite its fixed
horizontal helmet anchor. Correct the authored poses and their contact anchors;
do not conceal them with runtime camera or movement changes.

The session evidence is under `files/animation-baseline/` and
`files/animation-cadence/`, including native traces and rendered movies.
The repeatable harness is `tests/animation_probe.gd`.
Native cadence, player, help, and hit stop checks pass. Both native help
demonstrations were captured. Exported browser verification remains unresolved:
the browser canvas does not expose the tool needed to obtain its page handle,
and the fallback `agent-browser` executable is absent. Physical phone evidence
and player difficulty observations also remain unresolved.

## 2. Select additional environments and tasks

- [ ] **What:** Select the new environments and task types, then define their
  behavior and acceptance checks.

**Why:** The direction contains ten environments and six task concepts, but no
  final selection. Treating concepts as approved content would create unintended
  scope and incomplete recovery rules.

**Context:** Environment candidates are Cooling Gallery, Operations Suite, Fiber
Exchange, Loading Yard, Fire Response Hall, Pump Station, Rooftop Air Handlers,
Generator Courtyard, Facility Approach, and Expansion Site. The outdoor concepts
include facility scenery, trees, vehicles, parking, and construction. The proposed
background protest cameo is optional and is not an enemy encounter.

Task candidates are running a cable, assembling a rack from multiple components,
extinguishing a fire, restoring cooling, containing a leak, and restoring a power
branch. These are proposals, not selected additions. Start with
`game/task_system.gd`, `game/level_parser.gd`, `game/level_builder.gd`,
`game/level.gd`, and `tools/levels/`.

Reuse existing task, entity, input, prompt, and checkpoint mechanisms. Define
prerequisites, carried resources, partial progress, completion effects, and
checkpoint restoration for each selected task. A power task must not require an
elevator that only that task can enable. A restored task and its fire, liquid,
cooling, or power effects must agree.

```text
Checkpoint restoration
    |
    +--> Restore work, resources, and associated effects
    +--> Reset moving objects to authored safe states
    +--> Clear transient input and feedback
    +--> Resume a completable route
```

**Acceptance:** Obtain explicit content selections. Give each selected
environment distinct route geometry and work, not only different colors. Cover
blocked, active, interrupted, complete, and restored task states. Verify one
target owns the displayed prompt and action when targets overlap. Verify keyboard,
gamepad, and touch access. Provide a complete route and safe checkpoint routes.

**Depends on / blocked by:** User selection; measured traversal dimensions from
item 4; the accepted death and recovery contracts; asset decisions from item 5.
Selection must precede final estimates and asset production.

## 3. Decide the role of sliding

- [ ] **What:** Decide whether to retain sliding, then define its purpose in the
  revised levels.

**Why:** The user does not see a clear reason for the move. Additional forced
sliding sections would not resolve that concern by themselves.

**Context:** Sliding currently clears low trays and passes under drones. Start
with `game/player_motor.gd`, `game/player.gd`, `tools/levels/layout.py`,
`tools/levels/level3.py`, `tools/levels/level5.py`, and `game/help_content.gd`.
The plan proposes visibly useful service openings, shortcuts, or optional work
areas. Retention has not been decided.

**Acceptance:** Obtain the decision before revising slide dependent geometry.
If retained, make clearance and route benefit visible and teach the action.
If removed, revise affected obstacles, routes, controls, help, and tests together.
Preserve the distinction between a held input and a new press. Exercise low
clearance, buffered input, interruption, and checkpoint recovery.

**Depends on / blocked by:** User decision. Coordinate with upper route design
and selected environments. Do not remove the move as an animation workaround.

## 4. Define elevator geometry and safe restart states

- [ ] **What:** Measure traversal reach and author automatic elevators that reach
  a genuine second story, with safe boarding and checkpoint recovery.

**Why:** The existing 96 pixel lift is not sufficient evidence that an upper
route requires an elevator. Required routes must remain accessible after a fall
or checkpoint restart.

**Context:** Start with `game/entities/lift.gd`,
`game/level_validator.gd`, `game/player_motor.gd`,
`tools/levels/layout.py`, and `game/level.gd`. Lift rise appears in runtime
movement, validation, and route generation. Update those contracts together.
Some upper rewards already exist in Level 1; improve their purpose rather than
assume the level has no elevated work.

The user chose continuous travel with pauses at both landings, not call controls.
Measure jumping, wall jumping, and nearby platform access before selecting rise
and hazard span. Keep the validator approximate. Use real physics to test
boarding, riding, leaving, and attempted bypasses. Do not add a second physics
engine or a generated movement solver.

Define a safe initial landing and direction for each elevator. Restore task
effects before resetting its motion. Define safe initial movement and timing for
hazards without reactivating a hazard that saved task progress has disabled.
Do not assume time zero is safe for every authored phase offset.

**Acceptance:** Verify shaft clearance, wider jumps and visible landing areas,
automatic return, and completion from each checkpoint. Check checkpoint and
landing placement against active lethal liquid. Test falls, interrupted rides,
death during movement, and restored power dependencies. No restart may place the
hero directly in an unavoidable hazard.

**Depends on / blocked by:** Measured jump behavior, chosen landing pause
duration, per level geometry, and the separate progress restore and motion reset
methods. Task controlled elevators also depend on item 2.

## 5. Approve background depth and its asset contract

- [ ] **What:** Approve layer counts, scroll speeds, and composition for indoor
  and outdoor environments using rendered and measured evidence.

**Why:** Full height background coverage is already fixed, but the game still
uses two depth layers. Additional rack rows should communicate distance without
obscuring hazards or worsening motion quality.

**Context:** Start with `game/level.gd`, `tools/environment_assets.py`,
`tests/background_coverage_test.gd`, `tests/test_asset_pipeline.py`,
`tests/export_test.gd`, and `export_presets.cfg`. The earlier sketch proposed a
distant shell and four rack bands. That count and its speed factors are not
approved. The user approved ordered per environment manifests, not a replacement
for all asset tools.

Define layer order, texture path, scroll factor, tint, and coverage behavior in a
validated manifest. Keep background racks as artwork within layers, not
individual physics objects. Preserve required production asset errors and the
separate gray box mode.

**Acceptance:** Obtain visual approval of depth and foreground readability.
Check the highest and lowest camera positions and supported viewport shapes.
Measure frame timing and texture use before and after adding layers. Keep
background loading local to the active level. Extend export inclusion and source
exclusion checks for every declared environment. Record export size and justify
growth against a measured budget.

**Depends on / blocked by:** A rendered performance baseline and animation
diagnosis from item 1; user approval of composition; final camera bounds from
item 4; actual device evidence from item 6. Do not infer real phone performance
from emulation.

## 6. Collect difficulty and device evidence

- [ ] **What:** Collect player observations before changing difficulty targets,
  and record performance on actual supported devices.

**Why:** Automated route duration is not a measure of human difficulty. Average
frame rate alone does not establish smooth animation or acceptable phone play.

**Context:** Start with `tools/levels/layout.py`,
`tests/test_level_layouts.py`, `tests/route_test.gd`,
`.github/workflows/pages.yml`, `game/score.gd`, and
`game/save_store.gd`. The existing formula and three star smoke gate both couple
automation to difficulty. The user approved separating those contracts now while
retaining current numeric targets and earned stars.

Record completion time, failures, confusing interactions, elevator waiting, and
whether players find and use upper routes. Record the build and level for each
observation. Do not invent replacement targets or claim that a small sample
proves balance. Review the observation set before changing par or SLA values.

For performance, use repeatable segments and existing Godot and browser tools.
Include desktop native and web behavior, plus an available real phone. Record
the actual device, browser, build, and capture conditions. Compare frame timing,
loading, texture use, and dense background scenes. Add narrow diagnostics only
when existing tools cannot explain the result.

**Acceptance:** CI checks completion within the SLA and an independent route
budget, with no damage, respawns, or runtime errors. Star boundary tests remain
separate. Human difficulty changes cite observations. Performance budgets cite
actual measurements. Label emulated phone evidence explicitly, and record any
missing physical device evidence as unresolved.

**Depends on / blocked by:** Player participation and device access. Baseline
capture can start with existing content. Final calibration follows the selected
geometry, hazards, and tasks; it must not block separating the code contracts.

## NOT in scope

- Reimplementing completed milestones or the delivered guidance and branding.
- Multiplayer, accounts, or online leaderboards.
- A new currency, upgrade economy, or automatic difficulty adjustment.
- A general task scripting framework, a second physics engine, or a custom
  texture cache without a demonstrated need.
- Treating proposed environments, task rules, or sketch dimensions as approved.

## Review failure coverage

These are required checks for future changes, not passing test results.
Existing tests cover parts of the baseline; the new behavior still needs proof.
Task specific rows apply only if the corresponding concept is selected.

| Path | Realistic failure | Required coverage and handling |
|---|---|---|
| Level and asset loading | A required new texture or manifest is absent. | Extend parser, asset, and export tests; stop loading with a visible error. |
| Hero animation | A repeated action restarts or an artwork frame jumps. | Capture rendered motion; add cause specific playback or asset regressions; require visual confirmation because static validation can miss the visible defect. |
| Ordinary damage | The displayed reaction does not match the hazard. | Extend player and level tests with each cause; validate required clips before play. |
| Fatal contact | Invulnerability suppresses death, or overlapping contacts restore twice. | Extend health and level tests; accept fatal contact once, enter death state, and restore after 0.5 seconds. |
| Death beside an exit or checkpoint | The same frame completes the level or saves a fatal location. | Extend level integration tests; death takes priority and prevents those actions. |
| Progress restoration | Task text resets but its fire, liquid, or power effect does not. | Extend checkpoint and entity tests; restore associated state together before motion resumes. |
| Motion reset | A returning elevator or active hazard makes a checkpoint immediately fatal. | Add authored safe reset and placement checks, plus real routes from each checkpoint. |
| Upper routes | A required elevator can be bypassed or cannot be boarded safely. | Extend lift and real physics route tests; verify clear shafts, landing pauses, bypass attempts, and recovery. |
| Interaction selection | The prompt identifies a different task from the action. | Extend guidance and input tests with overlapping targets; one selected entity owns both. |
| Cable task | Partial placement or a consumed spool survives the wrong checkpoint. | Test partial work, completion, and retry; restore resource and endpoint state consistently. |
| Rack assembly | A component disappears without restoring its installed state. | Test each partial assembly state and retry; restore inventory and installation together. |
| Fire task | A fire stays extinguished after its task is undone. | Test interruption and checkpoint restoration; derive visible access from restored fire state. |
| Cooling task | Equipment reports success while its thermal state remains faulty. | Test prerequisites and visible completion effects; keep task and equipment state consistent. |
| Leak task | Restored progress leaves the route incorrectly drained or dangerous. | Test before and after drainage checkpoints; restore hazard state while keeping the floor solid. |
| Power task | Required parts are beyond equipment that the same task must enable. | Validate authored dependencies and run checkpoint routes; reject or correct an unwinnable layout before release. |
| Results | The wrong hero or star reaction appears. | Extend main flow and asset tests for both heroes and all three ratings; validate clips before use. |
| Difficulty and CI | A human target change fails an unrelated bot formula assertion. | Remove formula coupling across Python, Godot, and CI; retain independent completion budgets and star boundary tests. |
| Background depth | New layers expose empty space or obscure hazards. | Extend coverage tests and inspect rendered camera limits; reject invalid layer data at load. |
| Pause, help, and touch | A buffered or cancelled action fires after restoration. | Extend level, mobile bridge, and browser tests; clear transient state without synthesizing physical key releases. |
| Export and loading | Source images enter the download or new runtime art is omitted. | Extend inclusion and exclusion checks and measured size gates; fail the build with an actionable report. |

Three critical planning risks require explicit proof: safe placement over lethal
liquid, consistent restoration of task effects, and reachable prerequisites for
tasks that change access. Without the planned checks, each could fail silently.
They are not claims of defects in currently shipped features.
