#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

CI = Path(__file__).resolve().parent
ROOT = CI.parent
OUTPUT = CI / "output"

sys.path.insert(0, str(CI))

import prepare


def tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        sys.exit(f"test: `{name}` is not on PATH")
    return path


def install(force: bool) -> None:
    if force or not all(path.is_dir() for path in prepare.REQUIRED.values()):
        subprocess.run([tool("crater"), "install", "-y"], cwd=ROOT, check=True, stdin=subprocess.DEVNULL)


FLAKY_STUDIO = (
    "Studio run timed out",
    "no run-mode plugin took the run over",
    "ended the test session early",
    "did not start the run",
)


def run_jest(command: list[str], retries: int) -> int:
    for attempt in range(1, retries + 2):
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                   encoding="utf-8", errors="replace")
        output: list[str] = []
        assert process.stdout is not None
        for line in process.stdout:
            sys.stdout.write(line)
            output.append(line)
        code = process.wait()

        text = "".join(output)
        if code == 0 or not any(marker in text for marker in FLAKY_STUDIO) or attempt > retries:
            return code
        print(f"test: Studio did not run the suite, retrying ({attempt}/{retries})", flush=True)
    return 1


def main() -> int:
    in_ci = os.environ.get("CI") == "true"

    parser = argparse.ArgumentParser(description="Build the test place and run the Jest suite for src/core.d.luau")
    parser.add_argument("pattern", nargs="?", help="run only spec files whose path matches this regex, e.g. types/value")
    parser.add_argument("--backend", default="open-cloud" if in_ci else "studio-cli",
                        choices=["auto", "open-cloud", "studio", "studio-cli"])
    parser.add_argument("--install", action="store_true", help="run crater install even if packages exist")
    parser.add_argument("--prepare-only", action="store_true", help="only build CI/build, do not run tests")
    parser.add_argument("--retries", type=int, default=2, help="reruns when studio-cli fails to start the suite")
    args, extra = parser.parse_known_args()

    try:
        install(args.install)
    except subprocess.CalledProcessError as error:
        return error.returncode

    prepare.main()
    if args.prepare_only:
        return 0

    OUTPUT.mkdir(exist_ok=True)
    name = re.sub(r"\W", "_", args.pattern) if args.pattern else "all"

    command = [
        tool("jest-roblox-cli"),
        "--backend", args.backend,
        "--outputFile", str(OUTPUT / f"CI_{name}.json"),
        "--gameOutput", str(OUTPUT / f"game_{name}.log"),
        "--formatters", "github-actions" if in_ci else "default",
    ]
    if not in_ci:
        command.append("--verbose")
    if args.pattern:
        command += ["--testPathPattern", args.pattern]
    command += [a for a in extra if a != "--"]

    retries = args.retries if args.backend == "studio-cli" else 0
    return run_jest(command, retries)


if __name__ == "__main__":
    sys.exit(main())
