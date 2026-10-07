# Midcreek Hero remaining work

Recorded from the October 4, 2026 app direction review.
The user selected a full review and requested these six entries.
This document records decisions and prerequisites. It does not mark implementation
or verification complete.

The M0 to M7 milestones, mobile controls, graphical help, input display settings,
startup branding, climbing alignment, and full height background coverage are
already delivered. The earlier plan checkboxes do not reflect that status.
Climbing alignment does not establish smooth animation.

## Backlog status (October 6 reconciliation)

The backlog completion plan delivers the open work as stacked pull requests.
Each open item below has one acceptance criterion and names its pull request.

| Item | Status | Pull request |
|---|---|---|
| 1. Hero animation smoothness | Delivered in PR1 | PR1, `ridermw-hero-animation` |
| 2. Additional environments and tasks | Delivered | #26 (`ec3da76`, merged as `b2353f3`) |
| 3. Role of sliding | Decided: retained | October 5 request |
| 4. Elevator geometry and restart states | Delivered in PR3 | PR3, `ridermw-elevators` |
| 5. Background depth | Open | PR5, `ridermw-background-depth` |
| 5a. Background scale | Open | PR4, `ridermw-background-scale` |
| 6. Route timing contract | Delivered | Independent route timing increment |
| Cable pile movement, drone sliding | Delivered in PR2 | PR2, `ridermw-hazards` |
| Difficulty and device evidence | Requires owner | See "Requires owner" |

The size budget wording differs between an earlier draft and this file. The
draft said "establish a measured download size budget". This file says "report
measured download size without a size ceiling". This file has the later decision.

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
  Report measured download size without a size ceiling.

## 1. Diagnose hero animation smoothness

- [x] **What:** Diagnose and correct jerky running, repairing, and climbing for
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

**Acceptance criterion (PR1):** A rendered anchor probe for both heroes shows
no unexplained helmet, torso, tool, or boot anchor jump in run, idle to run, run
to idle, idle to diagnose, and diagnose to idle, and each corrected cause has a
regression that failed before the fix.

### Verified increment: frame anchor registration (PR1)

- [x] Extend `tests/animation_probe.gd` with idle to run, run to idle, idle to
  diagnose, and diagnose to idle phases, and record sprite facing. Diagnosis
  uses a Level 2 rack because Level 3 has no diagnosis rack.
- [x] Add `tools/animation_anchors.py`. It measures helmet, torso, boot span,
  and reach anchors in every frame and joins them with the rendered trace. It
  reports every independent cause of each frame change: source registration,
  authored pose, playback timing, or camera and render timing. A pose change
  cannot hide a timing or camera cause. Tool reach deltas are reported; a
  repair or diagnosis tool swing over registered boots is an authored pose.
  Its rules failed in tests before the implementation.
- [x] Measure before changing artwork. With fixed 60 Hz steps, every flagged
  change was source registration: the man's run frames 3 and 7 move the whole
  figure 9 and 4 texels forward (helmet x=125 and 120, other frames 114 to 116);
  both heroes' idle boots drift up to 3.5 texels; the man's diagnosis boots
  drift 3.5 texels in frames 0, 4, and 7. No playback timing or camera cause
  appeared. Evidence: `docs/evidence/animation-anchors/before-report.json`.
- [x] Classify authored poses separately. The run pose leans its helmet about
  7 texels ahead of the walk pose while the torso stays within 4 texels. The
  woman's diagnosis leans back over fixed boots. These stay unchanged.
- [x] Observe failing artwork regressions in `tests/test_asset_pipeline.py`:
  run helmet registration within 1 texel of x=116, and planted idle and
  diagnosis boots within 0.5 texel of the pivot.
- [x] Correct the frames with integer translation only. `python -m
  tools.animation_assets register` applies the run helmet rule and the planted
  stance rule to published frames; `normalize` applies the same rules. All 37
  changed frames keep their exact color counts and vertical bounds.
