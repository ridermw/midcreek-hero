# Midcreek Hero: data center side scroller design

Date: 2026-10-03
Status: approved in brainstorming, awaiting spec review

## Goal

Build a fast side scrolling platformer in the existing Cel Shift pixel art
style. The player is a data center technician. The player runs and jumps
through the data hall, avoids hazards, and completes work orders before the
service level agreement (SLA) timer expires. The game has music, a health bar,
tasks, and 5 levels. An autopilot agent delivers it in milestone pull requests.

## Constraints

- Engine: Godot 4.7.2, GDScript, Compatibility renderer, single threaded Web
  export. Keep the current `export_presets.cfg` and Pages workflow.
- Art: Cel Shift style. Nearest neighbor sampling. Binary alpha. Shared
  palette. Technician frames are 208x208 with the pivot at (104, 184).
- All new art is generated with MockUI through the existing asset pipeline.
  The game is not done until all clips, tiles, hazards, props, backgrounds,
  and UI art exist. Fallbacks to static poses do not count as done.
- Audio: CC0 tracks and SFX only, with recorded provenance.
- Target: web build on GitHub Pages. Keyboard and gamepad. Progress saved in
  browser storage.

## Gameplay

### Player

- One technician. The player selects man or woman on the start screen.
  Both use the normal (`*-midcreek`) variant with real tools. Hybrid variants
  are not used.
- Moves: run, jump (variable height), wall slide with wall jump, slide under
  cable trays, climb ladders.
- Actions: primary = repair (hold), secondary = diagnose (multimeter).
- Control aids: coyote time 0.1 s (the player can jump for 0.1 s after
  leaving a ledge) and jump buffer 0.1 s (a jump pressed up to 0.1 s before
  landing still happens).

### Health

- 5 segments.
- A hazard hit removes 1 segment and starts 1.0 s of invulnerability.
  The `reaction` clip plays on a hit.
- A coolant pickup restores 1 segment, up to 5.

### Tasks (work orders)

Each level has 3 to 6 work orders. A task panel in the HUD lists them.

| Task type | Player action |
|---|---|
| Repair rack | Hold primary for 2.0 s in range of a faulty rack |
| Diagnose then repair | Use secondary on the rack, then hold primary |
| Fetch part | Collect a part (PSU or DIMM), then deliver it to a named rack |
| Reseat cable | Press the prompted button within a 1.0 s window, 3 times |
| Reboot switch | Activate 3 switch panels in the displayed order |

The exit door opens when all required tasks are complete. Optional tasks do
not block the exit. The results screen and the save file record how many
optional tasks the player completed (best value per level).

### Failure, checkpoints, and score

- Health 0 or SLA timer 0: restart from the last checkpoint with full health.
  Tasks completed before that checkpoint stay complete. Tasks completed after
  it reset. The timer resets to the value it had at the checkpoint, with a
  minimum of 30 s, so a restart can always make progress.
- 3 checkpoints per level.
- Stars per level: 1 = finish; 2 = finish under par time; 3 = under par time
  and at most 1 hit. Total elapsed time includes time lost to restarts.

### Levels

Target length: 2 to 4 minutes at par time.

| # | Name | New mechanics | Hazards | Tasks |
|---|---|---|---|---|
| 1 | Cold Aisle Onboarding | Run, jump, repair; prompts on screen | Floor cable snags (static) | Repair rack ×3 |
| 2 | Hot Aisle | Fetch part | Heat vents (periodic damage zones) | Repair, fetch part, diagnose then repair |
| 3 | Cable Jungle | Overhead trays, slide, wall slide | Moving cable snags | Reseat cable, fetch part, repair |
| 4 | Power Room | Moving lifts | Spark arcs (timed) | Reboot switch, diagnose then repair, repair |
| 5 | Outage Night | Flickering lights, short SLA | Patrol drones, all prior hazards | All types; final task repairs 4 racks in one row |

Level N+1 unlocks when level N is finished.

## Architecture

### Scene flow

`game/main.tscn` becomes the main scene:
title → character select → level select → level → results → level select.
The sprite viewer (`viewer.tscn`) stays in the repo but is not the main
scene.

### Code units

Each unit has one purpose and its own headless test.

| File | Purpose | Depends on |
|---|---|---|
| `game/player.gd` | Movement, jump, slide, actions, health hooks. Evolves from `hero.gd`. | animation library, input map |
| `game/level_parser.gd` | Parse and validate `.level` text into plain data | none |
| `game/level_builder.gd` | Build a `TileMapLayer` and entity nodes from parsed data | tileset, entity scenes |
| `game/task_system.gd` | Work order state machine; emits `task_completed`, `all_required_done` | none |
| `game/health.gd` | Segments, damage, invulnerability, healing; emits `died` | none |
| `game/sla_timer.gd` | Countdown, checkpoint snapshot; emits `expired` | none |
| `game/checkpoint_manager.gd` | Store and restore player position, timer, task state | task system, SLA timer |
| `game/hazards/*.gd` | One script per hazard type; each deals damage through `health.gd` | health |
| `game/tasks/*.gd` | One script per interactive task object (rack, part, cable, switch) | task system |
| `game/hud.gd` | Health bar, SLA timer, task panel, prompts | health, SLA timer, task system |
| `game/save_store.gd` | Stars, best times, unlocked levels in `user://save.json` (IndexedDB on web) | none |
| `game/audio_director.gd` | Music per level, SFX playback, Music and SFX buses | audio files |
| `game/menus/*.gd` | Title, character select, level select, results | save store |

