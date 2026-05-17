#!/usr/bin/env python3
"""Local Waddle checks: fast inner-loop tier vs full CI parity.

Examples (from repo root):

  python scripts/waddle_checks.py fast
  python scripts/waddle_checks.py fast --from-git
  python scripts/waddle_checks.py fast --test apps/waddle_display/test/foo_test.dart
  python scripts/waddle_checks.py full
  python scripts/waddle_checks.py full --controller
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from waddle_check_common import (
    CheckTier,
    Step,
    _controller_dev_server_running,
    build_dart_workspace_steps,
    configure_stdio_encoding,
    controller_lockfile_stale_warning,
    flutter_test_argv,
    git_worktree_changed_files,
    repo_root,
    run_dart_workspace_steps,
    run_step,
    run_steps,
    scoped_paths,
    test_concurrency,
)


PREPUSH_SKIP_NPM_CI_REASON = (
    "fast tier does not run npm ci (use `waddle_checks.py full --controller` or CI); "
    "stop npm run dev before npm ci on Windows"
)


def _print_controller_windows_hints(controller: Path, *, full: bool) -> None:
    if os.name != "nt":
        return
    stale = controller_lockfile_stale_warning(controller)
    if stale:
        print(f"\nWARNING: {stale}", file=sys.stderr, flush=True)
    if full and _controller_dev_server_running(controller):
        print(
            "\nWARNING: npm run dev appears to be running — stop it before npm ci "
            "(native modules are locked on Windows).",
            file=sys.stderr,
            flush=True,
        )


def build_controller_steps(root: Path, tier: CheckTier) -> list[Step]:
    controller = root / "apps" / "waddle_controller"
    steps: list[Step] = []

    if tier == CheckTier.FULL:
        steps.append(Step("npm ci (waddle_controller)", ["npm", "ci"], controller))
        steps.extend(
            [
                Step("npm run lint (waddle_controller)", ["npm", "run", "lint"], controller),
                Step(
                    "npm run test:coverage (waddle_controller)",
                    ["npm", "run", "test:coverage"],
                    controller,
                ),
                Step(
                    "npm run coverage:check (waddle_controller)",
                    ["npm", "run", "coverage:check"],
                    controller,
                ),
                Step("npm run build (waddle_controller)", ["npm", "run", "build"], controller),
                Step(
                    "npm run build:server (waddle_controller)",
                    ["npm", "run", "build:server"],
                    controller,
                ),
            ]
        )
    else:
        print(f"\n==> npm ci — skipped ({PREPUSH_SKIP_NPM_CI_REASON})", flush=True)
        steps.extend(
            [
                Step("npm run lint (waddle_controller)", ["npm", "run", "lint"], controller),
                Step(
                    "npm run test (waddle_controller)",
                    ["npm", "run", "test"],
                    controller,
                ),
                Step("npm run build (waddle_controller)", ["npm", "run", "build"], controller),
            ]
        )
    return steps


def _apply_test_override(
    steps: list[Step],
    test_path: str,
    root: Path,
) -> list[Step]:
    p = Path(test_path)
    if not p.is_absolute():
        p = (root / test_path).resolve()
    if not p.is_file():
        print(f"ERROR: --test path not found: {p}", file=sys.stderr)
        return steps

    rel = p.relative_to(root / "apps" / "waddle_display")
    display = root / "apps" / "waddle_display"
    out: list[Step] = []
    for step in steps:
        if step.label.startswith("flutter test (waddle_display)"):
            out.append(
                Step(
                    f"flutter test (waddle_display) [{rel.as_posix()}]",
                    flutter_test_argv(
                        coverage=False,
                        concurrency=test_concurrency(),
                        test_paths=[rel.as_posix()],
                    ),
                    display,
                )
            )
        else:
            out.append(step)
    return out


def main(argv: list[str] | None = None) -> int:
    configure_stdio_encoding()
    parser = argparse.ArgumentParser(description="Run Waddle local check tiers.")
    parser.add_argument(
        "tier",
        choices=("fast", "full"),
        help="fast: no coverage, conditional pub get/codegen; full: CI parity",
    )
    parser.add_argument(
        "--from-git",
        action="store_true",
        help="Limit Dart packages/tests to worktree changes vs HEAD (fast tier only)",
    )
    parser.add_argument(
        "--test",
        metavar="PATH",
        help="Run only this display test file (under apps/waddle_display)",
    )
    parser.add_argument(
        "--controller",
        action="store_true",
        help="Also run waddle_controller checks",
    )
    args = parser.parse_args(argv)

    root = repo_root()
    os.environ.setdefault("WADDLE_REPO_ROOT", str(root))
    tier = CheckTier.FULL if args.tier == "full" else CheckTier.FAST

    changed: list[str] | None = None
    if args.from_git and tier == CheckTier.FAST:
        changed = git_worktree_changed_files(root)
        if changed:
            print(f"Git-scoped fast checks ({len(changed)} path(s) vs HEAD)")
        else:
            print("No git changes vs HEAD — running display analyze only")
    elif tier == CheckTier.FULL:
        changed = None

    scope_tests = tier == CheckTier.FAST and args.from_git and bool(changed)

    if args.test:
        scopes = {"dart_workspace"}
        changed_for_dart = changed
    elif tier == CheckTier.FAST and not args.from_git:
        scopes = {"dart_workspace"}
        changed_for_dart = None
    elif args.from_git:
        scopes = scoped_paths(changed) or {"dart_workspace"}
        changed_for_dart = changed
    else:
        scopes = {"dart_workspace"}
        changed_for_dart = changed

    if "dart_workspace" in scopes or args.test or tier == CheckTier.FULL:
        if tier == CheckTier.FAST and not args.from_git and not args.test:
            display = root / "apps" / "waddle_display"
            steps = [
                Step("flutter analyze (waddle_display)", ["flutter", "analyze"], display),
            ]
            code = run_steps(steps)
        else:
            steps = build_dart_workspace_steps(
                root,
                tier,
                changed_for_dart,
                scope_tests=scope_tests,
            )
            if args.test:
                steps = _apply_test_override(steps, args.test, root)
            code, _failed = run_dart_workspace_steps(steps)
        if code != 0:
            return code

    if args.controller:
        controller = root / "apps" / "waddle_controller"
        _print_controller_windows_hints(controller, full=tier == CheckTier.FULL)
        code = run_steps(build_controller_steps(root, tier))
        if code != 0:
            return code

    label = "Full" if tier == CheckTier.FULL else "Fast"
    print(f"\n{label} checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
