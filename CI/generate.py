#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

CI = Path(__file__).resolve().parent
ROOT = CI.parent
SOURCE = ROOT / "src"
DECLARATION = SOURCE / "core.d.luau"

RUNTIME_DIRS = ("class", "enums")


@dataclass
class Ref:
    name: str
    args: list["Node"] = field(default_factory=list)


@dataclass
class Table:
    fields: dict[str, bool]


@dataclass
class Function:
    pass


@dataclass
class Union:
    parts: list["Node"]


@dataclass
class Intersection:
    parts: list["Node"]


@dataclass
class Other:
    pass


Node = Ref | Table | Function | Union | Intersection | Other

TOKEN = re.compile(r"\s*(->|\.\.\.|\"[^\"]*\"|'[^']*'|[A-Za-z_][A-Za-z_0-9]*|[0-9]+|.)", re.S)


def strip_comments(text: str) -> str:
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


class Parser:
    def __init__(self, text: str):
        self.tokens = [t for t in TOKEN.findall(text) if t.strip()]
        self.i = 0

    def peek(self, offset: int = 0) -> str:
        j = self.i + offset
        return self.tokens[j] if j < len(self.tokens) else ""

    def take(self, expected: str | None = None) -> str:
        token = self.peek()
        if expected is not None and token != expected:
            raise SyntaxError(f"expected {expected!r}, got {token!r} near {' '.join(self.tokens[self.i:self.i + 8])}")
        self.i += 1
        return token

    def skip_balanced(self, open_: str, close: str) -> None:
        depth = 0
        while True:
            token = self.take()
            if token == open_:
                depth += 1
            elif token == close:
                depth -= 1
                if depth == 0:
                    return
            elif token == "":
                raise SyntaxError("unbalanced brackets")

    def type(self) -> Node:
        if self.peek() in ("|", "&"):
            self.take()
        parts = [self.intersection()]
        while self.peek() == "|":
            self.take()
            parts.append(self.intersection())
        return parts[0] if len(parts) == 1 else Union(parts)

    def intersection(self) -> Node:
        parts = [self.postfix()]
        while self.peek() == "&":
            self.take()
            parts.append(self.postfix())
        return parts[0] if len(parts) == 1 else Intersection(parts)

    def postfix(self) -> Node:
        node = self.primary()
        while self.peek() == "?":
            self.take()
            node = Union([node, Ref("nil")])
        return node

    def primary(self) -> Node:
        token = self.peek()

        if token == "<":
            self.skip_balanced("<", ">")
            return self.function_tail()

        if token == "(":
            start = self.i
            self.skip_balanced("(", ")")
            if self.peek() == "->":
                return self.function_tail(skip_args=False)
            end = self.i
            self.i = start + 1
            inner = self.type() if end - start > 2 else Other()
            self.i = end
            return inner

        if token == "{":
            return self.table()

        if token == "typeof":
            self.take()
            self.skip_balanced("(", ")")
            return Other()

        if token == "...":
            self.take()
            return self.postfix()

        if token[:1] in "\"'" or token.isdigit():
            self.take()
            return Other()

        if re.fullmatch(r"[A-Za-z_]\w*", token):
            name = self.take()
            while self.peek() == ".":
                self.take()
                name += "." + self.take()
            args: list[Node] = []
            if self.peek() == "<":
                self.take()
                while self.peek() != ">":
                    if self.peek() == "(" and self.is_type_pack():
                        self.skip_balanced("(", ")")
                        args.append(Other())
                    else:
                        args.append(self.type())
                    if self.peek() == ",":
                        self.take()
                self.take(">")
            if self.peek() == "...":
                self.take()
            return Ref(name, args)

        raise SyntaxError(f"unexpected {token!r} near {' '.join(self.tokens[self.i:self.i + 8])}")

    def is_type_pack(self) -> bool:
        depth, j = 0, self.i
        while True:
            token = self.tokens[j]
            depth += token == "("
            depth -= token == ")"
            j += 1
            if depth == 0:
                break
        return j >= len(self.tokens) or self.tokens[j] != "->"

    def function_tail(self, skip_args: bool = True) -> Node:
        if skip_args:
            self.skip_balanced("(", ")")
        self.take("->")
        if self.peek() == "(" and self.is_type_pack():
            self.skip_balanced("(", ")")
            while self.peek() == "?":
                self.take()
        else:
            self.type()
        return Function()

    def table(self) -> Node:
        self.take("{")
        fields: dict[str, bool] = {}
        while self.peek() != "}":
            if self.peek() == "[":
                self.skip_balanced("[", "]")
                self.take(":")
                self.type()
            elif self.peek(1) == ":" or (self.peek() in ("read", "write") and self.peek(2) == ":"):
                if self.peek() in ("read", "write") and self.peek(2) == ":":
                    self.take()
                name = self.take()
                self.take(":")
                fields[name] = isinstance(self.type(), Function)
            else:
                self.type()
            if self.peek() in (",", ";"):
                self.take()
        self.take("}")
        return Table(fields)


