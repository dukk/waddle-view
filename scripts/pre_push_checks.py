#!/usr/bin/env python3
"""Run CI-equivalent tests before git push. Used by .githooks/pre-push and Cursor hooks."""

from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Step:
    label: str
    argv: list[str]
    cwd: Path


def repo_root() -> Path:
    env = os.environ.get("WADDLE_REPO_ROOT")
    if env:
        return Path(env).resolve()
    here = Path(__file__).resolve().parent
    return (here / "..").resolve()


def skip_checks() -> bool:
    return os.environ.get("WADDLE_SKIP_PREPUSH_CHECKS", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }


def run_step(step: Step) -> int:
    print(f"\n==> {step.label}", flush=True)
    print(f"    cwd: {step.cwd}", flush=True)
    print(f"    cmd: {' '.join(step.argv)}", flush=True)
    result = subprocess.run(step.argv, cwd=step.cwd)
    if result.returncode != 0:
        print(f"\nFAILED: {step.label} (exit {result.returncode})", file=sys.stderr)
    return result.returncode


def scoped_paths(changed: list[str] | None) -> set[str]:
    """Return scope tokens: dart_workspace, controller, deploy."""
    if changed is None:
        return {"dart_workspace", "controller", "deploy"}
    scopes: set[str] = set()
    for path in changed:
        p = path.replace("\\", "/")
        if p.startswith("deploy/"):
            scopes.add("deploy")
        if p.startswith("apps/waddle_controller/"):
            scopes.add("controller")
        if (
            p.startswith("apps/waddle_display/")
            or p.startswith("apps/waddlectl/")
            or p.startswith("packages/")
            or p == "pubspec.yaml"
            or p.startswith("pubspec.lock")
        ):
            scopes.add("dart_workspace")
    return scopes


def git_changed_files(root: Path, remote_sha: str, local_sha: str) -> list[str] | None:
    zero = "0" * 40
    if not remote_sha or remote_sha == zero:
        return None
    result = subprocess.run(
        ["git", "diff", "--name-only", remote_sha, local_sha],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return lines


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


def build_steps(root: Path, scopes: set[str]) -> list[Step]:
    steps: list[Step] = []
    shared = root / "packages" / "waddle_shared"
    providers = root / "packages" / "waddle_data_providers"
    display = root / "apps" / "waddle_display"
    waddlectl = root / "apps" / "waddlectl"
    controller = root / "apps" / "waddle_controller"

    if "dart_workspace" in scopes:
        steps.extend(
            [
                Step("flutter pub get", ["flutter", "pub", "get"], root),
                Step(
                    "build_runner (waddle_shared)",
                    [
                        "dart",
                        "run",
                        "build_runner",
                        "build",
                        "--delete-conflicting-outputs",
                    ],
                    shared,
                ),
                Step(
                    "flutter test (waddle_shared)",
                    ["flutter", "test"],
                    shared,
                ),
                Step(
                    "dart test (waddle_data_providers)",
                    ["dart", "test"],
                    providers,
                ),
                Step(
                    "flutter analyze (waddle_display)",
                    ["flutter", "analyze"],
                    display,
                ),
                Step(
                    "flutter test (waddle_display)",
                    ["flutter", "test", "--timeout=60s"],
                    display,
                ),
                Step(
                    "flutter test (waddlectl)",
                    ["flutter", "test"],
                    waddlectl,
                ),
            ]
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
        npm = "npm.cmd" if os.name == "nt" else "npm"
        steps.extend(
            [
                Step(
                    "npm ci (waddle_controller)",
                    [npm, "ci"],
                    controller,
                ),
                Step(
                    "npm run build (waddle_controller)",
                    [npm, "run", "build"],
                    controller,
                ),
                Step(
                    "npm run lint (waddle_controller)",
                    [npm, "run", "lint"],
                    controller,
                ),
            ]
        )

    return steps


def main() -> int:
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

    steps = build_steps(root, scopes)
    for step in steps:
        code = run_step(step)
        if code != 0:
            print(
                "\nPush blocked: fix failures or push with --no-verify "
                "(not recommended).",
                file=sys.stderr,
            )
            print(
                "To skip locally: set WADDLE_SKIP_PREPUSH_CHECKS=1",
                file=sys.stderr,
            )
            return code

    print("\nPre-push checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