- [x] Measure after the change: zero unexplained changes for both heroes in
  all five phases (`after-report.json`). Native help captures for both heroes
  render the corrected clips.
- [ ] Browser run capture is blocked on this host. Headless Edge uses software
  rendering; each screenshot takes longer than one 71 ms run frame, so no
  capture matched its sampled frame. A real time native run on this host also
  renders at about 33 Hz, which quantizes frame changes to 2 physics ticks
  (`realtime-before-report.json`). That is a host limit, not a game cause.

[Run frames before and after](docs/evidence/animation-anchors/run-before-after.png)
show the helmet column at x=116 for both heroes.

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

The exact native traces are committed as
[before](docs/evidence/animation-cadence/before.json) and
[after](docs/evidence/animation-cadence/after.json). Group samples by `phase`;
subtract `wall_us` values at successive sprite frame changes to measure holds.
For the transition from frame 5 to frame 0, `physics_frame` spans confirm six
ticks after the fix, compared with occasional seven tick spans before it.
The baseline uses `3f35b12`. The corrected player matches `032ae3b`.
Rendered movies remain local session artifacts, not published evidence.
The repeatable harness is `tests/animation_probe.gd`.
Native cadence, player, help, and hit stop checks pass. Both native help
demonstrations were captured. The available Edge Work Browser subsequently
rendered the desktop export and completed the male Level 3 route without hits
or respawns. Browser frame timing and complete motion coverage remain unresolved.
Physical phone evidence and player difficulty observations also remain unresolved.

### Verified increment: climb cadence and direction

- [x] Diagnose the reported mismatch between climbing motion and playback.
  Six frames at 8 fps take 0.75 seconds while the hero travels 67.5 world pixels.
  The artwork depicts two hand steps; each 32 pixel ladder tile has two rungs.
  Descent also played the ascent sequence forward.
- [x] Tie the cycle to 32 pixels of movement and reverse it during descent.
  The motor still moves at 90 pixels per second. Effective playback becomes
  16.875 frames per second at that speed and scales with slower input.
  Stopping and changing direction retain the current pose.
- [x] Observe the failing regression for both heroes before changing playback.
  All 33 cadence checks then pass, including diagonal input and sideways exits.
  Real physics route segments cover ascent,
  descent, and return for both heroes without hits or respawns.
- [x] Capture native walking, running, repair, ascent, and descent for both heroes.
  The [native trace](docs/evidence/animation-cadence/climb-after.json) records
  playback speeds of 2.109375 for ascent and -2.109375 for descent.
- [x] Capture a climb, stop, and reversal in the same rendered scene.
  Each hero holds one unchanged position and sprite phase for 36 render samples
  during the stop, then resumes with reversed playback. Neither segment takes
  damage or respawns.
- [x] Verify exported ascent, descent, stop, and return for both heroes through
  ordinary emulated gamepad input. The recovered check centers the body clear
  of the upper landing before descent. Both heroes return within 3 world pixels
  of the held rung, stay attached to the ladder, and stop playback with no hits
  or respawns. Evidence: [man](docs/evidence/animation-cadence/browser-climb-man.json)
  and [woman](docs/evidence/animation-cadence/browser-climb-woman.json).
  This confirms the playback correction, not perfect artwork continuity or
  physical controller behavior.

The climb test uses an isolated prefix of the authored Level 3 route. Adding
descent to the full route shifted later moving hazard timing and caused hits,
so the production route remains unchanged. Its full completion check still
passes in 96.22 seconds without hits.

### Verified walking asset correction

- [x] Reproduce the repeated anatomical legs identified by the user in pairs
  2/6 and 3/7. Whole sheet generation continued the defect and was rejected.
- [x] Correct the opposite leg roles with individual masked pose edits.
  Check all four pairs for both heroes: 1/5 contact, 2/6 loading, 3/7 passing,
  and 4/8 push off and forward reach. Preserve the torso and equipment rather
  than mirroring the whole figure.
