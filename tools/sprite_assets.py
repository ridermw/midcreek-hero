"""Generate MockUI tiles, hazards, props and UI sprites and export pixel frames.

The catalog at art/cel-shift/catalog.json lists every asset. Each group shares
one palette of at most 96 opaque colors and writes <group>/manifest.json.
"""

import argparse
import json
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/cel-shift"
MAX_EDGE = 2048
GROUP_COLORS = 96
STYLE = (
    "TRUE PIXEL ART game sprite in the same Cel Shift style as image 1: dark stepped pixel "
    "contours, small square color clusters, shaded material ramps, cool data center palette. "
    "Never smooth illustration, vector art, 3D render or painted concept art. "
    "Use actual TRANSPARENT RGBA output around the object. No checkerboard, backdrop, "
    "ground shadow, scenery, text, labels, logos or watermark unless the prompt asks for text."
)


def load_catalog(art=ART):
    return json.loads((art / "catalog.json").read_text())


def asset_entry(name, art=ART):
    for asset in load_catalog(art)["assets"]:
        if asset["name"] == name:
            return asset
    raise KeyError(f"Unknown asset: {name}")


def source_size(cell, frames):
    """Return (width, height, scale) for a one-row source sheet that fits MockUI limits."""
    width, height = cell
    for scale in range(MAX_EDGE // min(width, height), 0, -1):
        w, h = width * frames * scale, height * scale
        if w <= MAX_EDGE and h <= MAX_EDGE and (width * scale) % 16 == 0 and (height * scale) % 16 == 0:
            return w, h, scale
    raise ValueError(f"No valid source size for cell {cell} with {frames} frames")


def prompt_text(asset):
    width, height, _ = source_size(asset["cell"], asset["frames"])
    frames = asset["frames"]
    if frames > 1:
        layout = (
            f"EXACT GRID: {frames} equal cells in one row, read left to right, each "
            f"{width // frames}x{height}. One animation frame per cell at the same scale and "
            "position. Every frame differs. No drawn grid lines or numbers."
        )
    else:
        layout = f"One object filling the {width}x{height} canvas."
    return (
        "Edit image 1: replace its entire content with a new isolated game sprite described below. "
        "Keep unchanged from image 1: the pixel art style, the color palette, the outline treatment "
        f"and the lighting direction.\n\n{STYLE}\n\n{layout}\n\nOBJECT: {asset['prompt']}"
    )


def render(name, art=ART):
    asset = asset_entry(name, art)
    width, height, _ = source_size(asset["cell"], asset["frames"])
    reference = ROOT / asset.get("reference", "art/cel-shift/environment/layers/equipment.png")
    prompt_dir = art / asset["group"] / "prompts"
    prompt_dir.mkdir(parents=True, exist_ok=True)
    prompt = prompt_text(asset)
    (prompt_dir / f"{name}.mock.md").write_text(
        f"---\nname: {name}\nsize: {width}x{height}\nquality: high\n---\n\n{prompt}\n"
    )
    target = art / asset["group"] / "generated" / f"{name}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "mockui", "edit", str(reference), "-p", prompt,
        "--strict-prompt", "--model", "sunburst", "--quality", "high",
        "--background", "transparent", "--size", f"{width}x{height}",
        "-o", str(target),
    ], check=True)
    sidecar = target.with_suffix(".png.metadata.json")
    data = json.loads(sidecar.read_text())
    data.pop("account", None)
    for item in data.get("inputs", []):
        item["path"] = Path(item["path"]).resolve().relative_to(ROOT).as_posix()
    data["source_image"] = reference.relative_to(ROOT).as_posix()
    sidecar.write_text(json.dumps(data, indent=2) + "\n")


