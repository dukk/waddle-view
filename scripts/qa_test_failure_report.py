#!/usr/bin/env python3
"""Persist QA scoped-check failures (analyze or tests) for Cursor stop-hook autofix."""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from waddle_check_common import QaScopedTestResult

FAILURE_REL = Path(".cursor/hooks/state/qa-test-failure.json")
OUTPUT_TAIL_MAX = 12_000
FAILURE_MAX_AGE_MS = 2 * 60 * 60 * 1000


def failure_path(root: Path) -> Path:
    return root / FAILURE_REL


def _tail(text: str, limit: int = OUTPUT_TAIL_MAX) -> str:
    if len(text) <= limit:
        return text
    return f"… ({len(text) - limit} chars truncated)\n{text[-limit:]}"


def write_failure(root: Path, result: QaScopedTestResult) -> None:
    path = failure_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload: dict[str, Any] = {
        "failed_at_ms": int(time.time() * 1000),
        "label": result.failure_label or "scoped check",
        "cwd": str(result.failure_cwd) if result.failure_cwd else "",
        "argv": result.failure_argv or [],
        "exit_code": result.exit_code,
        "output_tail": _tail(result.failure_output or ""),
        "edited_files": result.edited_files,
        "test_paths": result.test_paths,
    }
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def read_failure(root: Path) -> dict[str, Any] | None:
    path = failure_path(root)
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    failed_at = data.get("failed_at_ms")
    if isinstance(failed_at, int):
        age = int(time.time() * 1000) - failed_at
        if age > FAILURE_MAX_AGE_MS:
            return None
    return data


def clear_failure(root: Path) -> None:
    path = failure_path(root)
    try:
        path.unlink(missing_ok=True)
    except OSError:
        pass


def _failure_is_analyze(label: str) -> bool:
    lower = label.lower()
    return "analyze" in lower


def build_qa_autofix_prompt(failure: dict[str, Any]) -> str:
    label = str(failure.get("label") or "scoped check")
    exit_code = failure.get("exit_code")
    cwd = failure.get("cwd") or ""
    edited = failure.get("edited_files") or []
    test_paths = failure.get("test_paths") or []
    tail = str(failure.get("output_tail") or "").strip()
    is_analyze = _failure_is_analyze(label)

    edited_lines = "\n".join(f"- `{p}`" for p in edited[:25])
    if len(edited) > 25:
        edited_lines += f"\n- …and {len(edited) - 25} more"

    test_line = ", ".join(f"`{p}`" for p in test_paths[:10]) if test_paths else "see failure report"
    if len(test_paths) > 10:
        test_line += f", +{len(test_paths) - 10} more"

    argv = failure.get("argv") or []
    rerun = " ".join(str(a) for a in argv) if argv else "python scripts/qa_scoped_tests.py"
    if is_analyze and edited:
        rerun_files = " ".join(f'"{p}"' for p in edited[:20])
        rerun = f"python scripts/qa_scoped_tests.py --files {rerun_files}"

    failure_kind = "analyze" if is_analyze else "unit tests"
    lines = [
        f"**Mode: FIX** — scoped {failure_kind} failed after the last agent edit session.",
        "",
        f"**Failed step:** {label} (exit {exit_code})",
        f"**Working directory:** `{cwd}`",
    ]
    if not is_analyze:
        lines.append(f"**Scoped tests:** {test_line}")
    lines.extend(
        [
            "",
            "Read `.cursor/hooks/state/qa-test-failure.json` for full details.",
            "",
            f"**Edited files:**\n{edited_lines or '- (none listed)'}",
            "",
        ]
    )
    if is_analyze:
        lines.extend(
            [
                "Fix **all** analyzer issues (warnings count in CI): remove unused imports, "
                "unused locals, and dead code; run `dart fix --apply` in the package cwd when safe. "
                "Re-run scoped checks:",
                f"`{rerun}` (from repo root).",
            ]
        )
    else:
        lines.extend(
            [
                "Fix production code and/or tests with **minimal** diffs. Re-run the exact failing command:",
                f"`{rerun}` (from the repo root or cwd above).",
                "Do not refactor unrelated files. Add tests for new behavior per AGENTS.md.",
            ]
        )
    lines.extend(
        [
            "",
            "Follow [AGENTS.md](AGENTS.md) and "
            "[`.cursor/rules/waddle-view-tests.mdc`](.cursor/rules/waddle-view-tests.mdc) / "
            "[`.cursor/rules/waddle-controller-tests.mdc`](.cursor/rules/waddle-controller-tests.mdc).",
        ]
    )
    if tail:
        lines.extend(["", "**Command output (tail):**", "```", tail, "```"])

    body = "\n".join(lines)
    fix_tail = (
        "Repair the analyzer failures above (zero issues required). Report briefly and stop."
        if is_analyze
        else "Repair the scoped test failures above. When tests pass, report briefly and stop."
    )
    return f"{body}\n\n---\n\n/qa FIX\n\n{fix_tail}"
