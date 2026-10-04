"""Audio provenance checks use isolated fixtures inside the repository."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import wave
import zipfile

from tools import audio_assets

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/audio_assets.py"


class AudioAssetsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix=".test-", dir=ROOT / "audio")
        self.addCleanup(self.directory.cleanup)
        self.audio = Path(self.directory.name)
        (self.audio / "music").mkdir()
        (self.audio / "sfx").mkdir()
        (self.audio / "music/title.ogg").write_bytes(b"fixture audio")
        self.entry = {
            "file": "music/title.ogg",
            "url": "https://example.org/audio.zip",
            "page": "https://example.org/audio",
            "author": "Fixture Composer",
            "license": "CC0-1.0",
            "archive_member": "title.ogg",
            "sha256": hashlib.sha256(b"fixture audio").hexdigest(),
            "notes": "copy",
        }
        self.write_sources([self.entry])
        (self.audio / "LICENSES.md").write_text(
            "| File | Author | License | Source page |\n"
            "| --- | --- | --- | --- |\n"
            "| music/title.ogg | Fixture Composer | CC0-1.0 | https://example.org/audio |\n"
        )

    def write_sources(self, entries):
        (self.audio / "sources.json").write_text(json.dumps(entries))

    def run_tool(self, command):
        return subprocess.run(
            [sys.executable, "-B", str(TOOL), command, "--audio-root", str(self.audio)],
            capture_output=True, text=True, check=False,
        )

    def test_missing_sources_entry_fails(self):
        self.write_sources([])
        result = self.run_tool("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("music/title.ogg: missing sources entry", result.stderr)

    def test_bad_hash_fails(self):
        self.entry["sha256"] = "0" * 64
        self.write_sources([self.entry])
        result = self.run_tool("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("music/title.ogg: sha256 mismatch", result.stderr)

    def test_non_cc0_license_fails(self):
        self.entry["license"] = "CC-BY-4.0"
        self.write_sources([self.entry])
        result = self.run_tool("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("music/title.ogg: license must be CC0-1.0", result.stderr)

    def test_missing_license_row_fails(self):
        (self.audio / "LICENSES.md").write_text(
            "# Licenses\nMentioning music/title.ogg in prose is not a table row.\n"
        )
        result = self.run_tool("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("music/title.ogg: missing LICENSES.md row", result.stderr)

    def test_duplicate_entry_fails(self):
        self.write_sources([self.entry, self.entry])
        result = self.run_tool("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("music/title.ogg: duplicate sources entry", result.stderr)

    def test_missing_audio_file_fails_cleanly(self):
        (self.audio / "music/title.ogg").unlink()
        result = self.run_tool("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("music/title.ogg: file does not exist", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_malformed_manifest_fails_cleanly(self):
        for data in ("{", "{}", "[{}]"):
            with self.subTest(data=data):
                (self.audio / "sources.json").write_text(data)
                result = self.run_tool("check")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("sources.json:", result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_manifest_cannot_escape_audio_tree(self):
        self.entry["file"] = "../outside.wav"
        self.write_sources([self.entry])
        result = self.run_tool("check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid audio path", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_invalid_archive_member_fails_cleanly_before_fetch(self):
        archive = self.audio / "download.zip"
        with zipfile.ZipFile(archive, "w") as zipped:
            zipped.writestr("title.ogg", b"fixture audio")
        self.entry["url"] = archive.as_uri()
        for member in ([], {}, 7, True, ""):
            self.entry["archive_member"] = member
            self.write_sources([self.entry])
            for command in ("check", "fetch", "licenses"):
                with self.subTest(member=member, command=command):
                    result = self.run_tool(command)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("archive_member", result.stderr)
                    self.assertNotIn("Traceback", result.stderr)

    def test_licenses_regenerates_a_complete_table(self):
        (self.audio / "LICENSES.md").unlink()
        result = self.run_tool("licenses")
        self.assertEqual(result.returncode, 0, result.stderr)
        text = (self.audio / "LICENSES.md").read_text()
        self.assertIn("| File | Author | License | Source page |", text)
        self.assertIn(
            "| music/title.ogg | Fixture Composer | CC0-1.0 | https://example.org/audio |",
            text,
        )
        prose = "\n".join(line for line in text.splitlines() if not line.startswith("|"))
        self.assertNotIn("\u2014", prose)
        self.assertNotRegex(prose, r"\w-\w")
        self.assertEqual(self.run_tool("check").returncode, 0)

    def test_fetch_restores_a_direct_file_and_licenses(self):
        source = self.audio / "download.ogg"
        source.write_bytes(b"fixture audio")
        self.entry.update(url=source.as_uri(), archive_member=None)
        self.write_sources([self.entry])
        (self.audio / "music/title.ogg").unlink()
        (self.audio / "LICENSES.md").unlink()
        result = self.run_tool("fetch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.audio / "music/title.ogg").read_bytes(), b"fixture audio")
        self.assertEqual(self.run_tool("check").returncode, 0)

    def test_fetch_extracts_only_the_recorded_member(self):
        archive = self.audio / "download.zip"
        with zipfile.ZipFile(archive, "w") as zipped:
            zipped.writestr("nested/title.ogg", b"fixture audio")
            zipped.writestr("../unwanted.ogg", b"unrelated")
        self.entry.update(url=archive.as_uri(), archive_member="nested/title.ogg")
        self.write_sources([self.entry])
        (self.audio / "music/title.ogg").unlink()
        result = self.run_tool("fetch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.audio / "music/title.ogg").read_bytes(), b"fixture audio")
        self.assertFalse((self.audio / "unwanted.ogg").exists())
        self.assertEqual(self.run_tool("check").returncode, 0)

    def test_fetch_hash_failure_preserves_existing_file_and_continues(self):
        source = self.audio / "download.wav"
        source.write_bytes(b"new sound")
        self.entry.update(url=source.as_uri(), archive_member=None)
        good = dict(self.entry, file="sfx/new.wav",
                    sha256=hashlib.sha256(b"new sound").hexdigest())
        self.write_sources([self.entry, good])
        result = self.run_tool("fetch")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("music/title.ogg: sha256 mismatch", result.stderr)
        self.assertEqual((self.audio / "music/title.ogg").read_bytes(), b"fixture audio")
        self.assertEqual((self.audio / "sfx/new.wav").read_bytes(), b"new sound")

    def test_fetch_runs_the_recorded_ffmpeg_conversion(self):
        source = self.audio / "source.wav"
        with wave.open(str(source), "wb") as stream:
            stream.setparams((1, 2, 44100, 0, "NONE", "not compressed"))
            stream.writeframes(b"\x10\x00" * 4410)
        expected = self.audio / "reference.ogg"
        options = [
            "-map_metadata", "-1", "-c:a", "vorbis", "-strict", "experimental", "-ac", "2",
            "-q:a", "3", "-fflags", "+bitexact", "-flags:a", "+bitexact",
        ]
        subprocess.run(
            ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
             "-i", str(source), *options, str(expected)], check=True,
        )
        self.entry.update(
            url=source.as_uri(), archive_member=None,
            notes="ffmpeg: " + json.dumps(options),
            sha256=hashlib.sha256(expected.read_bytes()).hexdigest(),
        )
        self.write_sources([self.entry])
        result = self.run_tool("fetch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.audio / "music/title.ogg").read_bytes(), expected.read_bytes())

    def test_fetch_attempts_each_failed_shared_download_only_once(self):
        self.write_sources([
            self.entry,
            dict(self.entry, file="sfx/shared.wav"),
            dict(self.entry, file="sfx/other.wav", url="https://example.org/other.zip"),
        ])
        for error in (
            subprocess.CalledProcessError(22, ["curl"], stderr="archive unavailable"),
            FileNotFoundError("curl is unavailable"),
        ):
            with self.subTest(error=type(error).__name__):
                with patch.object(audio_assets.subprocess, "run", side_effect=error) as download:
                    errors = audio_assets.fetch(self.audio)
                self.assertEqual(download.call_count, 2, "each distinct URL is attempted once")
                self.assertEqual(len(errors), 3, "every affected asset reports its failure")
                self.assertEqual((self.audio / "music/title.ogg").read_bytes(), b"fixture audio")

    def test_fetch_continues_after_encrypted_or_unsupported_zip_members(self):
        source = self.audio / "good.wav"
        source.write_bytes(b"restored sound")
        good = dict(
            self.entry, file="sfx/restored.wav", url=source.as_uri(), archive_member=None,
            sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        )
        for kind, local_offset, central_offset, value in (
            ("encrypted", 6, 8, 1),
            ("unsupported compression", 8, 10, 99),
        ):
            with self.subTest(kind=kind):
                archive = self.audio / "invalid.zip"
                with zipfile.ZipFile(archive, "w") as zipped:
                    zipped.writestr("title.ogg", b"fixture audio")
                payload = bytearray(archive.read_bytes())
                central = payload.index(b"PK\x01\x02")
                payload[local_offset:local_offset + 2] = value.to_bytes(2, "little")
                payload[central + central_offset:central + central_offset + 2] = value.to_bytes(2, "little")
                archive.write_bytes(payload)
                self.entry["url"] = archive.as_uri()
                self.write_sources([self.entry, good])
                restored = self.audio / "sfx/restored.wav"
                restored.unlink(missing_ok=True)
                result = self.run_tool("fetch")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("music/title.ogg:", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                self.assertEqual(restored.read_bytes(), b"restored sound")
                self.assertEqual((self.audio / "music/title.ogg").read_bytes(), b"fixture audio")

    def test_real_repo_passes_check(self):
        result = subprocess.run(
            [sys.executable, "-B", str(TOOL), "check"],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_real_repo_ships_all_music_and_effects_within_budget(self):
        music = ("title", "results", "level1", "level2", "level3", "level4", "level5")
        effects = (
            "jump", "land", "hit", "heal", "repair_tick", "repair_done", "checkpoint",
            "door_open", "timer_warning", "fail", "win", "pickup", "deliver", "diagnose",
            "switch", "spark", "menu_move", "menu_select",
        )
        for track in music:
            with self.subTest(track=track):
                path = ROOT / "audio/music" / f"{track}.ogg"
                self.assertTrue(path.is_file(), str(path))
                self.assertLess(path.stat().st_size, 3_000_000)
                self.assertGreater(path.stat().st_size, 1000)
        for effect in effects:
            with self.subTest(effect=effect):
                self.assertTrue(any(
                    (ROOT / "audio/sfx" / f"{effect}.{extension}").is_file()
                    for extension in ("wav", "ogg")
                ), effect)


if __name__ == "__main__":
    unittest.main()
