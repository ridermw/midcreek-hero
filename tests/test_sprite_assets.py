"""Check the generic sprite pipeline contracts without generating artwork."""

import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools import sprite_assets


def write_catalog(art, assets):
    catalog = {"version": 1, "assets": assets}
    (art / "catalog.json").write_text(json.dumps(catalog))


class SpriteAssetsTest(unittest.TestCase):
    def test_layout_fits_limits_and_aspect(self):
        for cell, frames in (((32, 32), 1), ((12, 12), 1), ((32, 96), 1), ((32, 64), 4),
                             ((480, 120), 1), ((160, 32), 1), ((16, 16), 4), ((32, 16), 2)):
            with self.subTest(cell=cell, frames=frames):
                grid = sprite_assets.layout(cell, frames)
                width, height = grid["width"], grid["height"]
                self.assertLessEqual(max(width, height), 2048)
                self.assertLessEqual(max(width / height, height / width), 3.0)
                self.assertEqual(width % 16, 0)
                self.assertEqual(height % 16, 0)
                self.assertGreaterEqual(grid["cols"] * grid["rows"], frames)
                self.assertEqual(width, grid["cols"] * cell[0] * grid["scale"])
                self.assertEqual(height, grid["rows"] * grid["slot_height"] * grid["scale"])
                self.assertGreaterEqual(grid["slot_height"], cell[1])

    def paint_frames(self, grid, colors):
        image = Image.new("RGBA", (grid["width"], grid["height"]), (0, 0, 0, 0))
        slot_w = grid["width"] // grid["cols"]
        slot_h = grid["height"] // grid["rows"]
        for index, painter in enumerate(colors):
            x, y = (index % grid["cols"]) * slot_w, (index // grid["cols"]) * slot_h
            painter(image, x, y, slot_w, slot_h)
        return image

    def test_normalize_writes_binary_alpha_frames(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            asset = {"name": "spark", "group": "hazards", "cell": [16, 8], "frames": 2, "fps": 8, "prompt": "x"}
            write_catalog(art, [asset])
            grid = sprite_assets.layout((16, 8), 2)
            scale = grid["scale"]

            def solid(image, x, y, w, h):
                image.paste((200, 40, 40, 255), (x, y, x + w, y + h))

            def strip(image, x, y, w, h):
                image.paste((40, 200, 40, 100), (x, y, x + w, y + h))
                image.paste((40, 40, 200, 255), (x, y, x + scale * 4, y + h))

            image = self.paint_frames(grid, [solid, strip])
            source = art / "hazards/generated/spark.png"
            source.parent.mkdir(parents=True)
            image.save(source)
            paths = sprite_assets.normalize("spark", art)
            self.assertEqual(paths, ["frames/spark/00.png", "frames/spark/01.png"])
            for path in paths:
                with Image.open(art / "hazards" / path) as frame:
                    self.assertEqual(frame.size, (16, 8))
                    self.assertTrue(set(frame.getchannel("A").tobytes()) <= {0, 255})
            with Image.open(art / "hazards/frames/spark/01.png") as frame:
                self.assertEqual(frame.getpixel((0, 4))[3], 255)
                self.assertEqual(frame.getpixel((15, 4))[3], 0)

    def test_fit_modes_place_the_drawn_object(self):
        for fit, opaque_top, opaque_bottom in (("fill", 0, 15), ("top", 0, 3), ("bottom", 12, 15), ("center", 6, 9)):
            with self.subTest(fit=fit), tempfile.TemporaryDirectory() as directory:
                art = Path(directory)
                write_catalog(art, [{"name": "t", "group": "tiles", "cell": [16, 16], "frames": 1,
                                     "fps": 1, "fit": fit, "prompt": "x"}])
                grid = sprite_assets.layout((16, 16), 1)
                width, height = grid["width"], grid["height"]
                image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
                image.paste((90, 100, 110, 255), (0, height // 2, width, height * 3 // 4))
                (art / "tiles/generated").mkdir(parents=True)
                image.save(art / "tiles/generated/t.png")
                sprite_assets.normalize("t", art)
                with Image.open(art / "tiles/frames/t/00.png") as frame:
                    rows = [y for y in range(16) if frame.getpixel((8, y))[3]]
                    self.assertEqual((rows[0], rows[-1]), (opaque_top, opaque_bottom))

    def test_normalize_rejects_blank_frames(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            write_catalog(art, [{"name": "b", "group": "props", "cell": [16, 16], "frames": 2,
                                 "fps": 4, "fit": "center", "prompt": "x"}])
            grid = sprite_assets.layout((16, 16), 2)
            image = Image.new("RGBA", (grid["width"], grid["height"]), (0, 0, 0, 0))
            image.paste((90, 100, 110, 255), (0, 0, 32, 32))
            (art / "props/generated").mkdir(parents=True)
            image.save(art / "props/generated/b.png")
            with self.assertRaisesRegex(ValueError, "b frame 1 is blank"):
                sprite_assets.normalize("b", art)

    def test_normalize_rejects_wrong_size(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            write_catalog(art, [{"name": "a", "group": "ui", "cell": [12, 12], "frames": 1, "fps": 1, "prompt": "x"}])
            (art / "ui/generated").mkdir(parents=True)
            Image.new("RGBA", (10, 10)).save(art / "ui/generated/a.png")
            with self.assertRaisesRegex(ValueError, "wrong size"):
                sprite_assets.normalize("a", art)

    def test_group_palette_and_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            assets = [
                {"name": "a", "group": "props", "cell": [8, 8], "frames": 1, "fps": 1, "prompt": "x"},
                {"name": "b", "group": "props", "cell": [8, 8], "frames": 1, "fps": 1, "prompt": "x"},
            ]
            write_catalog(art, assets)
            for offset, asset in enumerate(assets):
                frame_dir = art / "props/frames" / asset["name"]
                frame_dir.mkdir(parents=True)
                frame = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
                for x in range(8):
                    for y in range(8):
                        frame.putpixel((x, y), (x * 30 + offset, y * 30, 120 + offset, 255))
                frame.putpixel((0, 0), (0, 0, 0, 0))
                frame.save(frame_dir / "00.png")
            sprite_assets.apply_group_palette("props", art, colors=16)
            self.assertLessEqual(len(sprite_assets.group_colors("props", art)), 16)
            with Image.open(art / "props/frames/a/00.png") as frame:
                self.assertEqual(frame.getpixel((0, 0)), (0, 0, 0, 0))
            manifest = sprite_assets.write_manifest("props", art)
            self.assertEqual(manifest["assets"]["a"], {"cell": [8, 8], "fps": 1, "frames": ["frames/a/00.png"]})
            written = json.loads((art / "props/manifest.json").read_text())
            self.assertEqual(written, manifest)

    def test_manifest_requires_every_frame(self):
        with tempfile.TemporaryDirectory() as directory:
            art = Path(directory)
            write_catalog(art, [{"name": "a", "group": "ui", "cell": [8, 8], "frames": 2, "fps": 1, "prompt": "x"}])
            (art / "ui/frames/a").mkdir(parents=True)
            Image.new("RGBA", (8, 8)).save(art / "ui/frames/a/00.png")
            with self.assertRaisesRegex(ValueError, "missing frame"):
                sprite_assets.write_manifest("ui", art)


class ShippedSpriteAssetsTest(unittest.TestCase):
    def test_every_catalog_asset_is_shipped_with_group_palette(self):
        catalog = sprite_assets.load_catalog(sprite_assets.ART)
        groups = sorted({asset["group"] for asset in catalog["assets"]})
        self.assertTrue(groups)
        for group in groups:
            with self.subTest(group=group):
                manifest = json.loads((sprite_assets.ART / group / "manifest.json").read_text())
                names = {a["name"] for a in catalog["assets"] if a["group"] == group}
                self.assertEqual(set(manifest["assets"]), names)
                for name, entry in manifest["assets"].items():
                    for path in entry["frames"]:
                        with Image.open(sprite_assets.ART / group / path) as frame:
                            self.assertEqual(list(frame.size), entry["cell"])
                            self.assertTrue(set(frame.getchannel("A").tobytes()) <= {0, 255})
                self.assertLessEqual(len(sprite_assets.group_colors(group, sprite_assets.ART)), 96)


if __name__ == "__main__":
    unittest.main()
