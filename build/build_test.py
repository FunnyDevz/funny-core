#!/usr/bin/env python3
"""Build a consumer-ready funny-core package and install it through crater.

The pipeline mirrors build/build.py (gpp + darklua), but produces a crater
package instead of a place:

  src/**          --gpp-->  Packages/funny-core/src/**
  src/vendor/**   --copy--> Packages/funny-core/src/vendor/**
                  --darklua--> relative requires inside the package
                  --crater publish--> build/dev/registry (local folder registry)
                  --crater install--> build/dev/consumer/Packages/funny-core

The package is self-contained: vendored dependencies from `src/vendor` travel
inside it, so the consumer project installs no extra packages. This is a local
smoke test; the public archive receives the same packages through crater's
`vendor_packages` mechanism, see build/BUILD.md.

darklua 0.19.0 drops Luau's `f <<T>>(x)` generic instantiation, so those are
masked as comments around the darklua pass and restored afterwards; the
helpers live in build/darklua_safe.py.

The result is intentionally shaped like a real dependency: the package has no
init.luau, so consumers require modules by path. See build/BUILD_DEV.md.
"""

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
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from crater_layout import load as load_layout
from darklua_safe import has_marker, mask_tree, restore_tree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCE = ROOT / "src"
LAYOUT = load_layout(ROOT)
DEV = HERE / "dev"
REGISTRY = DEV / "registry"
WORK = DEV / "work"
CONSUMER = DEV / "consumer"

PACKAGE_NAME = "funnydevz/funny-core"
PACKAGE_ROOT = WORK / "root" / "Packages" / "funny-core"
PACKAGE_SRC = PACKAGE_ROOT / "src"

SKIPPED = (".gpp", ".d.luau", ".project.json", ".darklua.json", ".md")
DARKLUA_CONFIG = SOURCE / "build_info.darklua.json"

GPP_ARGS = [
    "-U", "", "", "(", ",", ")", "(", ")", "#", "",
    "-M", "--#", "\\n", " ", " ", "\\n", "(", ")",
    "+cQQQ", "--[[#", "]]",
]

INDENTED_DIRECTIVE = re.compile(r"(?m)^[ \t]+--#")
INLINE_DIRECTIVE = re.compile(r"--\[\[#((?:if|ifdef|ifndef|elif) [^\]]*|else|endif)\]\]")
REQUIRE_ALIAS = re.compile(r"""require\(\s*(["'])@([\w-]+)""")
DIRECTIVE_LEFT = re.compile(r"(?m)^[ \t]*--#[^\n]*$")

CONSUMER_CLIENT_SMOKE = """\
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local core = Packages:WaitForChild("funny-core")

local LuaObject = require(core.src.class.core.LuaObject)
local Observer = require(core.src.class.core.Observer)
local EnumObject = require(core.src.class.core.EnumObject)
local Basis = require(core.src.class.struct.geometry.Basis)

print("[funny-core dev] client smoke ok", LuaObject.type, Observer.type, EnumObject.type, Basis.type)
"""

CONSUMER_SERVER_SMOKE = """\
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local core = Packages:WaitForChild("funny-core")

-- DataServer requires @include/ProfileStore. The dev package bundles
-- src/vendor, so the consumer does not install ProfileStore itself.
local DataServer = require(core.src.class.service.DataServer)

print("[funny-core dev] server smoke ok", DataServer.name)
"""


def fail(message: str) -> None:
    sys.exit(f"build_test: {message}")


def find_tool(name: str, required: bool = True) -> str | None:
    candidates = [name]

    if platform.system() == "Windows":
        candidates = [f"{name}.exe", f"{name}.cmd", name]

    for candidate in candidates:
        path = shutil.which(candidate)
        if path:
            return path

    if required:
        fail(f"`{name}` is not installed or not on PATH")

    return None


