#!/usr/bin/env python3
"""Run CI-equivalent tests before git push. Used by .githooks/pre-push and Cursor hooks.

Controller JavaScript deps are **not** reinstalled here (no ``npm ci``). A running
``npm run dev`` (Vite/tsx) locks native modules under ``node_modules`` on Windows and
causes ``EPERM`` during ``npm ci``. GitHub Actions runs ``npm ci`` on a clean runner;
pre-push only runs ``npm run build`` and ``npm run lint`` against your existing tree.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


# Pre-push never runs npm ci (see module docstring).
PREPUSH_SKIP_NPM_CI_REASON = (
    "pre-push does not run npm ci (CI installs on a clean runner; "
    "local npm run dev locks native modules on Windows)"
)


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


_path_augmented = False


def _windows_registry_path() -> list[str]:
    if os.name != "nt":
        return []
    try:
        import winreg
    except ImportError:
        return []

    entries: list[str] = []

    def read_path(root, subkey: str, name: str) -> None:
        try:
            with winreg.OpenKey(root, subkey) as key:
                value, _ = winreg.QueryValueEx(key, name)
        except OSError:
            return
        if isinstance(value, str) and value.strip():
            entries.extend(value.split(os.pathsep))

    read_path(winreg.HKEY_CURRENT_USER, "Environment", "Path")
    read_path(
        winreg.HKEY_LOCAL_MACHINE,
        r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment",
        "Path",
    )
    return entries


def augment_path_for_tooling() -> None:
    """Git hooks on Windows often have a minimal PATH; restore user + SDK paths."""
    global _path_augmented
    if _path_augmented:
        return
    _path_augmented = True

    extra: list[str] = []
    for key in ("FLUTTER_ROOT", "DART_SDK"):
        value = os.environ.get(key)
        if value:
            extra.append(str(Path(value) / "bin"))

    if os.name == "nt":
        extra.extend(_windows_registry_path())
        local_app_data = os.environ.get("LOCALAPPDATA", "")
        candidates = [
            Path(local_app_data) / "flutter" / "bin",
            Path.home() / "flutter" / "bin",
            Path.home() / "develop" / "flutter" / "bin",
            Path("C:/flutter/bin"),
            Path("C:/src/flutter/bin"),
        ]
        repo = repo_root()
        candidates.append(repo / ".flutter-sdk" / "bin")
        for path in candidates:
            if path.is_dir():
                extra.append(str(path))

    current = os.environ.get("PATH", "")
    combined: list[str] = []
    seen: set[str] = set()
    for entry in extra + ([current] if current else []):
        for part in entry.split(os.pathsep):
            part = part.strip()
            if not part:
                continue
            key = part.lower()
            if key in seen:
                continue
            seen.add(key)
            combined.append(part)
    if combined:
        os.environ["PATH"] = os.pathsep.join(combined)


def _configure_stdio_encoding() -> None:
    """Git hooks on Windows often default to a legacy console code page (e.g. cp1252)."""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (OSError, ValueError):
            pass


def _emit_stream(stream, text: str) -> None:
    """Write subprocess output without crashing on non-ASCII when the console is narrow."""
    if not text:
        return
    payload = text if text.endswith("\n") else f"{text}\n"
    try:
        stream.write(payload)
        stream.flush()
    except UnicodeEncodeError:
        encoding = getattr(stream, "encoding", None) or "utf-8"
        buf = getattr(stream, "buffer", None)
        if buf is not None:
            buf.write(payload.encode(encoding, errors="replace"))
            buf.flush()
        else:
            stream.write(payload.encode(encoding, errors="replace").decode(encoding))
            stream.flush()


def _npm_lockfile_satisfied(project_dir: Path) -> bool:
    """True when ``node_modules/.package-lock.json`` is at least as new as ``package-lock.json``."""
    lock = project_dir / "package-lock.json"
    stamp = project_dir / "node_modules" / ".package-lock.json"
    if not lock.is_file() or not stamp.is_file():
        return False
    try:
        return lock.stat().st_mtime_ns <= stamp.stat().st_mtime_ns
    except OSError:
        return False


def _waddle_node_tls_dir(controller: Path) -> Path:
    return controller.parent.parent / "packages" / "waddle_node_tls"


def _controller_dev_server_running(controller: Path) -> bool:
    """True when node appears to be running waddle_controller dev tooling."""
    ctrl = str(controller.resolve())
    ctrl_lower = ctrl.lower()
    dev_tokens = ("vite", "tsx", "concurrently", "esbuild")

    def matches(cmdline: str) -> bool:
        low = cmdline.lower()
        return ctrl_lower in low and any(token in low for token in dev_tokens)

    if os.name == "nt":
        script = (
            "Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" "
            "| ForEach-Object { $_.CommandLine }"
        )
        try:
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command", script],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired):
            return False
        if result.returncode != 0:
            return False
        return any(matches(line) for line in result.stdout.splitlines())

    try:
        result = subprocess.run(
            ["ps", "-eww", "-o", "command="],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    if result.returncode != 0:
        return False
    return any(matches(line) for line in result.stdout.splitlines())


def controller_lockfile_stale_warning(controller: Path) -> str | None:
    """Warn when lockfiles changed but node_modules may be stale (non-blocking)."""
    messages: list[str] = []
    if not _npm_lockfile_satisfied(controller):
        messages.append(
            "apps/waddle_controller: package-lock.json is newer than node_modules"
        )
    tls = _waddle_node_tls_dir(controller)
    if (tls / "package-lock.json").is_file() and not _npm_lockfile_satisfied(tls):
        messages.append(
            "packages/waddle_node_tls: package-lock.json is newer than node_modules"
        )
    if not messages:
        return None
    hint = (
        " — run `npm ci` in apps/waddle_controller after stopping `npm run dev` "
        "(CI verifies a clean install)."
    )
    if _controller_dev_server_running(controller):
        hint = (
            " — stop `npm run dev` in apps/waddle_controller, then run `npm ci` "
            "(dev locks native modules on Windows)."
        )
    return "; ".join(messages) + hint


def resolve_argv(argv: list[str]) -> list[str]:
    """Resolve CLI names to absolute paths (required on Windows for .bat shims)."""
    if not argv:
        return argv
    augment_path_for_tooling()
    executable = shutil.which(argv[0])
    if executable:
        return [executable, *argv[1:]]
    return argv


def run_step(step: Step) -> tuple[int, str]:
    argv = resolve_argv(step.argv)
    print(f"\n==> {step.label}", flush=True)
    print(f"    cwd: {step.cwd}", flush=True)
    print(f"    cmd: {' '.join(argv)}", flush=True)
    if argv == step.argv and shutil.which(step.argv[0]) is None:
        msg = (
            f"\nFAILED: command not found on PATH: {step.argv[0]!r}. "
            "Install it or add it to PATH (Git hooks use a minimal environment)."
        )
        print(msg, file=sys.stderr)
        return 127, msg
    result = subprocess.run(
        argv,
        cwd=step.cwd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.stdout:
        _emit_stream(sys.stdout, result.stdout)
    if result.stderr:
        _emit_stream(sys.stderr, result.stderr)
    combined = f"{result.stdout or ''}{result.stderr or ''}"
    if result.returncode != 0:
        print(f"\nFAILED: {step.label} (exit {result.returncode})", file=sys.stderr)
    return result.returncode, combined


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
        resolve_argv(["git", "diff", "--name-only", remote_sha, local_sha]),
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
    _configure_stdio_encoding()

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
        code, output = run_step(step)
        if code != 0:
            _record_failure(root, step, code, output, scopes)
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
            return code

    try:
        from prepush_failure_report import clear_failure

        clear_failure(root)
    except ImportError:
        pass

    print("\nPre-push checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
