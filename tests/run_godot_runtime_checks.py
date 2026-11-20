#!/usr/bin/env python3
"""Run the graphical-runtime assertions in Godot's headless runner."""

import argparse
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "game" / "project.godot"
MAIN_SCENE = b'run/main_scene="res://main.tscn"'
TEST_SCENE = b'run/main_scene="res://tests/phase2_runtime_checks.tscn"'


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot", help="Godot 4 executable")
    args = parser.parse_args()
    original = PROJECT.read_bytes()
    if original.count(MAIN_SCENE) != 1:
        raise RuntimeError("could not locate the project's unique main scene setting")
    try:
        PROJECT.write_bytes(original.replace(MAIN_SCENE, TEST_SCENE))
        result = subprocess.run(
            [args.godot, "--headless", "--path", str(ROOT / "game"), "--quit-after", "300", "--verbose"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
    finally:
        PROJECT.write_bytes(original)
    print(result.stdout, end="")
    print(result.stderr, end="")
    success_marker = "Phase 2 graphical runtime checks passed"
    errors = ("SCRIPT ERROR:", "ERROR: FAIL:", "Failed to load script")
    return 0 if result.returncode == 0 and success_marker in result.stdout and not any(x in result.stdout for x in errors) else 1


if __name__ == "__main__":
    raise SystemExit(main())
