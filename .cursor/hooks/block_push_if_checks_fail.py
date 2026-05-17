#!/usr/bin/env python3
"""Cursor beforeShellExecution: block agent git push when pre-push checks fail."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from hook_common import read_stdin_json, repo_root
from prepush_autofix import build_prepush_autofix_message


def is_git_push(command: str) -> bool:
    trimmed = command.strip()
    if not re.match(r"^git\s+", trimmed):
        return False
    # git push, git -C path push, git -c key=val push
    return bool(re.search(r"\bpush\b", trimmed))


def main() -> None:
    payload = read_stdin_json()
    command = payload.get("command", "")
    if not isinstance(command, str) or not is_git_push(command):
        print(json.dumps({"permission": "allow"}))
        sys.exit(0)

    root = repo_root()
    script = root / "scripts" / "pre_push_checks.py"
    env = os.environ.copy()
    env["WADDLE_REPO_ROOT"] = str(root)

    result = subprocess.run(
        [sys.executable, str(script)],
        cwd=root,
        env=env,
    )

    if result.returncode == 0:
        print(json.dumps({"permission": "allow"}))
        sys.exit(0)

    autofix = build_prepush_autofix_message(root)
    agent_message = autofix or (
        "git push was blocked because scripts/pre_push_checks.py failed. "
        "Run the same script locally, fix test/analyze failures, then push. "
        "Do not use --no-verify unless the user explicitly requests it."
    )

    print(
        json.dumps(
            {
                "permission": "deny",
                "user_message": (
                    "Pre-push checks failed (tests/analyze). The agent will start fixing "
                    "automatically—retry git push after checks pass."
                ),
                "agent_message": agent_message,
            }
        )
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
