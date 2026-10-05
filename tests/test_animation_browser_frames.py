from pathlib import Path
import unittest

from PIL import Image

from animation_browser_frames import locate_and_verify

ROOT = Path(__file__).resolve().parents[1]


class BrowserFrameTest(unittest.TestCase):
    def setUp(self):
        with Image.open(ROOT / "art/cel-shift/animations/frames/man-midcreek/walk/00.png") as source:
            self.texture = source.convert("RGBA")
        self.capture = Image.new("RGB", (640, 260), (5, 8, 13))
        self.capture.paste(self.texture, (100, 32), self.texture)

    def test_locates_and_checks_an_exact_rendered_frame(self):
        self.assertEqual(locate_and_verify(self.capture, self.texture, "fixture"), (100, 32))

    def test_checks_pixels_not_used_by_the_coarse_locator(self):
        opaque = [(x, y) for y in range(self.texture.height) for x in range(self.texture.width)
                  if self.texture.getpixel((x, y))[3] == 255]
        self.assertGreater(len(opaque) // 50, 1)
        x, y = opaque[1]
        color = self.capture.getpixel((x + 100, y + 32))
        self.capture.putpixel((x + 100, y + 32), tuple(255 - value for value in color))
        with self.assertRaisesRegex(AssertionError, "opaque pixel mismatch"):
            locate_and_verify(self.capture, self.texture, "changed fixture")


if __name__ == "__main__":
    unittest.main()
