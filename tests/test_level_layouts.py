"""Check that the level layout scripts reproduce the shipped levels and routes."""

import importlib
import json
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
    def test_cable_piles_wait_for_a_clear_jump_over_their_authored_x(self):
        for kind in ("snag", "mover"):
            with self.subTest(kind=kind):
                level = layout.Layout(20)
                getattr(level, kind)(10)
                self.assertEqual(level.grid[level.stand][10], "s" if kind == "snag" else "m")
                self.assertEqual(level.route[0], {"hold": ["move_right"], "until_hazard": 336, "gap": 62, "max_seconds": 12})
                self.assertEqual(level.route[1], {"hold": ["move_right", "jump"], "seconds": 0.45})

    def test_authored_guidance_carries_one_explicit_action(self):
        actions = {"move_left", "move_right", "move_up", "move_down", "jump", "slide", "repair", "diagnose", "pause"}
        for name in LEVELS:
            for prompt in importlib.import_module(f"tools.levels.{name}").build()[1]["prompts"]:
                with self.subTest(level=name, column=prompt["x"]):
                    self.assertIn("action", prompt)
                    self.assertIn("status", prompt)
                    if prompt["action"]:
                        self.assertIn(prompt["action"], actions)
                        self.assertIn(prompt["intent"], ["press", "hold"])
                        self.assertTrue(prompt["text"])
                        if prompt["action"] in {"repair", "diagnose"}:
                            self.assertIn(prompt.get("task"), {task["id"] for task in importlib.import_module(f"tools.levels.{name}").build()[1]["tasks"]})
                    else:
                        self.assertEqual(prompt["intent"], "")
                        self.assertTrue(prompt["status"])
                    self.assertNotRegex(prompt["text"] + prompt["status"], r"Pad:|E or X|E / X|Q / Y|C or Shift|hold E|Press Q")

    def test_current_authored_targets_are_preserved(self):
        for name, targets in zip(LEVELS, [(120, 195), (120, 195), (125, 200), (125, 200), (125, 170)]):
            header = importlib.import_module(f"tools.levels.{name}").build()[1]
            with self.subTest(level=name):
                self.assertEqual((header["par_seconds"], header["sla_seconds"]), targets)

    def test_each_recorded_route_has_a_positive_independent_budget(self):
        budgets = json.loads((layout.ROOT / "tests/route_budgets.json").read_text())
        self.assertEqual(set(budgets), {path.name[:2] for path in (layout.ROOT / "levels/routes").glob("*.route.json")})
        for level, seconds in budgets.items():
            with self.subTest(level=level):
                self.assertIs(type(seconds), int)
                self.assertGreater(seconds, 0)

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
