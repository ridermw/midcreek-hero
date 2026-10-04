# Data Center Side Scroller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a 5 level side scrolling platformer in a data center. It uses Cel Shift pixel art and has music, a health bar, an SLA timer, and work order tasks. It runs on GitHub Pages.

**Architecture:** Pure logic units (`RefCounted` scripts) hold the rules: health, SLA timer, task system, checkpoints, score, level parser, level validator, and player motor. Headless GDScript tests cover each unit. Thin Godot nodes (player, level controller, HUD, entities) connect the units to physics, input, art, and audio. Levels are text files that the parser reads and the builder turns into nodes.

**Tech Stack:** Godot 4.7.2, GDScript, Compatibility renderer, Web export without threads, Python 3 with Pillow for asset tools, MockUI for art, CC0 audio.

**Spec:** `docs/superpowers/specs/2026-10-03-datacenter-side-scroller-design.md`. Read it before each milestone.

## Global Constraints

- Godot version: 4.7.2. Renderer: `gl_compatibility`. Web export: `variant/thread_support=false`.
- Pixel art: nearest neighbor sampling (`texture_filter = 1`), binary alpha (0 or 255). Each asset group (technicians, tiles, hazards, props, ui, each background set) uses one shared palette. The union of opaque colors over all files in a group is at most 96.
- Technician frames: 208x208, pivot (104, 184). Clip set per variant: idle, walk, run, jump, slide, primary, secondary, reaction, signal.
- Tile size: 32x32 pixels. Level camera zoom: 2 (480x360 world pixels visible in the 960x720 window).
- Art source: MockUI only. Every asset has a prompt file, sanitized metadata, a normalize step, and a manifest entry. Fallback art does not count as done.
- Audio: CC0 only. `audio/LICENSES.md` lists every audio file.
- Health: 5 segments, 1.0 s invulnerability after a hit. SLA restart minimum: 30 s. Checkpoints per shipped level: 3. Tasks per shipped level: 3 to 6.
- Stars: 1 = finish; 2 = elapsed below par; 3 = elapsed below par and at most 1 hit.
- Logic units report errors through return values. They must not call `push_error`, because the test runner fails on any `ERROR` line.
- Godot tests print `<TAG>_COMPLETE: <N> checks, <F> failures` and run through `tools/godot_test.sh`.
- Prose in docs and README: no em dashes, no en dashes, no hyphenated words. Code, paths, and identifiers are exempt.

## Autopilot operating procedure

Apply these rules to every milestone.

1. **Branch.** Start each milestone from the latest `origin/main`. The step can run again safely:
   ```bash
   git fetch origin
   git switch m<N>-<slug> 2>/dev/null || git switch -c m<N>-<slug> origin/main
   gh pr list --head m<N>-<slug> --json number,state   # reuse an open PR if one exists
   ```
2. **Subplan.** For milestones M1 to M7, first use superpowers:writing-plans to write
   `docs/superpowers/plans/2026-10-03-m<N>-<slug>.md`. Use the interfaces in this
   document and in the M0 plan. Commit the subplan as the first commit.
3. **TDD.** For each task: write the failing test, run it, see it fail, write the code, run it, see it pass, commit. Run only the narrow test during a task. Run the full suite (step 7) once before each push.
4. **Commits.** Commit after each task. End each message with these trailers:
   ```
   Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>
   ```
5. **Review gate.** Before each push, run the rubber-duck agent on the diff. Fix findings that prevent bugs. Do not use other review agents.
6. **Push.** Push as `ridermw`. Check the identity first; never print tokens:
   ```bash
   test "$(gh api user -q .login)" = ridermw
   git -c credential.https://github.com.helper= \
       -c credential.https://github.com.helper='!gh auth git-credential' push -u origin HEAD
   ```
7. **Full suite.** Before each push:
   ```bash
   python3 -m unittest discover -s tests -p 'test_*.py'
   godot --headless --editor --path . --import
   for t in tests/*_test.gd; do
     case "$t" in tests/export_test.gd) continue ;; esac
     tag=$(basename "$t" .gd | tr '[:lower:]' '[:upper:]')
     tools/godot_test.sh "$t" "$tag" > /dev/null || { echo "FAILED: $t"; exit 1; }
   done
   ```
   `export_test.gd` does not run here. CI runs it against the exported pack.
   From M1 on, `world_test.gd` must pass and CI must run it.
