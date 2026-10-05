"""Verify opaque walking pixels in captures from animation_browser_test.mjs."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]


def locate_and_verify(capture, texture, label):
    opaque = [
        (x, y, texture.getpixel((x, y))[:3])
        for y in range(texture.height) for x in range(texture.width)
        if texture.getpixel((x, y))[3] == 255
    ]
    if not opaque:
        raise AssertionError(f"{label}: no opaque pixels")
    points = opaque[::max(1, len(opaque) // 50)]
    pixels = capture.load()
    best = (-1, 0, 0)
    # The test fixes a 960x720 viewport and crops the floor band at y=440.
    for oy in range(30, 35):
        for ox in range(-texture.width, capture.width):
            score = sum(
                0 <= x + ox < capture.width and 0 <= y + oy < capture.height
                and pixels[x + ox, y + oy] == color
                for x, y, color in points
            )
            if score > best[0]:
                best = (score, ox, oy)
    if best[0] != len(points):
        raise AssertionError(f"{label}: cannot locate the expected rendered frame")
    for x, y, color in opaque:
        px, py = x + best[1], y + best[2]
        if not (0 <= px < capture.width and 0 <= py < capture.height) or pixels[px, py] != color:
            raise AssertionError(f"{label}: opaque pixel mismatch at source ({x}, {y})")
    return best[1], best[2]


def verify(evidence):
    for hero in ("man", "woman"):
        for direction in ("right", "left"):
            sheet = Image.new("RGB", (220 * 8, 204), "#15222c")
            draw = ImageDraw.Draw(sheet)
            for index in range(8):
                path = evidence / f"{hero}-{direction}-{index}.png"
                with Image.open(path) as image:
                    capture = image.convert("RGB")
                source = ROOT / f"art/cel-shift/animations/frames/{hero}-midcreek/walk/{index:02}.png"
                with Image.open(source) as image:
                    texture = image.convert("RGBA")
                if direction == "left":
                    texture = ImageOps.mirror(texture)
                offset_x, _ = locate_and_verify(capture, texture, path)
                center = offset_x + 104
                left = max(0, min(capture.width - 220, center - 110))
                sheet.paste(capture.crop((left, 40, left + 220, 224)), (index * 220, 20))
                draw.text((index * 220 + 104, 4), str(index + 1), fill="white")
            sheet.save(evidence / f"{hero}-{direction}-sheet.png")
    print("ANIMATION_BROWSER_FRAMES_COMPLETE: all opaque source pixels match in 32 rendered frames.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    verify(parser.parse_args().evidence)
