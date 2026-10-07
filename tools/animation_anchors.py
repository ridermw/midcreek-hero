"""Measure hero frame anchors and classify discontinuities in rendered animation probe traces.

Usage: python -m tools.animation_anchors <native-trace.json> <report.json>
The trace comes from tests/animation_probe.gd. Anchors are texture pixels in the
208x208 cells; the sprite draws them at 0.5 world pixels per texel around x=104.
"""

import argparse
import json
from pathlib import Path

from PIL import Image

from tools import animation_assets

PIVOT_X = 104
WORLD_PER_TEXEL = 0.5
# Whole-figure moves above this many texels are visible (2 world px) registration jumps.
JUMP_TEXELS = 3
# Planted clips keep both boots in place; any larger boot span drift is registration.
PLANTED = ("idle", "primary", "secondary")
# Repair and diagnosis extend a tool; reach is the rightmost opaque column.
TOOL_CLIPS = ("primary", "secondary")
PLANTED_TEXELS = 1
# A translated figure moves its torso about as far as its helmet; a lean moves the helmet more.
TRANSLATION_RATIO = 0.75
TIMING_TICKS = 1.0
CAMERA_PIXELS = 1.0
UNEXPLAINED = ("source registration", "playback timing", "camera or render timing")


def frame_anchors(image):
    frame = image.convert("RGBA")
    pixels = frame.load()
    width, height = frame.size
    hat, vest = [], []
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if not a:
                continue
            if y < 90 and b > 110 and b > r * 2 and b - g > 60:
                hat.append((x, y))
            elif r > 180 and g > 90 and b < 90:
                vest.append(x)
    if not hat:
        raise ValueError("Frame has no visible blue helmet anchor")
    bounds = frame.getbbox()
    feet = frame.crop((0, bounds[3] - 16, width, bounds[3])).getbbox()
    xs = sorted(x for x, _ in hat)
    return {
        "helmet_x": xs[len(xs) // 2],
        "helmet_top": min(y for _, y in hat),
        "torso_x": round(sum(vest) / len(vest), 2) if vest else float(PIVOT_X),
        "boot_x": (feet[0] + feet[2] - 1) / 2,
        "reach_x": bounds[2] - 1,
    }


def load_anchors(art=None, clips=None):
    root = (art or animation_assets.ART) / "frames"
    anchors = {}
    for variant in animation_assets.VARIANTS:
        for clip in clips or animation_assets.CLIPS:
            for path in sorted((root / variant / clip).glob("*.png")):
                with Image.open(path) as image:
                    anchors[(variant, clip, int(path.stem))] = frame_anchors(image)
    return anchors


def classify(before, after, kind, ticks, fps, camera_error, clip, previous_clip):
    """Return every independent cause, so a pose or registration change cannot hide timing."""
    helmet = after["helmet_x"] - before["helmet_x"]
    torso = after["torso_x"] - before["torso_x"]
    boots = after["boot_x"] - before["boot_x"]
    reach = after["reach_x"] - before["reach_x"]
    causes = []
    if clip in PLANTED and previous_clip in PLANTED:
        # Planted boots separate a registration shift from an upper body lean.
        if abs(boots) > PLANTED_TEXELS:
            causes.append("source registration")
    elif (abs(helmet) > JUMP_TEXELS and abs(torso) > JUMP_TEXELS and helmet * torso > 0
          and abs(torso) >= TRANSLATION_RATIO * abs(helmet)):
        causes.append("source registration")
    # A helmet lean or a tool swing relative to the torso is authored motion.
    if not causes and (abs(helmet) > JUMP_TEXELS or (clip in TOOL_CLIPS and abs(reach - torso) > JUMP_TEXELS)):
        causes.append("authored pose")
    if kind != "transition" and ticks is not None and abs(ticks - 60.0 / fps) > TIMING_TICKS:
        causes.append("playback timing")
    if camera_error > CAMERA_PIXELS:
        causes.append("camera or render timing")
    return causes


def analyze(samples, anchors, fps):
    phases = {}
    for item in samples:
        phases.setdefault(item["phase"], []).append(item)
    report = {}
    for phase, items in phases.items():
        variant = phase.split("-")[0] + "-midcreek"
        changes = []
        last_change = None
        for previous, current in zip(items, items[1:]):
            if (previous["clip"], previous["frame"]) == (current["clip"], current["frame"]):
                continue
            before = anchors[(variant, previous["clip"], previous["frame"])]
            after = anchors[(variant, current["clip"], current["frame"])]
            if previous["clip"] != current["clip"]:
                kind = "transition"
            elif current["frame"] < previous["frame"]:
                kind = "loop"
            else:
                kind = "frame"
            ticks = None
            if last_change is not None and last_change["clip"] == current["clip"] and kind != "transition":
                ticks = current["physics_frame"] - last_change["physics_frame"]
            dx = current["position"][0] - previous["position"][0]
            camera_dx = current["camera"][0] - previous["camera"][0]
            sign = -1 if current.get("flip") else 1
            helmet = after["helmet_x"] - before["helmet_x"]
            reach = after["reach_x"] - before["reach_x"]
            changes.append({
                "kind": kind,
                "from": [previous["clip"], previous["frame"]],
                "to": [current["clip"], current["frame"]],
                "physics_frame": current["physics_frame"],
                "ticks": ticks,
                "physics_dx": round(dx, 3),
                "helmet_texels": helmet,
                "torso_texels": round(after["torso_x"] - before["torso_x"], 2),
                "boot_texels": after["boot_x"] - before["boot_x"],
                "reach_texels": reach,
                "helmet_world": helmet * WORLD_PER_TEXEL * sign,
                "reach_world": reach * WORLD_PER_TEXEL * sign,
                "causes": classify(before, after, kind, ticks, fps[current["clip"]], abs(camera_dx - dx), current["clip"], previous["clip"]),
            })
            last_change = current
        unexplained = [c for c in changes if any(cause in UNEXPLAINED for cause in c["causes"])]
        report[phase] = {
            "changes": changes,
            "unexplained": len(unexplained),
            "max_helmet_texels": max((abs(c["helmet_texels"]) for c in unexplained), default=0),
        }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace")
    parser.add_argument("report")
    parser.add_argument("--art", type=Path, help="Animation art root to measure; defaults to the published frames.")
    args = parser.parse_args()
    samples = json.loads(Path(args.trace).read_text())
    fps = dict(zip(animation_assets.CLIPS, animation_assets.FPS))
    report = analyze(samples, load_anchors(args.art, sorted({s["clip"] for s in samples})), fps)
    Path(args.report).write_text(json.dumps(report, indent=1) + "\n", newline="\n")
    for phase, result in report.items():
        causes = {}
        for change in result["changes"]:
            for cause in change["causes"] or ["none"]:
                causes[cause] = causes.get(cause, 0) + 1
        print(f"{phase}: changes={len(result['changes'])} unexplained={result['unexplained']} "
              f"max_helmet_texels={result['max_helmet_texels']} causes={causes}")


if __name__ == "__main__":
    main()
