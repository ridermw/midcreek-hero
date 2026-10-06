"""Check compact expansion backgrounds without changing the existing sets."""

import tempfile
import unittest
import json
from pathlib import Path

from PIL import Image

from tools import environment_assets, sprite_assets


class ExpansionArtTests(unittest.TestCase):
    def test_expansion_set_uses_one_shared_palette_and_ordered_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "cooling-gallery/generated"
            source.mkdir(parents=True)
            for layer, offset in [("far", 0), ("equipment", 100)]:
                image = Image.new("RGBA", (1280, 720))
                image.putdata([
                    ((x + offset) % 256, (x // 5 + offset) % 256, offset,
                     0 if layer == "equipment" and x // 1280 < 180 else 255)
                    for x in range(1280 * 720)
                ])
                image.save(source / f"{layer}.png")
            self.assertTrue(hasattr(environment_assets, "normalize_set"), "A complete set needs shared normalization.")
            if not hasattr(environment_assets, "normalize_set"):
                return
            environment_assets.normalize_set("cooling-gallery", root)
            colors = set()
            for layer in ["far", "equipment"]:
                with Image.open(root / f"cooling-gallery/{layer}.png") as image:
                    colors.update(pixel[:3] for pixel in image.convert("RGBA").getdata() if pixel[3])
            self.assertLessEqual(len(colors), 96)
            manifest = json.loads((root / "cooling-gallery/manifest.json").read_text())
            self.assertEqual([layer["name"] for layer in manifest["layers"]], ["Far", "Equipment"])
            self.assertEqual([layer["scale"] for layer in manifest["layers"]], [2, 2])

    def test_work_catalog_extends_assets_without_mutating_legacy_catalog(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = {"version": 1, "assets": [{"name": "floor", "group": "tiles"}]}
            (root / "catalog.json").write_text(json.dumps(base))
            (root / "work").mkdir()
            (root / "work/catalog.json").write_text(json.dumps({
                "version": 1, "assets": [{"name": "spool", "group": "work"}],
            }))
            self.assertEqual(
                [entry["name"] for entry in sprite_assets.load_catalog(root)["assets"]],
                ["floor", "spool"],
            )
            self.assertEqual(json.loads((root / "catalog.json").read_text()), base)

    def test_compact_background_preserves_binary_alpha_and_pixel_palette(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "cooling-gallery/generated"
            source.mkdir(parents=True)
            image = Image.new("RGBA", (1280, 720), (40, 80, 120, 255))
            image.paste((200, 100, 50, 0), (0, 0, 640, 360))
            image.save(source / "equipment.png")
            environment_assets.normalize("equipment", root, "cooling-gallery")
            with Image.open(root / "cooling-gallery/equipment.png") as result:
                self.assertEqual(result.size, (320, 180))
                rgba = result.convert("RGBA")
                self.assertEqual(set(rgba.getchannel("A").getdata()), {0, 255})
                self.assertLessEqual(len(set(rgba.getdata())), 97)

    def test_compact_far_background_remains_opaque(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "loading-yard/generated"
            source.mkdir(parents=True)
            image = Image.new("RGB", (1280, 720))
            image.putdata(
                [(x % 256, (x // 3) % 256, (x // 7) % 256)
                 for x in range(1280 * 720)]
            )
            image.save(source / "far.png")
            environment_assets.normalize("far", root, "loading-yard")
            with Image.open(root / "loading-yard/far.png") as result:
                self.assertEqual(result.size, (320, 180))
                self.assertLessEqual(len(set(result.convert("RGB").getdata())), 96)
                self.assertEqual(result.convert("RGBA").getchannel("A").getextrema(), (255, 255))


if __name__ == "__main__":
    unittest.main()
