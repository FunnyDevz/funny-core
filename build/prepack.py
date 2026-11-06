#!/usr/bin/env python3
"""Build the publishable funny-core package that crater packs and publishes.

`crater.json` sets `package_root` to `build/package`, so this script produces
the exact tree that goes into the archive:

  src/**                gpp-preprocessed and darklua-processed modules
  src/core.d.luau       public type declarations
  src/vendor/**         temporary copy used only to resolve aliases

Vendored packages live in `src/vendor` during development, and crater 0.7.5
packs them at the same path, so the built code points at `vendor/import/...`
and `vendor/include/...` inside `src/`. The temporary copy below only lets
darklua resolve `@import` / `@include`; crater adds the locked packages from
`crater.lock` when packing.
"""

from __future__ import annotations

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
from darklua_safe import compact_tree, has_marker, mask_tree, restore_tree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCE = ROOT / "src"
LAYOUT = load_layout(ROOT)
OUTPUT = ROOT / "build" / "package"
TARGET_SRC = OUTPUT / "src"

SKIPPED = (".gpp", ".d.luau", ".project.json", ".darklua.json", ".md")
DARKLUA_CONFIG = SOURCE / "build_info.darklua.json"
REQUIRE_ALIAS = re.compile(r"""require\(\s*(["'])@([\w-]+)""")

GPP_ARGS = [
    "-U", "", "", "(", ",", ")", "(", ")", "#", "",
    "-M", "--#", "\\n", " ", " ", "\\n", "(", ")",
    "+cQQQ", "--[[#", "]]",
]

INDENTED_DIRECTIVE = re.compile(r"(?m)^[ \t]+--#")
INLINE_DIRECTIVE = re.compile(r"--\[\[#((?:if|ifdef|ifndef|elif) [^\]]*|else|endif)\]\]")


def fail(message: str) -> None:
    sys.exit(f"prepack: {message}")


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

        if relative.parts and relative.parts[0] in (vendor, "temp"):
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


def write_luaurc() -> Path:
    aliases = {
        "templates": "templates",
        "class": "class",
        "enums": "enums",
        "static": "static",
        "extension": "extension",
        "platform": "platform",
        "project": "static/project",
        "declare": "static/declare",
        **LAYOUT["aliases"],
    }

    path = TARGET_SRC / ".luaurc"
    path.write_text(json.dumps({"aliases": aliases}, indent=4) + "\n", "utf-8")
    return path


def transform(darklua: str, luaurc: Path) -> None:
    masked = mask_tree(TARGET_SRC)

    print("darklua > package")
    try:
        run([
            darklua,
            "process",
            str(TARGET_SRC),
            str(TARGET_SRC),
            "--config",
            str(DARKLUA_CONFIG),
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


def validate() -> None:
    left: list[str] = []

    for file in sorted(TARGET_SRC.rglob("*.luau")):
        text = file.read_text("utf-8")
        relative = file.relative_to(TARGET_SRC).as_posix()

        for match in REQUIRE_ALIAS.finditer(text):
            left.append(f"{relative}: @{match.group(2)}")

        if has_marker(text):
            left.append(f"{relative}: unrestored type instantiation marker")

    if left:
        fail("package check failed after darklua:\n  " + "\n  ".join(left[:20]))


def main() -> None:
    if not (SOURCE / "project.gpp").is_file():
        fail(f"cannot find {SOURCE / 'project.gpp'}")

    vendor = LAYOUT["vendor_path"]

    if not vendor.is_dir():
        fail(f"missing {LAYOUT['vendor_path']}: run `crater install -y` first")

    gpp = find_tool("gpp")
    darklua = find_tool("darklua")

    print(f"source > {SOURCE}")
    print(f"output > {OUTPUT}")

    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)

    TARGET_SRC.mkdir(parents=True)

    header_text = (SOURCE / "project.gpp").read_text("utf-8") + "\n" + (SOURCE / "build.gpp").read_text("utf-8")

    with tempfile.TemporaryDirectory() as temporary:
        header = Path(temporary) / "defines.gpp"
        header.write_text(header_text, "utf-8")
        preprocess(gpp, SOURCE, TARGET_SRC, collect_defines(), header, LAYOUT["vendor_name"])

    # Temporary copies only: `pack` injects the locked packages at the same
    # `src/vendor/...` path and the built code already points there.
    temporary_vendor = TARGET_SRC / LAYOUT["vendor_name"]
    shutil.copytree(vendor, temporary_vendor)
    luaurc = write_luaurc()
    transform(darklua, luaurc)
    shutil.rmtree(temporary_vendor)
    print(f"compact > {compact_tree(TARGET_SRC)} files")

    # `.d.luau` is not runtime code, so it is copied after darklua.
    shutil.copyfile(SOURCE / "core.d.luau", TARGET_SRC / "core.d.luau")

    validate()
    print(f"packable > {OUTPUT}")


if __name__ == "__main__":
    main()
