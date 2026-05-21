#!/usr/bin/env python3
"""Wall-clock and iteration state for post-commit build/test fix loops."""

from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

LOOP_REL = Path(".cursor/hooks/state/commit-fix-loop.json")
DEFAULT_MAX_WALL_MS = 20 * 60 * 1000
DEFAULT_BUILD_ITER_LIMIT = 15
DEFAULT_TEST_ITER_LIMIT = 15


def loop_path(root: Path) -> Path:
    return root / LOOP_REL


def max_wall_ms() -> int:
    raw = os.environ.get("WADDLE_COMMIT_FIX_MAX_WALL_MS", "").strip()
    if raw.isdigit():
        return int(raw)
    return DEFAULT_MAX_WALL_MS


def build_iter_limit() -> int:
    raw = os.environ.get("WADDLE_COMMIT_BUILD_FIX_LOOP_LIMIT", "").strip()
    if raw.isdigit():
        return int(raw)
    return DEFAULT_BUILD_ITER_LIMIT


def test_iter_limit() -> int:
    raw = os.environ.get("WADDLE_COMMIT_TEST_FIX_LOOP_LIMIT", "").strip()
    if raw.isdigit():
        return int(raw)
    return DEFAULT_TEST_ITER_LIMIT


def read_loop(root: Path) -> dict[str, Any] | None:
    path = loop_path(root)
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def write_loop(root: Path, payload: dict[str, Any]) -> None:
    path = loop_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def clear_loop(root: Path) -> None:
    path = loop_path(root)
    try:
        path.unlink(missing_ok=True)
    except OSError:
        pass


def ensure_loop_started(root: Path, commit_sha: str) -> dict[str, Any]:
    """Start or reset the loop timer for this commit SHA."""
    now = int(time.time() * 1000)
    state = read_loop(root)
    if state and state.get("commit_sha") == commit_sha:
        return state
    payload: dict[str, Any] = {
        "started_at_ms": now,
        "commit_sha": commit_sha,
        "build_iterations": 0,
        "test_iterations": 0,
    }
    write_loop(root, payload)
    return payload


def wall_clock_exceeded(state: dict[str, Any] | None) -> bool:
    if not state:
        return False
    started = state.get("started_at_ms")
    if not isinstance(started, int):
        return False
    return int(time.time() * 1000) - started > max_wall_ms()


def increment_build_iteration(root: Path) -> dict[str, Any] | None:
    state = read_loop(root)
    if not state:
        return None
    state["build_iterations"] = int(state.get("build_iterations") or 0) + 1
    write_loop(root, state)
    return state


def increment_test_iteration(root: Path) -> dict[str, Any] | None:
    state = read_loop(root)
    if not state:
        return None
    state["test_iterations"] = int(state.get("test_iterations") or 0) + 1
    write_loop(root, state)
    return state


def build_iteration_exceeded(state: dict[str, Any] | None) -> bool:
    if not state:
        return False
    return int(state.get("build_iterations") or 0) >= build_iter_limit()


def test_iteration_exceeded(state: dict[str, Any] | None) -> bool:
    if not state:
        return False
    return int(state.get("test_iterations") or 0) >= test_iter_limit()


def build_help_request_prompt() -> str:
    return (
        "Post-commit auto-fix **stopped after 20 minutes** (or iteration limit). "
        "Build and/or test checks are still failing.\n\n"
        "Read `.cursor/hooks/state/commit-build-failure.json` and "
        "`.cursor/hooks/state/commit-test-failure.json` if present. "
        "**Summarize blockers**, suggest concrete next steps, and **wait for user direction**. "
        "Do **not** start another `/build-fix` or `/test-fix` pass unless the user explicitly asks.\n\n"
        "To resume auto-fix: fix issues manually and run `python scripts/post_commit_gate.py`, "
        "or delete `.cursor/hooks/state/commit-fix-loop.json` and make a new commit."
    )