8. **PR.** Open one PR per milestone with `gh pr create --base main` (skip if step 1 found one).
   Then run `gh pr edit <number> --add-reviewer @copilot`. Request the review again after each push.
9. **Wait with limits.** Run `timeout 1800 gh pr checks <number> --watch --fail-fast`. If a check
   fails, read the log with `gh run view --log-failed`, fix the cause, and push again. Stop after
   3 failed fix attempts for the same check. Wait at most 15 minutes for the Copilot review. If no
   review arrives, record that in the PR body and continue.
10. **Merge.** Merge only when CI is green and every review thread has a reply or a fix:
    `gh pr merge <number> --squash --delete-branch`. Then start the next milestone.
11. **Stop conditions.** Stop and report the exact command, its output, and the next action for
    Matthew in these cases: the identity check in step 6 fails, a push or merge is denied,
    branch protection blocks the merge, or a stop limit in step 9 or step 13 is reached.
12. **Stalls.** Wrap long commands in `timeout` (Godot tests 120 s, MockUI renders 600 s,
    exports 300 s). If a command times out, stop it, find the cause, and do not wait.
13. **Art loop.** Before each MockUI batch, run `mockui status`. After each render, normalize
    and open the preview PNG with the `view` tool. Reject a render that breaks the style,
    scale, transparency, or frame count rules. Render it again with a corrected prompt.
    After 3 failed renders of one asset, stop the milestone and report the asset, the prompts,
    and the previews. Do not substitute fallback art.
14. **Images.** Run `python3 -m unittest discover -s tests -p 'test_*.py'` after each
    normalize step. It enforces size, alpha, palette, and manifest rules.
15. **README.** Update `README.md` in each milestone with how to play and test the new parts.

## File structure

| Path | Responsibility | Milestone |
|---|---|---|
| `tools/godot_test.sh` | Run one Godot test; fail on error lines or a missing completion line | M0 |
| `game/health.gd` | Health segments, invulnerability, healing | M0 |
| `game/sla_timer.gd` | SLA countdown, warning, expiry, restore with minimum | M0 |
| `game/score.gd` | Star rating | M0 |
| `game/task_system.gd` | Work order state | M0 |
| `game/checkpoint_manager.gd` | Save and restore position, timer, completed tasks | M0 |
| `game/level_parser.gd` | Parse `.level` text into a Dictionary | M0 |
| `game/level_validator.gd` | Shipped level rules and reachability | M0 |
| `game/level_builder.gd` | Collision bodies and visuals from parsed data | M0, M1 |
| `game/player_motor.gd` | Movement physics without nodes | M0, M4 |
| `game/input_setup.gd` | Keyboard and gamepad input map | M0 |
| `game/player.gd`, `game/player.tscn` | Player body, input, animation | M0, M1 |
| `game/entities/*.gd` | Rack, part, cable port, switch panel, checkpoint, coolant, exit | M0, M3 to M6 |
| `game/hazards/*.gd` | Cable snag, heat vent, moving snag, spark arc, drone | M0, M3 to M6 |
| `game/level.gd`, `game/level.tscn` | Level controller | M0 |
| `game/hud.gd` | Health bar, SLA timer, task list, prompts, results | M0, M1 |
| `game/save_store.gd` | Save file | M2 |
| `game/audio_director.gd` | Music and SFX | M2 |
| `game/main.gd`, `game/main.tscn`, `game/menus/*.gd` | Screen flow | M2 |
| `levels/*.level`, `levels/LEGEND.md` | Level data | M0, M2 to M6 |
| `levels/routes/*.route.json`, `tests/route_test.gd` | Playthrough bot | M2 |
| `tools/sprite_assets.py`, `art/cel-shift/catalog.json` | Generate and normalize tiles, hazards, props, UI | M1 |
| `tools/audio_assets.py`, `audio/sources.json`, `audio/LICENSES.md` | Fetch and record CC0 audio | M2 |