@dataclass
class Declaration:
    name: str
    exported: bool
    body: Node


DECLARATION_START = re.compile(r"^(export\s+)?type\s+(\w+)\s*(<[^\n]*?>)?\s*=", re.M)


def parse_declarations(text: str) -> dict[str, Declaration]:
    text = strip_comments(text)
    starts = list(DECLARATION_START.finditer(text))
    result: dict[str, Declaration] = {}
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        body = text[match.end() : end]
        parser = Parser(body)
        try:
            node = parser.type()
        except SyntaxError as error:
            raise SyntaxError(f"type {match.group(2)}: {error}") from None
        if parser.peek() != "":
            raise SyntaxError(f"type {match.group(2)}: trailing {parser.peek()!r}")
        result[match.group(2)] = Declaration(match.group(2), bool(match.group(1)), node)
    return result


class Model:
    def __init__(self, declarations: dict[str, Declaration]):
        self.declarations = declarations

    def fields(self, node: Node, seen: frozenset[str] = frozenset()) -> dict[str, bool]:
        if isinstance(node, Table):
            return dict(node.fields)
        if isinstance(node, Intersection):
            merged: dict[str, bool] = {}
            for part in node.parts:
                merged.update(self.fields(part, seen))
            return merged
        if isinstance(node, Ref):
            if node.name == "extend":
                extension = node.args[0] if node.args else Table({})
                base = node.args[1] if len(node.args) > 1 else Ref("luaobject")
                return {**self.fields(base, seen), **self.fields(extension, seen)}
            if node.name in self.declarations and node.name not in seen:
                return self.fields(self.declarations[node.name].body, seen | {node.name})
        return {}

    def base(self, node: Node) -> str | None:
        if isinstance(node, Ref):
            if node.name == "extend":
                base = node.args[1] if len(node.args) > 1 else Ref("luaobject")
                return base.name if isinstance(base, Ref) else None
            if node.name in self.declarations:
                return node.name
        return None

    def bases(self, name: str) -> list[str]:
        chain: list[str] = []
        current = self.base(self.declarations[name].body)
        while current and current not in chain and current != name:
            chain.append(current)
            if current not in self.declarations:
                break
            current = self.base(self.declarations[current].body)
        return chain

    def is_object(self, name: str) -> bool:
        return name == "luaobject" or "luaobject" in self.bases(name)

    def mixins(self, node: Node, seen: frozenset[str] = frozenset()) -> set[str]:
        if isinstance(node, Intersection):
            return set().union(*(self.mixins(part, seen) for part in node.parts))
        if isinstance(node, Ref):
            if node.name == "extend":
                return set().union(*(self.mixins(arg, seen) for arg in node.args))
            if node.name in self.declarations and node.name not in seen:
                return {node.name} | self.mixins(self.declarations[node.name].body, seen | {node.name})
        return set()

    def enumitem_of(self, name: str) -> str | None:
        node = self.declarations[name].body
        if isinstance(node, Ref) and node.name == "enumitem" and node.args:
            arg = node.args[0]
            if isinstance(arg, Ref) and arg.name in self.declarations:
                return arg.name
        return None