def run(command: list[str], cwd: Path = ROOT, quiet: bool = False) -> str:
    if not quiet:
        print(f"» {' '.join(str(part) for part in command)}")

    result = subprocess.run(command, cwd=cwd, capture_output=True)

    output = result.stdout.decode("utf-8", "replace")
    error = result.stderr.decode("utf-8", "replace")

    if result.returncode != 0:
        text = (error or output).strip()
        fail(f"`{Path(command[0]).name}` failed:\n{text}")

    return output


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

        if relative.parts and relative.parts[0] in ("temp", vendor):
            continue

        name = file.name

        if not name.endswith(".luau") or name.endswith(SKIPPED):
            continue

        output = target / relative
        output.parent.mkdir(parents=True, exist_ok=True)

        text = file.read_text("utf-8")
        text = INDENTED_DIRECTIVE.sub("--#", text)
        text = INLINE_DIRECTIVE.sub(lambda match: f"\n--#{match.group(1)}\n", text)

        print(f"gpp > {relative.as_posix()}")
        result = subprocess.run(
            [gpp, *defines, f"-I{source}", "--include", str(header), *GPP_ARGS],
            input=text.encode("utf-8"),
            capture_output=True,
        )

        if result.returncode != 0:
            message = (result.stderr or result.stdout).decode("utf-8", "replace").strip()
            fail(f"gpp failed on {relative.as_posix()}:\n{message}")

        output.write_bytes(result.stdout.replace(b"\r\n", b"\n"))


def prepare_package_tree() -> None:
    vendor = LAYOUT["vendor_path"]

    if not vendor.is_dir():
        fail(f"missing {LAYOUT['vendor_path']}: run `crater install -y` first")

    if PACKAGE_ROOT.exists():
        shutil.rmtree(PACKAGE_ROOT)

    PACKAGE_SRC.mkdir(parents=True)

    print(f"copy > {LAYOUT['vendor_path']}")
    shutil.copytree(vendor, PACKAGE_SRC / LAYOUT["vendor_name"])


def write_darklua_luaurc() -> Path:
    # The dev package keeps the repository layout, so the aliases are the same
    # as in src/config.luaurc. Vendored packages travel inside `src/vendor`;
    # the realm aliases come from crater.settings.json (build/crater_layout.py).
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

    path = PACKAGE_SRC / ".luaurc"
    path.write_text(json.dumps({"aliases": aliases}, indent=4) + "\n", "utf-8")
    return path