## Milestones

| Milestone | Plan | PR title |
|---|---|---|
| M0 Core | `docs/superpowers/plans/2026-10-03-m0-core.md` (complete) | `feat: core platformer systems and gray box level` |
| M1 Art base | subplan, see below | `feat: technician clips, tileset, props, and UI art` |
| M2 Level 1 and flow | subplan, see below | `feat: level 1, menus, save, and audio` |
| M3 Level 2 | subplan, see below | `feat: level 2 hot aisle` |
| M4 Level 3 | subplan, see below | `feat: level 3 cable jungle` |
| M5 Level 4 | subplan, see below | `feat: level 4 power room` |
| M6 Level 5 | subplan, see below | `feat: level 5 outage night` |
| M7 Polish | subplan, see below | `feat: polish, balance, and release` |

---

## M1: Art base

**Depends on:** M0 merged.

**Deliverables**

1. Technician clips. Extend `tools/animation_assets.py`:
   - `CLIPS = ("idle", "walk", "run", "jump", "slide", "primary", "secondary", "reaction", "signal")`
   - `FPS = (6, 10, 14, 10, 12, 10, 10, 10, 8)`
   - `NORMAL_COUNTS = (6, 8, 8, 6, 4, 6, 8, 4, 6)`
   - `NORMAL_POSES["jump"]`: "Six-frame RIGHT-FACING PROFILE jump: 1 crouch, 2 push off with arms swinging up, 3 rising with knees tucked, 4 apex, 5 falling with legs reaching down, 6 landing crouch. Hands empty."
   - `NORMAL_POSES["slide"]`: "Four-frame RIGHT-FACING PROFILE floor slide: 1 drop low, 2 slide on hip with lead leg extended and one hand trailing on floor, 3 hold low slide, 4 rise to crouch. Body height in frames 2 and 3 at most half the standing height. Hands empty."
   - Keep the loop rule: only idle, walk, and run loop.
   - Mirror the changes in `game/animation_library.gd`: same `CLIPS` order and `FRAME_COUNTS = [6, 8, 8, 6, 4, 6, 8, 4, 6]`.
   - Update `tests/test_asset_pipeline.py` first, so it fails until the tables match.
2. Render and normalize 16 clips. Man: run, jump, slide, primary, secondary, reaction, signal. Woman: all 9. For each clip:
   ```bash
   timeout 600 python3 tools/animation_assets.py render --variant <variant> --clip <clip>
   python3 tools/animation_assets.py normalize --variant <variant> --clip <clip>
   ```
   Open `art/cel-shift/animations/previews/<variant>/<clip>.png` with `view`. Apply the art loop rule.
   Then run `python3 tools/animation_assets.py manifest` and check that it prints `Manifest clips: 18`.
3. Generic sprite tool `tools/sprite_assets.py` with `render`, `normalize`, `manifest` operations, driven by `art/cel-shift/catalog.json`. Each catalog entry:
   ```json
   {"name": "rack-fault", "group": "tiles", "cell": [32, 96], "frames": 1,
    "reference": "art/cel-shift/environment/layers/equipment.png",
    "prompt": "One server rack front, ... red fault LED ..."}
   ```
   `render` calls `mockui edit <reference> -p <prompt> --strict-prompt --model sunburst --quality high --background transparent --size <W>x<H> -o art/cel-shift/<group>/generated/<name>.png`. It writes the sanitized sidecar the same way `animation_assets.render` does. The source size is the cell multiplied by 8 for each axis and by the frame count horizontally, capped at 2048 per axis.
   `normalize` thresholds alpha at 128 and scales with nearest neighbor into the cell size per frame. It writes `art/cel-shift/<group>/frames/<name>/<NN>.png`.
   `palette --group <group>` builds one 96 color palette from all normalized frames in the group (median cut, no dithering). It maps every frame in the group to that palette and writes `art/cel-shift/<group>/palette.png`. Run it after the last normalize step of each group.
   `tests/test_sprite_assets.py` also scans every shipped file in each group. It checks size, binary alpha, and that the union of opaque colors in the group is at most 96. Apply the same group palette check to the technician frames in `tests/test_asset_pipeline.py`. The existing per clip palette in `animation_assets.normalize` must change to one palette for both technicians.
   `manifest` writes `art/cel-shift/<group>/manifest.json`: `{"version": 1, "assets": {"<name>": {"cell": [w, h], "frames": [...paths], "fps": <n>}}}`.
   Test it in `tests/test_sprite_assets.py` with a synthetic RGBA image: size, binary alpha, palette count, manifest paths.
