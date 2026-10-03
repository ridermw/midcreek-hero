# Midcreek Hero

Pixel-art and character-direction experiments for Midcreek.

## Godot hello world

**[Open the web viewer](https://ridermw.github.io/midcreek-hero/)**

A minimal viewer shows one of the 24 current individual hero sprites at a time.
Press **Space** to advance; after the last image it wraps to the first.
Holding Space does not skip through images. The caption identifies the
character, variant and pose.

Uses Godot 4.7.2, GDScript, nearest-neighbor sprite filtering, the Compatibility
renderer, and a single-threaded Web export. The viewer reads the existing
sprite manifest.

Open `project.godot` in Godot and press F5, or export and preview in a browser:

```sh
godot --headless --editor --path . --import
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 18765 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:18765/`. If necessary, click the game once to give it
keyboard focus. Install the matching Godot export templates before exporting.
The complete `build/web/` folder is suitable for static hosting on GitHub Pages;
it needs no backend or cross-origin-isolation headers. The
`Godot web viewer` workflow imports, tests, and exports on pull requests,
then deploys successful builds from `main` to GitHub Pages. Generated builds
are ignored by Git rather than committed.

Run the sprite-loading and keyboard-cycle checks:

```sh
godot --headless --path . --script tests/viewer_test.gd
```

## Cel Shift pixel sprites

The current [sprite set](art/cel-shift/sprites/README.md) contains normal and
hybrid male/female variants, four transparent sheets, and 24 individual sprites.
Normal technicians use real tools without fantasy effects. Hybrids retain the
industrial sword/shield silhouettes and effects.

![Current sprite comparison](art/cel-shift/sprites/preview.png)

## Animated data hall checkpoint

The `game/world.tscn` scene adds two technicians, local rack repair, camera
tracking, and three environment layers. It requires all seven authored
animation clips for each technician. Only the man's idle and walk clips are
complete. The scene reports missing artwork instead of using static sprites.
The sprite viewer remains the main scene.

Install the asset-tool dependency and normalize the checked-in environment
sources:

```sh
python3 -m pip install -r tools/requirements.txt
python3 tools/environment_assets.py normalize
```

Use `--layer far`, `--layer equipment`, or `--layer floor` to normalize one
layer. The command writes `environment/layers/` under `art/cel-shift/`.
It uses nearest-neighbor sampling. Far and equipment layers become 640x360.
The floor strip becomes 640x96. The equipment layer uses binary alpha.
Source dimensions and transparency must match the layer contract.

All animation prompts use the existing idle/walk geometry: 512x512 source
cells, a boot baseline at y=448, and a standing height of approximately 270
pixels. Keep this geometry when generating the remaining clips. The
normalizer uses one fixed 512-to-171 scale and writes 208x208 frames.
After generating and normalizing all clips, run:

```sh
python3 tools/animation_assets.py manifest
godot --headless --editor --path . --import
godot --headless --path . --script tests/world_test.gd
```

Both runtime JSON manifests are included explicitly in Web exports.
Run the asset-pipeline regression checks with:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
godot --headless --path . --script tests/environment_test.gd
```
