"""Check, document, and restore the CC0 audio listed in audio/sources.json."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def load_sources(audio):
    try:
        entries = json.loads((audio / "sources.json").read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise ValueError(f"sources.json: {error}") from error
    fields = ("file", "url", "page", "author", "license", "sha256", "notes")
    if not isinstance(entries, list):
        raise ValueError("sources.json: expected an array")
    for entry in entries:
        if not isinstance(entry, dict) or any(
            not isinstance(entry.get(field), str) or not entry[field] for field in fields
        ) or "archive_member" not in entry:
            raise ValueError("sources.json: incomplete or invalid entry")
        member = entry["archive_member"]
        if member is not None and (not isinstance(member, str) or not member):
            raise ValueError("sources.json: archive_member must be null or a nonempty string")
        name = Path(entry["file"])
        if (
            name.is_absolute() or len(name.parts) < 2
            or name.parts[0] not in ("music", "sfx") or ".." in name.parts
            or not (audio / name).resolve().is_relative_to(audio.resolve())
        ):
            raise ValueError(f"sources.json: invalid audio path: {entry['file']}")
    return entries


def check(audio):
    entries = load_sources(audio)
    names = Counter(entry["file"] for entry in entries)
    errors = []
    license_file = audio / "LICENSES.md"
    license_text = license_file.read_text() if license_file.exists() else ""
    rows = {
        line.split("|")[1].strip().strip("`")
        for line in license_text.splitlines()
        if line.startswith("|") and len(line.split("|")) == 6
    }
    for entry in entries:
        if names[entry["file"]] != 1:
            errors.append(f"{entry['file']}: duplicate sources entry")
        if entry["file"] not in rows:
            errors.append(f"{entry['file']}: missing LICENSES.md row")
        if entry.get("license") != "CC0-1.0":
            errors.append(f"{entry['file']}: license must be CC0-1.0")
        path = audio / entry["file"]
        if not path.is_file():
            errors.append(f"{entry['file']}: file does not exist")
        elif hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            errors.append(f"{entry['file']}: sha256 mismatch")
    for group in ("music", "sfx"):
        for path in (audio / group).rglob("*"):
            if path.is_file() and path.suffix != ".import":
                name = path.relative_to(audio).as_posix()
                if name not in names:
                    errors.append(f"{name}: missing sources entry")
    return errors


def licenses(audio):
    entries = load_sources(audio)
    lines = [
        "# Audio licenses", "",
        "All audio is released under CC0. Source pages were checked before use.",
        "See sources.json for archive members, conversion commands, and file hashes.",
        "",
        "| File | Author | License | Source page |",
        "| --- | --- | --- | --- |",
    ]
    for entry in sorted(entries, key=lambda item: item["file"]):
        cells = [entry[key] for key in ("file", "author", "license", "page")]
        lines.append("| " + " | ".join(cells) + " |")
    (audio / "LICENSES.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def fetch(audio):
    """Best effort restoration. Only replace files after their final hash matches."""
    entries = load_sources(audio)
    errors = []
    downloads = {}
    download_failures = {}
    with tempfile.TemporaryDirectory(prefix=".fetch-", dir=audio) as directory:
        scratch = Path(directory)
        for entry in entries:
            name = entry["file"]
            try:
                if entry["license"] != "CC0-1.0":
                    raise ValueError("license must be CC0-1.0")
                url = entry["url"]
                if url in download_failures:
                    raise download_failures[url]
                if url not in downloads:
                    archive = scratch / f"download-{len(downloads)}"
                    try:
                        subprocess.run([
                            "curl", "--fail", "--location", "--silent", "--show-error",
                            "--retry", "2", "--connect-timeout", "20", "--max-time", "180",
                            "--output", str(archive), url,
                        ], check=True, capture_output=True, text=True)
                    except (OSError, subprocess.CalledProcessError) as error:
                        download_failures[url] = error
                        raise
                    downloads[url] = archive
                source = downloads[url]
                if entry["archive_member"] is not None:
                    with zipfile.ZipFile(source) as archive:
                        payload = archive.read(entry["archive_member"])
                    source = scratch / "source"
                    source.write_bytes(payload)
                candidate = scratch / ("converted" + Path(name).suffix)
                notes = entry["notes"]
                if notes == "copy":
                    shutil.copyfile(source, candidate)
                elif notes.startswith("ffmpeg: "):
                    options = json.loads(notes.removeprefix("ffmpeg: "))
                    if not isinstance(options, list) or not all(
                        isinstance(option, str) for option in options
                    ):
                        raise ValueError("ffmpeg notes must contain an array of arguments")
                    subprocess.run([
                        "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
                        "-i", str(source), *options, str(candidate),
                    ], check=True, capture_output=True, text=True)
                else:
                    raise ValueError("notes must be copy or ffmpeg: followed by a JSON array")
                if hashlib.sha256(candidate.read_bytes()).hexdigest() != entry["sha256"]:
                    raise ValueError("sha256 mismatch; existing file left unchanged")
                target = audio / name
                target.parent.mkdir(parents=True, exist_ok=True)
                candidate.replace(target)
            except (OSError, ValueError, KeyError, zipfile.BadZipFile,
                    subprocess.CalledProcessError) as error:
                detail = error.stderr.strip() if isinstance(
                    error, subprocess.CalledProcessError
                ) else str(error)
                errors.append(f"{name}: {detail}")
    licenses(audio)
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "licenses", "fetch"))
    parser.add_argument("--audio-root", type=Path, default=ROOT / "audio")
    args = parser.parse_args()
    try:
        if args.command == "licenses":
            licenses(args.audio_root)
            return 0
        errors = fetch(args.audio_root) if args.command == "fetch" else check(args.audio_root)
    except (OSError, ValueError) as error:
        errors = [str(error)]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Audio {args.command} passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
