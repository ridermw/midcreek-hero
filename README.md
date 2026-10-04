# Midcreek Hero

A pixel art side scroller set in a data center. You play a technician who runs,
jumps, slides, and climbs through 5 data halls, avoids hazards, and completes
work orders before the service level agreement (SLA) timer runs out.

**[Play in the browser](https://ridermw.github.io/midcreek-hero/)**

Built with Godot 4.7.2, GDScript, the Compatibility renderer, and a single
threaded Web export. All art is generated with MockUI and normalized to pixel
frames. All music and sound effects are CC0; see [audio/LICENSES.md](audio/LICENSES.md)
and [audio/PROVENANCE.md](audio/PROVENANCE.md).

## Build and run

Open `project.godot` in Godot and press F5, or export and preview in a browser:

```sh
godot --headless --editor --path . --import
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
cp web/mobile.js web/mobile.css build/web/
python3 -m http.server 18765 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:18765/`. Click the game once to give it keyboard focus;
browsers also start audio only after this first input. Install the matching
Godot export templates before exporting. The `Godot web viewer` workflow
imports, tests, and exports on pull requests, then deploys successful builds
from `main` to GitHub Pages.

Smoke mode plays a level's recorded route through the full game:
`http://127.0.0.1:18765/?route=03` in a browser (the page title reports the
result), or `godot --headless --fixed-fps 60 --path . -- --route=03` on the desktop.

The title screen has a Settings screen with music and sound effect volume
sliders. The volumes are saved with your progress.
Settings also selects Keyboard, Gamepad, or Touch control graphics.
This choice changes the displayed controls, not which input devices work.
Without a saved choice, detected phones use Touch and other devices use Keyboard.

Open How to Play from the title screen for graphical controls and animated
examples of all five work order types. During a level, press Escape and open
How to Play from the pause menu. Back returns to the pause menu without
restarting the level or resuming the timer.
Action hints show one control for the selected display. The control pulses
when an action is needed and stays steady while held. Task status remains
visible when a part is missing or a switch sequence is wrong.

The web loading screen and engine startup use the Midcreek Hero title artwork.
The app icon uses the same pixels centered on a transparent 480 by 480 canvas,
without stretching the logo. Loading progress and startup errors remain visible.

The original sprite viewer is still in `viewer.tscn`. Run its checks with:


```sh
godot --headless --path . --script tests/viewer_test.gd
```

## Cel Shift pixel sprites

The current [sprite set](art/cel-shift/sprites/README.md) contains normal and
hybrid male/female variants, four transparent sheets, and 24 individual sprites.
Normal technicians use real tools without fantasy effects. Hybrids retain the
industrial sword/shield silhouettes and effects.

![Current sprite comparison](art/cel-shift/sprites/preview.png)

## Data hall art test

The `game/world.tscn` scene is the earlier art test: two technicians, local
rack repair, camera tracking, and the cold aisle layers. It requires every
authored clip for both technicians and reports missing artwork instead of
using static sprites. The game itself starts from `game/main.tscn`.

Install the asset-tool dependency and normalize the checked-in environment
sources:

```sh
python3 -m pip install -r tools/requirements.txt
python3 tools/environment_assets.py normalize
```

Use `--layer far`, `--layer equipment`, or `--layer floor` to normalize one
layer. The command writes `environment/layers/` under `art/cel-shift/` (the
cold aisle set). The other 4 level sets use `render --set <name> --layer far`
or `--layer equipment`, then `normalize --set <name>`.
It uses nearest-neighbor sampling. Far and equipment layers become 640x360.
The floor strip becomes 640x96. The equipment layer uses binary alpha.
Source dimensions and transparency must match the layer contract.
In gameplay, the distant layer scales uniformly to cover the level height,
including the highest camera position. Equipment keeps its original scale.

All animation prompts share one geometry: 512x512 source cells, a boot
baseline at y=448, and a standing height of approximately 270 pixels. The
normalizer uses one fixed 512-to-171 scale and writes 208x208 frames.
Ponytail guidance applies only to the woman. The normalizer checks all frame
hashes before it writes files, so duplicate artwork cannot overwrite prior
frames or previews.
After generating and normalizing all clips, run:

```sh
python3 tools/animation_assets.py manifest
godot --headless --editor --path . --import
godot --headless --path . --script tests/world_test.gd
```

Both runtime JSON manifests are included explicitly in Web exports.
Generated source sheets and previews are excluded from Web exports.
Local primary and diagnostic actions face the rack when it is in range.
Run the asset-pipeline regression checks with:

Install ffmpeg on your PATH first. The audio conversion regression test
uses its native Vorbis encoder. CI installs ffmpeg before running this suite.

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
godot --headless --path . --script tests/environment_test.gd
godot --headless --path . --script tests/local_action_test.gd
```

CI also opens the exported resource pack from outside the project directory.
It checks that runtime textures remain available and source-art directories
are absent.

## Play

Open the [web build](https://ridermw.github.io/midcreek-hero/) or run
`godot --path .`. The game starts on the title screen. Choose a technician,
then choose a work order. Finish every required task before the SLA timer
reaches zero, then reach the exit door.

| Action | Keyboard | Gamepad |
|---|---|---|
| Run | A and D, or the arrow keys | Left stick or D pad |
| Jump | Space | A |
| Climb a ladder | W or Up, S or Down | Left stick or D pad |
| Slide | C or Shift | B |
| Repair (hold) | E | X |
| Diagnose | Q | Y |
| Pause | Escape or P | Start |

### Phone touchscreen

The web build adds touch controls on phones with a coarse pointer and touch
support. Detection uses the screen size, not the browser name. The short
screen edge must be at most 600 CSS pixels. The long edge must be at most
1000 CSS pixels. Desktop windows and touch laptops keep the existing interface.
Detection runs at page load.

Menus and volume sliders work in either orientation. Rotate the phone to
landscape for gameplay. Use Left and Right to run, Up and Down to climb, and
Jump and Slide for movement. Hold Repair at a rack. Use Diagnose when prompted.
Cable sequences show Repair, Diagnose, or Jump. Use Repair at each numbered
switch in order. Multiple fingers can hold different controls at the same time.

Controls stay outside the game image and inside the screen safe area.
Pause shows the work order list, Resume, Restart work order, and Quit to level
select. Portrait rotation and loss of browser focus pause gameplay. Resume
explicitly after returning to landscape. Cancellation and screen changes clear
touch input without releasing physical keyboard input.
Screen reader activation toggles held movement and Repair. Activate the same
control again to release it. Other actions remain single presses.

Run the touch regression tests:

```sh
node --test tests/mobile_web_test.cjs
tools/godot_test.sh tests/mobile_input_test.gd MOBILE_INPUT_TEST
tools/godot_test.sh tests/mobile_bridge_test.gd MOBILE_BRIDGE_TEST
```

Loading screen checks run with `node --test tests/loading_shell_test.cjs`.

The help navigation browser regression requires Microsoft Edge and an installed
Playwright package. Pass the absolute path to that package:

```sh
node tests/mobile_help_browser_test.mjs /absolute/path/to/node_modules/playwright
```

This check opens an isolated emulated phone browser. It verifies that changing
help pages resets scroll position, while repeated updates preserve scroll and
focus. It does not run in the default Node test command.

For rendered browser checks, open the local export in a dedicated
`agent-browser` session. Get that session's endpoint with
`agent-browser get cdp-url`. The test uses Chrome DevTools Protocol (CDP) to
send touch events through that same browser. It also checks desktop detection
and captures desktop keyboard gameplay. Supply an evidence directory:

```sh
node tests/mobile_browser_test.mjs <cdp-websocket-url> http://127.0.0.1:18765/ <evidence-directory>
```

Add `--smoke` to play the first recorded route through the exported game and
check the mobile results screen. This adds about 100 seconds.

This is emulated phone testing. It does not replace physical iPhone or Android
testing. Native mobile exports are not part of this feature.

## Levels

| # | Name | New mechanics | Hazards |
|---|---|---|---|
| 1 | Cold Aisle Onboarding | Run, jump, repair | Cable snags, open floor tiles |
| 2 | Hot Aisle | Fetch a PSU or DIMM, diagnose then repair | Heat vents (1.5 s off, 0.4 s warning, 1.0 s on) |
| 3 | Cable Jungle | Slide under trays, ladders, wall jump, reseat a cable | Moving cable snags |
| 4 | Power Room | Ride lifts, reboot a switch in order | Spark arcs (1.4 s off, 0.5 s flicker, 0.6 s on) |
| 5 | Outage Night | Darkness with a flashlight, every task type, a row of 4 racks | Patrol drones (slide under them), all earlier hazards |

Work order types: hold E to repair a red rack. For a fetch order, run over the
spare part, then hold E at the rack that shows the part icon. For a diagnose
order, press Q at the rack with the amber marker, then hold E. To reseat a
cable, press E at the port, then press each button the HUD shows within 1 s.
To reboot a switch, press E at switch panels 1, 2, and 3 in that order; a wrong
panel turns them all off. A spark sound marks each arc becoming active.
Stand on a lift to ride it 3 tiles up. Slide under a low tray; the slide continues until there is room to stand. Press
into a wall in the air to slow your fall, and jump to kick off it. A restart at a
checkpoint undoes pickups, diagnoses, repairs, cable reseats, and switch throws
made after that checkpoint.

Progress (stars, best times, unlocked levels, and the chosen technician) is
saved in `user://save.json`. On the web this is browser storage.

Each level has a route file in `levels/routes/`. `tests/route_test.gd` plays every
route at a fixed 60 frames per second and checks that it finishes without a
restart.

    tools/godot_test.sh tests/route_test.gd ROUTE_TEST

A test can request engine flags with a first line such as
`# godot_test_args: --fixed-fps 60`.

Route steps accept only `tap`, only `wait`, or `hold` with `seconds` or a target
(`until_x` or `until_y`) and `max_seconds`. A target needs exactly one matching
direction: left or right for x, up or down for y. Extra fields are rejected rather
than ignored.

Holding slide produces one press, including across adjacent hold steps. Release
slide with a wait or a step without slide before triggering it again. The
motor buffers a slide press for 0.1 s, so a press just before a slide ends
starts the next slide with no gap. Every route must finish with no damage.

## Level layouts

`tools/levels/level1.py` to `level5.py` build each level grid and its route
together with the helpers in `tools/levels/layout.py`. Run one from the
repository root to rewrite its files, then run the route test:

    python3 -m tools.levels.level3
    tools/godot_test.sh tests/route_test.gd ROUTE_TEST

Each level has 3 checkpoints and 3 to 6 work orders. Par and SLA are authored
human difficulty targets. Their current values remain unchanged:

| Level | Route time | Par | SLA |
|---|---|---|---|
| 1 Cold Aisle Onboarding | 93.2 s | 120 s | 195 s |
| 2 Hot Aisle | 95.7 s | 120 s | 195 s |
| 3 Cable Jungle | 96.2 s | 125 s | 200 s |
| 4 Power Room | 97.2 s | 125 s | 200 s |
| 5 Outage Night | 99.9 s | 125 s | 170 s |

`tests/test_level_layouts.py` checks that the scripts reproduce the shipped
files exactly. Change par or SLA only after collecting player observations.
Changing these targets does not recalculate earned stars.

Automated route timing is separate. `tests/route_budgets.json` assigns each
route a 110 second completion budget. The baseline routes take 93.17 to
99.87 seconds, leaving at least 10 seconds of timing margin.
These budgets are not player targets or device performance measurements.
Review a budget change when intended geometry or task changes alter a route.

Both the Godot route test and CI require completion within the independent
budget and before the authored SLA, with no hits, respawns, or runtime errors.
The smoke checker accepts all three star ratings. Star boundary tests remain
separate in `tests/sla_timer_test.gd`.
`tools/check_route_result.py <level-id> <smoke-log>` applies the CI check.
To verify that par no longer determines route acceptance without changing any
level file, run:

```sh
ROUTE_ONLY=03 ROUTE_PAR_SECONDS=1 tools/godot_test.sh tests/route_test.gd ROUTE_TEST
```

## Core platformer

The gray box level tests movement, health, the SLA timer, repair tasks,
checkpoints, and the exit. It uses flat colors. Generated art comes in M1.

    godot --path . res://game/level.tscn

Controls: A and D or the arrow keys to run, Space to jump, hold E to repair.
A gamepad uses the left stick or D pad, A to jump, and X to repair.

Run one core test:

    tools/godot_test.sh tests/level_test.gd LEVEL_TEST

Level files are in `levels/`. `levels/LEGEND.md` describes the format.

## Game art pipeline

All game art is generated with MockUI and normalized to binary alpha pixel
frames. Each asset group (technician animations, tiles, hazards, props, ui)
shares one palette of at most 96 opaque colors.
The sprite normalizer rejects blank frames both before and after resizing,
including sparse artwork that disappears when its alpha is thresholded.
It validates the entire sequence before replacing previously normalized frames.

Technician clips: idle, walk, run, jump, slide, primary, secondary, reaction,
signal, and climb for the man and the woman. Climb is drawn from behind with
alternating hands and feet; it plays while the technician moves on a ladder and
holds its pose while the technician stops on one.
One alternating hand cycle covers the two rungs in a 32 pixel ladder tile.
Playback follows movement speed and reverses during descent. At the unchanged
90 pixels per second climbing speed, a full cycle takes about 0.356 seconds.
Changing direction or stopping does not restart the pose.
Climb normalization aligns the blue hard hat with the ladder axis in every
frame. It preserves the shared scale and boot baseline, and rejects artwork
that has no alignment anchor or would be clipped.

Held repairs loop on the sprite's render clock. They do not wait for a physics
tick to restart. The player keeps a private animation configuration, so this
does not change the shared clips used by the art viewer and help.

To reproduce walking, running, repair, ascent, descent, and a climb stop and
reversal for both heroes in Level 3, then
capture both repair help demonstrations:

```sh
mkdir -p /tmp/midcreek-motion
godot --path . --script tests/animation_probe.gd -- --output=/tmp/midcreek-motion
```

The probe uses repeatable input and writes frame, physics, camera, and timing
samples to `native-trace.json`. It also writes two help screenshots. Use a
separate run with `--write-movie /tmp/midcreek-motion/actions.avi --fixed-fps 60`
before `--` to record all twelve action cases and the help demonstrations.
Movie mode fixes the simulation rate; do not use its timing as a device
performance measurement. The probe does not change saved progress.

To regenerate the square app icon from the title without changing its pixels:

```sh
python3 - <<'PY'
from PIL import Image
with Image.open("art/cel-shift/ui/frames/title/00.png") as title:
    icon = Image.new("RGBA", (480, 480))
    icon.paste(title.convert("RGBA"), (0, 180))
    icon.save("art/cel-shift/ui/icon.png")
PY
```

    python3 tools/animation_assets.py render --variant woman-midcreek --clip jump
    python3 tools/animation_assets.py normalize --variant woman-midcreek --clip jump
    python3 tools/sprite_assets.py palette --group animations
    python3 tools/animation_assets.py manifest

Tiles, hazards, props, and UI come from `art/cel-shift/catalog.json`. Each entry
has a cell size, a frame count, a `fit` mode, and a prompt.

    python3 tools/sprite_assets.py render --name rack-fault
    python3 tools/sprite_assets.py normalize --name rack-fault
    python3 tools/sprite_assets.py palette --group tiles
    python3 tools/sprite_assets.py manifest --group tiles

`fit` modes: `fill` stretches the drawn object to the cell, `top`, `bottom`, and
`center` keep its aspect ratio, and `canvas` scales the whole render.
