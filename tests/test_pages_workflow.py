"""Run the Pages workflow smoke assertion against sample route results."""

import os
import pathlib
import subprocess
import tempfile
import unittest

WORKFLOW = pathlib.Path(__file__).resolve().parents[1] / ".github" / "workflows" / "pages.yml"


def smoke_assertion() -> str:
    lines = [line.strip() for line in WORKFLOW.read_text().splitlines() if "^SMOKE_RESULT" in line]
    if len(lines) != 1:
        raise AssertionError(f"Expected one smoke result assertion, found {len(lines)}.")
    return lines[0]


class PagesSmokeAssertionTest(unittest.TestCase):
    def accepts(self, result_line: str) -> bool:
        with tempfile.TemporaryDirectory() as temp:
            pathlib.Path(temp, "smoke-03.log").write_text(f"Godot Engine\n{result_line}\n")
            env = dict(os.environ, RUNNER_TEMP=temp, n="03")
            return subprocess.run(["bash", "-c", smoke_assertion()], env=env).returncode == 0

    def test_three_stars_without_respawns_passes(self):
        self.assertTrue(self.accepts("SMOKE_RESULT 03 stars=3 respawns=0 elapsed=41.20"))

    def test_fewer_than_three_stars_fails(self):
        for stars in (0, 1, 2):
            with self.subTest(stars=stars):
                self.assertFalse(self.accepts(f"SMOKE_RESULT 03 stars={stars} respawns=0 elapsed=41.20"))

    def test_respawns_or_another_level_fail(self):
        self.assertFalse(self.accepts("SMOKE_RESULT 03 stars=3 respawns=1 elapsed=41.20"))
        self.assertFalse(self.accepts("SMOKE_RESULT 02 stars=3 respawns=0 elapsed=41.20"))


if __name__ == "__main__":
    unittest.main()
