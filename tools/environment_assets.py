"""Normalize generated environment layers for the data hall runtime."""

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/cel-shift/environment"
LAYERS = {
    "far": ((1280, 720), (640, 360)),
    "equipment": ((1280, 720), (640, 360)),
    "floor": ((1536, 512), (640, 96)),
}


def normalize(layer, art=ART):
    source_size, output_size = LAYERS[layer]
    source = art / "generated" / f"{layer}.png"
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
    output = art / "layers" / f"{layer}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output)
    print(f"Normalized {layer}: {output_size[0]}x{output_size[1]}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("normalize",))
    parser.add_argument("--layer", choices=LAYERS)
    args = parser.parse_args()
    for layer in (args.layer,) if args.layer else LAYERS:
        normalize(layer)


if __name__ == "__main__":
    main()