- [x] Keep source authoring corrections separate from runtime normalization.
  Restore shortened source leg extent to one shared source floor reference.
  The normalizer still applies one fixed scale to every source cell.
- [x] Remove the measured three pixel head step between opposite sheet rows.
  The head registration regression failed for all eight opposite phase pairs
  before source correction. Paired phases now differ by at most one raster pixel.
- [x] Add and observe a failing contact regression: the old female passing
  poses had two grounded feet. Both heroes now pass the one grounded foot check.
  This check does not replace visual verification of anatomical leg identity.
- [x] Add a measured depth-value guard for all four opposite pairs. Independent
  review found that the female 4/8 pair still repeated the near leg; this
  regression failed for that pair before its masked occlusion correction.
  Every pair now reverses the depth-value cue. Visual occlusion review remains
  required because the value cue is a proxy, not an anatomical classifier.
- [x] Preserve the published animation palette when normalizing replacements.
  The palette preservation and invalid palette regressions failed before the
  implementation and now pass.
- [x] Preserve the previous walking shade budgets of 39 colors for the man and
  37 for the woman. A regression caught the draft's excessive shade density.
  Canonical source pixels now use the original walking color ramps.
- [x] Retain actual generator records, timestamps, model versions, input hashes,
  and prompts for the base generations and masked edits. Append the source
  retouch history and canonical source hashes instead of replacing provenance.
- [x] Capture complete native walking cycles for the
  [man](docs/evidence/animation-cadence/walk-man.png) and
  [woman](docs/evidence/animation-cadence/walk-woman.png).
  Eight frames, 10 fps, movement rules, and the shared palette remain unchanged.
- [x] Verify exported walking through normal game input with an emulated
  gamepad. Both heroes display all eight frames while moving right and left,
  then stop and pause without replaying released input. All 32 captures match
  every opaque source pixel. Published browser frames cover
  [man right](docs/evidence/animation-cadence/browser-man-right.png),
  [man left](docs/evidence/animation-cadence/browser-man-left.png),
  [woman right](docs/evidence/animation-cadence/browser-woman-right.png), and
  [woman left](docs/evidence/animation-cadence/browser-woman-left.png).
- [x] Verify the optional browser probe is absent from ordinary URLs and from
  a real release export, even when its query flag is supplied.
- [x] Run the existing emulated phone input regression with the shared CDP
  helper. Correct its stale expectation of a text prompt without changing
  the delivered graphical prompt behavior.

Running and repair artwork still require separate continuity work.
Different frame hashes or different arm poses are not proof that legs alternate.

## 2. Implement approved additional environments and tasks

- [x] **What:** Add ten levels with the approved environments and all six new
  task types. Preserve the existing five levels and sliding.

**Delivered:** #26 (`ec3da76`, merged to main as `b2353f3`). Evidence:
`docs/evidence/campaign-expansion/`. Levels 06 to 15 pass the full route and
every checkpoint replay for both heroes.

**Why:** The user approved all ten environments and six task types on October 5.
The new work belongs in levels 06 through 15, not revisions of existing levels.

**Context:** Approved environments are Cooling Gallery, Operations Suite, Fiber
Exchange, Loading Yard, Fire Response Hall, Pump Station, Rooftop Air Handlers,
Generator Courtyard, Facility Approach, and Expansion Site. The outdoor concepts
include facility scenery, trees, vehicles, parking, and construction. The proposed
background protest cameo is optional and is not an enemy encounter.

Approved tasks are running a cable, assembling a rack from multiple components,
extinguishing a fire, restoring cooling, containing a leak, and restoring a power
branch. The [expansion design](docs/superpowers/specs/2026-10-05-campaign-expansion-design.md)
records mapping, resource rules, effects, and checkpoint contracts. Start with
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

**Acceptance:** Give each approved
environment distinct route geometry and work, not only different colors. Cover
blocked, active, interrupted, complete, and restored task states. Verify one
target owns the displayed prompt and action when targets overlap. Verify keyboard,
gamepad, and touch access. Provide a complete route and safe checkpoint routes.