4. Catalog entries for M1 (other groups come in later milestones):
   - tiles (32x32 unless noted): `floor`, `raised-floor`, `platform`, `tray`, `ladder`, `rack-ok` (32x96), `rack-fault` (32x96), `exit-closed` (64x96), `exit-open` (64x96), `checkpoint-off` (32x64), `checkpoint-on` (32x64, 4 frames)
   - hazards: `cable-snag` (32x16, 2 frames)
   - props: `coolant` (16x16, 4 frames)
   - ui: `health-full`, `health-empty` (12x12), `task-open`, `task-done` (12x12), `star-on`, `star-off` (24x24), `title` (480x120), `button` (160x32)
5. Level visuals. `level_builder.gd` gains `build_tiles(level, tile_layer: TileMapLayer)`. It creates a `TileSet` with one atlas source per tile frame from the tiles manifest. The `ColorRect` visuals from M0 are removed. Collision stays in `build_solids`.
6. Entities and the HUD draw manifest textures instead of `_draw` shapes.
7. Player: replace the gray `Body` rect with `AnimatedSprite2D` named `Sprite` at offset (0, -80), loaded from `animation_library.gd`. Clip choice is the pure function `Player.choose_clip(on_floor: bool, velocity: Vector2, sliding: bool, hurt: bool, action: StringName) -> StringName`:
   hurt -> `reaction`; action not empty -> action; sliding -> `slide`; not on floor -> `jump`; `absf(velocity.x) > 10` -> `run`; else `idle`.
   Test `choose_clip` in `tests/player_test.gd` for every branch.
8. Level 1 background: register the existing `environment/layers` set as `cold-aisle`. `environment.gd` gains `load_set(name: String) -> bool`, which reads `art/cel-shift/environment/<name>/` and keeps `layers/` as the `cold-aisle` path.
9. Export: add the new manifests to `include_filter`. Add `art/cel-shift/*/generated/*` to `exclude_filter`. Extend `tests/export_test.gd` with one runtime texture per new group.

**Acceptance**

- `animation_assets.py manifest` prints `Manifest clips: 18`. `tests/world_test.gd` passes with real artwork.
- Remove the `world_test.gd` skip from the full suite loop and from the CI loop added in M0. It must pass.
- Every catalog entry has normalized frames. `tests/test_sprite_assets.py` checks that every catalog name has a manifest entry.
- `tools/godot_test.sh tests/level_test.gd LEVEL_TEST` passes with tiles visible. Make a manual screenshot check with a debug run (`godot --path . res://game/level.tscn`) and record the screenshot path in the PR body.

---

## M2: Level 1 and game flow

**Depends on:** M1 merged.

**Deliverables**

1. `levels/01-cold-aisle.level`: 160 to 220 tiles wide, 12 to 16 rows. Tasks: 3 `repair` tasks. Hazards: `s` cable snags only. Coolant: 2. Prompts: header key `"prompts": [{"at": "<anchor or column>", "text": "..."}]`. The HUD shows the text while the player is within 3 tiles. Teach in order: run, jump, repair.
2. Playthrough bot.
   - `tools/godot_test.sh` passes `$GODOT_EXTRA_ARGS` to Godot. Route tests run with `GODOT_EXTRA_ARGS="--fixed-fps 60"`, so every run gets the same physics steps.
   - Route format `levels/routes/01-cold-aisle.route.json`: an array of steps. Step kinds:
     `{"hold": ["move_right"], "seconds": 1.5}`,
     `{"hold": ["move_right"], "until_x": 1280, "max_seconds": 10}`,
     `{"tap": "jump"}`, `{"hold": ["move_right", "jump"], "seconds": 0.4}`,
     `{"hold": ["repair"], "seconds": 2.1}`, `{"wait": 0.5}`.
   - `tests/route_test.gd` loads each level that has a route. It drives `player.input_override` and `level.action_override`, and runs real physics frames. It checks that `finished` fires before the SLA ends, with 0 respawns.
   - Write routes by reading the level grid. Run the bot, read the final player position, and adjust. The bot is the reachability authority. `level_validator.gd` only finds obvious errors.
