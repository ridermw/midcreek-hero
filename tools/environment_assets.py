"""Normalize generated environment layers for the data hall runtime."""

import argparse
import json
import subprocess
from pathlib import Path

from PIL import Image

if __package__:
    from .sprite_assets import _build_palette
else:
    from sprite_assets import _build_palette

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/cel-shift/environment"
LAYERS = {
    "far": ((1280, 720), (640, 360)),
    "equipment": ((1280, 720), (640, 360)),
    "floor": ((1536, 512), (640, 96)),
}
FAR_WORLD_PX_PER_TEXEL = 2.0
EQUIPMENT_WORLD_PX_PER_TEXEL = 1.0
TILE = 32
COLD_AISLE = "cold-aisle"
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
EXPANSION_SETS = {
    "cooling-gallery": {
        "far": "A cooling gallery with tall pale chiller housings, cyan pipe loops along the ceiling and blue service lighting.",
        "equipment": "Chilled water distribution pipes, a large round pump, blue valve wheels and finned cooling units.",
    },
    "operations-suite": {
        "far": "A data center operations suite with observation windows, wall monitor arrays without text and recessed ceiling lights.",
        "equipment": "Operator desks with small teal monitor screens, equipment test benches and mobile diagnostic carts.",
    },
    "fiber-exchange": {
        "far": "A fiber exchange room with tall optical distribution frames, suspended cable baskets and violet work lights.",
        "equipment": "Fiber patch panels, coils of thin orange optical fiber and structured cable distribution frames.",
    },
    "loading-yard": {
        "far": "An outdoor facility loading yard at daylight, warehouse loading doors, a parked box truck in strict side view, fences and distant trees.",
        "equipment": "Shipping crates, pallet stacks and a low loading dock with wheel stops. No vehicles moving.",
    },
    "fire-response-hall": {
        "far": "A fire response corridor with fire rated doors, red pipework, wall mounted safety cabinets and emergency lighting. No flames.",
        "equipment": "Red hose reels, extinguisher cabinets, suppression cylinders and metal safety barriers.",
    },
    "pump-station": {
        "far": "An industrial pump station with large water pipes rising vertically, inspection windows and blue concrete walls.",
        "equipment": "Two large centrifugal pumps, thick blue pipes, pressure gauges without text and shutoff valve wheels.",
    },
    "rooftop-air-handlers": {
        "far": "A flat data center rooftop in daylight, distant city buildings below a pale sky, low parapet walls and ventilation ducts.",
        "equipment": "Large rooftop air handler cabinets, circular fan housings and low grey ventilation ducts.",
    },
    "generator-courtyard": {
        "far": "An outdoor generator courtyard with concrete acoustic walls, security fencing and tall exhaust stacks against a pale sky.",
        "equipment": "Enclosed standby diesel generator units, fuel tanks and electrical distribution cabinets.",
    },
    "facility-approach": {
        "far": "A data center facility approach in daylight, glass entrance facade, trees, a parking area with side view parked cars and security fencing.",
        "equipment": "Low security bollards, planted tree beds and a small gatehouse in strict side elevation.",
    },
    "expansion-site": {
        "far": "A data center expansion construction site, exposed steel frame bays, unfinished wall panels and a stationary crane silhouette against daylight sky.",
        "equipment": "Stacked building panels, cable drums, portable construction barriers and unfinished utility cabinets.",
    },
}


