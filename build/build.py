#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from crater_layout import load as load_layout
from darklua_safe import compact_tree, mask_tree, restore_tree

SKIPPED = (".gpp", ".d.luau", ".project.json", ".darklua.json", ".md")
DARKLUA_CONFIG = "build_info.darklua.json"
LUAURC = "config.luaurc"

GPP_ARGS = [
    "-U", "", "", "(", ",", ")", "(", ")", "#", "",
    "-M", "--#", "\\n", " ", " ", "\\n", "(", ")",
    "+cQQQ", "--[[#", "]]",
]

INDENTED_DIRECTIVE = re.compile(r"(?m)^[ \t]+--#")
INLINE_DIRECTIVE = re.compile(r"--\[\[#((?:if|ifdef|ifndef|elif) [^\]]*|else|endif)\]\]")


def fail(message: str) -> None:
    sys.exit(f"build: {message}")


def find_tool(name: str) -> str:
    candidates = [name]

    if platform.system() == "Windows":
        candidates = [f"{name}.exe", f"{name}.cmd", name]

    for candidate in candidates:
        path = shutil.which(candidate)
        if path:
            return path

    fail(f"`{name}` is not installed or not on PATH")
    return ""


def find_root(start: Path) -> Path:
    for directory in (start, *start.parents):
        if (directory / "src" / "project.gpp").is_file():
            return directory

    fail(f"cannot find src with project.gpp from {start}")
    return start


def run(command: list[str], **kwargs) -> subprocess.CompletedProcess:
    result = subprocess.run(command, capture_output=True, **kwargs)

    if result.returncode != 0:
        output = result.stderr or result.stdout
        text = output.decode("utf-8", "replace") if isinstance(output, bytes) else output
        fail(f"`{Path(command[0]).name}` failed:\n{text}")

    return result


def collect_defines() -> list[str]:
    commit = os.environ.get("CORE_COMMIT")

    if os.environ.get("CI") == "true" and commit:
        print(f"unique > {commit}")
        return [f'-DUNIQUE="{commit}"']

    print("unique > NON_PRODUCTION_BUILD (local build)")
    return []


def preprocess(gpp: str, source: Path, target: Path, defines: list[str], header: Path, vendor: str) -> None:
    for file in sorted(source.rglob("*")):
        if not file.is_file():
            continue

        relative = file.relative_to(source)
        name = file.name

        if relative.parts and relative.parts[0] == vendor:
            continue

        if not name.endswith(".luau") or name.endswith(SKIPPED):
            continue

        output = target / relative
        output.parent.mkdir(parents=True, exist_ok=True)

        text = file.read_text("utf-8")
        text = INDENTED_DIRECTIVE.sub("--#", text)
        text = INLINE_DIRECTIVE.sub(lambda match: f"\n--#{match.group(1)}\n", text)

        print(f"gpp > {relative.as_posix()}")
        result = run(
            [gpp, *defines, f"-I{source}", "--include", str(header), *GPP_ARGS],
            input=text.encode("utf-8"),
        )
        output.write_bytes(result.stdout.replace(b"\r\n", b"\n"))


def transform(darklua: str, source: Path, target: Path) -> None:
    luaurc = target / ".luaurc"
    shutil.copyfile(source / LUAURC, luaurc)

    masked = mask_tree(target)

    # darklua 0.19.0 drops Luau's `f <<T>>(x)` while regenerating the AST, so
    # the instantiations are temporarily masked as comments. `--format
    # retain_lines` is required because the default format strips comments.
    print("darklua > core")
    try:
        run([
            darklua,
            "process",
            str(target),
            str(target),
            "--config",
            str(source / DARKLUA_CONFIG),
            "--format",
            "retain_lines",
        ])
    finally:
        luaurc.unlink(missing_ok=True)

    try:
        restore_tree(masked)
    except ValueError as error:
        fail(str(error))

    if masked:
        print(f"check > preserved type instantiations in {len(masked)} files")


def copy_vendor(layout: dict, output: Path) -> None:
    source = layout["vendor_path"]

    if not source.is_dir():
        fail(f"missing {layout['vendor']}, run `crater install` first")

    print(f"copy > {layout['vendor_path']}")
    shutil.copytree(source, output / "core" / layout["vendor_name"])


def write_project(output: Path) -> Path:
    project = output / "build.project.json"
    tree = {
        "$className": "DataModel",
        "ReplicatedStorage": {
            "core": {"$path": "core"},
        },
    }

    project.write_text(json.dumps({"name": "funny-core", "tree": tree}, indent=2), "utf-8")
    return project


def main() -> None:
    parser = argparse.ArgumentParser(description="Build funny-core into build.rbxl")
    parser.add_argument("-o", "--output", type=Path, help="output directory, ../bin from the current directory by default")
    arguments = parser.parse_args()

    cwd = Path.cwd().resolve()
    root = find_root(cwd)
    source = root / "src"
    output = (arguments.output or cwd.parent / "bin").resolve()
    layout = load_layout(root)

    if output == root or output in source.parents or output == source or source in output.parents:
        fail(f"refusing to build into {output}")

    gpp = find_tool("gpp")
    darklua = find_tool("darklua")
    rojo = find_tool("rojo")

    print(f"platform > {platform.system()} {platform.machine()}")
    print(f"source > {source}")
    print(f"output > {output}")

    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)

    core = output / "core"
    core.mkdir()

    with tempfile.TemporaryDirectory() as temporary:
        header = Path(temporary) / "defines.gpp"
        header.write_text(
            (source / "project.gpp").read_text("utf-8") + "\n" + (source / "build.gpp").read_text("utf-8"),
            "utf-8",
        )
        preprocess(gpp, source, core, collect_defines(), header, layout["vendor_name"])

    # Vendor has to exist before darklua resolves `@import` / `@include`.
    # `build_info.darklua.json` skips `vendor/**`, so the files stay pristine.
    copy_vendor(layout, output)
    transform(darklua, source, core)
    print(f"compact > {compact_tree(core, layout['vendor_name'])} files")

    project = write_project(output)
    place = output / "build.rbxl"

    print("rojo > build.rbxl")
    run([rojo, "build", str(project), "--output", str(place)])

    print(f"builded > {place}")


if __name__ == "__main__":
    main()
