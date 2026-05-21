#!/usr/bin/env python3
"""Post-commit build + test gate for Git post-commit hook and Cursor fix loops.

Phase 1: codegen, analyze, and TypeScript builds (no unit tests).
Phase 2: pre-push-equivalent unit tests (build steps already run in phase 1).

Examples (from repo root):

  python scripts/post_commit_gate.py
  python scripts/post_commit_gate.py --build-only
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from commit_build_failure_report import clear_failure as clear_build_failure
from commit_build_failure_report import write_failure as write_build_failure
from commit_fix_loop import clear_loop, ensure_loop_started
from commit_test_failure_report import clear_failure as clear_test_failure
from commit_test_failure_report import write_failure as write_test_failure
from waddle_check_common import (
    Step,
    build_post_commit_build_steps,
    collect_commit_changed_files,
    configure_stdio_encoding,
    git_head_sha,
    repo_root,
    run_dart_workspace_steps,
    run_step,
    scoped_paths,
)

# Controller build steps run in phase 1 only.
_POST_COMMIT_TEST_STEP_PREFIXES = (
    "flutter test",
    "dart test",
    "deploy unit tests",
    "npm run lint (waddle_controller)",
)


def skip_checks() -> bool:
    return os.environ.get("WADDLE_SKIP_POST_COMMIT_CHECKS", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }


def _is_post_commit_test_step(step: Step) -> bool:
    return step.label.startswith(_POST_COMMIT_TEST_STEP_PREFIXES)


def build_test_steps(root: Path, scopes: set[str], changed: list[str] | None) -> list[Step]:
    from pre_push_checks import build_steps

    steps = build_steps(root, scopes, changed)
    return [s for s in steps if _is_post_commit_test_step(s)]


def _record_build_failure(
    root: Path,
    step: Step,
    exit_code: int,
    output: str,
    scopes: set[str],
    commit_sha: str,
) -> None:
    write_build_failure(
        root,
        label=step.label,
        cwd=step.cwd,
        argv=step.argv,
        exit_code=exit_code,
        output=output,
        scopes=sorted(scopes),
        commit_sha=commit_sha,
    )


def _record_test_failure(
    root: Path,
    step: Step,
    exit_code: int,
    output: str,
    scopes: set[str],
    commit_sha: str,
) -> None:
    write_test_failure(
        root,
        label=step.label,
        cwd=step.cwd,
        argv=step.argv,
        exit_code=exit_code,
        output=output,
        scopes=sorted(scopes),
        commit_sha=commit_sha,
    )


def run_build_phase(
    root: Path,
    scopes: set[str],
    changed: list[str] | None,
    commit_sha: str,
) -> int:
    print("\n==> Post-commit phase 1: build / analyze", flush=True)
    steps = build_post_commit_build_steps(root, scopes, changed)
    if not steps:
        print("Post-commit build: nothing to run for scopes.", flush=True)
        return 0

    dart_steps = [
        s
        for s in steps
        if s.label.startswith(
            ("flutter pub get", "build_runner", "dart analyze", "flutter analyze")
        )
    ]
    other_steps = [s for s in steps if s not in dart_steps]

    if dart_steps:
        code, failed = run_dart_workspace_steps(dart_steps)
        if code != 0:
            ensure_loop_started(root, commit_sha)
            _record_build_failure(root, failed or dart_steps[0], code, "", scopes, commit_sha)
            _print_build_failed()
            return code

    for step in other_steps:
        code, output = run_step(step)
        if code != 0:
            ensure_loop_started(root, commit_sha)
            _record_build_failure(root, step, code, output, scopes, commit_sha)
            _print_build_failed()
            return code

    clear_build_failure(root)
    print("\nPost-commit build phase passed.", flush=True)
    return 0


def run_test_phase(
    root: Path,
    scopes: set[str],
    changed: list[str] | None,
    commit_sha: str,
) -> int:
    print("\n==> Post-commit phase 2: unit tests", flush=True)
    steps = build_test_steps(root, scopes, changed)
    if not steps:
        print("Post-commit tests: nothing to run for scopes.", flush=True)
        return 0

    dart_steps = [s for s in steps if s.label.startswith(("flutter test", "dart test"))]
    other_steps = [s for s in steps if s not in dart_steps]

    if dart_steps:
        code, failed = run_dart_workspace_steps(dart_steps)
        if code != 0:
            ensure_loop_started(root, commit_sha)
            _record_test_failure(root, failed or dart_steps[0], code, "", scopes, commit_sha)
            _print_test_failed()
            return code

    for step in other_steps:
        code, output = run_step(step)
        if code != 0:
            ensure_loop_started(root, commit_sha)
            _record_test_failure(root, step, code, output, scopes, commit_sha)
            _print_test_failed()
            return code

    clear_test_failure(root)
    print("\nPost-commit test phase passed.", flush=True)
    return 0


def _print_build_failed() -> None:
    print(
        "\nPost-commit build failed. Failure saved to "
        ".cursor/hooks/state/commit-build-failure.json",
        file=sys.stderr,
    )
    print(
        "Cursor: /build-fix will auto-continue when a session is active (20 min cap).",
        file=sys.stderr,
    )
    print("Skip: WADDLE_SKIP_POST_COMMIT_CHECKS=1", file=sys.stderr)


def _print_test_failed() -> None:
    print(
        "\nPost-commit tests failed. Failure saved to "
        ".cursor/hooks/state/commit-test-failure.json",
        file=sys.stderr,
    )
    print(
        "Cursor: /test-fix will auto-continue when a session is active (20 min cap).",
        file=sys.stderr,
    )
    print("Skip: WADDLE_SKIP_POST_COMMIT_CHECKS=1", file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    configure_stdio_encoding()
    parser = argparse.ArgumentParser(description="Post-commit build + test gate.")
    parser.add_argument(
        "--build-only",
        action="store_true",
        help="Run phase 1 (build/analyze) only.",
    )
    args = parser.parse_args(argv)

    if skip_checks():
        print("WADDLE_SKIP_POST_COMMIT_CHECKS set — skipping post-commit gate.")
        return 0

    root = repo_root()
    os.environ.setdefault("WADDLE_REPO_ROOT", str(root))
    commit_sha = git_head_sha(root)

    changed = collect_commit_changed_files(root)
    scopes = scoped_paths(changed)
    if not scopes:
        print("No Dart/controller/deploy paths in commit — skipping post-commit gate.")
        clear_build_failure(root)
        clear_test_failure(root)
        clear_loop(root)
        return 0

    if changed is None:
        print("Running full post-commit gate (initial commit or unknown diff).")
    else:
        print(f"Scoped post-commit gate: {', '.join(sorted(scopes))}")

    build_code = run_build_phase(root, scopes, changed, commit_sha)
    if build_code != 0:
        return build_code

    if args.build_only:
        return 0

    test_code = run_test_phase(root, scopes, changed, commit_sha)
    if test_code != 0:
        return test_code

    clear_build_failure(root)
    clear_test_failure(root)
    clear_loop(root)
    print("\nPost-commit gate passed (build + tests).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
