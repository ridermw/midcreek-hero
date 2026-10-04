"""Run the Pages workflow smoke assertion against sample route results."""

import os
import pathlib
import subprocess
import tempfile
import unittest

WORKFLOW = pathlib.Path(__file__).resolve().parents[1] / ".github" / "workflows" / "pages.yml"


def smoke_assertion() -> str:
    lines = [
        line.strip() for line in WORKFLOW.read_text().splitlines()
        if "^SMOKE_RESULT" in line or "tools/check_route_result.py" in line
    ]
    if len(lines) != 1:
        raise AssertionError(f"Expected one smoke result assertion, found {len(lines)}.")
    return lines[0]


class PagesSmokeAssertionTest(unittest.TestCase):
    def accepts(self, result_line: str) -> bool:
        with tempfile.TemporaryDirectory() as temp:
            pathlib.Path(temp, "smoke-03.log").write_text(f"Godot Engine\n{result_line}\n")
            env = dict(os.environ, RUNNER_TEMP=temp, n="03")
            return subprocess.run(
                ["bash", "-c", smoke_assertion()], env=env, cwd=WORKFLOW.parents[2],
                capture_output=True,
            ).returncode == 0

    def test_clean_completion_accepts_all_three_ratings(self):
        for stars in (1, 2, 3):
            with self.subTest(stars=stars):
                self.assertTrue(self.accepts(f"SMOKE_RESULT 03 stars={stars} respawns=0 elapsed=99.00 hits=0 sla=200.00"))

    def test_respawns_or_another_level_fail(self):
        self.assertFalse(self.accepts("SMOKE_RESULT 03 stars=3 respawns=1 elapsed=41.20 hits=0 sla=200.00"))
        self.assertFalse(self.accepts("SMOKE_RESULT 02 stars=3 respawns=0 elapsed=41.20 hits=0 sla=200.00"))

    def test_damage_fails_even_with_three_stars(self):
        self.assertFalse(self.accepts("SMOKE_RESULT 03 stars=3 respawns=0 elapsed=41.20 hits=1 sla=200.00"))

    def test_route_budget_is_independent_of_sla(self):
        self.assertTrue(self.accepts("SMOKE_RESULT 03 stars=1 respawns=0 elapsed=110.00 hits=0 sla=200.00"))
        self.assertFalse(self.accepts("SMOKE_RESULT 03 stars=3 respawns=0 elapsed=110.01 hits=0 sla=999.00"))

    def test_sla_still_limits_a_route_within_its_budget(self):
        self.assertTrue(self.accepts("SMOKE_RESULT 03 stars=2 respawns=0 elapsed=99.99 hits=0 sla=100.00"))
        self.assertFalse(self.accepts("SMOKE_RESULT 03 stars=3 respawns=0 elapsed=100.00 hits=0 sla=100.00"))

    def test_incomplete_duplicate_and_invalid_results_fail(self):
        valid = "SMOKE_RESULT 03 stars=3 respawns=0 elapsed=41.20 hits=0 sla=200.00"
        for value in [
            "", valid + "\n" + valid, valid.replace(" hits=0", ""),
            valid.replace("41.20", "nan"), valid.replace("41.20", "-1"),
            valid.replace("200.00", "inf"), valid.replace("200.00", "0"),
            valid + "\nSCRIPT ERROR: Failed playback", valid + "\nERROR: Missing asset",
        ]:
            with self.subTest(value=value):
                self.assertFalse(self.accepts(value))


if __name__ == "__main__":
    unittest.main()
