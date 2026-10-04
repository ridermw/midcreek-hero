"""Check the export and normalization contracts without generating artwork."""

import configparser
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from tools import animation_assets, environment_assets

ROOT = Path(__file__).resolve().parents[1]


class AssetPipelineTest(unittest.TestCase):
    def test_export_includes_runtime_manifests(self):
        presets = configparser.ConfigParser()
        presets.read(ROOT / "export_presets.cfg")
        includes = presets["preset.0"]["include_filter"].strip('"').split(",")
        self.assertIn("art/cel-shift/sprites/manifest.json", includes)
        self.assertIn("art/cel-shift/animations/manifest.json", includes)

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
        expected = ("idle", "walk", "run", "jump", "slide", "primary", "secondary", "reaction", "signal")
        self.assertEqual(animation_assets.CLIPS, expected)
        self.assertEqual(animation_assets.NORMAL_COUNTS, (6, 8, 8, 6, 4, 6, 8, 4, 6))
        self.assertEqual(len(animation_assets.FPS), len(expected))
        self.assertEqual(set(animation_assets.NORMAL_POSES), set(expected))
        library = (ROOT / "game/animation_library.gd").read_text()
        self.assertIn("const FRAME_COUNTS: Array[int] = [6, 8, 8, 6, 4, 6, 8, 4, 6]", library)
        for clip in expected:
            self.assertIn(f'\t&"{clip}",', library)

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


if __name__ == "__main__":
    unittest.main()