3. Save store `game/save_store.gd`:
   - `func _init(path: String = "user://save.json")`
   - `func load_data() -> void`: a missing file gives defaults. A file that does not parse is renamed to `save.corrupt.json`, and defaults are used.
   - `func record(level_id: String, stars: int, seconds: float) -> void`: keeps the best stars and the best time, and unlocks the next level.
   - `func is_unlocked(level_id: String) -> bool`: `"01"` is always unlocked.
   - `func save() -> bool`
   - Data: `{"version": 1, "character": "man", "levels": {"01": {"stars": 3, "best_seconds": 142.5}}, "unlocked": ["01"]}`
   - Test `tests/save_store_test.gd` with path `user://test-save.json`. Cases: defaults, record, best values kept, unlock, corrupt file renamed, save and load round trip.
4. Screens: `game/main.tscn` (new main scene in `project.godot`) calls `InputSetup.install()` in `_ready()` before it creates the first screen. `main_flow_test.gd` checks that menu actions exist before any level loads. `main.tscn` owns one child screen at a time: `title` -> `character_select` -> `level_select` -> `level` -> `results` -> `level_select`. Pause (`pause` action) opens a menu with Resume, Restart level, and Quit to level select. All menus work with keyboard and gamepad focus. Test `tests/main_flow_test.gd`: drive `main.go_to(screen_name)` and check the active child and the save calls.
5. Audio.
   - `audio/sources.json`: entries `{"file": "music/level1.ogg", "url": "...", "page": "...", "author": "...", "license": "CC0-1.0", "sha256": "..."}`.
   - `tools/audio_assets.py fetch` downloads each file, checks sha256, and writes `audio/LICENSES.md` as a table. `tools/audio_assets.py check` checks the files and table only. CI runs `check`.
   - Get files from CC0 sources (Kenney asset pages, or OpenGameArt pages whose license field is CC0). Read the license on the source page before you add a file. Record the page URL.
   - M2 needs these tracks: `title`, `results`, `level1`. It needs these SFX: jump, land, hit, heal, repair_tick, repair_done, checkpoint, door_open, timer_warning, fail, win.
   - `tests/test_audio_assets.py`: every file under `audio/` except the 2 metadata files has a sources entry. Each entry has license `CC0-1.0`, a matching hash, and a row in `LICENSES.md`.
   - `game/audio_director.gd`: buses `Music` and `SFX` (add them in `default_bus_layout.tres`). `play_music(name)` crossfades in 0.5 s. `play_sfx(name)` uses a pool of 8 `AudioStreamPlayer` nodes. Unknown names return `false`, with no error. Test the name lookup and the pool limit in `tests/audio_director_test.gd`.
   - Browsers block audio until the first user gesture. `audio_director.gd` has `var unlocked: bool` (false on the web, true on other platforms; check `OS.has_feature("web")`) and `var pending_music: String`. Before `unlocked`, `play_music(name)` only stores the name in `pending_music`. The first `InputEventKey`, `InputEventMouseButton`, or `InputEventJoypadButton` press in `_input` sets `unlocked = true` and plays `pending_music`. The title screen shows "Press any key". Test the pending, unlock, and play sequence with `unlocked` set by hand.
