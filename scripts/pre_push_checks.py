#!/usr/bin/env python3
"""Run CI-equivalent tests before git push. Used by .githooks/pre-push and Cursor hooks.

Controller JavaScript deps are **not** reinstalled here (no ``npm ci``). A running
``npm run dev`` (Vite/tsx) locks native modules under ``node_modules`` on Windows and
causes ``EPERM`` during ``npm ci``. GitHub Actions runs ``npm ci`` on a clean runner;
pre-push only runs ``npm run build`` and ``npm run lint`` against your existing tree.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from waddle_check_common import (
    CheckTier,
    Step,
    _controller_dev_server_running,
    _npm_lockfile_satisfied,
    build_dart_workspace_steps,
    configure_stdio_encoding,
    controller_lockfile_stale_warning,
    repo_root,
    run_dart_workspace_steps,
    run_step,
    scoped_paths,
)


PREPUSH_SKIP_NPM_CI_REASON = (
    "pre-push does not run npm ci (CI installs on a clean runner; "
    "local npm run dev locks native modules on Windows)"
)


def skip_checks() -> bool:
    return os.environ.get("WADDLE_SKIP_PREPUSH_CHECKS", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }


def read_prepush_refs(root: Path) -> list[tuple[str, str, str, str]]:
    """Parse git pre-push stdin: local_ref local_sha remote_ref remote_sha."""
    if not sys.stdin.isatty():
        lines = sys.stdin.read().splitlines()
    else:
        lines = []
    refs: list[tuple[str, str, str, str]] = []
    for line in lines:
        parts = line.split()
        if len(parts) >= 4:
            refs.append((parts[0], parts[1], parts[2], parts[3]))
    return refs


def collect_changed_files(root: Path) -> list[str] | None:
    refs = read_prepush_refs(root)
    if not refs:
        return None
    from waddle_check_common import git_changed_files

    all_changed: set[str] = set()
    any_full = False
    for _local_ref, local_sha, _remote_ref, remote_sha in refs:
        changed = git_changed_files(root, remote_sha, local_sha)
        if changed is None:
            any_full = True
        else:
            all_changed.update(changed)
    if any_full:
        return None
    return sorted(all_changed)


def build_steps(root: Path, scopes: set[str], changed: list[str] | None) -> list[Step]:
    steps: list[Step] = []
    controller = root / "apps" / "waddle_controller"

    if "dart_workspace" in scopes:
        steps.extend(
            build_dart_workspace_steps(
                root,
                CheckTier.PREPUSH,
                changed,
                scope_tests=False,
            )
        )

    if "deploy" in scopes:
        steps.append(
            Step(
                "deploy unit tests",
                [
                    sys.executable,
                    "-m",
                    "unittest",
                    "discover",
                    "-s",
                    "deploy",
                    "-p",
                    "test_*.py",
                ],
                root,
            )
        )

    if "controller" in scopes:
        print(
            f"\n==> npm ci (waddle_controller) — skipped ({PREPUSH_SKIP_NPM_CI_REASON})",
            flush=True,
        )
        stale = controller_lockfile_stale_warning(controller)
        if stale:
            print(f"\nWARNING: {stale}", file=sys.stderr, flush=True)
        steps.extend(
            [
                Step(
                    "npm run build (waddle_controller)",
                    ["npm", "run", "build"],
                    controller,
                ),
                Step(
                    "npm run lint (waddle_controller)",
                    ["npm", "run", "lint"],
                    controller,
                ),
            ]
        )

    return steps


def _record_failure(
    root: Path,
    step: Step,
    exit_code: int,
    output: str,
    scopes: set[str],
) -> None:
    from prepush_failure_report import write_failure

    write_failure(
        root,
        label=step.label,
        cwd=step.cwd,
        argv=step.argv,
        exit_code=exit_code,
        output=output,
        scopes=sorted(scopes),
    )


def main() -> int:
    configure_stdio_encoding()

    if skip_checks():
        print("WADDLE_SKIP_PREPUSH_CHECKS set — skipping pre-push checks.")
        return 0

    root = repo_root()
    os.environ.setdefault("WADDLE_REPO_ROOT", str(root))

    changed = collect_changed_files(root)
    scopes = scoped_paths(changed)
    if not scopes:
        print("No Dart/controller/deploy paths in push — skipping pre-push checks.")
        return 0

    if changed is None:
        print("Running full pre-push check suite (new branch or unknown diff).")
    else:
        print(f"Scoped pre-push checks: {', '.join(sorted(scopes))}")

    steps = build_steps(root, scopes, changed)

    dart_steps = [
        s
        for s in steps
        if s.label.startswith(("flutter pub get", "build_runner", "flutter test", "dart test", "flutter analyze"))
    ]
    other_steps = [s for s in steps if s not in dart_steps]

    if dart_steps:
        code, failed = run_dart_workspace_steps(dart_steps)
        if code != 0:
            _record_failure(root, failed or dart_steps[0], code, "", scopes)
            _print_push_blocked()
            return code

    for step in other_steps:
        code, output = run_step(step)
        if code != 0:
            _record_failure(root, step, code, output, scopes)
            _print_push_blocked()
            return code

    try:
        from prepush_failure_report import clear_failure

        clear_failure(root)
    except ImportError:
        pass

    print("\nPre-push checks passed.")
    return 0


def _print_push_blocked() -> None:
    print(
        "\nPush blocked: fix failures or push with --no-verify "
        "(not recommended).",
        file=sys.stderr,
    )
    print(
        "To skip locally: set WADDLE_SKIP_PREPUSH_CHECKS=1",
        file=sys.stderr,
    )
    print(
        "Cursor Agent: failure saved to .cursor/hooks/state/prepush-last-failure.json "
        "(retry git push from agent chat to auto-continue fixes).",
        file=sys.stderr,
    )


if __name__ == "__main__":
    sys.exit(main())
