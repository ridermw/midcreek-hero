"""Export the four reviewed pixel-art sheets; requires Pillow.

Run with: python art/cel-shift/sprites/prepare.py
"""

from bisect import bisect_right
from collections import deque
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
VARIANTS = ("man-midcreek", "woman-midcreek", "man-hybrid", "woman-hybrid")
CELL = 208
PIVOT = (104, 184)
ANCHORS = (126, 400, 654, 904, 1190, 1428)
# Effects can overlap another sprite's x range without actually touching it.
# Assign connected components as a whole instead of cutting through columns.
CUTS = (210, 535, 800, 1060, 1322)
BASELINE = 430
COLORS = 96


def require(condition, message):
    if not condition:
        raise ValueError(message)


def split_sprites(path):
    with Image.open(path) as source:
        require(source.mode == "RGBA", f"{path.name}: missing RGBA transparency")
        require(source.size == (1536, 512), f"{path.name}: unexpected size")
        source.load()
        image = source.copy()
    alpha = image.getchannel("A").tobytes()
    require(0 in alpha and max(alpha) >= 128, f"{path.name}: unusable alpha")
    width, height = image.size
    unseen = {i for i, value in enumerate(alpha) if value >= 128}
    masks = [bytearray(width * height) for _ in range(6)]
    large_components = [0] * 6
    while unseen:
        first = unseen.pop()
        queue = deque([first])
        component = []
        left, right = width, 0
        while queue:
            i = queue.popleft()
            component.append(i)
            y, x = divmod(i, width)
            left, right = min(left, x), max(right, x)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height:
                        neighbor = ny * width + nx
                        if neighbor in unseen:
                            unseen.remove(neighbor)
                            queue.append(neighbor)
        slot = bisect_right(CUTS, (left + right) / 2)
        if len(component) >= 5000:
            large_components[slot] += 1
        for i in component:
            masks[slot][i] = 255
    require(large_components == [1] * 6,
            f"{path.name}: expected one body per pose, got {large_components}")

    frames = []
    for slot, mask in enumerate(masks):
        frame = image.copy()
        frame.putalpha(Image.frombytes("L", image.size, bytes(mask)))
        frame = frame.resize((768, 256), Image.Resampling.NEAREST)
        bounds = frame.getbbox()
        require(bounds is not None, f"{path.name}: empty pose {slot}")
        crop = frame.crop(bounds)
        position = (PIVOT[0] - ANCHORS[slot] // 2 + bounds[0],
                    PIVOT[1] - BASELINE // 2 + bounds[1])
        require(position[0] >= 1 and position[1] >= 1
                and position[0] + crop.width < CELL
                and position[1] + crop.height < CELL,
                f"{path.name}: pose {slot} would clip at {position}, {crop.size}")
        canvas = Image.new("RGBA", (CELL, CELL))
        canvas.alpha_composite(crop, position)
        frames.append(canvas)
    return frames


def export():
    groups = {name: split_sprites(ROOT / "generated" / f"{name}.png")
              for name in VARIANTS}
    samples = [pixel[:3] for frames in groups.values() for frame in frames
               for pixel in frame.getdata() if pixel[3]]
    swatches = Image.new("RGB", (256, (len(samples) + 255) // 256), samples[0])
    swatches.putdata(samples)
    palette = swatches.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT,
                               dither=Image.Dither.NONE)
    manifest = {
        "status": "sprite concepts; not a continuous animation or engine-tested asset",
        "cell_size": [CELL, CELL],
        "pivot_pixels": list(PIVOT),
        "filter": "nearest",
        "alpha": "binary: 0 or 255",
        "palette_limit": COLORS,
        "source_scale": 0.5,
        "source_foot_baseline": BASELINE,
        "source_anchor_x": list(ANCHORS),
        "variants": {},
    }
    preview = Image.new("RGB", (CELL * 6, (CELL + 24) * 4), "#e1e4eb")
    draw = ImageDraw.Draw(preview)
    for row, (name, frames) in enumerate(groups.items()):
        atlas = Image.new("RGBA", (CELL * 6, CELL))
        output = ROOT / "individual" / name
        output.mkdir(parents=True, exist_ok=True)
        labels = ("ready", "reach", "testing", "reaction", "running", "signal")
        if name.endswith("hybrid"):
            labels = ("ready", "slash", "diagnostic-effect", "block", "running", "triumph")
        entries = []
        for i, (frame, label) in enumerate(zip(frames, labels)):
            result = frame.convert("RGB").quantize(
                palette=palette, dither=Image.Dither.NONE).convert("RGBA")
            result.putalpha(frame.getchannel("A"))
            result.paste((0, 0, 0, 0), mask=frame.getchannel("A").point(
                lambda value: 255 if value == 0 else 0))
            filename = f"{i + 1:02d}-{label}.png"
            result.save(output / filename)
            atlas.paste(result, (i * CELL, 0))
            entries.append({
                "name": label,
                "file": f"individual/{name}/{filename}",
                "frame": {"x": i * CELL, "y": 0, "w": CELL, "h": CELL},
                "pivot_pixels": list(PIVOT),
            })
        (ROOT / "sheets").mkdir(exist_ok=True)
        atlas.save(ROOT / "sheets" / f"{name}.png")
        require(set(atlas.getchannel("A").getdata()) == {0, 255},
                f"{name}: alpha must contain both transparent and opaque pixels")
        require(atlas.getcolors(COLORS + 1) is not None,
                f"{name}: exceeded palette limit")
        manifest["variants"][name] = {
            "sheet": f"sheets/{name}.png",
            "source": f"generated/{name}.png",
            "source_sha256": hashlib.sha256(
                (ROOT / "generated" / f"{name}.png").read_bytes()).hexdigest(),
            "frames": entries,
        }
        y = row * (CELL + 24)
        draw.rectangle((0, y, preview.width, y + 23), fill="#192331")
        draw.text((8, y + 6), name.replace("-", " ").upper(), fill="white")
        for cy in range(0, CELL, 8):
            for cx in range(0, preview.width, 8):
                color = "#d8dce4" if (cx // 8 + cy // 8) % 2 else "#f0f2f6"
                draw.rectangle((cx, y + 24 + cy, cx + 7, y + 31 + cy), fill=color)
        preview.paste(atlas, (0, y + 24), atlas)
    manifest["palette_rgb"] = [
        list(color) for color in sorted({p[:3] for name in VARIANTS
             for p in Image.open(ROOT / "sheets" / f"{name}.png").getdata() if p[3]})
    ]
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    preview.save(ROOT / "preview.png")
    print("Exported 4 transparent sheets and 24 individual sprites; alpha and palette passed.")


if __name__ == "__main__":
    export()
