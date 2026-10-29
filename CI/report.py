#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

CI = Path(__file__).resolve().parent
OUTPUT = CI / "output"

ANSI = re.compile(r"\x1b\[[0-9;]*m")
LUA_SOURCE = re.compile(r'\[string "ReplicatedStorage\.core\.([^"]+)"\]')
JEST_FRAME = re.compile(r"ReplicatedStorage\.DevPackages\.\w+:\d+: ")
MAX_REASON = 400


def clean(text: str) -> str:
    text = ANSI.sub("", text)
    text = LUA_SOURCE.sub(lambda m: m.group(1).replace(".", "/"), text)
    return JEST_FRAME.sub("", text)


def cell(text: str) -> str:
    text = text.replace("|", "\\|").replace("\n", " ").strip()
    return text if len(text) <= MAX_REASON else text[: MAX_REASON - 1] + "…"


def literal(value: object) -> str:
    return json.dumps(value, ensure_ascii=False) if not isinstance(value, str) else f'"{value}"'


def title_of(test: dict) -> str:
    return " › ".join([*(test.get("ancestorTitles") or [])[1:], test.get("title") or test.get("fullName", "?")])


def reason(test: dict) -> str:
    method = re.match(r"has method (\w+)$", test.get("title") or "")
    for detail in test.get("failureDetails") or []:
        matcher = detail.get("matcherResult") if isinstance(detail, dict) else None
        if not matcher:
            continue
        expected, actual = matcher.get("expected"), matcher.get("actual")
        if isinstance(expected, list) and isinstance(actual, list):
            extra = sorted(set(map(str, actual)) - set(map(str, expected)))
            missing = sorted(set(map(str, expected)) - set(map(str, actual)))
            parts = []
            if extra:
                parts.append("not declared: " + ", ".join(extra))
            if missing:
                parts.append("missing: " + ", ".join(missing))
            if parts:
                return "; ".join(parts)
        title = test.get("title") or ""
        if expected is True and actual is False and re.match(r"(it/)?is\(", title):
            return f"`{title}` returned false"
        if method and expected == "function":
            return f"missing method `{method.group(1)}`" if actual == "nil" else f"`{method.group(1)}` is a {actual}, not a function"
        return f"expected {literal(expected)}, got {literal(actual)}"

    message = clean(" ".join(test.get("failureMessages") or [""]))
    message = re.sub(r"^Error:\s*", "", message.strip())
    required = re.match(r"require (\S+) failed:\s*(.*)", message, re.S)
    if required:
        detail = next((line.strip() for line in required.group(2).splitlines() if line.strip()), "")
        return f"`{required.group(1)}` fails to load: {detail}"
    return next((line.strip() for line in message.splitlines() if line.strip()), "unknown failure")


def suite_reason(suite: dict) -> str:
    message = clean(suite.get("failureMessage") or "")
    lines = [line.strip() for line in message.splitlines() if line.strip() and not line.strip().startswith("●")]
    return lines[0] if lines else "suite failed to run"


def name_of(suite: dict) -> str:
    path = suite.get("testFilePath") or suite.get("name") or "?"
    return re.sub(r"\.spec(\.luau)?$", "", path.replace("\\", "/").split("/")[-1])


def load(path: Path | None) -> dict:
    if path is None:
        candidates = sorted(OUTPUT.glob("CI_*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
        if not candidates:
            sys.exit("report: no CI/output/CI_*.json found")
        path = candidates[0]
    return json.loads(path.read_text("utf-8"))


def render(results: dict) -> str:
    failed_suites: dict[str, list[tuple[str, str]]] = {}
    passed_in: dict[str, int] = {}
    todo: list[tuple[str, str]] = []

    for suite in results.get("testResults", []):
        name = name_of(suite)
        tests = suite.get("testResults") or []
        failures = [(title_of(t), reason(t)) for t in tests if t.get("status") == "failed"]
        if not failures and suite.get("failureMessage") and not suite.get("numPassingTests"):
            failures = [("suite", suite_reason(suite))]
        if failures:
            failed_suites[name] = failures
            passed_in[name] = sum(1 for t in tests if t.get("status") == "passed")
        todo += [(name, t.get("title", "")) for t in tests if t.get("status") == "todo"]

    passed = results.get("numPassedTests", 0)
    failed = results.get("numFailedTests", 0)
    total_todo = results.get("numTodoTests", len(todo))
    suites = results.get("numTotalTestSuites", 0)
    broken = sum(1 for failures in failed_suites.values() if failures and failures[0][0] == "suite")
    ok = results.get("success") and not failed_suites

    out = [
        f"## {'✅' if ok else '❌'} core.d.luau type tests",
        "",
        f"**{failed}** failed · **{passed}** passed · **{total_todo}** todo · "
        f"{suites - len(failed_suites)}/{suites} types clean"
        + (f" · **{broken}** suites failed to run" if broken else ""),
        "",
    ]

    if failed_suites:
        out += [
            f"<details><summary><b>📋 Failed types</b> · {len(failed_suites)}</summary>",
            "",
            "| Type | Failed | Passed | Reason |",
            "| --- | ---: | ---: | --- |",
        ]
        for name, failures in sorted(failed_suites.items(), key=lambda item: (-len(item[1]), item[0])):
            missing = [m.group(1) for _, why in failures if (m := re.match(r"missing method `(\w+)`", why))]
            reasons: dict[str, int] = defaultdict(int)
            for _, why in failures:
                if not why.startswith("missing method"):
                    reasons[why] += 1
            top = sorted(reasons.items(), key=lambda item: -item[1])
            parts = [why for why, _ in top[:2]]
            if missing:
                parts.append("missing methods: " + ", ".join(f"`{m}`" for m in missing))
            hidden = len(top) - 2
            summary = "; ".join(parts) + (f" (+{hidden} more)" if hidden > 0 else "")
            out.append(f"| `{name}` | {len(failures)} | {passed_in[name]} | {cell(summary)} |")
        out += ["", "</details>", ""]

        total = sum(len(failures) for failures in failed_suites.values())
        out += [f"<details><summary><b>❌ Failures</b> · {total} tests in {len(failed_suites)} types</summary>", ""]
        for name, failures in sorted(failed_suites.items()):
            out += [f"<details><summary><code>{name}</code> · {len(failures)} failed</summary>", ""]
            out += [f"- `{title}`: {cell(why)}" for title, why in failures]
            out += ["", "</details>", ""]
        out += ["</details>", ""]

    if todo:
        out += [f"<details><summary><b>📝 Todo</b> · {len(todo)} types without a runtime contract</summary>", ""]
        out += [f"- `{name}`: {why}" for name, why in sorted(todo)]
        out += ["", "</details>", ""]

    return "\n".join(out)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    sys.stdout.reconfigure(encoding="utf-8")
    print(render(load(path)))


if __name__ == "__main__":
    main()
