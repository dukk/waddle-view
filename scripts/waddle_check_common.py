"""Shared helpers for local Waddle check scripts (pre-push, fast/full tiers)."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any


class CheckTier(str, Enum):
    PREPUSH = "prepush"
    FAST = "fast"
    FULL = "full"


@dataclass(frozen=True)
class Step:
    label: str
    argv: list[str]
    cwd: Path


# Drift codegen inputs (see AGENTS.md migration discipline).
BUILD_RUNNER_PREFIXES = (
    "packages/waddle_shared/lib/persistence/",
    "packages/waddle_shared/pubspec.yaml",
    "packages/waddle_shared/build.yaml",
)

PUBSPEC_MARKERS = ("pubspec.yaml", "pubspec.lock")

DART_PACKAGE_PREFIXES: tuple[tuple[str, str], ...] = (
    ("packages/waddle_shared/", "shared"),
    ("packages/waddle_integrations/", "integrations"),
    ("packages/waddle_plugin_sdk/", "plugin_sdk"),
    ("apps/waddle_display/", "display"),
    ("apps/waddlectl/", "waddlectl"),
)

CONTROLLER_PREFIX = "apps/waddle_controller/"


_path_augmented = False
# Node binary directory captured before augment_path_for_tooling() mutates PATH.
_node_bin_dir_before_augment: str | None = None


def _capture_node_bin_dir_before_augment() -> None:
    """Remember which `node` resolves first (e.g. Cursor Node 22 vs Program Files Node 24)."""
    global _node_bin_dir_before_augment
    if _node_bin_dir_before_augment is not None:
        return
    node = shutil.which("node")
    if node:
        _node_bin_dir_before_augment = str(Path(node).resolve().parent)


def _subprocess_env_for_cwd(cwd: Path) -> dict[str, str] | None:
    """Prefer pre-augment Node for waddle_controller (better-sqlite3 ABI matches engines)."""
    if "waddle_controller" not in str(cwd).replace("\\", "/"):
        return None
    preferred = _node_bin_dir_before_augment
    if not preferred:
        return None
    env = os.environ.copy()
    env["PATH"] = preferred + os.pathsep + env.get("PATH", "")
    return env


def repo_root() -> Path:
    env = os.environ.get("WADDLE_REPO_ROOT")
    if env:
        return Path(env).resolve()
    here = Path(__file__).resolve().parent
    return (here / "..").resolve()


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
    _capture_node_bin_dir_before_augment()
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


def configure_stdio_encoding() -> None:
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (OSError, ValueError):
            pass


def _emit_stream(stream, text: str) -> None:
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


def resolve_argv(argv: list[str]) -> list[str]:
    if not argv:
        return argv
    augment_path_for_tooling()
    executable = shutil.which(argv[0])
    if executable:
        return [executable, *argv[1:]]
    return argv


def clean_windows_flutter_native_assets(package_dir: Path) -> None:
    """Drop stale sqlite3 native-asset outputs before flutter/dart test on Windows.

    Flutter/Dart copy sqlite3.dll into build/native_assets and
    .dart_tool/lib; an existing destination triggers PathExistsException
    (errno 183) when hooks re-run (e.g. after pub get or a prior test).
    """
    if sys.platform != "win32":
        return
    native_assets = package_dir / "build" / "native_assets"
    if native_assets.is_dir():
        shutil.rmtree(native_assets, ignore_errors=True)
    bundled_dll = package_dir / ".dart_tool" / "lib" / "sqlite3.dll"
    if bundled_dll.is_file():
        bundled_dll.unlink(missing_ok=True)


def clean_windows_flutter_native_assets_for_workspace(root: Path) -> None:
    """Clear sqlite3.dll bundle paths for all workspace Dart packages (Windows)."""
    if sys.platform != "win32":
        return
    for prefix, _key in DART_PACKAGE_PREFIXES:
        clean_windows_flutter_native_assets(root / prefix.rstrip("/"))


def _is_flutter_test_argv(argv: list[str]) -> bool:
    return len(argv) >= 2 and argv[0] == "flutter" and argv[1] == "test"


def run_step(step: Step) -> tuple[int, str]:
    argv = resolve_argv(step.argv)
    if sys.platform == "win32" and _is_flutter_test_argv(step.argv):
        # pub get / build_runner may already have copied sqlite3.dll; flutter test
        # copies again without overwriting on Windows (errno 183).
        clean_windows_flutter_native_assets(step.cwd)
        clean_windows_flutter_native_assets_for_workspace(repo_root())
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
        env=_subprocess_env_for_cwd(step.cwd),
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
    elif sys.platform == "win32" and result.returncode == 0:
        if step.label == "flutter pub get":
            clean_windows_flutter_native_assets_for_workspace(step.cwd)
        elif step.label.startswith("build_runner (waddle_shared)"):
            clean_windows_flutter_native_assets(step.cwd)
    return result.returncode, combined


def run_steps(steps: list[Step]) -> int:
    for step in steps:
        code, _output = run_step(step)
        if code != 0:
            return code
    return 0


def run_steps_parallel(steps: list[Step]) -> int:
    """Run independent steps concurrently; fail fast on first non-zero exit."""
    if not steps:
        return 0
    if len(steps) == 1:
        code, _ = run_step(steps[0])
        return code

    exit_code = 0
    with ThreadPoolExecutor(max_workers=len(steps)) as pool:
        futures = {pool.submit(run_step, step): step for step in steps}
        for future in as_completed(futures):
            code, _ = future.result()
            if code != 0 and exit_code == 0:
                exit_code = code
    return exit_code


def test_concurrency() -> int:
    """Default parallel test workers (override with WADDLE_TEST_CONCURRENCY)."""
    raw = os.environ.get("WADDLE_TEST_CONCURRENCY", "").strip()
    if raw:
        try:
            return max(1, int(raw))
        except ValueError:
            pass
    # Parallel flutter test on Windows races copying sqlite3.dll into
    # build/native_assets (PathExistsException errno 183).
    if sys.platform == "win32":
        return 1
    cpus = os.cpu_count() or 4
    return max(1, min(4, cpus))


def parallel_analyze_enabled() -> bool:
    return os.environ.get("WADDLE_CHECKS_PARALLEL_ANALYZE", "1").strip().lower() not in {
        "0",
        "false",
        "no",
    }


def _normalize_path(path: str) -> str:
    return path.replace("\\", "/")


def needs_pub_get(changed: list[str] | None) -> bool:
    """True when workspace lockfiles changed or the diff scope is unknown."""
    if changed is None:
        return True
    for path in changed:
        p = _normalize_path(path)
        if p == "pubspec.yaml" or p.startswith("pubspec.lock"):
            return True
        if any(marker in p for marker in PUBSPEC_MARKERS):
            return True
    return False


def needs_build_runner(changed: list[str] | None) -> bool:
    """True when Drift schema/codegen inputs may have changed."""
    if changed is None:
        return True
    for path in changed:
        p = _normalize_path(path)
        if any(p.startswith(prefix) for prefix in BUILD_RUNNER_PREFIXES):
            return True
    return False


def changed_dart_packages(changed: list[str] | None) -> set[str] | None:
    """Package keys needing tests, or None meaning run the full Dart workspace."""
    if changed is None:
        return None
    packages: set[str] = set()
    for path in changed:
        p = _normalize_path(path)
        if p == "pubspec.yaml" or p.startswith("pubspec.lock"):
            return None
        for prefix, key in DART_PACKAGE_PREFIXES:
            if p.startswith(prefix):
                packages.add(key)
    return packages


def lib_path_to_test_candidate(repo: Path, lib_path: str) -> Path | None:
    """Map lib/foo.dart -> test/foo_test.dart when that file exists."""
    p = _normalize_path(lib_path)
    if "/lib/" not in p or not p.endswith(".dart") or p.endswith(".g.dart"):
        return None
    prefix, rest = p.split("/lib/", 1)
    candidate = repo / prefix / "test" / rest.replace(".dart", "_test.dart")
    if candidate.is_file():
        return candidate
    return None


def infer_scoped_test_paths(repo: Path, changed: list[str]) -> dict[str, list[str]]:
    """Per-package relative test paths to pass to flutter/dart test."""
    scoped: dict[str, list[str]] = {}
    for path in changed:
        p = _normalize_path(path)
        if p.endswith("_test.dart"):
            for prefix, key in DART_PACKAGE_PREFIXES:
                if p.startswith(prefix):
                    rel = p[len(prefix) :]
                    scoped.setdefault(key, [])
                    if rel not in scoped[key]:
                        scoped[key].append(rel)
            continue
        candidate = lib_path_to_test_candidate(repo, p)
        if candidate is None:
            continue
        for prefix, key in DART_PACKAGE_PREFIXES:
            norm_prefix = _normalize_path(prefix)
            cand = _normalize_path(str(candidate.relative_to(repo)))
            if cand.startswith(norm_prefix):
                rel = cand[len(norm_prefix) :]
                scoped.setdefault(key, [])
                if rel not in scoped[key]:
                    scoped[key].append(rel)
    return scoped


def infer_controller_test_paths(repo: Path, changed: list[str]) -> list[str]:
    """Relative paths under apps/waddle_controller for Vitest (src/**/*.test.ts)."""
    controller = repo / "apps" / "waddle_controller"
    paths: list[str] = []
    for path in changed:
        p = _normalize_path(path)
        if not p.startswith(CONTROLLER_PREFIX):
            continue
        rel = p[len(CONTROLLER_PREFIX) :]
        if rel.endswith(".test.ts"):
            if rel not in paths:
                paths.append(rel)
            continue
        if rel.endswith(".ts") and not rel.endswith(".d.ts") and (
            rel.startswith("src/") or "/src/" in rel
        ):
            candidate = rel.replace(".ts", ".test.ts")
            if (controller / candidate).is_file() and candidate not in paths:
                paths.append(candidate)
    return paths


def qa_widen_shared_tests(changed: list[str]) -> bool:
    """Run full waddle_shared tests when persistence or Drift codegen may have changed."""
    for path in changed:
        p = _normalize_path(path)
        if p.startswith("packages/waddle_shared/lib/persistence/"):
            return True
    return needs_build_runner(changed)


@dataclass(frozen=True)
class QaScopedTestResult:
    exit_code: int
    skipped: bool
    edited_files: list[str]
    test_paths: list[str]
    failure_label: str | None = None
    failure_cwd: Path | None = None
    failure_argv: list[str] | None = None
    failure_output: str | None = None


def build_qa_scoped_test_steps(root: Path, edited_files: list[str]) -> list[Step]:
    """Test-only steps for edited paths (no analyze, coverage, or pub get)."""
    changed = [_normalize_path(f) for f in edited_files if f and f.strip()]
    if not changed:
        return []

    packages = changed_dart_packages(changed)
    if packages is not None and not packages:
        packages = None

    widen_shared = qa_widen_shared_tests(changed)
    scoped = infer_scoped_test_paths(root, changed)
    if widen_shared:
        scoped.pop("shared", None)

    concurrency = test_concurrency()
    dirs = package_dirs(root)
    steps: list[Step] = []

    dart_packages: tuple[tuple[str, Path, Any], ...] = (
        (
            "shared",
            dirs["shared"],
            lambda tp: flutter_test_argv(
                coverage=False,
                concurrency=concurrency,
                test_paths=tp,
            ),
        ),
        (
            "integrations",
            dirs["integrations"],
            lambda tp: dart_test_argv(
                concurrency=concurrency,
                test_paths=tp,
                coverage=False,
            ),
        ),
        (
            "plugin_sdk",
            dirs["plugin_sdk"],
            lambda tp: dart_test_argv(
                concurrency=concurrency,
                test_paths=tp,
                coverage=False,
            ),
        ),
        (
            "display",
            dirs["display"],
            lambda tp: flutter_test_argv(
                coverage=False,
                concurrency=concurrency,
                test_paths=tp,
            ),
        ),
        (
            "waddlectl",
            dirs["waddlectl"],
            lambda tp: flutter_test_argv(
                coverage=False,
                concurrency=concurrency,
                test_paths=tp,
            ),
        ),
    )

    for key, cwd, argv_fn in dart_packages:
        if packages is not None and key not in packages:
            continue
        test_paths = scoped.get(key)
        if test_paths:
            rel_label = ", ".join(test_paths[:3])
            if len(test_paths) > 3:
                rel_label += f", +{len(test_paths) - 3} more"
            steps.append(
                Step(
                    f"scoped test ({key}: {rel_label})",
                    argv_fn(test_paths),
                    cwd,
                )
            )
        elif widen_shared and key == "shared":
            steps.append(
                Step(
                    "scoped test (shared: full package)",
                    argv_fn(None),
                    cwd,
                )
            )

    controller_rel = infer_controller_test_paths(root, changed)
    if controller_rel:
        controller = root / "apps" / "waddle_controller"
        rel_label = ", ".join(controller_rel[:3])
        if len(controller_rel) > 3:
            rel_label += f", +{len(controller_rel) - 3} more"
        steps.append(
            Step(
                f"scoped test (controller: {rel_label})",
                ["npm", "run", "test", "--", *controller_rel],
                controller,
            )
        )

    return steps


def collect_qa_test_path_labels(steps: list[Step]) -> list[str]:
    labels: list[str] = []
    for step in steps:
        if step.argv[:3] == ["npm", "run", "test"]:
            labels.extend(step.argv[4:])
        else:
            labels.extend(step.argv[3:])
    return labels


def run_qa_scoped_tests(root: Path, edited_files: list[str]) -> QaScopedTestResult:
    """Run scoped unit tests for edited files; 0 pass/skip, non-zero on failure."""
    normalized = [_normalize_path(f) for f in edited_files if f and f.strip()]
    steps = build_qa_scoped_test_steps(root, normalized)
    test_paths = collect_qa_test_path_labels(steps)

    if not steps:
        print(
            "QA scoped tests: skipped (no mappable unit tests for edited files).",
            flush=True,
        )
        return QaScopedTestResult(
            exit_code=0,
            skipped=True,
            edited_files=normalized,
            test_paths=[],
        )

    for step in steps:
        code, output = run_step(step)
        if code != 0:
            return QaScopedTestResult(
                exit_code=code,
                skipped=False,
                edited_files=normalized,
                test_paths=test_paths,
                failure_label=step.label,
                failure_cwd=step.cwd,
                failure_argv=list(step.argv),
                failure_output=output,
            )

    print("QA scoped tests: all passed.", flush=True)
    return QaScopedTestResult(
        exit_code=0,
        skipped=False,
        edited_files=normalized,
        test_paths=test_paths,
    )


def flutter_test_argv(
    *,
    coverage: bool,
    concurrency: int,
    test_paths: list[str] | None = None,
    skip_pub: bool = False,
) -> list[str]:
    argv = ["flutter", "test", "--timeout=60s", f"--concurrency={concurrency}"]
    if skip_pub or sys.platform == "win32":
        # Workspace pub get already ran; avoid a second hook pass that races on
        # sqlite3.dll copies (PathExistsException errno 183 on Windows).
        argv.append("--no-pub")
    if coverage:
        argv.append("--coverage")
    if test_paths:
        argv.extend(test_paths)
    return argv


def dart_test_argv(
    *,
    concurrency: int,
    test_paths: list[str] | None = None,
    coverage: bool = False,
) -> list[str]:
    argv = ["dart", "test", f"--concurrency={concurrency}"]
    if coverage:
        argv.append("--coverage=coverage")
    if test_paths:
        argv.extend(test_paths)
    return argv


def scoped_paths(changed: list[str] | None) -> set[str]:
    if changed is None:
        return {"dart_workspace", "controller", "deploy"}
    scopes: set[str] = set()
    for path in changed:
        p = _normalize_path(path)
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
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def git_worktree_changed_files(root: Path) -> list[str]:
    """Staged and unstaged paths vs HEAD (for local fast checks)."""
    files: set[str] = set()
    for extra in ([], ["--cached"]):
        result = subprocess.run(
            resolve_argv(["git", "diff", "--name-only", *extra, "HEAD"]),
            cwd=root,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            files.update(line.strip() for line in result.stdout.splitlines() if line.strip())
    return sorted(files)


def package_dirs(root: Path) -> dict[str, Path]:
    return {
        "shared": root / "packages" / "waddle_shared",
        "integrations": root / "packages" / "waddle_integrations",
        "plugin_sdk": root / "packages" / "waddle_plugin_sdk",
        "display": root / "apps" / "waddle_display",
        "waddlectl": root / "apps" / "waddlectl",
    }


def build_dart_workspace_steps(
    root: Path,
    tier: CheckTier,
    changed: list[str] | None,
    *,
    scope_tests: bool,
) -> list[Step]:
    """Build Dart workspace check steps for pre-push, fast, or full tiers."""
    dirs = package_dirs(root)
    shared = dirs["shared"]
    integrations = dirs["integrations"]
    plugin_sdk = dirs["plugin_sdk"]
    display = dirs["display"]
    waddlectl = dirs["waddlectl"]

    include_coverage = tier == CheckTier.FULL
    concurrency = test_concurrency()
    if tier == CheckTier.PREPUSH:
        packages = None
    else:
        packages = changed_dart_packages(changed)
    scoped_tests = (
        infer_scoped_test_paths(root, changed) if scope_tests and changed else {}
    )

    steps: list[Step] = []

    if needs_pub_get(changed):
        steps.append(Step("flutter pub get", ["flutter", "pub", "get"], root))
    else:
        print("\n==> flutter pub get — skipped (no pubspec/lock changes)", flush=True)

    if needs_build_runner(changed):
        steps.append(
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
            )
        )
    else:
        print(
            "\n==> build_runner (waddle_shared) — skipped (no Drift/codegen changes)",
            flush=True,
        )

    def package_enabled(key: str) -> bool:
        return packages is None or key in packages

    def test_paths_for(key: str) -> list[str] | None:
        paths = scoped_tests.get(key)
        return paths if paths else None

    if package_enabled("shared"):
        steps.append(
            Step(
                "flutter test (waddle_shared)",
                flutter_test_argv(
                    coverage=include_coverage,
                    concurrency=concurrency,
                    test_paths=test_paths_for("shared"),
                ),
                shared,
            )
        )

    if package_enabled("integrations"):
        steps.append(
            Step(
                "dart test (waddle_integrations)",
                dart_test_argv(
                    concurrency=concurrency,
                    test_paths=test_paths_for("integrations"),
                    coverage=include_coverage,
                ),
                integrations,
            )
        )
        if include_coverage:
            steps.append(
                Step(
                    "format_coverage (waddle_integrations)",
                    [
                        "dart",
                        "run",
                        "coverage:format_coverage",
                        "--lcov",
                        "--in=coverage",
                        "--out=coverage/lcov.info",
                        "--report-on=lib",
                    ],
                    integrations,
                ),
            )

    if package_enabled("plugin_sdk"):
        steps.append(
            Step(
                "dart test (waddle_plugin_sdk)",
                dart_test_argv(
                    concurrency=concurrency,
                    test_paths=test_paths_for("plugin_sdk"),
                    coverage=include_coverage,
                ),
                plugin_sdk,
            )
        )
        if include_coverage:
            steps.append(
                Step(
                    "format_coverage (waddle_plugin_sdk)",
                    [
                        "dart",
                        "run",
                        "coverage:format_coverage",
                        "--lcov",
                        "--in=coverage",
                        "--out=coverage/lcov.info",
                        "--report-on=lib",
                    ],
                    plugin_sdk,
                ),
            )

    steps.append(
        Step(
            "flutter analyze (waddle_display)",
            ["flutter", "analyze"],
            display,
        )
    )

    if package_enabled("display"):
        steps.append(
            Step(
                "flutter test (waddle_display)",
                flutter_test_argv(
                    coverage=include_coverage,
                    concurrency=concurrency,
                    test_paths=test_paths_for("display"),
                ),
                display,
            )
        )

    if package_enabled("waddlectl"):
        steps.append(
            Step(
                "flutter test (waddlectl)",
                flutter_test_argv(
                    coverage=False,
                    concurrency=concurrency,
                    test_paths=test_paths_for("waddlectl"),
                ),
                waddlectl,
            )
        )

    if include_coverage:
        shared_lcov = shared / "coverage" / "lcov.info"
        plugin_lcov = plugin_sdk / "coverage" / "lcov.info"
        steps.append(
            Step(
                "line coverage (waddle_display)",
                [
                    "dart",
                    "run",
                    "tool/coverage_check.dart",
                    "--min=80",
                    "--target=90",
                    "coverage/lcov.info",
                    str(shared_lcov),
                    str(plugin_lcov),
                ],
                display,
            )
        )

    return steps


def _npm_lockfile_satisfied(project_dir: Path) -> bool:
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


def run_dart_workspace_steps(steps: list[Step]) -> tuple[int, Step | None]:
    """Run workspace steps; parallelize analyze + display tests when adjacent."""
    i = 0
    while i < len(steps):
        step = steps[i]
        if (
            i + 1 < len(steps)
            and step.label == "flutter analyze (waddle_display)"
            and steps[i + 1].label.startswith("flutter test (waddle_display)")
            and parallel_analyze_enabled()
        ):
            print(
                "\n==> parallel: flutter analyze + flutter test (waddle_display)",
                flush=True,
            )
            code = run_steps_parallel([step, steps[i + 1]])
            if code != 0:
                return code, step
            i += 2
            continue
        code, _ = run_step(step)
        if code != 0:
            return code, step
        i += 1
    return 0, None
