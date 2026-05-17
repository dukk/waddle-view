#!/usr/bin/env python3
"""Persist pre-push failure details for Cursor hooks to auto-continue fixes."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

FAILURE_REL = Path(".cursor/hooks/state/prepush-last-failure.json")
OUTPUT_TAIL_MAX = 12_000
FAILURE_MAX_AGE_MS = 2 * 60 * 60 * 1000


def failure_path(root: Path) -> Path:
    return root / FAILURE_REL


def _tail(text: str, limit: int = OUTPUT_TAIL_MAX) -> str:
    if len(text) <= limit:
        return text
    return f"… ({len(text) - limit} chars truncated)\n{text[-limit:]}"


def write_failure(
    root: Path,
    *,
    label: str,
    cwd: Path,
    argv: list[str],
    exit_code: int,
    output: str,
    scopes: list[str],
) -> None:
    path = failure_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload: dict[str, Any] = {
        "failed_at_ms": int(time.time() * 1000),
        "label": label,
        "cwd": str(cwd),
        "argv": argv,
        "exit_code": exit_code,
        "output_tail": _tail(output),
        "scopes": scopes,
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


def build_autofix_prompt(failure: dict[str, Any]) -> str:
    label = str(failure.get("label") or "pre-push step")
    exit_code = failure.get("exit_code")
    cwd = failure.get("cwd") or ""
    scopes = failure.get("scopes") or []
    scope_line = ", ".join(scopes) if scopes else "unknown"
    tail = str(failure.get("output_tail") or "").strip()

    lines = [
        "Pre-push checks failed before `git push` was allowed.",
        "",
        f"**Failed step:** {label} (exit {exit_code})",
        f"**Working directory:** `{cwd}`",
        f"**Scopes:** {scope_line}",
        "",
        "Fix every reported issue, then run `python scripts/pre_push_checks.py` from the "
        "repo root. When it exits 0, retry the same `git push`.",
        "Do **not** use `--no-verify` unless the user explicitly asked.",
        "",
        "Follow [AGENTS.md](AGENTS.md) and "
        "[`.cursor/skills/run-waddle-checks/SKILL.md`](.cursor/skills/run-waddle-checks/SKILL.md).",
    ]
    if tail:
        lines.extend(["", "**Command output (tail):**", "```", tail, "```"])

    body = "\n".join(lines)
    return (
        f"{body}\n\n"
        "---\n\n"
        "/multitask Fix the pre-push failure above.\n\n"
        "Repair analyze, test, lint, or build errors for the failed scope only—no unrelated "
        "refactors. Re-run `python scripts/pre_push_checks.py` until it passes, then tell "
        "the parent agent to retry `git push`."
    )
