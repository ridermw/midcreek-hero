import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ExportBudgetTest(unittest.TestCase):
    def run_check(self, files, maximum=10, required=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            export = root / "web"
            export.mkdir()
            for name, size in files.items():
                path = export / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"x" * size)
            budget = root / "budget.json"
            budget.write_text(json.dumps({
                "maximum_bytes": maximum,
                "required_files": ["index.html", "index.pck"] if required is None else required,
            }))
            return subprocess.run(
                [sys.executable, str(ROOT / "tools/check_export_budget.py"),
                 str(export), "--budget", str(budget)],
                capture_output=True, text=True,
            )

    def test_exact_boundary_passes_and_one_extra_byte_fails(self):
        result = self.run_check({"index.html": 2, "index.pck": 8})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("total_bytes=10", result.stdout)
        result = self.run_check({"index.html": 2, "index.pck": 9})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("11", result.stderr)

    def test_every_published_file_counts_including_nested_files(self):
        result = self.run_check({"index.html": 2, "index.pck": 7, "extra/texture.bin": 2})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("11", result.stderr)

    def test_undeclared_published_file_fails_even_below_the_budget(self):
        result = self.run_check({"index.html": 2, "index.pck": 2, "source.metadata.json": 1})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source.metadata.json", result.stderr)

    def test_pages_marker_is_allowed_without_becoming_a_runtime_requirement(self):
        result = self.run_check({"index.html": 2, "index.pck": 2, ".nojekyll": 0})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_shipped_budget_matches_the_recorded_measurement(self):
        budget = json.loads((ROOT / "tests/export_budget.json").read_text())
        baseline = budget["baseline"]
        self.assertEqual(sum(baseline["files"].values()), baseline["total_bytes"])
        self.assertEqual(set(budget["required_files"]), set(baseline["files"]))
        self.assertEqual(budget["maximum_bytes"], ((baseline["total_bytes"] + 1048575) // 1048576) * 1048576)

    def test_missing_or_empty_runtime_file_fails(self):
        for files in ({"index.html": 2}, {"index.html": 2, "index.pck": 0}):
            with self.subTest(files=files):
                result = self.run_check(files)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("index.pck", result.stderr)

    def test_empty_budget_or_invalid_limit_fails(self):
        for maximum in (0, -1, True, "10", 10.5):
            with self.subTest(maximum=maximum):
                result = self.run_check({"index.html": 2, "index.pck": 1}, maximum=maximum)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("maximum_bytes", result.stderr)
        result = self.run_check({"index.html": 2, "index.pck": 1}, required=[])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("required_files", result.stderr)

    def test_unreadable_subdirectory_cannot_hide_published_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            export = root / "web"
            hidden = export / "assets"
            hidden.mkdir(parents=True)
            (export / "index.html").write_bytes(b"x")
            (hidden / "large.bin").write_bytes(b"xx")
            budget = root / "budget.json"
            budget.write_text(json.dumps({"maximum_bytes": 1, "required_files": ["index.html"]}))
            hidden.chmod(0)
            try:
                try:
                    list(hidden.iterdir())
                except PermissionError:
                    pass
                else:
                    self.skipTest("This account bypasses directory permissions.")
                result = subprocess.run(
                    [sys.executable, str(ROOT / "tools/check_export_budget.py"),
                     str(export), "--budget", str(budget)], capture_output=True, text=True,
                )
                self.assertNotEqual(result.returncode, 0, "Unreadable export data must not count as zero bytes.")
                self.assertIn("Cannot measure export", result.stderr)
            finally:
                hidden.chmod(0o700)


if __name__ == "__main__":
    unittest.main()