**Depends on / blocked by:** Measured traversal dimensions from
item 4; the accepted death and recovery contracts; asset decisions from item 5.
Fatal liquid and death recovery remain owned by the existing campaign session.
The new session owns new work state, level content, progression, and backgrounds.
Do not add new level files before their routes and required assets are ready.

### Task state increment

- [x] Add isolated state units for all six approved tasks.
- [x] Observe focused failures before implementation and verify partial rollback.
- [x] Connect task entities, resource inventory, prompts, artwork, and effects.
- [x] Deliver complete routes and every checkpoint replay for levels 06 through 15.
- [x] Verify native and browser captures and report export size.

Level 06, Cooling Gallery, now includes its authored route, three checkpoints,
runtime artwork, and save migration from completed level 05. Both heroes finish
the native and exported browser routes in 41.83 seconds without hits or respawns.
Native replay from each checkpoint also completes without additional respawns.
Levels 07 through 09 now have authored routes and pass native checkpoint replay
for both heroes. Their distinct layouts use separate component stores, upper
and lower fiber routes, and covered loading platforms around a service trench.
Levels 10 through 12 now have authored routes and pass native checkpoint replay
for both heroes. Fire suppression requires a reachable refill station; Pump
Station returns through the drained floor; the rooftop route uses a lower
maintenance passage between equipment platforms.
Levels 13 through 15 complete the approved campaign. Their authored routes and
all checkpoint replays pass for both heroes. Expansion Site combines all six
mechanics and returns through the drained construction floor. Level 15 saves
its result without offering a nonexistent next level.

## 3. Decide the role of sliding

- [x] **What:** Decide whether to retain sliding, then define its purpose in the
  revised levels.

**Decision:** Retained. The October 5 request keeps sliding and the existing
level behavior. Sliding clears low trays. PR2 makes it the only way past
security drones.

**Why:** The user does not see a clear reason for the move. Additional forced
sliding sections would not resolve that concern by themselves.

**Context:** The October 5 request retains sliding and existing level behavior.
Sliding currently clears low trays and passes under drones. Start
with `game/player_motor.gd`, `game/player.gd`, `tools/levels/layout.py`,
`tools/levels/level3.py`, `tools/levels/level5.py`, and `game/help_content.gd`.
The plan proposes visibly useful service openings, shortcuts, or optional work
areas. Do not remove or rework the existing move during this expansion.

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

**Acceptance criterion (PR3):** At all six lift sites, real physics shows that
jump and wall jump cannot reach the upper story without the lift, and the route
gate passes for every checkpoint and both heroes after a death during a ride.

**Depends on / blocked by:** Measured jump behavior, chosen landing pause
duration, per level geometry, and the separate progress restore and motion reset
methods. Task controlled elevators also depend on item 2.

**Delivered (PR3):**
- Runtime lifts now rise 5 tiles / 160 px, use a 96 by 16 px one way platform,
  move at 64 px/s, and pause for 1.0 s at the lower and upper landings.
  The full period is 7.0 s. `game/entities/lift.gd` is the runtime source of
  truth for `RISE_TILES`; `game/level_validator.gd` reads that constant, and
  `tools/levels/layout.py` has a parity test against it.
- Level 04 and 05 lift decks are generated at row 7 (`stand - 5`) from
  `tools/levels/level4.py`, `tools/levels/level5.py`, and
  `tools/levels/layout.py`. The shipped `.level` and `.route.json` files were
  regenerated, not hand edited.