def normalize(name, art=ART):
    asset = asset_entry(name, art)
    cell_w, cell_h = asset["cell"]
    frames = asset["frames"]
    width, height, scale = source_size((cell_w, cell_h), frames)
    source = art / asset["group"] / "generated" / f"{name}.png"
    image = Image.open(source).convert("RGBA")
    if image.size != (width, height):
        raise ValueError(f"{source}: wrong size {image.size}, expected {(width, height)}")
    output = art / asset["group"] / "frames" / name
    output.mkdir(parents=True, exist_ok=True)
    for old in output.glob("*.png"):
        old.unlink()
    paths = []
    crops = [image.crop((index * cell_w * scale, 0, (index + 1) * cell_w * scale, height))
             for index in range(frames)]
    fit = asset.get("fit", "canvas")
    if fit != "canvas":
        boxes = [crop.getchannel("A").point(lambda value: 255 if value >= 128 else 0).getbbox()
                 for crop in crops]
        boxes = [box for box in boxes if box]
        if not boxes:
            raise ValueError(f"{source}: no opaque pixels")
        union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
                 max(b[2] for b in boxes), max(b[3] for b in boxes))
        crops = [crop.crop(union) for crop in crops]
    for crop in crops:
        frame = _fit(crop, (cell_w, cell_h), fit)
        alpha = frame.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        frame.putalpha(alpha)
        frame.paste((0, 0, 0, 0), mask=alpha.point(lambda value: 255 if value == 0 else 0))
        path = output / f"{len(paths):02d}.png"
        frame.save(path)
        paths.append(path.relative_to(art / asset["group"]).as_posix())
    return paths


def _fit(crop, cell, fit):
    if fit in ("canvas", "fill"):
        return crop.resize(cell, Image.Resampling.BOX)
    if fit not in ("top", "bottom", "center"):
        raise ValueError(f"Unknown fit mode: {fit}")
    factor = min(cell[0] / crop.width, cell[1] / crop.height)
    size = (max(1, round(crop.width * factor)), max(1, round(crop.height * factor)))
    scaled = crop.resize(size, Image.Resampling.BOX)
    x = (cell[0] - size[0]) // 2
    y = {"top": 0, "bottom": cell[1] - size[1], "center": (cell[1] - size[1]) // 2}[fit]
    frame = Image.new("RGBA", cell, (0, 0, 0, 0))
    frame.paste(scaled, (x, y))
    return frame


def group_frames(group, art=ART):
    return sorted((art / group / "frames").rglob("*.png"))


def group_colors(group, art=ART):
    colors = set()
    for path in group_frames(group, art):
        with Image.open(path) as frame:
            colors.update(pixel[:3] for pixel in frame.convert("RGBA").getdata() if pixel[3])
    return colors


def apply_group_palette(group, art=ART, colors=GROUP_COLORS):
    paths = group_frames(group, art)
    frames = [Image.open(path).convert("RGBA") for path in paths]
    samples = [pixel[:3] for frame in frames for pixel in frame.getdata() if pixel[3]]
    if not samples:
        raise ValueError(f"{group}: no opaque pixels")
    source = Image.new("RGB", (256, (len(samples) + 255) // 256), samples[0])
    source.putdata(samples)
    palette = source.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    for path, frame in zip(paths, frames):
        alpha = frame.getchannel("A")
        result = frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        result.putalpha(alpha)
        result.paste((0, 0, 0, 0), mask=alpha.point(lambda value: 255 if value == 0 else 0))
        result.save(path)
    swatch = palette.convert("RGB").resize((len(palette.getpalette()) // 3, 1))
    swatch.save(art / group / "palette.png")


def write_manifest(group, art=ART):
    manifest = {"version": 1, "assets": {}}
    for asset in load_catalog(art)["assets"]:
        if asset["group"] != group:
            continue
        frames = [f"frames/{asset['name']}/{index:02d}.png" for index in range(asset["frames"])]
        for path in frames:
            if not (art / group / path).is_file():
                raise ValueError(f"{group}/{asset['name']}: missing frame {path}")
        manifest["assets"][asset["name"]] = {"cell": asset["cell"], "fps": asset["fps"], "frames": frames}
    (art / group / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("render", "normalize", "palette", "manifest"))
    parser.add_argument("--name")
    parser.add_argument("--group")
    args = parser.parse_args()
    if args.operation in ("render", "normalize") and not args.name:
        parser.error("--name is required")
    if args.operation in ("palette", "manifest") and not args.group:
        parser.error("--group is required")
    if args.operation == "render":
        render(args.name)
    elif args.operation == "normalize":
        print(args.name, normalize(args.name))
    elif args.operation == "palette":
        apply_group_palette(args.group)
        print(args.group, "colors:", len(group_colors(args.group)))
    else:
        print(args.group, "assets:", len(write_manifest(args.group)["assets"]))


if __name__ == "__main__":
    main()
