#!/usr/bin/env python3
"""Run scoped analyze and unit tests for agent-edited files (Cursor stop hook).

Examples (from repo root):

  python scripts/qa_scoped_tests.py --files apps/waddle_controller/src/api/foo.ts
  python scripts/qa_scoped_tests.py --files-json '["packages/waddle_shared/lib/foo.dart"]'

Set WADDLE_SKIP_QA_HOOK_TESTS=1 to skip analyze and tests (exit 0).
Set WADDLE_SKIP_QA_HOOK_ANALYZE=1 to skip analyze only (tests still run).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from qa_test_failure_report import clear_failure, write_failure
from waddle_check_common import configure_stdio_encoding, repo_root, run_qa_scoped_tests


def main(argv: list[str] | None = None) -> int:
    configure_stdio_encoding()
    parser = argparse.ArgumentParser(
        description="Run scoped Dart analyze and unit tests for edited files.",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        default=[],
        help="Repo-relative edited file paths",
    )
    parser.add_argument(
        "--files-json",
        help="JSON array of repo-relative paths (used by hooks)",
    )
    args = parser.parse_args(argv)

    if os.environ.get("WADDLE_SKIP_QA_HOOK_TESTS", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }:
        print("QA scoped checks: skipped (WADDLE_SKIP_QA_HOOK_TESTS).", flush=True)
        return 0

    files: list[str] = list(args.files)
    if args.files_json:
        try:
            parsed = json.loads(args.files_json)
            if isinstance(parsed, list):
                files.extend(str(p) for p in parsed if p)
        except json.JSONDecodeError:
            print("ERROR: --files-json must be a JSON array", file=sys.stderr)
            return 2

    root = repo_root()
    os.environ.setdefault("WADDLE_REPO_ROOT", str(root))

    result = run_qa_scoped_tests(root, files)
    if result.exit_code == 0:
        clear_failure(root)
        return 0

    write_failure(root, result)
    return result.exit_code if result.exit_code != 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
