import unittest

from tools.levels.expansion import cooling_gallery
from tools.levels.layout import ROOT


class ExpansionLayoutTest(unittest.TestCase):
    def test_cooling_gallery_reproduces_its_level_and_route(self):
        layout, header = cooling_gallery()
        level, route = layout.render(header)
        self.assertEqual(level, (ROOT / "levels/06-cooling-gallery.level").read_text())
        self.assertEqual(route, (ROOT / "levels/routes/06-cooling-gallery.route.json").read_text())
        self.assertEqual((header["par_seconds"], header["sla_seconds"]), (210, 420))
        self.assertEqual(
            {task["type"] for task in header["tasks"]},
            {"restore_cooling", "contain_leak", "run_cable"},
        )
        for task in header["tasks"]:
            for x, y in task.get("effect_cells", []):
                if task["type"] == "contain_leak":
                    self.assertEqual(layout.grid[y][x], "~")
                    self.assertEqual(layout.grid[y + 1][x], "#")


if __name__ == "__main__":
    unittest.main()