- `tests/elevator_bypass_test.gd` removes lift collision during bypass trials.
  For all six lift sites and both heroes, normal jumps leave the floor and are
  observed through landing or 1.5 s without standing on the deck. Wall jump
  trials assert wall contact before each jump press and assert that the press
  produces an upward kick away from the deck face. Repeated wall-contact trials
  repeat that asserted kick several times. Nearby-platform trials discover every
  authored standable non-lift cell within 6 columns of the deck's left edge,
  start a run-and-jump trial from each one, and assert the hero never stands on
  the deck top. `tests/elevator_test.gd` covers boarding, riding, leaving the
  top landing, falling mid ride, and death during a ride restoring the
  checkpoint while the lift returns to the lower pause.
- `tests/level_validator_test.gd` checks the 5 tile shaft, 96 px deck sweep,
  standable upper landing, no checkpoints in shafts, and validator reachability
  with each lift removed. `tests/power_room_test.gd` covers the new offset
  timing and ride height.
- Evidence: rendered Level 04 captures for both heroes at each lift ride are in
  `docs/evidence/elevators/`. Route gates for levels 04 and 05 pass with zero
  hits and zero added respawns. Current route times are 109.2 s for level 04 and
  108.9 s for level 05, both under the unchanged 110 s budget.
- CI route gate groups now run `01,02,03` and `04,05` separately so the 60 s
  Godot test runner does not kill the longer elevator replay group.
- Rejected alternatives: keeping the 96 px / 3 tile lift with ceiling caps was
  rejected because it did not prove a real second story. Call controls were
  rejected by the accepted plan. A generated movement solver and a second
  physics engine were rejected; the validator stays approximate and real
  physics tests cover bypass attempts.

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
exclusion checks for every declared environment. Report export size without
using size as an acceptance gate.

**Depends on / blocked by:** A rendered performance baseline and animation
diagnosis from item 1; user approval of composition; final camera bounds from
item 4; actual device evidence from item 6. Do not infer real phone performance
from emulation.

**Acceptance criterion (PR5):** Every environment manifest declares ordered
shell, far, racks, and equipment layers with existing art, and the desktop
probe records p95 frame time at or below 16.7 ms on levels 1, 9, and 14.
Composition approval stays with the owner.

## 5a. Correct background object scale

- [ ] **What:** Make background objects match the hero scale. Level 07 shows
  a desk at about 1.2 times hero height.

**Why:** Equipment layers fill the full view height without a hero scale rule,
and layer texels are up to 8.5 times the hero texel size.

**Context:** `tools/environment_assets.py`, `game/background_set.gd`,
`tests/background_manifest_test.gd`, and the reference capture
`docs/evidence/campaign-expansion/07-man-native.png`.

**Acceptance criterion (PR4):** In equipment layers, opaque regions connected
to the floor band are at most 92 world px tall, every layer has an integer texel
ratio to the hero, and the paired level 07 capture shows the chair top at or
below the hero shoulder.

## 6. Collect difficulty and device evidence

- [x] **What:** Separate the automated route timing contract from human
  difficulty. Delivered by the independent route timing increment below.
  Player observations and device measurements moved to "Requires owner".

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

### Verified increment: independent route timing

- [x] Remove the Python par formula and the Godot formula and par range gates.
  Keep all five authored par and SLA values unchanged.
- [x] Use `tests/route_budgets.json` for independent automated timing limits.
  Each route has a 110 second budget, compared with measured completion times
  of 93.17, 95.73, 96.22, 97.20, and 99.87 seconds.
- [x] Require CI completion before the SLA and within the route budget, with
  no hits, respawns, or runtime errors. Reject missing, duplicate, or invalid
  completion records. Accept all three ratings independently of route timing.
- [x] Prove the separation with real physics. Level 3 with a test only par of
  1 second finishes in 96.22 seconds with one star and no hits. It failed the
  old formula and range checks, then passed the independent route check.
- [x] Preserve earned stars and keep score boundary checks separate.
- [ ] Collect player observations before changing human difficulty targets.
- [ ] Verify the updated browser smoke assertion in an exported browser.