def find_runtime() -> dict[str, str]:
    result: dict[str, str] = {}
    for directory in RUNTIME_DIRS:
        for file in sorted((SOURCE / directory).rglob("*.luau")):
            match = re.search(r"^(?:const|local)\s+class\s*:\s*(\w+)", file.read_text("utf-8"), re.M)
            if match and match.group(1) not in result:
                result[match.group(1)] = file.relative_to(SOURCE).with_suffix("").as_posix()
    return result


@dataclass
class Spec:
    type: str
    kind: str
    lines: list[str]


def lua_list(values: list[str]) -> str:
    return "{ " + ", ".join(f'"{v}"' for v in values) + " }" if values else "{}"


def build_specs(model: Model, runtime: dict[str, str]) -> list[Spec]:
    specs: list[Spec] = []
    exported = [d for d in model.declarations.values() if d.exported]

    implementers: dict[str, list[str]] = {}
    for name in runtime:
        if name in model.declarations:
            for mixin in model.mixins(model.declarations[name].body):
                implementers.setdefault(mixin, []).append(name)

    for declaration in exported:
        name = declaration.name
        fields = model.fields(declaration.body)
        methods = sorted(k for k, is_function in fields.items() if is_function)
        values = sorted(k for k, is_function in fields.items() if not is_function)

        if name in runtime and model.is_object(name):
            bases = model.bases(name)
            if "enumobject" in bases:
                items = [v for v in values if v not in model.fields(Ref("enumobject"))]
                specs.append(Spec(name, "enum", [
                    f'\ttype = "{name}",',
                    f'\tmodule = "{runtime[name]}",',
                    f"\titems = {lua_list(sorted(items))},",
                    f"\tmethods = {lua_list(methods)},",
                ]))
            else:
                specs.append(Spec(name, "class", [
                    f'\ttype = "{name}",',
                    f'\tmodule = "{runtime[name]}",',
                    f"\tbases = {lua_list(bases)},",
                    f"\tmethods = {lua_list(methods)},",
                ]))
            continue

        enum = model.enumitem_of(name) if name.startswith("enumitem_") else None
        if enum and enum in runtime:
            specs.append(Spec(name, "enumitem", [
                f'\ttype = "{name}",',
                f'\tenum = "{enum}",',
                f'\tmodule = "{runtime[enum]}",',
            ]))
            continue

        users = sorted(u for u in implementers.get(name, []) if u != name)
        if methods and users:
            specs.append(Spec(name, "mixin", [
                f'\ttype = "{name}",',
                f"\tmethods = {lua_list(methods)},",
                "\timplementers = {",
                *[f'\t\t{{ type = "{u}", module = "{runtime[u]}" }},' for u in users],
                "\t},",
            ]))
            continue

        if model.is_object(name) or enum:
            reason = "no runtime implementation in src/class or src/enums"
        elif values and users:
            reason = "only data fields, nothing callable to check"
        elif methods or values:
            reason = "interface is not mixed into any implemented class"
        else:
            reason = "type-only alias, nothing to check at runtime"
        specs.append(Spec(name, "pending", [f'\ttype = "{name}",', f'\treason = "{reason}",']))

    return specs




def write_specs(specs: list[Spec], target: Path) -> None:
    directory = target / "types"
    directory.mkdir(parents=True, exist_ok=True)
    for spec in specs:
        body = "\n".join(spec.lines)
        (directory / f"{spec.type}.spec.luau").write_text(
            f'local contract = require("../contract")\n\ncontract.{spec.kind}({{\n{body}\n}})\n',
            "utf-8",
            newline="\n",
        )


def collect() -> list[Spec]:
    model = Model(parse_declarations(DECLARATION.read_text("utf-8")))
    return build_specs(model, find_runtime())


def main(target: Path | None = None) -> None:
    specs = collect()
    if target is not None:
        write_specs(specs, target)

    counts: dict[str, int] = {}
    for spec in specs:
        counts[spec.kind] = counts.get(spec.kind, 0) + 1
    summary = ", ".join(f"{kind} {count}" for kind, count in sorted(counts.items()))
    print(f"generate: {len(specs)} types from {DECLARATION.relative_to(ROOT).as_posix()} ({summary})")

    if target is None:
        for spec in specs:
            print(f"  {spec.kind:9} {spec.type}")


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else None)