6. Optional tasks. `level.gd` adds `optional_done` and `optional_total` to the `finished` result. The results screen shows "Optional work: 1 of 2". The save store keeps the best `optional_done` for each level. Stars do not change.
7. Export: add `levels/routes/*.route.json,audio/sources.json` to `include_filter`. Import `.ogg` and `.wav` as audio resources, so they export without filters. Keep files in `audio/music/` and `audio/sfx/`. Extend `export_test.gd`: `ResourceLoader.exists` for `res://audio/music/level1.ogg` and one SFX, and `FileAccess.file_exists` for the level 1 route.

**Acceptance**

- Level 1 route passes. Title to results works in the exported web build. Check it with the browser canvas on `python3 -m http.server 18765 --bind 127.0.0.1 --directory build/web`.
- Progress persists across a browser reload.

---

## Shared rules for level milestones M3 to M6

Each level milestone delivers these items. The subplan gives exact names.

1. Mechanics and entities with headless tests. These are pure logic tests. Construct the node, call `advance(delta)` or the interaction method, and check the state.
2. Catalog entries and normalized art for new tiles, hazards, and props. Use the art loop rule.
3. A background set `art/cel-shift/environment/<background>/` with `far.png` (640x360) and `equipment.png` (640x360, binary alpha). The level draws only these 2 parallax layers; the floor comes from the tile art. Generate them with `python3 tools/environment_assets.py render --set <name> --layer far|equipment`, then `normalize --set <name>`. Each layer uses the matching `layers/` file of the cold aisle set as its style reference.
4. A music track from a CC0 source, added through `audio/sources.json`.
5. The level file, 160 to 260 tiles wide. It uses each new mechanic first in a safe spot, then under pressure. It has 3 checkpoints and 3 to 6 tasks.
6. A route file that passes `tests/route_test.gd`.
7. Par and SLA: run the route, take its elapsed time `r`. Set `par_seconds = ceil(r * 1.25 / 5) * 5` and `sla_seconds = ceil(par_seconds * 1.6 / 5) * 5`. Level 5 uses factor 1.35 for the SLA.
8. Checkpoint state. Every stateful entity (part, rack with `diagnosed`, cable port, switch panel, coolant) has `func capture_state() -> Dictionary` and `func restore_state(state: Dictionary) -> void`. `level.gd` gains `func capture_state() -> Dictionary`, which collects all entity states and level state such as `carried_part`. `checkpoint_manager.gd` gains `var level_state: Dictionary`. `begin` and `activate` store `level.capture_state()`, and `_respawn` calls `level.restore_state(checkpoints.level_state)`. M3 makes this change first. For each new task type, test that progress made before a checkpoint stays after a respawn, and that progress made after the checkpoint is undone.
9. Hazard interface for all hazard scripts: `var active: bool`, `func advance(delta: float) -> void`, `func hit_rect() -> Rect2`. The level controller calls `advance` each physics step and damages the player when `active and hit_rect().intersects(player.hit_rect())`.

## M3: Level 2 Hot Aisle

- Hazard `v` heat vent (`game/hazards/heat_vent.gd`): cycle 1.5 s off, 0.4 s warning (visible, no damage), 1.0 s on. Phase offset = `fmod(cell.x * 0.37, 2.9)` so vents in a row do not sync. Hit rect: 28x64 above the vent cell. Art: `heat-vent` 32x16 with 4 frames, `heat-plume` 32x64 with 4 frames.
- Task `fetch` (`game/entities/part.gd`): the part sits at `part_at`. Touching it sets `level.carried_part = task_id`. The player can carry only one part at a time. Holding `repair` for 0.5 s at the target rack with the matching part completes the task. Art: `psu`, `dimm` (16x16). Header field `"part": "psu"` or `"dimm"`.
- Task `diagnose_repair`: press `diagnose` in range. The rack sets `diagnosed = true` and plays `secondary`. `repair` progress counts only after `diagnosed`. The HUD prompt reads "Diagnose first (Q / Y)" when the player holds repair before diagnosing.
- SFX: pickup, deliver, diagnose. Music: `level2`. Background: `hot-aisle` (warm red lighting).

## M4: Level 3 Cable Jungle

