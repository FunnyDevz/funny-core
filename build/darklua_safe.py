"""Keep Luau type instantiations alive through a darklua pass.

darklua 0.19.0 rebuilds Lua from its own AST and silently drops Luau's
explicit generic instantiation syntax `f <<T>>(x)` (Luau itself supports it):

    local x = self:get <<number>> (1)
    -- becomes
    local x = self:get (1)

The workaround is to replace every `<<T>>` with a comment marker before
darklua runs, then put the original text back. darklua must run with
`--format retain_lines`, because the default format strips comments and would
drop the markers.

The scanner understands short strings, long strings and both comment styles,
so `<<` inside them is never touched. Type arguments are matched with angle
bracket depth, so nested generics such as `<<maybe<value<number>, item>>>`
survive too, and the `>` of a `->` function type is ignored.
"""

from __future__ import annotations

import re
from pathlib import Path

TYPEINST_MARKER = "__CORE_TYPEINST_{}__"
TYPEINST_PREFIX = "--[[__CORE_TYPEINST_"
LONG_BRACKET_OPEN = re.compile(r"\[(=*)\[")


def type_instantiation_marker(index: int) -> str:
    return "--[[" + TYPEINST_MARKER.format(index) + "]]"


def has_marker(text: str) -> bool:
    return TYPEINST_PREFIX in text


def _long_bracket_end(text: str, index: int) -> int | None:
    match = LONG_BRACKET_OPEN.match(text, index)

    if not match:
        return None

    close = "]" + match.group(1) + "]"
    end = text.find(close, match.end())

    if end == -1:
        return None

    return end + len(close)


def _short_string_end(text: str, index: int) -> int:
    quote = text[index]
    cursor = index + 1

    while cursor < len(text):
        char = text[cursor]

        if char == "\\":
            cursor += 2
            continue

        if char == quote:
            return cursor + 1

        if char == "\n":
            return cursor

        cursor += 1

    return len(text)


def _comment_end(text: str, index: int) -> int:
    if text.startswith("--[", index):
        end = _long_bracket_end(text, index + 2)

        if end is not None:
            return end

    newline = text.find("\n", index)
    return len(text) if newline == -1 else newline


def _type_instantiation_end(text: str, index: int) -> int | None:
    cursor = index + 2
    depth = 0

    while cursor < len(text):
        char = text[cursor]

        if char in "\"'":
            cursor = _short_string_end(text, cursor)
            continue

        if text.startswith("--", cursor):
            cursor = _comment_end(text, cursor)
            continue

        if char == "[":
            end = _long_bracket_end(text, cursor)

            if end is not None:
                cursor = end
                continue

        if char == "<":
            depth += 1
        elif char == ">":
            if cursor > 0 and text[cursor - 1] == "-":
                pass
            elif depth > 0:
                depth -= 1
            elif text.startswith(">>", cursor):
                return cursor + 2
            else:
                return None

        cursor += 1

    return None


def mask(text: str) -> tuple[str, list[str]]:
    parts: list[str] = []
    types: list[str] = []
    cursor = 0

    while cursor < len(text):
        char = text[cursor]

        if char in "\"'":
            end = _short_string_end(text, cursor)
            parts.append(text[cursor:end])
            cursor = end
            continue

        if text.startswith("--", cursor):
            end = _comment_end(text, cursor)
            parts.append(text[cursor:end])
            cursor = end
            continue

        if char == "[":
            end = _long_bracket_end(text, cursor)

            if end is not None:
                parts.append(text[cursor:end])
                cursor = end
                continue

        if text.startswith("<<", cursor):
            end = _type_instantiation_end(text, cursor)

            if end is not None:
                types.append(text[cursor:end])
                parts.append(type_instantiation_marker(len(types) - 1))
                cursor = end
                continue

        parts.append(char)
        cursor += 1

    return "".join(parts), types


def restore(text: str, types: list[str]) -> str:
    found = text.count(TYPEINST_PREFIX)

    if found != len(types):
        raise ValueError(f"darklua dropped {len(types) - found} of {len(types)} type instantiations")

    for index, original in enumerate(types):
        text = text.replace(type_instantiation_marker(index), original)

    return text


def mask_tree(directory: Path) -> dict[Path, list[str]]:
    masked: dict[Path, list[str]] = {}

    for file in sorted(directory.rglob("*.luau")):
        text = file.read_text("utf-8")
        updated, types = mask(text)

        if types:
            file.write_text(updated, "utf-8")
            masked[file] = types

    return masked


def restore_tree(masked: dict[Path, list[str]]) -> None:
    for file, types in masked.items():
        try:
            text = restore(file.read_text("utf-8"), types)
        except ValueError as error:
            raise ValueError(f"{file}: {error}") from error

        file.write_text(text, "utf-8")
