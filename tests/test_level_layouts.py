"""Check that the level layout scripts reproduce the shipped levels and routes."""

import importlib
import unittest

from tools.levels import layout

LEVELS = {
    "level1": "01-cold-aisle",
    "level2": "02-hot-aisle",
    "level3": "03-cable-jungle",
    "level4": "04-power-room",
    "level5": "05-outage-night",
}


class LevelLayoutTest(unittest.TestCase):
    def test_par_and_sla_follow_the_plan_rule(self):
        self.assertEqual(layout.par_and_sla(42.3), (55, 90))
        self.assertEqual(layout.par_and_sla(35.88), (45, 75))
        self.assertEqual(layout.par_and_sla(55.98, 1.35), (70, 95))

    def test_scripts_reproduce_shipped_levels(self):
        for module_name, slug in LEVELS.items():
            with self.subTest(level=slug):
                module = importlib.import_module(f"tools.levels.{module_name}")
                grid, header = module.build()
                level, route = grid.render(header)
                self.assertEqual(level, (layout.ROOT / "levels" / f"{slug}.level").read_text())
                self.assertEqual(route, (layout.ROOT / "levels" / "routes" / f"{slug}.route.json").read_text())


if __name__ == "__main__":
    unittest.main()