- Change the motor interface first, with all M0 motor tests still passing:
  `func step(input: Dictionary, context: Dictionary, delta: float) -> Vector2`. The `context` keys are `on_floor: bool`, `on_wall: bool`, `wall_normal_x: float`, `ceiling_blocked: bool`, and `on_ladder: bool`. `player.gd` builds the context from `is_on_floor()`, `is_on_wall()`, `get_wall_normal()`, a `ShapeCast2D` above the head, and ladder cell overlap. The new input keys are `slide_pressed: bool` and `vertical: float` (from the new `move_up` and `move_down` actions; W and S, Up and Down, and the left stick Y axis). Move `jump` from W and Up to Space only, and bind `slide` to C and Shift, so the keys do not overlap. Update `input_setup.gd`, `tests/player_test.gd`, and the README controls table.
- `player_motor.gd` gains slide and wall slide. Test each value:
  - Slide: `slide_pressed` on the floor starts a slide at 260 px/s in the facing direction for 0.45 s. The collision shape changes from 18x48 to 18x24. When `ceiling_blocked` is true at the end, the slide continues until the ceiling clears.
  - Wall slide: in the air, `on_wall` and direction toward the wall limit the fall speed to 90 px/s.
  - Wall jump: `jump_pressed` while wall sliding sets velocity (-wall_normal_x * 220, -460).
- Tile `T` tray: a solid 32x16 bar at the top of its cell. The gap below a tray row is 1 tile, so only a sliding player can pass.
- Ladder `|`: up and down at 90 px/s while overlapping a ladder cell. Gravity is off while climbing.
- Hazard `m` moving snag: patrols from `cell.x - 3` to `cell.x + 3` tiles at 60 px/s.
- Task `reseat` (`game/entities/cable_port.gd`): pressing `repair` in range starts 3 windows. Each window shows one button from `[repair, diagnose, jump]` and lasts 1.0 s. The sequence is the task id hash `abs(hash(task_id)) % 27` written as 3 base 3 digits, so tests can predict it. A wrong press or a timeout restarts the sequence.
- Art: slide clips (from M1), `tray`, `ladder`, `cable-port`, `moving-snag` (32x16, 4 frames). Music: `level3`. Background: `cable-jungle`.

## M5: Level 4 Power Room

- Hazard `k` spark arc: cycle 1.4 s off, 0.5 s warning flicker, 0.6 s on. Hit rect: 64x24 centered on the cell. Art: `spark-arc` 64x24 with 4 frames, `spark-emitter` 32x32.
- Lift `l` (`game/entities/lift.gd`, `AnimatableBody2D`): 64x16. Moves up 3 tiles and back at 48 px/s with a 0.5 s pause at each end. The validator treats a lift cell as standable, with jump reach from the top position. Art: `lift` 64x16.
- Task `reboot` (`game/entities/switch_panel.gd`): 3 anchors in `at` order. Press `repair` at each panel in order. A wrong panel resets all 3. The HUD shows the order as 1, 2, 3 above the panels. Art: `switch-off`, `switch-on` (32x48).
- SFX: switch, spark. Music: `level4`. Background: `power-room`.

## M6: Level 5 Outage Night

- Hazard `d` drone: patrols from `cell.x - 5` to `cell.x + 5` tiles at 70 px/s. It bobs 4 px vertically with a 1 s period. Hit rect: 24x16. Art: `drone` 32x24 with 4 frames.
- Darkness: `CanvasModulate` at `Color(0.3, 0.32, 0.4)` and a `PointLight2D` (texture: radial gradient, radius 160 px) on the player. Every 6 to 9 s (seeded by level name) the darkness modulate goes to `Color(0.12, 0.12, 0.18)` for 1.2 s. Check visibility in the Compatibility renderer of the web build before you finish the milestone.
- Final task: a `repair` task with 4 anchors in one row. It completes when all 4 racks are done. The M0 controller already supports this.
- Uses all earlier hazards and task types. Music: `level5`. Background: `outage-night`.

## M7: Polish and release