All five routes passed both the Godot route gate and the full main scene smoke
checker. The Node touch checks pass. Browser smoke execution and physical device
measurements remain unresolved; syntax checks do not replace those observations.
The exported resource check caught diagnostic traces entering the download.
An explicit `docs/evidence/*` exclusion removed 917752 bytes from the debug
resource pack. All 46 resource checks now pass. This is not a production
download budget or a device performance result.

## Follow up: continuous cable pile movement

- [x] Make every cable pile obstacle move continuously during gameplay,
  including the currently stationary piles. The user named Mario mushrooms
  as the movement reference on October 5.

Define movement speed, direction changes, and terrain edge behavior before
implementation. Preserve visible collision bounds. Update affected route timing
and verify safe checkpoint recovery for both heroes.

**Acceptance criterion (PR2):** Every cable pile changes x within 2 s and
stays inside its floor span, and the route gate passes for every checkpoint
and both heroes with the level 03 known gaps removed.

**Delivered (PR2):**
- Stationary piles patrol at 40 px/s and reverse at walls, floor edges, and
  48 px from the authored cell (decision 3A). The validator rejects a pile
  with less than 32 px to patrol (8A). Moving piles keep 96 px at 60 px/s.
  Drones and both pile kinds share `game/hazards/patrol.gd` (5A); existing
  hazard behavior tests pass unchanged.
- Respawn resets hazard and lift motion in every level, not only levels with
  work stations (1A). A failing Level 3 test showed the old gap. The gate
  holds the hero still for 2 s after every checkpoint restore with zero hits.
- Fixed takeoff points cannot clear a pile whose phase differs between a full
  run and a checkpoint replay. The route step `until_hazard` waits on safe
  floor until a run up and jump are predicted clear, using the deterministic
  patrol and the motor's jump constants. Rejected alternatives: phase hazards
  from the level timer (conflicts with authored safe restart states), and
  fixed waits (route time grows with every pile).
- A route slide press made in the air now waits for floor contact. A checkpoint
  replay landed a jump at a tray entrance and lost its slide press.
- Level 05 moves one pile from column 160 to 162, so a heat vent jump cannot
  land within its reach. Levels 01 to 05 were regenerated with their scripts
  (2A); only routes and that one pile changed.
- Evidence: `tests/hazard_motion_test.gd`, `tests/hazard_route_test.gd`, the
  route gate for all fifteen levels, and captures in `docs/evidence/hazards/`.

## Follow up: pass security drones only by sliding

- [x] Prevent the hero from jumping over security drones. Sliding underneath
  must be the only way to pass them. The user requested this on October 5.

Use visible drone geometry and matching collision bounds. Verify that ordinary
jumps and wall jumps cannot bypass a drone, while sliding provides safe
clearance for both heroes. Update affected routes and checkpoint recovery checks.

**Acceptance criterion (PR2):** Real physics shows that jump and wall jump into
each drone cause a hit, while keyboard, gamepad, and touch slides pass under it
for both heroes.

**Delivered (PR2):** A drone draws a pulsing scanner beam from 36 to 200 px
above the floor; the drawn beam and the hit rectangle share `beam_rect()`
(decision 4A). Rejected alternatives: a ceiling cap above each drone (geometry
edits in every level) and a higher hover (allows running under).
`tests/drone_clearance_test.gd` failed for jump and wall jump before the beam.
It now shows both are hit, and `InputEventKey`, `InputEventJoypadButton`, and
`MobileInput` touch slides pass under the beam for both heroes (9A).

## Requires owner

These items need people or physical devices. Agents supply captures and
procedures but cannot close them.

### Physical phone performance

**What:** Record frame timing and loading on an actual supported phone.
**Why:** Emulated phone evidence does not establish real performance.
**Context:** Use repeatable segments in levels 1, 9, and 14 with the exported
web build. Record the device, browser, build, and capture conditions. Compare
dense background scenes before and after PR5.
**Depends on:** A physical phone and the PR5 build.

### Physical controller checks

