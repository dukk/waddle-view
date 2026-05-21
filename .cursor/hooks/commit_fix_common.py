#!/usr/bin/env python3
"""Shared post-commit build/test fix follow-up for Cursor hooks."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def _scripts_path(root: Path) -> None:
    scripts = str(root / "scripts")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)


def run_post_commit_gate(root: Path) -> int:
    script = root / "scripts" / "post_commit_gate.py"
    env = os.environ.copy()
    env["WADDLE_REPO_ROOT"] = str(root)
    result = subprocess.run(
        [sys.executable, str(script)],
        cwd=root,
        env=env,
    )
    return result.returncode


def _commit_fix_pending(root: Path) -> bool:
    _scripts_path(root)
    from commit_build_failure_report import read_failure as read_build_failure
    from commit_fix_loop import read_loop
    from commit_test_failure_report import read_failure as read_test_failure

    return bool(read_build_failure(root) or read_test_failure(root) or read_loop(root))


def resolve_commit_fix_followup(
    root: Path,
    *,
    rerun_gate: bool,
) -> str | None:
    """Return a followup_message body, or None when no commit-fix action is needed."""
    if os.environ.get("WADDLE_SKIP_POST_COMMIT_CHECKS", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }:
        return None

    if not _commit_fix_pending(root):
        return None

    _scripts_path(root)
    from commit_build_failure_report import build_autofix_prompt as build_build_prompt
    from commit_build_failure_report import read_failure as read_build_failure
    from commit_fix_loop import (
        build_help_request_prompt,
        build_iteration_exceeded,
        increment_build_iteration,
        increment_test_iteration,
        read_loop,
        test_iteration_exceeded,
        wall_clock_exceeded,
    )
    from commit_test_failure_report import build_autofix_prompt as build_test_prompt
    from commit_test_failure_report import read_failure as read_test_failure

    if rerun_gate:
        run_post_commit_gate(root)

    build_failure = read_build_failure(root)
    test_failure = read_test_failure(root)
    loop_state = read_loop(root)

    if not build_failure and not test_failure:
        return None

    if wall_clock_exceeded(loop_state):
        return build_help_request_prompt()

    if build_failure:
        if build_iteration_exceeded(loop_state):
            return build_help_request_prompt()
        increment_build_iteration(root)
        return build_build_prompt(build_failure)

    if test_failure:
        if test_iteration_exceeded(loop_state):
            return build_help_request_prompt()
        increment_test_iteration(root)
        return build_test_prompt(test_failure)

    return None


def emit_followup(message: str) -> None:
    print(json.dumps({"followup_message": message}))