- Screen shake on hit: camera offset with a random amplitude of 4 px that decays over 0.25 s. Hit stop: pause the level for 0.05 s on a hit. Test the decay math as a pure function.
- Particles: sparks on repair completion and spark arcs (`CPUParticles2D`, Compatibility renderer).
- Timer warning: the HUD timer turns red and pulses below 30 s, and the `timer_warning` SFX plays once.
- Balance: run every route. Recompute par and SLA with the M3 rule. Check that each level takes 2 to 4 minutes at par.
- Accessibility: a Settings screen has Music and SFX volume sliders. They are stored in the save file under `"settings"`.
- README: how to play, controls table (keyboard and gamepad), level list, test commands, asset and audio provenance links.
- Web smoke mode: when the URL has `?route=0N` (read with `JavaScriptBridge.eval("location.search")` when `OS.has_feature("web")`), `main.gd` loads level N and plays `levels/routes/0N-*.route.json` with the route runner from M2. Move the runner from `tests/route_test.gd` into `game/route_runner.gd` so the test and the game share it. Before the release, open each `?route=01` to `?route=05` in the browser canvas on the local export. Confirm that each run reaches the results screen with music playing. Record the results in the PR body.
- Persistence: in the browser canvas, finish level 1, reload the page, and confirm that level 2 is unlocked.
- Release: merge to `main`. Wait for the Pages deploy. Open `https://ridermw.github.io/midcreek-hero/` in the browser canvas. Play Level 1 to the results screen.

## Done checklist

- [ ] 5 levels playable from title to results on GitHub Pages.
- [ ] 5 route tests pass in CI.
- [ ] 18 technician clips, every catalog asset, and 5 background sets exist as generated art.
- [ ] `audio/LICENSES.md` covers every audio file. All entries are CC0.
- [ ] All Python and Godot tests pass in CI.
- [ ] README describes play, controls, tests, and provenance.

## Mobile touch interface handoff

This separate effort starts from completed M0 to M7 on `main` at `ff1bcc2`.
It does not authorize a merge. Ask the coordinator before integration.

The browser shell detects touch support, a coarse pointer, and phone screen
dimensions. It does not use a user agent string. Desktop uses the same canvas
resize policy and existing Godot menus. Phone menus expose the actual Godot
Button and HSlider controls through `game/mobile_bridge.gd`. Menu commands
include a revision so a command from a replaced screen cannot activate a
different control.

`game/mobile_input.gd` holds mobile state separately from physical input.
It retains short taps until the next physics frame. All consumers can read
the same frame edge. The player and task controller combine this state with
their existing input. Recorded routes retain their existing override path.

`web/mobile.js` owns pointers, browser lifecycle events, audio activation,
menu rendering, and phone layout. `web/mobile.css` reserves space around a
4:3 canvas and respects safe area insets. Portrait gameplay pauses rather
than changing level geometry. Browser menus remain scrollable. Gameplay
controls prevent scrolling and release on cancellation, lost capture,
orientation changes, focus loss, page hiding, and screen changes.

The export uses `web/shell.html`. Copy `web/mobile.js` and `web/mobile.css`
beside the exported HTML. The Pages workflow and README include this step.
The shell changes the canvas resize policy only when phone detection passes.

Validation commands are in the README. The Godot tests exercise the actual
menu callbacks, volume persistence, cable sequences, diagnosis, repair,
part delivery, ordered switches, and physical input isolation. The browser
test uses a dedicated agent-browser Chrome session plus CDP touch emulation.
It captures phone screens and desktop keyboard gameplay. Do not label this
evidence as physical phone testing.

Verified on 2026-10-04: 52 Python tests, all Godot test scripts through the
repository runner, 11 mobile input checks, 40 mobile bridge checks, and
40 exported resource checks passed. The browser run exercised real emulated
touch events, simultaneous movement and jump, cancellation, audio activation,
menu error visibility, assistive hold activation, and resize focus retention.
It checked phone sizes of 390x844, 844x390, 667x375 with a simulated notch,
and 568x320. Desktop keyboard navigation reached gameplay at 960x720.
The exported first route reached mobile results with 3 stars and no hits.
Screenshots are in `docs/mobile/` and are excluded from the game export.
Physical phone testing and approval to merge remain outside this verification.
