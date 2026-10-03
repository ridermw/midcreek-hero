"""Generate authored MockUI animation clips and export deterministic pixel frames."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/cel-shift/animations"
VARIANTS = ("man-midcreek", "woman-midcreek")
CLIPS = ("idle", "walk", "run", "primary", "secondary", "reaction", "signal")
FPS = (6, 10, 14, 10, 10, 10, 8)
NORMAL_COUNTS = (6, 8, 8, 6, 8, 4, 6)
NORMAL_POSES = {
    "idle": "Small breathing loop, hands relaxed or resting near tool belt. Six phases: neutral, inhale begins, chest rises, inhale peak, exhale, near-neutral returning seamlessly to first. Keep planted feet absolutely stationary.",
    "walk": "Eight-frame RIGHT-FACING PROFILE walk loop: 1 left leg forward/right back contact, 2 weight sinks onto left heel, 3 right leg passes under hips while left supports, 4 rise over left toe/right reaches forward, 5 right forward/left back contact, 6 sink on right heel, 7 left passes under hips while right supports, 8 rise over right toe/left reaches forward. Arms swing opposite legs. Feet alternate, torso remains stable. Every phase differs. Hands empty, tools on belt.",
    "run": "Eight-frame RIGHT-FACING PROFILE run loop: 1 left-foot contact and right trailing, 2 compress over left, 3 left pushes off/right knee drives forward, 4 airborne right leg reaching ahead, 5 right-foot contact/left trailing, 6 compress right, 7 right pushes off/left knee drives, 8 airborne left leg reaching ahead. Clear alternating leg cycle and opposing bent arms. Hands empty.",
    "primary": "Six-frame RIGHT-FACING working reach with short real ratchet: 1 hand goes to belt, 2 lifts small ratchet, 3 extends arm toward imaginary fastener at chest height, 4 tightens through short arc, 5 eases back, 6 returns near belt. Other hand steadies naturally. No rack in sprite. Tool shorter than forearm; no blades, shields or trails.",
    "secondary": "Eight-frame RIGHT-FACING multimeter test: 1 take compact meter from belt, 2 hold meter at waist, 3 extend test probe toward right, 4 contact/hold, 5 look down at meter, 6 lift probe clear, 7 retract lead, 8 lower meter. Thin red/black test cable hangs DOWN under gravity. Blank tiny screen. No glow, spell, floating cable or UI.",
    "reaction": "Four-frame RIGHT-FACING startled braced reaction: 1 surprise/flinch, 2 knees bend and forearm raises to protect face, 3 hold low with both feet planted, 4 relax back. Empty hands, no shield or panel, no sparks. Never kneel.",
    "signal": "Six-frame coworker signal: 1 neutral, 2 right elbow lifts, 3 right hand reaches overhead open palm, 4 small wave, 5 hand lowers, 6 back to neutral. Empty raised hand. No raised tool or weapon.",
}


def configuration(variant, clip):
    count = NORMAL_COUNTS[CLIPS.index(clip)]
    columns = count // 2
    return count, columns, (columns * 512, 1024)


def prompt_text(variant, clip):
    count, columns, size = configuration(variant, clip)
    woman = variant.startswith("woman")
    identity = (
        "WOMAN: dark ponytail visibly tied below blue hard hat; short slate sleeves and bare forearms, tapered blue jeans."
        if woman else
        "MAN: clean-shaven, short dark hair below blue hard hat; long slate sleeves to wrists, roomy straight blue jeans. No beard or moustache."
    )
    phases = NORMAL_POSES[clip]
    mode = "NORMAL REAL-WORLD technician: ordinary hand tools only. NO sword, shield, rack panel, magic, spell, glowing trail or combat armor."
    return f"""---
name: {variant}-{clip}-animation
size: {size[0]}x{size[1]}
quality: high
---

Edit image 1 into a TRUE PIXEL ART animated sprite sheet for the SAME character.
Image 1 is the approved character IDENTITY, pixel-art STYLE and PALETTE reference.
Replace its single pose with a complete {count}-frame {clip.upper()} animation.
Keep the same face, hair, hard hat, clothing, compact adult RPG proportions,
dark stepped pixel contours, small square color clusters and shaded material ramps.
Never switch to smooth cel illustration, vector art, a 3D render or painted concept art.