`fault_rack.gd` evolves into `game/tasks/rack.gd`.

### Level file format

Path: `levels/0N-<slug>.level`. Tile size: 32x32 pixels.

```text
{
  "name": "Cold Aisle Onboarding",
  "sla_seconds": 240,
  "par_seconds": 150,
  "music": "level1",
  "background": "cold-aisle",
  "tasks": [
    {"id": "r1", "type": "repair", "at": "A", "required": true}
  ]
}
---
....................................
..................A.................
P.......====..........C.........E...
####################################
```

The JSON header comes first, then a `---` line, then the tile grid.
Legend: `.` empty, `#` floor, `=` platform, `|` ladder, `T` cable tray,
`P` player start, `C` checkpoint, `E` exit, `h` coolant. Uppercase letters
other than `C`, `E`, `P`, and `T` are entity anchors that the header
references. Each hazard type uses one reserved lowercase letter. The full
legend is in `levels/LEGEND.md`, and the loader reads the same table.

### Assets

All art uses MockUI. Run `mockui status` before each generation batch.
Every asset gets a prompt file under `prompts/`, sanitized metadata under
`generated/`, a normalize step in `tools/`, and an entry in the matching
manifest. Only normalized outputs ship in the Web export.

| Asset group | Contents |
|---|---|
| Technician clips | idle, walk, run, jump, slide, primary, secondary, reaction, signal for man and woman (18 clips; man idle and walk exist), existing 512 to 208 geometry |
| Tileset | Floor, raised floor tile, platform, cable tray, ladder, rack face (OK and fault), exit door, checkpoint beacon |
| Hazards | Heat vent, spark arc, cable snag, patrol drone (animated frames) |
| Props and pickups | PSU, DIMM, coolant, switch panel, cable port |
| Backgrounds | 5 parallax sets (far, equipment, floor), one per level |
| UI | Health segment, task icons, star, title art, button frames |

### Audio

- 7 music tracks: title, results, and one per level.
- About 15 SFX: jump, land, hit, heal, repair tick, repair done, diagnose,
  pickup, deliver, switch, checkpoint, door open, timer warning, fail, win.
- Sources: CC0 only (for example Kenney, OpenGameArt).
- Format: OGG Vorbis for music, WAV or OGG for SFX.
- `audio/LICENSES.md` records file, source URL, author, and license for every
  file. A test fails if a file has no entry.

## Error handling

- The level loader rejects a level with an unknown legend character, a task
  that references a missing anchor, no player start, or no exit. It reports
  the file and line.
- Missing animation clips or textures stop the level with an error on screen,
  as the current world scene does. There is no silent fallback.
- A corrupt save file is renamed to `save.corrupt.json` and a new save starts.

## Testing

| Check | Tool |
|---|---|
| Unit tests: health, SLA timer, task system, checkpoints, save store | GDScript headless tests |
| Level validator: parse, reachability of every task and the exit with the jump arc, par < SLA | GDScript headless test over `levels/` |
| Playthrough bot: replay one input recording per level; it must reach the exit | GDScript headless test |
| Asset checks: binary alpha, frame size, palette limit, manifest completeness | Python `unittest` |
| Audio provenance: every audio file has a license entry | Python `unittest` |
| Export check: runtime manifests, levels, and audio are in the pack | existing `tests/export_test.gd`, extended |

Godot can exit 0 on parse errors and on runtime script errors. Each test runner
must fail on `ERROR`, `SCRIPT ERROR`, or `Parse Error` in output, and each
test must set a completion flag that the runner checks.

## Delivery milestones

Each milestone is one PR. Merge it before the next milestone starts.
Request Copilot review when each PR opens and after each push. Commit and
push often. Update the README after each milestone.

| Milestone | Scope |
|---|---|
| M0 Core | Player controller, level parser and builder, health, SLA timer, checkpoints, HUD, gray box test level, unit tests |
| M1 Art base | 14 technician clips, tileset, Level 1 background, UI art |
| M2 Level 1 and flow | Level 1, menus, results, save store, audio director, first music and SFX |
| M3 Level 2 | Heat vents, fetch part, Level 2 background and music |
| M4 Level 3 | Cable trays, ladders, slide, wall slide, wall jump, reseat cable, Level 3 assets |
| M5 Level 4 | Spark arcs, lifts, reboot switch, Level 4 assets |
| M6 Level 5 | Drones, flicker, final task, Level 5 assets |
| M7 Polish | Screen shake, balance pass, playthrough recordings, README, Pages deploy |

## Done criteria

- All 5 levels are playable from the title screen to the results screen on
  the GitHub Pages build.
- Every level has a passing playthrough recording.
- All asset groups in the Assets table exist as generated art.
- All tests pass in CI.

## Out of scope

- Hybrid (sword and shield) variants.
- Multiplayer, online leaderboards, and mobile touch controls.
- Desktop exports.
