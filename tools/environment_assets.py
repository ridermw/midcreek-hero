"""Normalize generated environment layers for the data hall runtime."""

import argparse
import json
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/cel-shift/environment"
LAYERS = {
    "far": ((1280, 720), (640, 360)),
    "equipment": ((1280, 720), (640, 360)),
    "floor": ((1536, 512), (640, 96)),
}
STYLE = (
    "Strict side-on orthographic elevation, NOT isometric, for a pixel art data center "
    "side scroller. Horizontal seams must match perfectly at the left and right edges for "
    "repetition. Selective dark pixel outlines, short stepped shading ramps, deliberate "
    "square pixel clusters at approximately 2x2 pixels. Match detailed RPG sprite "
    "backgrounds, not smooth cel shaded illustration. No text, words, numerals, logos, UI, "
    "watermark, characters or border."
)
LAYER_RULES = {
    "far": "Opaque background. Distant architecture only. Lower 150 pixels are floor.",
    "equipment": (
        "Actual TRANSPARENT RGBA output: transparent sky and gaps, opaque equipment only. "
        "A row of equipment standing on the bottom edge, filling roughly the lower two thirds."
    ),
}
SETS = {
    "hot-aisle": {
        "far": "A hot aisle containment corridor: warm amber lighting, exhaust ceiling ducts, heat haze shimmer drawn as pixel ripples, orange warning stripes on pale walls.",
        "equipment": "The hot exhaust side of server racks: dense rear fans, red and orange status lights, thick power cables, a few portable floor fans and heat warning signs without text.",
    },
    "cable-jungle": {
        "far": "A cable vault under a data hall: low concrete ceiling crowded with yellow ladder trays, hanging blue and orange cable bundles, dim teal lighting.",
        "equipment": "Patch panels and network cross connect frames overflowing with blue, orange and yellow patch cables, cable spools on the floor, cable ties.",
    },
    "power-room": {
        "far": "An electrical power room: tall grey switchgear cabinets in the distance, busbar ducts on the ceiling, cool white lighting with yellow hazard stripes on the floor.",
        "equipment": "Battery UPS cabinets, power distribution units with breaker rows, transformer housings and thick copper busbars, small green and amber indicator lights.",
    },
    "outage-night": {
        "far": "The same bright data hall architecture during a power outage at night: very dark navy and violet tones, red emergency lights, faint moonlight through clerestory windows.",
        "equipment": "Rows of server racks in an outage: most lights dark, a few red emergency strobes, scattered flickering blue status lights, dark silhouettes with rim light.",
    },
}
SOURCE_SIZE = (1280, 720)


def prompt_text(name, layer):
    return (
        "Edit image 1: replace its entire content with a new background layer described below. "
        "Keep unchanged from image 1: the pixel art style, the pixel scale, the outline treatment "
        f"and the side view camera.\n\n{STYLE}\n\n{LAYER_RULES[layer]}\n\nSCENE: {SETS[name][layer]}"
    )


def render(name, layer, art=ART):
    reference = art / "layers" / f"{layer}.png"
    target = art / name / "generated" / f"{layer}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    prompts = art / name / "prompts"
    prompts.mkdir(parents=True, exist_ok=True)
    prompt = prompt_text(name, layer)
    size = f"{SOURCE_SIZE[0]}x{SOURCE_SIZE[1]}"
    (prompts / f"{layer}.mock.md").write_text(
        f"---\nname: {name}-{layer}\nsize: {size}\nquality: high\n---\n\n{prompt}\n"
    )
    background = "transparent" if layer == "equipment" else "opaque"
    subprocess.run([
        "mockui", "edit", str(reference), "-p", prompt, "--strict-prompt",
        "--model", "sunburst", "--quality", "high", "--background", background,
        "--size", size, "-o", str(target),
    ], check=True)
    sidecar = target.with_suffix(".png.metadata.json")
    data = json.loads(sidecar.read_text())
    data.pop("account", None)
    for item in data.get("inputs", []):
        item["path"] = Path(item["path"]).resolve().relative_to(ROOT).as_posix()
    data["source_image"] = reference.relative_to(ROOT).as_posix()
    sidecar.write_text(json.dumps(data, indent=2) + "\n")


def normalize(layer, art=ART, name=None):
    source_size, output_size = LAYERS[layer]
    if name is not None:
        source_size = SOURCE_SIZE
    base = art / name if name else art
    source = base / "generated" / f"{layer}.png"
    with Image.open(source) as image:
        if image.size != source_size:
            raise ValueError(f"{source}: wrong size {image.size}, expected {source_size}")
        result = image.convert("RGBA")
    alpha_range = result.getchannel("A").getextrema()
    if layer == "equipment":
        if alpha_range[0] != 0 or alpha_range[1] < 128:
            raise ValueError(f"{source}: equipment requires transparent and visible pixels")
    elif alpha_range != (255, 255):
        raise ValueError(f"{source}: {layer} must be opaque")
    result = result.resize(output_size, Image.Resampling.NEAREST)
    if layer == "equipment":
        alpha = result.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        if alpha.getextrema() != (0, 255):
            raise ValueError(f"{source}: normalization lost transparent or visible pixels")
        result.putalpha(alpha)
        result.paste((0, 0, 0, 0), mask=alpha.point(lambda value: 255 if value == 0 else 0))
    output = (art / name / f"{layer}.png") if name else (art / "layers" / f"{layer}.png")
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output)
    print(f"Normalized {layer}: {output_size[0]}x{output_size[1]}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("normalize", "render"))
    parser.add_argument("--layer", choices=LAYERS)
    parser.add_argument("--set", dest="name", choices=SETS)
    args = parser.parse_args()
    if args.operation == "render":
        if not args.name or args.layer not in ("far", "equipment"):
            parser.error("render needs --set and --layer far or equipment")
        render(args.name, args.layer)
        return
    layers = (args.layer,) if args.layer else (("far", "equipment") if args.name else LAYERS)
    for layer in layers:
        normalize(layer, ART, args.name)


if __name__ == "__main__":
    main()