def prompt_text(name, layer):
    return (
        "Edit image 1: replace its entire content with a new background layer described below. "
        "Keep unchanged from image 1: the pixel art style, the pixel scale, the outline treatment "
        f"and the side view camera.\n\n{STYLE}\n\n{LAYER_RULES[layer]}\n\nSCENE: {(SETS | EXPANSION_SETS)[name][layer]}"
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


def campaign_background_heights():
    heights = {}
    for path in sorted((ROOT / "levels").glob("[0-9][0-9]-*.level")):
        if path.name.startswith("00-"):
            continue
        header_text, grid_text = path.read_text().replace("\r\n", "\n").split("\n---\n", 1)
        name = json.loads(header_text)["background"]
        height = len([row for row in grid_text.splitlines() if row]) * TILE
        previous = heights.setdefault(name, height)
        if previous != height:
            raise ValueError(f"{name}: shared background levels have different heights: {previous} and {height}")
    return heights


def normalized_size(layer, name=None):
    if layer == "far" and name is not None:
        height = campaign_background_heights()[name]
        return (640, int(height / FAR_WORLD_PX_PER_TEXEL))
    if layer == "equipment" and name in EXPANSION_SETS:
        return (320, 180)
    return LAYERS[layer][1]


def layer_texture_path(name, layer):
    if name is None:
        return f"res://art/cel-shift/environment/layers/{layer}.png"
    return f"res://art/cel-shift/environment/{name}/{layer}.png"


def write_manifest(name, art=ART):
    if name is None:
        name = COLD_AISLE
    target = art / name / "manifest.json"
    layers = []
    for layer, scroll, tint, scale in [
        ("far", 0.2, [0.42, 0.47, 0.56], FAR_WORLD_PX_PER_TEXEL),
        ("equipment", 0.6, [0.55, 0.6, 0.68], EQUIPMENT_WORLD_PX_PER_TEXEL),
    ]:
        layers.append({
            "name": layer.capitalize(),
            "texture": layer_texture_path(name, layer),
            "scroll": scroll, "tint": tint, "coverage": "native", "scale": scale,
        })
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({"version": 1, "layers": layers}, indent=2) + "\n", newline="\n")


def normalize(layer, art=ART, name=None):
    source_size = LAYERS[layer][0]
    output_size_for = normalized_size(layer, name)
    if name is not None:
        source_size = SOURCE_SIZE
    base = art if name in (None, COLD_AISLE) else art / name
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
    result = result.resize(output_size_for, Image.Resampling.NEAREST)
    if layer == "equipment":
        alpha = result.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        if alpha.getextrema() != (0, 255):
            raise ValueError(f"{source}: normalization lost transparent or visible pixels")
        result.putalpha(alpha)
        result.paste((0, 0, 0, 0), mask=alpha.point(lambda value: 255 if value == 0 else 0))
    if name in EXPANSION_SETS:
        alpha = result.getchannel("A")
        result = result.convert("RGB").quantize(colors=96, dither=Image.Dither.NONE).convert("RGBA")
        result.putalpha(alpha)
        result.paste((0, 0, 0, 0), mask=alpha.point(lambda value: 255 if value == 0 else 0))
    output = (art / name / f"{layer}.png") if name else (art / "layers" / f"{layer}.png")
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output)
    print(f"Normalized {layer}: {output_size_for[0]}x{output_size_for[1]}")


def normalize_set(name, art=ART):
    if name not in EXPANSION_SETS:
        raise ValueError("Compact set normalization only accepts expansion environments")
    paths = [art / name / f"{layer}.png" for layer in ("far", "equipment")]
    for layer in ("far", "equipment"):
        normalize(layer, art, name)
    images = []
    colors = set()
    for path in paths:
        with Image.open(path) as image:
            rgba = image.convert("RGBA")
        images.append(rgba)
        colors.update(pixel[:3] for pixel in rgba.getdata() if pixel[3])
    palette = _build_palette(sorted(colors), 96)
    for path, image in zip(paths, images):
        alpha = image.getchannel("A")
        output = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        output.putalpha(alpha)
        output.paste((0, 0, 0, 0), mask=alpha.point(lambda value: 255 if value == 0 else 0))
        output.save(path)
    write_manifest(name, art)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("normalize", "render"))
    parser.add_argument("--layer", choices=LAYERS)
    parser.add_argument("--set", dest="name", choices={COLD_AISLE: {}} | SETS | EXPANSION_SETS)
    args = parser.parse_args()
    if args.operation == "render":
        if not args.name or args.layer not in ("far", "equipment"):
            parser.error("render needs --set and --layer far or equipment")
        render(args.name, args.layer)
        return
    if args.name and args.layer is None:
        if args.name == COLD_AISLE:
            for layer in ("far", "equipment"):
                normalize(layer, ART, args.name)
            write_manifest(args.name)
        elif args.name in EXPANSION_SETS:
            normalize_set(args.name)
        else:
            for layer in ("far", "equipment"):
                normalize(layer, ART, args.name)
            write_manifest(args.name)
        return
    layers = (args.layer,) if args.layer else (("far", "equipment") if args.name else LAYERS)
    for layer in layers:
        normalize(layer, ART, args.name)
    if args.layer in (None, "far", "equipment"):
        if args.name is None:
            for layer in (("far", "equipment") if args.layer is None else (args.layer,)):
                normalize(layer, ART, COLD_AISLE)
        write_manifest(args.name)


if __name__ == "__main__":
    main()
