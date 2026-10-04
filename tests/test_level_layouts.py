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
