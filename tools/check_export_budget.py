"""Validate published web files and report size before HTTP compression."""

import argparse
import json
import os
import stat
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--budget", type=Path, default=ROOT / "tests/export_budget.json")
    args = parser.parse_args()
    try:
        budget = json.loads(args.budget.read_text())
    except (OSError, ValueError) as error:
        parser.error(f"Cannot read export budget {args.budget}: {error}")
    if not isinstance(budget, dict):
        parser.error("Export budget must be an object")
    required = budget.get("required_files")
    if not isinstance(required, list) or not required or any(
        not isinstance(name, str) or not name or "\\" in name
        or PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts
        for name in required
    ):
        parser.error("required_files must contain relative file paths inside the export")
    if not args.directory.is_dir() or args.directory.is_symlink():
        parser.error(f"Export directory does not exist or is a symlink: {args.directory}")
    files = {}
    def scan_error(error):
        raise error

    try:
        for parent, directories, names in os.walk(args.directory, onerror=scan_error):
            for name in sorted(directories + names):
                path = Path(parent) / name
                info = path.lstat()
                if stat.S_ISLNK(info.st_mode):
                    parser.error(f"Export must not contain symlinks: {path}")
                if stat.S_ISREG(info.st_mode):
                    files[path.relative_to(args.directory).as_posix()] = info.st_size
                elif not stat.S_ISDIR(info.st_mode):
                    parser.error(f"Export contains a nonregular file: {path}")
    except OSError as error:
        parser.error(f"Cannot measure export: {error}")
    for name in required:
        if files.get(name, 0) <= 0:
            parser.error(f"Missing or empty required runtime file: {name}")
    total = sum(files.values())
    for name, size in sorted(files.items(), key=lambda item: (-item[1], item[0])):
        print(f"{size:>10} {name}")
    unexpected = sorted(set(files) - set(required) - {".nojekyll"})
    if unexpected:
        parser.error("Undeclared published files: " + ", ".join(unexpected))
    print(f"EXPORT_FILES_PASS total_bytes={total}")


if __name__ == "__main__":
    main()
