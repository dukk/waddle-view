#!/usr/bin/env python3
"""sessionStart: queue /build-fix or /test-fix when post-commit gate failed."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from commit_fix_common import resolve_commit_fix_followup
from hook_common import read_stdin_json, repo_root


def main() -> None:
    _ = read_stdin_json()
    root = repo_root()
    followup = resolve_commit_fix_followup(root, rerun_gate=False)
    if followup:
        print(json.dumps({"followup_message": followup}))
    else:
        print("{}")
    sys.exit(0)


if __name__ == "__main__":
    main()