**What:** Play one level with a physical gamepad and confirm move, jump, slide,
repair, and prompts.
**Why:** Headless tests inject gamepad events. They do not prove a real device
mapping in a browser.
**Context:** `game/input_setup.gd`, `game/control_prompt.gd`, and the exported
web build. Record the controller model and browser.
**Depends on:** A physical controller.

### Player difficulty observations

**What:** Collect completion time, failures, confusing interactions, elevator
waits, and upper route use from players.
**Why:** Automated route duration does not measure human difficulty. Par and
SLA values change only when observations justify it.
**Context:** `tools/levels/layout.py`, `game/score.gd`, and
`tests/route_budgets.json`. Record the build and level for each observation.
**Depends on:** Player participation, after PR2 and PR3 change hazards and lifts.

## Verified reconciliation (PR0)

- [x] Back up unpushed work as `backup/hero-animation-improvements` and
  `backup/preserved-{e40bdbd,9b93224,3188760,e7c6a37,fbc789e}`.
- [x] Audit each backup against main. Main contains or supersedes every file,
  except tooling artifacts and `tests/liquid_capture.gd`. The capture harness
  stays on its backup branch. `tests/expansion_capture.gd` now has a fixture
  path and a death capture mode instead (`docs/evidence/liquid/`).
- [x] Extend `tests/expansion_route_test.gd` to levels 01 to 15. It replays
  the full route and every checkpoint suffix for both heroes. It failed for
  uncovered levels and for a truncated level 01 route before the change.
- [x] The extended gate found that the level 01, 02, and 04 routes jump
  through the third checkpoint flag without activating it. Feet were 17 px
  above the flag base. The checkpoint trigger now matches the visible 64 px
  flag. Rejected alternative: move checkpoints or routes, which leaves the
  same trap for players.
- [x] The gate takes about 199 s locally and about 98 s in CI. CI runs it in
  four `EXPANSION_ONLY` groups of about 25 s each, below the 60 s limit.
- [x] Known gap for PR2: level 03 replays from checkpoints 0 and 1 took hits,
  because hazards restart at their authored phase. PR2 removed both entries;
  `KNOWN_GAPS` is empty.

## NOT in scope

- Reimplementing completed milestones or the delivered guidance and branding.
- Multiplayer, accounts, or online leaderboards.
- A new currency, upgrade economy, or automatic difficulty adjustment.
- A general task scripting framework, a second physics engine, or a custom
  texture cache without a demonstrated need.
- Adding unapproved environments or replacing existing levels with new content.

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
| Export and loading | Source images enter the download or new runtime art is omitted. | Extend inclusion and exclusion checks; fail invalid exports with an actionable report. Report size without a ceiling. |

Three critical planning risks require explicit proof: safe placement over lethal
liquid, consistent restoration of task effects, and reachable prerequisites for
tasks that change access. Without the planned checks, each could fail silently.
They are not claims of defects in currently shipped features.

## Verified repair artwork registration

- [x] Reproduce planted stance drift separately from playback and physics.
  Across six repair frames, the man's boot span center varies by 17 texture
  pixels and the woman's by 10. The rendered physics position remains fixed.
- [x] Observe failing shipped artwork and normalization regressions before
  correcting the registration.
- [x] Register the lower boot span at the x=104 pivot with integer translation.
  All twelve published frames preserve their exact pixel colors and counts,
  vertical baseline, scale, authored six frame count, and 10 fps cadence.
  Normalization rejects missing floor contact or clipped artwork before writes.
- [x] Verify native gameplay and both selected hero help demonstrations.
- [x] Verify ordinary emulated gamepad repair in the exported debug game.
  Both heroes display all six frames without moving, taking hits, or respawning.
  Every opaque source pixel matches the browser captures:
  [man](docs/evidence/animation-cadence/repair-man-browser.png),
  [woman](docs/evidence/animation-cadence/repair-woman-browser.png).
  The corresponding JSON traces preserve input outcome and player state.