{identity}
Both: blue hard hat/ear defenders, lime hi-vis vest, orange trim, broad silver
bands, slate shirt, blue denim, brown boots and tool belt. Outfit and character
size must remain IDENTICAL across frames. Ponytail mass stays consistent.
{mode}

EXACT GRID: {columns} columns by 2 rows, read left-to-right then top-to-bottom.
Exactly {count} figures, one per equal 512x512 cell. No drawn grid, numbers or labels.
Each cell uses local coordinates: body centered near x=256, BOOT CONTACT BASELINE
y=480, standing figure including hat approximately 400 pixels tall. All painted
pixels, including tools/hair, must remain inside x=32..480 and y=32..496.
Character anatomy is drawn at the SAME scale in every frame; don't resize each pose
to fill the cell. Foot position may change through stride but the floor is fixed.
Camera/facing stays consistent. Right-facing profile for locomotion; do not
alternate front and back views or rotate the character through the cycle.

FRAME BREAKDOWN:
{phases}

Draw every individual phase as distinct authored pixel artwork. In-between frames
must actually move the knees, ankles, elbows and hands through the action; do not
copy the same standing pose across the sheet. Keep body volume and costume stable.
No motion blur; changing limb silhouettes must carry the motion.

Use actual TRANSPARENT RGBA output. Alpha zero around every figure and in limb
gaps. Do not draw a checkerboard, white/beige backdrop, ground shadow, scenery,
captions, logos, watermark, duplicate extras or opaque frame cards.
"""


def write_prompts():
    for variant in VARIANTS:
        directory = ART / "prompts" / variant
        directory.mkdir(parents=True, exist_ok=True)
        for clip in CLIPS:
            (directory / f"{clip}.mock.md").write_text(prompt_text(variant, clip))


def render(variant, clip):
    prompt_file = ART / "prompts" / variant / f"{clip}.mock.md"
    prompt_file.parent.mkdir(parents=True, exist_ok=True)
    prompt_file.write_text(prompt_text(variant, clip))
    _, _, size = configuration(variant, clip)
    source = ROOT / f"art/cel-shift/sprites/individual/{variant}/01-ready.png"
    prompt = prompt_file.read_text().split("---", 2)[2].strip()
    target = ART / "generated" / variant / f"{clip}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "mockui", "edit", str(source), "-p", prompt,
        "--strict-prompt", "--model", "sunburst", "--quality", "high",
        "--background", "transparent", "--size", f"{size[0]}x{size[1]}",
        "-o", str(target),
    ], check=True)
    sidecar = target.with_suffix(".png.metadata.json")
    data = json.loads(sidecar.read_text())
    data.pop("account", None)
    for item in data.get("inputs", []):
        item["path"] = Path(item["path"]).relative_to(ROOT).as_posix()
    data["source_image"] = source.relative_to(ROOT).as_posix()
    data["reference_images"] = []
    sidecar.write_text(json.dumps(data, indent=2) + "\n")


def normalize(variant, clip):
    count, columns, size = configuration(variant, clip)
    source = ART / "generated" / variant / f"{clip}.png"
    image = Image.open(source).convert("RGBA")
    if image.size != size:
        raise ValueError(f"{source}: wrong size {image.size}, expected {size}")
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] != 0:
        raise ValueError(f"{source}: no actual transparency")
    image.putalpha(alpha.point(lambda value: 255 if value >= 128 else 0))
    cells = []
    bounds_list = []
    for index in range(count):
        x, y = (index % columns) * 512, (index // columns) * 512
        cell = image.crop((x, y, x + 512, y + 512))
        bounds = cell.getbbox()
        if bounds is None:
            raise ValueError(f"{source}: empty frame {index}")
        cells.append(cell)
        bounds_list.append(bounds)
    # Correct sheet-row placement as a group, not each pose's moving body.
    # Preserve all artwork and one shared scale rather than clipping to a guessed crop.
    baselines = [max(b[3] for b in bounds_list[row * columns:(row + 1) * columns])
                 for row in range(2)]
    frames = []
    for index, cell in enumerate(cells):
        scaled = cell.resize((171, 171), Image.Resampling.NEAREST)
        frame = Image.new("RGBA", (208, 208))
        position = (18, 184 - round(baselines[index // columns] * 171 / 512))
        bounds = scaled.getbbox()
        if bounds is None or position[1] + bounds[1] < 1 or position[1] + bounds[3] >= 208:
            raise ValueError(f"{source}: frame {index} cannot fit without clipping")
        frame.alpha_composite(scaled, position)
        frames.append(frame)
    samples = [pixel[:3] for frame in frames for pixel in frame.getdata() if pixel[3]]
    palette_source = Image.new("RGB", (256, (len(samples) + 255) // 256), samples[0])
    palette_source.putdata(samples)
    palette = palette_source.quantize(colors=96, method=Image.Quantize.MEDIANCUT,
                                      dither=Image.Dither.NONE)
    output = ART / "frames" / variant / clip
    output.mkdir(parents=True, exist_ok=True)
    paths, hashes = [], []
    for index, frame in enumerate(frames):
        result = frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        result.putalpha(frame.getchannel("A"))
        result.paste((0, 0, 0, 0), mask=frame.getchannel("A").point(lambda value: 255 if not value else 0))
        path = output / f"{index:02d}.png"
        result.save(path)
        paths.append(path.relative_to(ART).as_posix())
        hashes.append(hashlib.sha256(result.tobytes()).hexdigest())
    if len(set(hashes)) != count:
        raise ValueError(f"{source}: duplicate authored frames")
    preview = Image.new("RGB", (columns * 208, 2 * 208), "#d9dde4")
    for index, path in enumerate(paths):
        frame = Image.open(ART / path)
        preview.paste(frame, ((index % columns) * 208, (index // columns) * 208), frame)
    preview_dir = ART / "previews" / variant
    preview_dir.mkdir(parents=True, exist_ok=True)
    preview.save(preview_dir / f"{clip}.png")
    animated = []
    for path in paths:
        frame = Image.open(ART / path)
        background = Image.new("RGBA", frame.size, "#d9dde4")
        background.alpha_composite(frame)
        animated.append(background.resize((416, 416), Image.Resampling.NEAREST).convert("RGB"))
    animated[0].save(preview_dir / f"{clip}.gif", save_all=True, append_images=animated[1:],
                     duration=round(1000 / FPS[CLIPS.index(clip)]), loop=0)
    print(f"Normalized {variant}/{clip}: {count} distinct transparent frames")


def manifest():
    result = {"version": 1, "cell_size": [208, 208], "pivot": [104, 184], "variants": {}}
    for variant in VARIANTS:
        animations = {}
        for i, clip in enumerate(CLIPS):
            count, _, _ = configuration(variant, clip)
            paths = [f"frames/{variant}/{clip}/{n:02d}.png" for n in range(count)]
            if not all((ART / p).is_file() for p in paths):
                continue
            animations[clip] = {"fps": FPS[i], "loop": clip in ("idle", "walk", "run"), "frames": paths}
        if animations:
            result["variants"][variant] = {"animations": animations}
    (ART / "manifest.json").write_text(json.dumps(result, indent=2) + "\n")
    print("Manifest clips:", sum(len(v["animations"]) for v in result["variants"].values()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("prompts", "render", "normalize", "manifest"))
    parser.add_argument("--variant", choices=VARIANTS)
    parser.add_argument("--clip", choices=CLIPS)
    args = parser.parse_args()
    if args.operation in ("render", "normalize") and not (args.variant and args.clip):
        parser.error("--variant and --clip are required")
    if args.operation == "prompts":
        write_prompts()
    elif args.operation == "render":
        render(args.variant, args.clip)
    elif args.operation == "normalize":
        normalize(args.variant, args.clip)
    else:
        manifest()


if __name__ == "__main__":
    main()
