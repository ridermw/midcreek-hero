"""Contracts for lift art drawing."""

import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class LiftArtTest(unittest.TestCase):
    def test_lift_deck_uses_integer_texture_segments(self):
        source = (ROOT / "game" / "entities" / "lift.gd").read_text()
        self.assertNotIn("draw_texture_rect(art.texture", source)
        self.assertIn("draw_texture(texture, Vector2(-SIZE.x / 2.0, 0))", source)
        self.assertIn("draw_texture_rect_region", source)
        self.assertIn("Rect2(16, 0, 32, SIZE.y)", source)
        self.assertIn("Rect2(0, 0, 32, SIZE.y)", source)


if __name__ == "__main__":
    unittest.main()