This is a registration correction, not proof of perfect repair artwork.
The woman's individual boot edges still vary by up to 3 texture pixels within
the centered stance. PR1 registers idle and diagnosis boots on the same pivot.
Torso and tool poses still need visual judgment.
The lower 16 pixel band must contain only planted boots; future source art
must respect that assumption.

Runtime pixel colors remain unchanged. The previews also replace stale
versions whose colors differed from the published frames. Future normalization
reproduces the corrected geometry, not necessarily the existing color reduction
of older source sheets. Browser captures used the separately reviewed debug
probe from PR 15; the production repair assets do not depend on that probe.
Running artwork continuity, physical device evidence, and the remaining campaign
work stay open.

## Verified export coverage and size reporting

- [x] Replace sample-only resource assurance with loads of every declared
  animation, gameplay sprite, viewer sprite, background layer, and audio stream.
  Recursively check the exported art tree for source directories and metadata.
- [x] Prove the expanded check with a deliberately missing ladder texture.
  The previous 53 check gate incorrectly passed that pack. The expanded gate
  rejected it with the exact missing path. The restored full release pack
  passes 413 checks.
- [x] Measure the full published release artifact at 52800035 bytes under
  Godot 4.7.2. Record each file in `tests/export_budget.json`.
- [x] Count every published file, including nested additions, and reject missing
  or empty required runtime files. Size reporting has no acceptance ceiling.
- [x] Exercise acceptance above the former limit, nested file measurement,
  missing resources, and invalid required file configuration.
- [x] Reproduce and fix silent omission of an unreadable nested directory.
  Directory scan errors now fail export validation. Symlinks and nonregular files
  also fail instead of producing incomplete totals.
- [x] Reject undeclared published files independently of size.
  The recorded per-file baseline and required file list agree in
  a regression test. `.nojekyll` remains the only optional published file.

Size reporting measures file bytes before HTTP compression. It is not a measured
phone transfer size or a loading performance guarantee. Asset or engine changes
need a fresh measurement, but growth alone does not block delivery.

## Verified cable hazard visibility

- [x] Render stationary and moving cables at double pixel scale with nearest
  sampling. Keep the existing artwork, palette, and frame cadence.
- [x] Match collision rectangles to the combined opaque frame bounds:
  64 by 16 world pixels for stationary cables, 64 by 22 for moving cables.
  The visibility regression failed four checks before the correction.
- [x] Reproduce the larger footprint's effect on recorded routes.
  Level 3 and Level 5 initially took damage; do not weaken that gate.
  Real physics traces separated late takeoff from landing over a moving cable.
- [x] Adjust only the affected recorded launch positions. Level 3 changes
  three launch points by -32, -6, and +8 pixels. Level 5 changes one by +32.
  Generated level geometry, hazard positions, patrol range, movement speed,
  authored par and SLA, and independent route budgets remain unchanged.
- [x] Verify all five complete routes without hits or respawns.
  Completion times remain 93.17, 95.73, 96.22, 97.20, and 99.87 seconds.
- [x] Capture stationary and moving cable silhouettes in actual native levels.
  The alpha-bound check matches every declared cable frame.
- [x] Capture both cable types in exported browser gameplay with no hits or
  respawns: [stationary](docs/evidence/cables/stationary-browser.png) and
  [moving](docs/evidence/cables/moving-browser.png).
- [ ] Collect physical device and player readability observations.

This improves cable size and visibility. It does not establish new human
difficulty targets. `ROUTE_TRACE=1` now includes nearby hazard rectangles when
a hit occurs so future traversal failures can be diagnosed without changing
the damage or route acceptance rules.

The launch offsets depend on the current upstream route and patrol phase.
Recheck them after earlier route edits. A real physics sweep verified both
tuned Level 3 launches with offsets of -3 and +3 pixels around the selected
point (one physics tick in either direction). The -6 pixel launch still passes
at -6 additional pixels but fails at +6; the +8 pixel launch passes at +6
additional pixels but fails at -6. These are measured scripted-route margins,
not a human difficulty result.
