import unittest
import json

from tools.levels.expansion import BUILDERS, cooling_gallery
from tools.levels.layout import ROOT


class ExpansionLayoutTest(unittest.TestCase):
    def test_fire_pump_and_rooftop_levels_have_approved_work(self):
        expected = {
            "10-fire-response-hall": ["extinguish_fire", "extinguish_fire", "restore_cooling"],
            "11-pump-station": ["contain_leak", "contain_leak", "restore_cooling"],
            "12-rooftop-air-handlers": ["restore_cooling", "run_cable", "restore_power"],
        }
        for slug, kinds in expected.items():
            with self.subTest(level=slug):
                path = ROOT / "levels" / (slug + ".level")
                self.assertTrue(path.is_file())
                header = json.loads(path.read_text().split("\n---\n")[0])
                self.assertCountEqual([task["type"] for task in header["tasks"]], kinds)
                self.assertTrue((ROOT / "levels/routes" / (slug + ".route.json")).is_file())

    def test_all_authored_expansion_levels_and_routes_reproduce(self):
        for slug, build in BUILDERS.items():
            with self.subTest(level=slug):
                layout, header = build()
                level, route = layout.render(header)
                self.assertEqual(level, (ROOT / "levels" / (slug + ".level")).read_text())
                self.assertEqual(route, (ROOT / "levels/routes" / (slug + ".route.json")).read_text())

    def test_next_three_levels_have_the_approved_work_mapping(self):
        expected = {
            "07-operations-suite": ["assemble_rack", "run_cable", "restore_power"],
            "08-fiber-exchange": ["run_cable", "run_cable", "assemble_rack"],
            "09-loading-yard": ["assemble_rack", "contain_leak", "restore_power"],
        }
        for slug, kinds in expected.items():
            with self.subTest(level=slug):
                path = ROOT / "levels" / (slug + ".level")
                self.assertTrue(path.is_file(), "The authored level must exist.")
                header = json.loads(path.read_text().split("\n---\n")[0])
                self.assertCountEqual([task["type"] for task in header["tasks"]], kinds)
                self.assertTrue((ROOT / "levels/routes" / (slug + ".route.json")).is_file())
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
