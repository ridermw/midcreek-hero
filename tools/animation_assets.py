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
CLIPS = ("idle", "walk", "run", "jump", "slide", "primary", "secondary", "reaction", "signal", "climb")
LOOPING = ("idle", "walk", "run", "climb")
FPS = (6, 10, 14, 10, 12, 10, 10, 10, 8, 8)
NORMAL_COUNTS = (6, 8, 8, 6, 4, 6, 8, 4, 6, 6)
NORMAL_POSES = {
    "idle": "Small breathing loop, hands relaxed or resting near tool belt. Six phases: neutral, inhale begins, chest rises, inhale peak, exhale, near-neutral returning seamlessly to first. Keep planted feet absolutely stationary.",
    "walk": "Eight-frame RIGHT-FACING PROFILE walk loop: 1 left leg forward/right back contact, 2 weight sinks onto left heel, 3 right leg passes under hips while left supports, 4 rise over left toe/right reaches forward, 5 right forward/left back contact, 6 sink on right heel, 7 left passes under hips while right supports, 8 rise over right toe/left reaches forward. Arms swing opposite legs. Feet alternate, torso remains stable. Every phase differs. Hands empty, tools on belt.",
    "run": "Eight-frame RIGHT-FACING PROFILE run loop: 1 left-foot contact and right trailing, 2 compress over left, 3 left pushes off/right knee drives forward, 4 airborne right leg reaching ahead, 5 right-foot contact/left trailing, 6 compress right, 7 right pushes off/left knee drives, 8 airborne left leg reaching ahead. Clear alternating leg cycle and opposing bent arms. Hands empty.",
    "jump": "Six-frame RIGHT-FACING PROFILE jump: 1 crouch with knees bent, 2 push off with arms swinging up, 3 rising with knees tucked, 4 apex with legs together, 5 falling with legs reaching down, 6 landing crouch. Hands empty, tools on belt. Feet leave the baseline in frames 3 to 5 by up to 60 pixels.",
    "slide": "Four-frame RIGHT-FACING PROFILE floor slide: 1 drop low into a crouch, 2 slide on hip with lead leg extended forward and one hand trailing on the floor, 3 hold the low slide, 4 rise back to a crouch. In frames 2 and 3 the whole body, including the hard hat, is at most half the standing height. Boots stay on the baseline. Hands empty.",
    "primary": "Six-frame RIGHT-FACING working reach with short real ratchet: 1 hand goes to belt, 2 lifts small ratchet, 3 extends arm toward imaginary fastener at chest height, 4 tightens through short arc, 5 eases back, 6 returns near belt. Other hand steadies naturally. No rack in sprite. Tool shorter than forearm; no blades, shields or trails.",
    "secondary": "Eight-frame RIGHT-FACING multimeter test: 1 take compact meter from belt, 2 hold meter at waist, 3 extend test probe toward right, 4 contact/hold, 5 look down at meter, 6 lift probe clear, 7 retract lead, 8 lower meter. Thin red/black test cable hangs DOWN under gravity. Blank tiny screen. No glow, spell, floating cable or UI.",
    "reaction": "Four-frame RIGHT-FACING startled braced reaction: 1 surprise/flinch, 2 knees bend and forearm raises to protect face, 3 hold low with both feet planted, 4 relax back. Empty hands, no shield or panel, no sparks. Never kneel.",
    "climb": "Six-frame BACK VIEW ladder climb loop: the character is seen from directly behind, facing away from the viewer, climbing an invisible vertical ladder. Back of the hard hat, back of the hi-vis vest with its silver bands, tool belt at the waist. 1 right hand reaches high and left knee lifts, 2 right hand grips while the body rises, 3 hands level at shoulder height with feet together, 4 left hand reaches high and right knee lifts, 5 left hand grips while the body rises, 6 hands level again with feet together. Hands and feet alternate. Arms bent at the elbows, palms gripping empty air where rungs would be. Do not draw the ladder, rungs or rails. Body centered, not leaning sideways. The lowest boot stays on the baseline. EQUIPMENT IS FIXED: the brown leather tool pouch hangs on the character's RIGHT hip, which is the RIGHT side of the image in this back view, in ALL SIX frames. Frames 4 to 6 are NOT mirror images of frames 1 to 3: only the arms and legs swap, the pouch, belt buckle side and any hair stay exactly where they are.",
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
    facing = (
        "Camera/facing stays consistent. BACK VIEW in every frame, seen from directly\nbehind; do not turn the character to the side or toward the viewer."
        if clip == "climb" else
        "Camera/facing stays consistent. Right-facing profile for locomotion; do not\nalternate front and back views or rotate the character through the cycle."
    )
    hair_guidance = " Ponytail mass stays consistent." if woman else ""
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
size must remain IDENTICAL across frames.{hair_guidance}
{mode}

EXACT GRID: {columns} columns by 2 rows, read left-to-right then top-to-bottom.
Exactly {count} figures, one per equal 512x512 cell. No drawn grid, numbers or labels.
Each cell uses local coordinates: body centered near x=256, BOOT CONTACT BASELINE
y=448, standing figure including hat approximately 270 pixels tall. All painted
pixels, including effects/tools/hair, must remain inside x=64..448 and y=96..480.
Character anatomy is drawn at the SAME scale in every frame; don't resize each pose
to fill the cell. Foot position may change through stride but the floor is fixed.
{facing}

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
        if clip in ("climb", "primary"):
            try:
                frame = align_climb(frame) if clip == "climb" else align_repair(frame)
            except ValueError as error:
                raise ValueError(f"{source}: frame {index}: {error}") from error
        frames.append(frame)
    palette_path = ART / "palette.png"
    if palette_path.exists():
        with Image.open(palette_path) as swatch:
            if swatch.height != 1 or not 1 <= swatch.width <= 96 or swatch.mode != "RGB":
                raise ValueError(f"{palette_path}: palette must be an RGB row of 1 to 96 colors; found {swatch.mode} {swatch.size}")
            colors = [swatch.getpixel((x, 0)) for x in range(swatch.width)]
        palette = Image.new("P", (1, 1))
        palette.putpalette([channel for color in colors for channel in color]
                           + list(colors[0]) * (256 - len(colors)))
    else:
        samples = [pixel[:3] for frame in frames for pixel in frame.getdata() if pixel[3]]
        palette_source = Image.new("RGB", (256, (len(samples) + 255) // 256), samples[0])
        palette_source.putdata(samples)
        palette = palette_source.quantize(colors=96, method=Image.Quantize.MEDIANCUT,
                                          dither=Image.Dither.NONE)
    results, hashes = [], []
    for frame in frames:
        result = frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        result.putalpha(frame.getchannel("A"))
        result.paste((0, 0, 0, 0), mask=frame.getchannel("A").point(lambda value: 255 if not value else 0))
        results.append(result)
        hashes.append(hashlib.sha256(result.tobytes()).hexdigest())
    if len(set(hashes)) != count:
        raise ValueError(f"{source}: duplicate authored frames")
    write_frames(variant, clip, results)
    print(f"Normalized {variant}/{clip}: {count} distinct transparent frames")


def align_repair(frame):
    bounds = frame.getbbox()
    if bounds is None or not 181 <= bounds[3] <= 187:
        raise ValueError("Repair frame has no planted boot contact at the floor baseline")
    # Only the planted boots anchor repair; the torso and tool move during the action.
    feet = frame.crop((0, bounds[3] - 16, frame.width, bounds[3])).getbbox()
    offset = 104 - (feet[0] + feet[2] - 1) // 2
    if bounds[0] + offset < 0 or bounds[2] + offset > frame.width:
        raise ValueError("Repair frame cannot align without clipping")
    aligned = Image.new("RGBA", frame.size)
    aligned.paste(frame, (offset, 0))
    return aligned


def align_climb(frame):
    # The fixed blue hard hat anchors the ladder pose; raised arms change its full bounds.
    blue = set()
    for y in range(85):
        for x in range(frame.width):
            r, g, b, a = frame.getpixel((x, y))
            if a and b > 110 and b > r * 2 and b - g > 60:
                blue.add((x, y))
    regions = []
    while blue:
        pending = [blue.pop()]
        region = []
        while pending:
            x, y = pending.pop()
            region.append((x, y))
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                neighbor = (x + dx, y + dy)
                if neighbor in blue:
                    blue.remove(neighbor)
                    pending.append(neighbor)
        if len(region) >= 16:
            regions.append(region)
    if not regions:
        raise ValueError("Climb frame has no visible blue hard hat alignment anchor")
    region = min(regions, key=lambda points: min(y for _, y in points))
    hat = [x for x, _ in region]
    offset = 104 - sorted(hat)[len(hat) // 2]
    left, _, right, _ = frame.getbbox()
    if left + offset < 0 or right + offset > frame.width:
        raise ValueError("Climb frame cannot align without clipping")
    aligned = Image.new("RGBA", frame.size)
    aligned.paste(frame, (offset, 0))
    return aligned


def write_frames(variant, clip, results):
    _, columns, _ = configuration(variant, clip)
    output = ART / "frames" / variant / clip
    output.mkdir(parents=True, exist_ok=True)
    paths = []
    for index, result in enumerate(results):
        path = output / f"{index:02d}.png"
        result.save(path)
        paths.append(path.relative_to(ART).as_posix())
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


def manifest():
    result = {"version": 1, "cell_size": [208, 208], "pivot": [104, 184], "variants": {}}
    for variant in VARIANTS:
        animations = {}
        for i, clip in enumerate(CLIPS):
            count, _, _ = configuration(variant, clip)
            paths = [f"frames/{variant}/{clip}/{n:02d}.png" for n in range(count)]
            if not all((ART / p).is_file() for p in paths):
                continue
            animations[clip] = {"fps": FPS[i], "loop": clip in LOOPING, "frames": paths}
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