def transform(darklua: str, luaurc: Path) -> None:
    masked = mask_tree(PACKAGE_SRC)

    # darklua 0.19.0 drops `f <<T>>(x)` while regenerating the AST, so the
    # instantiations are temporarily masked as comments. `--format retain_lines`
    # is required because the default format strips comments. See darklua_safe.
    print("darklua > funny-core")
    try:
        run([
            darklua,
            "process",
            str(PACKAGE_SRC),
            str(PACKAGE_SRC),
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


def validate_package_src() -> None:
    alias_left: list[str] = []
    directive_left: list[str] = []
    marker_left: list[str] = []

    for file in sorted(PACKAGE_SRC.rglob("*.luau")):
        text = file.read_text("utf-8")
        relative = file.relative_to(PACKAGE_SRC).as_posix()

        # Vendored packages bring their own `@self` requires; darklua skips
        # them, and the consumer resolves them with crater's darklua setup.
        if relative == LAYOUT["vendor_name"] or relative.startswith(f"{LAYOUT['vendor_name']}/"):
            continue

        for match in REQUIRE_ALIAS.finditer(text):
            alias_left.append(f"{relative}: @{match.group(2)}")

        for match in DIRECTIVE_LEFT.finditer(text):
            directive_left.append(f"{relative}: {match.group(0).strip()}")

        if has_marker(text):
            marker_left.append(relative)

    if alias_left:
        fail("unresolved alias requires after darklua:\n  " + "\n  ".join(alias_left[:20]))

    if directive_left:
        fail("unprocessed gpp directives after gpp:\n  " + "\n  ".join(directive_left[:20]))

    if marker_left:
        fail("type instantiation markers were not restored:\n  " + "\n  ".join(marker_left[:20]))

    print("check > no alias requires, no gpp directives and no markers left")


def write_package_manifest(version: str) -> None:
    manifest = {
        "$schema": "https://raw.githubusercontent.com/TheExeDEV/crater/main/schemas/crater.schema.json",
        "name": PACKAGE_NAME,
        "version": version,
        "description": "Local test build of funny-core (gpp + darklua). Not for the public registry.",
        "license": "MPLv2",
        "registry": REGISTRY.as_posix(),
        "can_publish": True,
        "import_to": "shared",
        "path_to_main": "",
        "path_to_definition_files": ["./src/core.d.luau"],
        # Vendored packages are bundled under src/vendor, so the consumer
        # project installs nothing else.
        "import_client": [],
        "import_server": [],
        "import_develop": [],
        "package_files": {
            "exclude": [
                "src/*.gpp",
                "src/config.luaurc",
                "src/default.project.json",
                "src/build_info.darklua.json",
                "src/temp/**",
            ],
            "allow": [],
        },
    }

    (PACKAGE_ROOT / "crater.json").write_text(json.dumps(manifest, indent=2) + "\n", "utf-8")
    shutil.copyfile(ROOT / "LICENSE.md", PACKAGE_ROOT / "LICENSE.md")


def publish(crater: str) -> None:
    print(f"publish > {PACKAGE_NAME} into {REGISTRY}")
    output = run([crater, "publish", "-y"], cwd=PACKAGE_ROOT)
    print(output.strip())


def write_consumer(version: str) -> None:
    CONSUMER.mkdir(parents=True, exist_ok=True)
    (CONSUMER / "client").mkdir(exist_ok=True)
    (CONSUMER / "server").mkdir(exist_ok=True)

    dependency = f"funny-core:{PACKAGE_NAME}@{version}"

    manifest = {
        "$schema": "https://raw.githubusercontent.com/TheExeDEV/crater/main/schemas/crater.schema.json",
        "name": "funnydevz/funny-core-dev-consumer",
        "version": "0.0.1",
        "description": "Consumer project for the local funny-core test build.",
        "registry": REGISTRY.as_posix(),
        "can_publish": False,
        "import_to": "shared",
        "path_to_main": "",
        "import_client": [dependency],
        "import_server": [],
        "import_develop": [],
        "package_files": {"exclude": [], "allow": []},
    }

    settings = {
        "$schema": "https://raw.githubusercontent.com/TheExeDEV/crater/main/schemas/crater.settings.schema.json",
        "client": {"path": "Packages", "alias": "import"},
        "server": {"path": "ServerPackages", "alias": "include"},
        "develop": {"path": "DevPackages", "alias": "internal"},
        "luaurc": ".luaurc",
        # funny-core ships src/core.d.luau through path_to_definition_files, so
        # crater keeps warning until the consumer lets luau-lsp see them.
        "vscode_definitions": True,
        "confirm": False,
        "link_style": "roblox",
        # The consumer requires modules by relative path, there are no @alias
        # requires left for crater to set darklua up for.
        "darklua": False,
        "sync": "auto",
    }

    project = {
        "name": "funny-core-dev",
        "tree": {
            "$className": "DataModel",
            "ReplicatedStorage": {
                "$className": "ReplicatedStorage",
                "Packages": {"$path": "Packages"},
            },
            "ServerScriptService": {
                "$className": "ServerScriptService",
                "Smoke": {"$path": "server"},
            },
            "StarterPlayer": {
                "$className": "StarterPlayer",
                "StarterPlayerScripts": {
                    "$className": "StarterPlayerScripts",
                    "Smoke": {"$path": "client"},
                },
            },
        },
    }

    luaurc = {"aliases": {"import": "./Packages"}}

    (CONSUMER / "crater.json").write_text(json.dumps(manifest, indent=2) + "\n", "utf-8")
    (CONSUMER / "crater.settings.json").write_text(json.dumps(settings, indent=2) + "\n", "utf-8")
    (CONSUMER / "default.project.json").write_text(json.dumps(project, indent=2) + "\n", "utf-8")
    (CONSUMER / ".luaurc").write_text(json.dumps(luaurc, indent=4) + "\n", "utf-8")
    (CONSUMER / "client" / "Smoke.client.luau").write_text(CONSUMER_CLIENT_SMOKE, "utf-8")
    (CONSUMER / "server" / "Smoke.server.luau").write_text(CONSUMER_SERVER_SMOKE, "utf-8")


def install(crater: str) -> None:
    print("install > consumer project")
    output = run([crater, "install", "-y"], cwd=CONSUMER)
    print(output.strip())


def build_place(rojo: str | None, requested: bool) -> None:
    if not requested:
        print("place > skipped (--no-place)")
        return

    if not rojo:
        print("place > skipped (rojo is not installed)")
        return

    print("rojo > consumer/build.rbxl")
    try:
        run([rojo, "build", str(CONSUMER / "default.project.json"), "--output", str(CONSUMER / "build.rbxl")])
    except SystemExit:
        print("place > rojo build failed; the crater install itself is still complete")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build funny-core with gpp + darklua, publish it into a local crater registry, and install it into build/dev/consumer"
    )
    parser.add_argument("--version", help="package version (default: 0.0.1-dev.<unix timestamp>)")
    parser.add_argument("--keep", action="store_true", help="keep build/dev/registry between runs")
    parser.add_argument("--no-place", action="store_true", help="do not run rojo build for the consumer place")
    arguments = parser.parse_args()

    if not (SOURCE / "project.gpp").is_file():
        fail(f"cannot find {SOURCE / 'project.gpp'}")

    gpp = find_tool("gpp")
    darklua = find_tool("darklua")
    crater = find_tool("crater")
    place_requested = not arguments.no_place
    rojo = find_tool("rojo", required=False) if place_requested else None

    version = arguments.version or f"0.0.1-dev.{int(time.time())}"

    print(f"platform > {platform.system()} {platform.machine()}")
    print(f"source > {SOURCE}")
    print(f"package > {PACKAGE_NAME}@{version}")
    print(f"dev > {DEV}")

    if DEV.exists() and not arguments.keep:
        shutil.rmtree(DEV)

    for directory in (REGISTRY, WORK, CONSUMER):
        directory.mkdir(parents=True, exist_ok=True)

    prepare_package_tree()

    with tempfile.TemporaryDirectory() as temporary:
        header = Path(temporary) / "defines.gpp"
        header.write_text(
            (SOURCE / "project.gpp").read_text("utf-8") + "\n" + (SOURCE / "build.gpp").read_text("utf-8"),
            "utf-8",
        )
        preprocess(gpp, SOURCE, PACKAGE_SRC, collect_defines(), header, LAYOUT["vendor_name"])

    luaurc = write_darklua_luaurc()
    transform(darklua, luaurc)

    # .d.luau files are type declarations, not modules; darklua must not parse
    # them as runtime code, so copy them after the transform.
    shutil.copyfile(SOURCE / "core.d.luau", PACKAGE_SRC / "core.d.luau")

    validate_package_src()
    write_package_manifest(version)
    publish(crater)
    write_consumer(version)
    install(crater)
    build_place(rojo, place_requested)

    print()
    print("done >", PACKAGE_NAME, version)
    print("package >", PACKAGE_ROOT)
    print("registry >", REGISTRY)
    print("consumer >", CONSUMER)

    if place_requested and rojo:
        print("place >", CONSUMER / "build.rbxl")

    print()
    print("next >")
    print("  rojo serve", CONSUMER / "default.project.json")

    if place_requested and rojo:
        print("  # or open", CONSUMER / "build.rbxl", "in Studio")


if __name__ == "__main__":
    main()
