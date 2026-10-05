"""Check the export and normalization contracts without generating artwork."""

import configparser
import json
from statistics import mean
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from tools import animation_assets, environment_assets

ROOT = Path(__file__).resolve().parents[1]


class AssetPipelineTest(unittest.TestCase):
    def test_app_icon_preserves_the_title_artwork_without_stretching(self):
        with Image.open(ROOT / "art/cel-shift/ui/frames/title/00.png") as title:
            with Image.open(ROOT / "art/cel-shift/ui/icon.png") as icon:
                self.assertEqual(icon.size, (480, 480))
                self.assertEqual(icon.crop((0, 180, 480, 300)).tobytes(), title.tobytes())
                self.assertIsNone(icon.crop((0, 0, 480, 180)).getbbox())
                self.assertIsNone(icon.crop((0, 300, 480, 480)).getbbox())

    def test_export_includes_runtime_manifests(self):
        presets = configparser.ConfigParser()
        presets.read(ROOT / "export_presets.cfg")
        includes = presets["preset.0"]["include_filter"].strip('"').split(",")
        self.assertIn("art/cel-shift/sprites/manifest.json", includes)
        self.assertIn("art/cel-shift/animations/manifest.json", includes)

    def test_export_ships_no_prompts_or_catalog(self):
        presets = configparser.ConfigParser()
        presets.read(ROOT / "export_presets.cfg")
        includes = presets["preset.0"]["include_filter"].strip('"').split(",")
        excludes = presets["preset.0"]["exclude_filter"].strip('"').split(",")
        self.assertNotIn("art/cel-shift/catalog.json", includes)
        self.assertIn("art/cel-shift/*/prompts/*", excludes)
        self.assertIn("art/cel-shift/catalog.json", excludes)

    def test_export_excludes_source_artwork_not_runtime_artwork(self):
        presets = configparser.ConfigParser()
        presets.read(ROOT / "export_presets.cfg")
        excludes = presets["preset.0"]["exclude_filter"].strip('"').split(",")
        for directory in (
            "art/cel-shift/animations/generated",
            "art/cel-shift/animations/previews",
            "art/cel-shift/environment/generated",
        ):
            with self.subTest(directory=directory):
                self.assertIn(directory + "/*", excludes)
        self.assertNotIn("art/cel-shift/animations/frames/*", excludes)
        self.assertNotIn("art/cel-shift/environment/layers/*", excludes)

    def test_clip_tables_cover_platformer_moves(self):
        expected = ("idle", "walk", "run", "jump", "slide", "primary", "secondary", "reaction", "signal", "climb")
        self.assertEqual(animation_assets.CLIPS, expected)
        self.assertEqual(animation_assets.NORMAL_COUNTS, (6, 8, 8, 6, 4, 6, 8, 4, 6, 6))
        self.assertEqual(animation_assets.LOOPING, ("idle", "walk", "run", "climb"))
        self.assertIn("BACK VIEW", animation_assets.NORMAL_POSES["climb"])
        self.assertEqual(len(animation_assets.FPS), len(expected))
        self.assertEqual(set(animation_assets.NORMAL_POSES), set(expected))
        library = (ROOT / "game/animation_library.gd").read_text()
        self.assertIn("const FRAME_COUNTS: Array[int] = [6, 8, 8, 6, 4, 6, 8, 4, 6, 6]", library)
        self.assertIn('const LOOPING: Array[StringName] = [&"idle", &"walk", &"run", &"climb"]', library)
        for clip in expected:
            self.assertIn(f'\t&"{clip}",', library)

    def test_shipped_clips_share_baseline_and_scale(self):
        standing = ("idle", "walk", "run", "primary", "secondary", "signal")
        # Authored run frames 4 and 8 and jump frames 3 to 5 leave the floor.
        airborne = {"run": {3, 7}, "jump": {2, 3, 4}}
        for variant in animation_assets.VARIANTS:
            heights = []
            for clip in animation_assets.CLIPS:
                frames = sorted((animation_assets.ART / "frames" / variant / clip).glob("*.png"))
                self.assertTrue(frames, f"{variant}/{clip} has frames")
                for index, path in enumerate(frames):
                    with Image.open(path) as frame:
                        box = frame.getbbox()
                    with self.subTest(variant=variant, clip=clip, frame=path.name):
                        self.assertIsNotNone(box, "frames contain visible pixels")
                        self.assertLessEqual(box[3], 187, "boots do not sink below the floor")
                        if index not in airborne.get(clip, set()):
                            self.assertLessEqual(abs(box[3] - 184), 3, "grounded boots sit on the baseline")
                    if clip in standing:
                        heights.append(box[3] - box[1])
            median = sorted(heights)[len(heights) // 2]
            with self.subTest(variant=variant):
                self.assertLessEqual(max(heights), median * 1.15)
                self.assertGreaterEqual(min(heights), median * 0.85)

    def test_walk_passing_poses_have_one_grounded_foot(self):
        for variant in animation_assets.VARIANTS:
            for index in (2, 6):
                path = animation_assets.ART / "frames" / variant / "walk" / f"{index:02}.png"
                with Image.open(path) as frame:
                    bottom = frame.getbbox()[3]
                    contact = [
                        x for x in range(frame.width)
                        if any(frame.getpixel((x, y))[3] for y in range(bottom - 3, bottom))
                    ]
                spans = sum(i == 0 or x != contact[i - 1] + 1 for i, x in enumerate(contact))
                with self.subTest(variant=variant, frame=index + 1):
                    self.assertEqual(spans, 1, "The passing leg lifts clear while the other foot supports the body.")

    def test_walk_preserves_its_existing_shade_budget(self):
        for variant, limit in (("man-midcreek", 39), ("woman-midcreek", 37)):
            colors = set()
            for path in (animation_assets.ART / "frames" / variant / "walk").glob("*.png"):
                with Image.open(path) as frame:
                    colors.update(pixel[:3] for pixel in frame.getdata() if pixel[3])
            with self.subTest(variant=variant):
                self.assertLessEqual(len(colors), limit, "Keep the measured per-hero walking shade budget.")

    def walk_denim_depth_delta(self, path):
        with Image.open(path) as source:
            frame = source.convert("RGBA")
        bottom = frame.getbbox()[3]
        # Below-belt denim value supplements, but does not replace, visual occlusion review.
        pixels = [
            (x, 0.299 * r + 0.587 * g + 0.114 * b)
            for y in range(bottom - 56, bottom)
            for x in range(frame.width)
            for r, g, b, a in [frame.getpixel((x, y))]
            if a and b > r + 15 and b > 70
        ]
        self.assertTrue(pixels, f"{path}: visible denim is required")
        center = mean(x for x, _ in pixels)
        rear = [value for x, value in pixels if x < center]
        front = [value for x, value in pixels if x >= center]
        self.assertTrue(rear and front, f"{path}: both leg regions are required")
        return mean(front) - mean(rear)

    def test_walk_opposite_phases_exchange_leg_depth(self):
        for variant in animation_assets.VARIANTS:
            frames = animation_assets.ART / "frames" / variant / "walk"
            deltas = [self.walk_denim_depth_delta(frames / f"{i:02}.png") for i in range(8)]
            for i in range(4):
                with self.subTest(variant=variant, pair=(i + 1, i + 5)):
                    self.assertLess(deltas[i] * deltas[i + 4], 0, "Opposite phases exchange the lit near leg and darker far leg.")

    def test_walk_opposite_phases_keep_head_registration(self):
        for variant in animation_assets.VARIANTS:
            frames = animation_assets.ART / "frames" / variant / "walk"
            tops = []
            for i in range(8):
                with Image.open(frames / f"{i:02}.png") as frame:
                    tops.append(frame.getbbox()[1])
            for i in range(4):
                with self.subTest(variant=variant, pair=(i + 1, i + 5)):
                    self.assertLessEqual(abs(tops[i] - tops[i + 4]), 1, "Opposite gait phases share head registration within one raster pixel.")

    @staticmethod
    def pouch_offset(path):
        """Horizontal offset of the brown tool pouch from the figure center, at belt height."""
        with Image.open(path) as frame:
            image = frame.convert("RGBA")
        left, top, right, bottom = image.getbbox()
        pouch, body = [], []
        # The belt sits 55 to 80 pixels above the boot baseline in every frame.
        for y in range(bottom - 80, bottom - 55):
            for x in range(left, right):
                r, g, b, a = image.getpixel((x, y))
                if not a:
                    continue
                # Leather brown only; the vest's safety orange is brighter (r >= 200).
                if 90 < r < 200 and 40 < g < 110 and b < 70 and r > g + 25:
                    pouch.append(x)
                else:
                    body.append(x)
        if len(pouch) < 8 or not body:
            return 0.0
        # Measure against the hips, not the bounding box, which shifts with a raised arm.
        return sum(pouch) / len(pouch) - sorted(body)[len(body) // 2]

    def test_climb_keeps_the_tool_pouch_on_one_side(self):
        for variant in animation_assets.VARIANTS:
            frames = sorted((animation_assets.ART / "frames" / variant / "climb").glob("*.png"))
            offsets = [self.pouch_offset(path) for path in frames]
            with self.subTest(variant=variant, offsets=[round(o, 1) for o in offsets]):
                self.assertEqual(len(frames), 6)
                self.assertTrue(all(abs(o) >= 3 for o in offsets), "pouch is visible beside the body")
                self.assertTrue(all(o > 0 for o in offsets), "pouch stays on the right hip, image right in the back view")

    def test_climb_hat_stays_over_the_ladder_axis(self):
        for variant in animation_assets.VARIANTS:
            for path in sorted((animation_assets.ART / "frames" / variant / "climb").glob("*.png")):
                with Image.open(path) as frame:
                    blue = [
                        x for y in range(85) for x in range(frame.width)
                        if (lambda p: p[3] and p[2] - p[0] > 80 and p[2] - p[1] > 60)(
                            frame.getpixel((x, y))
                        )
                    ]
                with self.subTest(variant=variant, frame=path.name):
                    self.assertTrue(blue, "the blue hard hat is visible")
                    center = (min(blue) + max(blue)) / 2
                    self.assertLessEqual(abs(center - 104), 3, "climb helmet bounds stay over the ladder axis")

    def test_climb_alignment_preserves_pixels_and_baseline(self):
        frame = Image.new("RGBA", (208, 208))
        frame.paste((15, 80, 180, 255), (132, 35, 149, 51))
        frame.paste((180, 200, 20, 255), (128, 52, 155, 125))
        frame.paste((60, 40, 20, 255), (134, 125, 150, 184))
        aligned = animation_assets.align_climb(frame)
        self.assertEqual(aligned.getpixel((104, 40)), (15, 80, 180, 255))
        self.assertEqual(aligned.getbbox()[3], 184)
        self.assertEqual(sorted(frame.getcolors(208 * 208)), sorted(aligned.getcolors(208 * 208)))
        self.assertEqual(aligned.tobytes(), animation_assets.align_climb(aligned).tobytes())

    def test_climb_alignment_rejects_missing_anchor_and_clipping(self):
        with self.assertRaisesRegex(ValueError, "hard hat"):
            animation_assets.align_climb(Image.new("RGBA", (208, 208)))
        frame = Image.new("RGBA", (208, 208))
        frame.paste((15, 80, 180, 255), (12, 35, 29, 51))
        frame.putpixel((207, 120), (120, 120, 120, 255))
        with self.assertRaisesRegex(ValueError, "clipping"):
            animation_assets.align_climb(frame)

    def test_climb_alignment_ignores_separate_blue_shoulders(self):
        frame = Image.new("RGBA", (208, 208))
        frame.paste((15, 80, 180, 255), (112, 35, 129, 51))
        frame.paste((15, 80, 180, 255), (50, 70, 101, 84))
        aligned = animation_assets.align_climb(frame)
        self.assertEqual(aligned.getpixel((104, 40)), (15, 80, 180, 255))
        self.assertEqual(aligned.getpixel((40, 75)), (15, 80, 180, 255))

    def test_normalize_climb_aligns_authored_off_center_figures(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            source = art / "generated/man-midcreek"
            source.mkdir(parents=True)
            sheet = Image.new("RGBA", (1536, 1024))
            for index, center in enumerate((280, 300, 320, 240, 260, 220)):
                x, y = index % 3 * 512, index // 3 * 512
                sheet.paste((15, 80, 180, 255), (x + center - 20, y + 100, x + center + 20, y + 140))
                sheet.paste((180, 200, 20, 255), (x + center - 30, y + 145, x + center + 30, y + 320))
                sheet.paste((60, 40, 20, 255), (x + center - 20, y + 320, x + center + 20, y + 448))
                sheet.paste((255, 255, 255, 255), (x + center, y + 160 + index * 12, x + center + 9, y + 169 + index * 12))
            sheet.save(source / "climb.png")
            with patch.object(animation_assets, "ART", art):
                animation_assets.normalize("man-midcreek", "climb")
            for path in sorted((art / "frames/man-midcreek/climb").glob("*.png")):
                with self.subTest(frame=path.name), Image.open(path) as frame:
                    self.assertEqual(frame.getpixel((104, 72)), (15, 80, 180, 255))
                    self.assertEqual(frame.getbbox()[3], 184)

    def test_ponytail_guidance_is_woman_specific(self):
        for clip in animation_assets.CLIPS:
            with self.subTest(clip=clip):
                man = animation_assets.prompt_text("man-midcreek", clip)
                woman = animation_assets.prompt_text("woman-midcreek", clip)
                self.assertNotIn("ponytail", man.lower())
                self.assertIn("Ponytail mass stays consistent.", woman)

    def test_every_clip_uses_existing_geometry(self):
        geometry = (
            "y=448, standing figure including hat approximately 270 pixels tall. All painted\n"
            "pixels, including effects/tools/hair, must remain inside x=64..448 and y=96..480."
        )
        for variant in animation_assets.VARIANTS:
            for clip in animation_assets.CLIPS:
                with self.subTest(variant=variant, clip=clip):
                    self.assertIn(geometry, animation_assets.prompt_text(variant, clip))
        for clip in ("idle", "walk"):
            path = animation_assets.ART / "prompts/man-midcreek" / f"{clip}.mock.md"
            self.assertEqual(path.read_text(), animation_assets.prompt_text("man-midcreek", clip))

    def test_normalized_environment_contract(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            (art / "generated").mkdir()
            for layer, (source_size, output_size) in environment_assets.LAYERS.items():
                with self.subTest(layer=layer):
                    image = Image.new("RGBA", source_size, (20, 40, 60, 255))
                    if layer == "equipment":
                        image.paste((80, 90, 100, 127), (0, 0, 640, 720))
                        image.paste((20, 40, 60, 128), (640, 0, 1280, 720))
                        image.putpixel((0, 0), (0, 0, 0, 0))
                    image.save(art / "generated" / f"{layer}.png")
                    environment_assets.normalize(layer, art)
                    output = art / "layers" / f"{layer}.png"
                    first = output.read_bytes()
                    environment_assets.normalize(layer, art)
                    self.assertEqual(first, output.read_bytes())
                    with Image.open(output) as result:
                        self.assertEqual(result.size, output_size)
                        self.assertEqual(result.mode, "RGBA")
                        if layer == "equipment":
                            self.assertEqual(set(result.getchannel("A").tobytes()), {0, 255})
                            self.assertEqual(result.getpixel((0, 0)), (0, 0, 0, 0))
                            self.assertEqual(result.getpixel((639, 0)), (20, 40, 60, 255))
                        else:
                            self.assertEqual(result.getchannel("A").getextrema(), (255, 255))
                            self.assertEqual(result.getpixel((0, 0)), (20, 40, 60, 255))

    def test_background_sets_cover_every_level(self):
        self.assertEqual(
            set(environment_assets.SETS), {"hot-aisle", "cable-jungle", "power-room", "outage-night"}
        )
        for name, prompts in environment_assets.SETS.items():
            with self.subTest(name=name):
                self.assertEqual(set(prompts), {"far", "equipment"})
                text = environment_assets.prompt_text(name, "equipment")
                self.assertIn("Edit image 1", text)
                self.assertIn("Keep unchanged", text)

    def test_named_set_normalizes_into_its_own_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            (art / "hot-aisle/generated").mkdir(parents=True)
            Image.new("RGBA", (1280, 720), (90, 40, 30, 255)).save(art / "hot-aisle/generated/far.png")
            environment_assets.normalize("far", art, "hot-aisle")
            with Image.open(art / "hot-aisle/far.png") as result:
                self.assertEqual(result.size, (640, 360))
            self.assertFalse((art / "layers/far.png").exists())

    def test_environment_rejects_invalid_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            (art / "generated").mkdir()
            for layer, (source_size, _) in environment_assets.LAYERS.items():
                with self.subTest(layer=layer):
                    source = art / "generated" / f"{layer}.png"
                    Image.new("RGBA", (10, 10)).save(source)
                    with self.assertRaisesRegex(ValueError, "wrong size"):
                        environment_assets.normalize(layer, art)
                    alpha = 255 if layer == "equipment" else 0
                    Image.new("RGBA", source_size, (20, 40, 60, alpha)).save(source)
                    with self.assertRaisesRegex(ValueError, "transparent and visible|must be opaque"):
                        environment_assets.normalize(layer, art)
                    self.assertFalse((art / "layers" / f"{layer}.png").exists())

    def test_checked_in_environment_outputs_are_reproducible(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            (art / "generated").mkdir()
            for layer, (_, output_size) in environment_assets.LAYERS.items():
                with self.subTest(layer=layer):
                    source = environment_assets.ART / "generated" / f"{layer}.png"
                    (art / "generated" / source.name).write_bytes(source.read_bytes())
                    environment_assets.normalize(layer, art)
                    committed = environment_assets.ART / "layers" / source.name
                    with Image.open(art / "layers" / source.name) as actual:
                        with Image.open(committed) as expected:
                            self.assertEqual(expected.size, output_size)
                            self.assertEqual(actual.tobytes(), expected.tobytes())

    def test_environment_metadata_has_no_account(self):
        for path in (environment_assets.ART / "generated").glob("*.metadata.json"):
            with self.subTest(path=path.name):
                self.assertNotIn("account", json.loads(path.read_text()))

    def test_duplicate_animation_rejection_preserves_outputs(self):
        for existing in (False, True):
            with self.subTest(existing=existing), tempfile.TemporaryDirectory() as directory:
                art = Path(directory)
                generated = art / "generated/man-midcreek"
                generated.mkdir(parents=True)
                count, columns, size = animation_assets.configuration("man-midcreek", "idle")
                sheet = Image.new("RGBA", size)
                for index in range(count):
                    x, y = (index % columns) * 512, (index // columns) * 512
                    sheet.paste((40, 80, 120, 255), (x + 192, y + 128, x + 320, y + 448))
                sheet.save(generated / "idle.png")
                output = art / "frames/man-midcreek/idle"
                previews = art / "previews/man-midcreek"
                previous = {}
                if existing:
                    output.mkdir(parents=True)
                    previews.mkdir(parents=True)
                    for index in range(count):
                        path = output / f"{index:02d}.png"
                        previous[path] = f"previous-frame-{index}".encode()
                    for extension in ("png", "gif"):
                        previous[previews / f"idle.{extension}"] = b"previous-preview"
                    for path, content in previous.items():
                        path.write_bytes(content)
                with patch.object(animation_assets, "ART", art):
                    with self.assertRaisesRegex(ValueError, "duplicate authored frames"):
                        animation_assets.normalize("man-midcreek", "idle")
                if existing:
                    for path, content in previous.items():
                        self.assertEqual(path.read_bytes(), content)
                else:
                    self.assertFalse(output.exists())
                    self.assertFalse(previews.exists())

    def test_unique_animation_writes_frames_and_previews(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            generated = art / "generated/man-midcreek"
            generated.mkdir(parents=True)
            source = animation_assets.ART / "generated/man-midcreek/idle.png"
            (generated / "idle.png").write_bytes(source.read_bytes())
            with patch.object(animation_assets, "ART", art):
                animation_assets.normalize("man-midcreek", "idle")
            frames = sorted((art / "frames/man-midcreek/idle").glob("*.png"))
            self.assertEqual(len(frames), 6)
            pixels = []
            for path in frames:
                with Image.open(path) as frame:
                    self.assertEqual(frame.size, (208, 208))
                    self.assertEqual(set(frame.getchannel("A").tobytes()), {0, 255})
                    pixels.append(frame.tobytes())
            self.assertEqual(len(set(pixels)), 6)
            for extension in ("png", "gif"):
                self.assertTrue((art / "previews/man-midcreek" / f"idle.{extension}").is_file())

    def test_animation_normalization_preserves_the_published_palette(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            generated = art / "generated/man-midcreek"
            generated.mkdir(parents=True)
            source = animation_assets.ART / "generated/man-midcreek/idle.png"
            (generated / "idle.png").write_bytes(source.read_bytes())
            swatch = Image.new("RGB", (2, 1))
            swatch.putdata([(0, 0, 0), (255, 255, 255)])
            swatch.save(art / "palette.png")
            with patch.object(animation_assets, "ART", art):
                animation_assets.normalize("man-midcreek", "idle")
            for path in (art / "frames/man-midcreek/idle").glob("*.png"):
                with Image.open(path) as frame:
                    colors = {pixel[:3] for pixel in frame.getdata() if pixel[3]}
                self.assertLessEqual(colors, {(0, 0, 0), (255, 255, 255)})

    def test_invalid_published_palette_does_not_replace_animation_frames(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            generated = art / "generated/man-midcreek"
            generated.mkdir(parents=True)
            source = animation_assets.ART / "generated/man-midcreek/idle.png"
            (generated / "idle.png").write_bytes(source.read_bytes())
            Image.new("RGB", (2, 2)).save(art / "palette.png")
            saved = art / "frames/man-midcreek/idle/00.png"
            saved.parent.mkdir(parents=True)
            saved.write_bytes(b"previous frame")
            with patch.object(animation_assets, "ART", art):
                with self.assertRaisesRegex(ValueError, "palette"):
                    animation_assets.normalize("man-midcreek", "idle")
            self.assertEqual(saved.read_bytes(), b"previous frame")


if __name__ == "__main__":
    unittest.main()
