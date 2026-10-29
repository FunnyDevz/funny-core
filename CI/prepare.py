#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import posixpath
import re
import shutil
import sys
from pathlib import Path

CI = Path(__file__).resolve().parent
ROOT = CI.parent
SOURCE = ROOT / "src"
TARGET = CI / "build"

REQUIRED = {
    "Packages": ROOT / "Packages",
    "ServerPackages": ROOT / "ServerPackages",
    "DevPackages": ROOT / "DevPackages",
}

DIRECTIVE = re.compile(r"^--#(\w+)\s*(.*?)\s*$")
INLINE_DIRECTIVE = re.compile(r"--\[\[#((?:if|ifdef|ifndef|elif) [^\]]*|else|endif)\]\]")
INLINE_MACRO = re.compile(r"--\[\[#(\w+)\]\]")
REQUIRE = re.compile(r"""require\(\s*(["'])@(\w+)(/[^"']*)?\1\s*\)""")


class Preprocessor:
    def __init__(self, defines: dict[str, str]):
        self.defines = dict(defines)

    def truthy(self, expr: str) -> bool:
        def atom(token: str) -> bool:
            token = token.strip()
            if token.startswith("!"):
                return not atom(token[1:])
            if token.startswith("(") and token.endswith(")"):
                return self.truthy(token[1:-1])
            if re.fullmatch(r"\w+", token) and not token.isdigit():
                token = self.defines.get(token, "0")
            return token.strip().strip('"') not in ("", "0", "false")

        return any(all(atom(a) for a in part.split("&&")) for part in expr.split("||"))

    def expand(self, line: str) -> str:
        line = INLINE_MACRO.sub(lambda m: self.defines.get(m.group(1), ""), line)
        if not self.defines:
            return line
        names = "|".join(re.escape(n) for n in sorted(self.defines, key=len, reverse=True))
        return re.sub(rf"\b(?:{names})\b", lambda m: self.defines[m.group(0)], line)

    def run(self, text: str) -> str:
        text = re.sub(r"(?m)^[ \t]+--#", "--#", text)
        text = INLINE_DIRECTIVE.sub(lambda m: f"\n--#{m.group(1)}\n", text)

        out: list[str] = []
        stack: list[tuple[bool, bool, bool]] = []
        active = True

        for line in text.split("\n"):
            m = DIRECTIVE.match(line)
            if not m:
                if active:
                    out.append(self.expand(line))
                continue

            name, arg = m.group(1), m.group(2)
            if name in ("if", "ifdef", "ifndef"):
                if name == "if":
                    cond = self.truthy(arg)
                elif name == "ifdef":
                    cond = arg in self.defines
                else:
                    cond = arg not in self.defines
                stack.append((active and cond, cond, active))
                active = active and cond
            elif name == "elif":
                _, taken, parent = stack.pop()
                cond = not taken and self.truthy(arg)
                stack.append((parent and cond, taken or cond, parent))
                active = parent and cond
            elif name == "else":
                _, taken, parent = stack.pop()
                stack.append((parent and not taken, True, parent))
                active = parent and not taken
            elif name == "endif":
                _, _, active = stack.pop()
            elif not active:
                continue
            elif name == "define":
                key, _, value = arg.partition(" ")
                self.defines[key] = value.strip()
            elif name == "undef":
                self.defines.pop(arg, None)
            elif name == "include":
                pass
            else:
                raise ValueError(f"unsupported directive --#{name}")

        if stack:
            raise ValueError("unterminated --#if")
        return "\n".join(out)


def load_defines() -> dict[str, str]:
    pre = Preprocessor({})
    unique = os.environ.get("CORE_COMMIT")
    if os.environ.get("CI") == "true" and unique:
        pre.defines["UNIQUE"] = f'"{unique}"'
    pre.run((SOURCE / "project.gpp").read_text("utf-8") + "\n" + (SOURCE / "build.gpp").read_text("utf-8"))
    return pre.defines


def load_aliases() -> dict[str, str]:
    raw = (SOURCE / "config.luaurc").read_text("utf-8")
    raw = re.sub(r",(\s*[}\]])", r"\1", raw)
    return json.loads(raw)["aliases"]


def rewrite_requires(text: str, module: str, aliases: dict[str, str], where: str) -> str:
    here = posixpath.dirname(module)

    def replace(m: re.Match[str]) -> str:
        alias, rest = m.group(2), m.group(3) or ""
        if alias not in aliases:
            raise ValueError(f"{where}: unknown alias @{alias}")
        target = posixpath.normpath(posixpath.join(aliases[alias], rest.lstrip("/")))
        relative = posixpath.relpath(target, here or ".")
        if not relative.startswith("../"):
            relative = "./" + relative
        return f'require("{relative}")'

    return REQUIRE.sub(replace, text)


def build_core() -> None:
    defines = load_defines()
    aliases = load_aliases()
    core = TARGET / "core"

    for file in sorted(SOURCE.rglob("*.luau")):
        relative = file.relative_to(SOURCE).as_posix()
        if relative.endswith(".d.luau"):
            continue

        text = file.read_text("utf-8")
        try:
            text = Preprocessor(defines).run(text)
            text = rewrite_requires(text, relative[: -len(".luau")], aliases, relative)
        except ValueError as error:
            sys.exit(f"prepare: {relative}: {error}")

        output = core / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text, "utf-8", newline="\n")


def build_spec() -> None:
    spec = TARGET / "spec"
    shutil.copytree(CI / "spec", spec, dirs_exist_ok=True)

    import generate

    generate.main(spec)


def main() -> None:
    missing = [name for name, path in REQUIRED.items() if not path.is_dir()]
    if missing:
        sys.exit(f"prepare: missing {', '.join(missing)}, run `crater install` first")

    for part in ("core", "spec"):
        if (TARGET / part).exists():
            shutil.rmtree(TARGET / part)
    TARGET.mkdir(parents=True, exist_ok=True)
    build_core()
    build_spec()
    print(f"prepare: {TARGET.relative_to(ROOT).as_posix()} ready")


if __name__ == "__main__":
    main()
