#!/usr/bin/env python3
"""Audit dependencies (npm, Dart lockfile) and write .cursor/hooks/state/security-audit.json."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

STATE_REL = Path(".cursor/hooks/state/security-audit.json")

NPM_PROJECTS = (
    ("npm:waddle_controller", Path("apps/waddle_controller")),
    ("npm:waddle_display_mock_api", Path("apps/waddle_display_mock_api")),
)

SEVERITY_KEYS = ("critical", "high", "moderate", "low", "info")


def repo_root() -> Path:
    env = os.environ.get("WADDLE_REPO_ROOT")
    if env:
        return Path(env).resolve()
    return Path(__file__).resolve().parent.parent


def state_path(root: Path) -> Path:
    return root / STATE_REL


def git_head(root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip() or None
    except (OSError, subprocess.CalledProcessError):
        return None


def empty_counts() -> dict[str, int]:
    return {k: 0 for k in SEVERITY_KEYS} | {"total": 0}


def merge_counts(target: dict[str, int], source: dict[str, int]) -> None:
    for key in SEVERITY_KEYS:
        target[key] = target.get(key, 0) + source.get(key, 0)
    target["total"] = target.get("total", 0) + source.get("total", 0)


def npm_counts(audit: dict[str, Any]) -> dict[str, int]:
    meta = audit.get("metadata", {}).get("vulnerabilities", {})
    counts = empty_counts()
    for key in SEVERITY_KEYS:
        counts[key] = int(meta.get(key, 0) or 0)
    counts["total"] = int(meta.get("total", 0) or 0)
    return counts


def npm_vulnerability_list(audit: dict[str, Any], limit: int = 50) -> list[dict[str, Any]]:
    vulns = audit.get("vulnerabilities") or {}
    items: list[dict[str, Any]] = []
    for name, detail in vulns.items():
        if not isinstance(detail, dict):
            continue
        items.append(
            {
                "name": name,
                "severity": detail.get("severity"),
                "via": detail.get("via"),
                "range": detail.get("range"),
                "fixAvailable": detail.get("fixAvailable"),
            }
        )
    items.sort(
        key=lambda v: (
            {"critical": 0, "high": 1, "moderate": 2, "low": 3, "info": 4}.get(
                str(v.get("severity", "")).lower(), 5
            ),
            str(v.get("name", "")),
        )
    )
    return items[:limit]


def run_npm_audit(root: Path, project_id: str, rel_dir: Path) -> dict[str, Any]:
    cwd = root / rel_dir
    npm = "npm.cmd" if os.name == "nt" else "npm"
    entry: dict[str, Any] = {
        "id": project_id,
        "path": rel_dir.as_posix(),
        "tool": "npm-audit",
        "ok": True,
        "counts": empty_counts(),
        "vulnerabilities": [],
        "error": None,
    }
    if not (cwd / "package.json").is_file():
        entry["ok"] = False
        entry["error"] = "package.json missing"
        return entry

    result = subprocess.run(
        [npm, "audit", "--json"],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    stdout = result.stdout.strip()
    if not stdout:
        entry["ok"] = False
        entry["error"] = result.stderr.strip() or f"npm audit exit {result.returncode}"
        return entry

    try:
        audit = json.loads(stdout)
    except json.JSONDecodeError as exc:
        entry["ok"] = False
        entry["error"] = f"invalid npm audit JSON: {exc}"
        return entry

    counts = npm_counts(audit)
    entry["counts"] = counts
    entry["vulnerabilities"] = npm_vulnerability_list(audit)
    entry["exit_code"] = result.returncode
    entry["ok"] = counts["total"] == 0
    return entry


def parse_osv_results(data: dict[str, Any]) -> tuple[dict[str, int], list[dict[str, Any]]]:
    counts = empty_counts()
    findings: list[dict[str, Any]] = []
    results = data.get("results") or []
    if not isinstance(results, list):
        return counts, findings

    for result in results:
        if not isinstance(result, dict):
            continue
        packages = result.get("packages") or []
        if not isinstance(packages, list):
            continue
        for pkg in packages:
            if not isinstance(pkg, dict):
                continue
            vulns = pkg.get("vulnerabilities") or []
            if not isinstance(vulns, list):
                continue
            for vuln in vulns:
                if not isinstance(vuln, dict):
                    continue
                severity = str(vuln.get("severity", "unknown")).lower()
                if severity in counts:
                    counts[severity] += 1
                counts["total"] += 1
                findings.append(
                    {
                        "package": pkg.get("package", {}).get("name")
                        if isinstance(pkg.get("package"), dict)
                        else pkg.get("name"),
                        "severity": severity,
                        "id": vuln.get("id"),
                        "summary": vuln.get("summary"),
                    }
                )

    findings.sort(
        key=lambda v: (
            {"critical": 0, "high": 1, "moderate": 2, "low": 3, "info": 4}.get(
                str(v.get("severity", "")).lower(), 5
            ),
            str(v.get("package", "")),
        )
    )
    return counts, findings[:50]


def run_osv_scan(root: Path) -> dict[str, Any]:
    entry: dict[str, Any] = {
        "id": "dart:workspace",
        "path": ".",
        "tool": "osv-scanner",
        "ok": True,
        "counts": empty_counts(),
        "vulnerabilities": [],
        "error": None,
        "skipped": False,
    }
    scanner = shutil.which("osv-scanner")
    if not scanner:
        entry["skipped"] = True
        entry["ok"] = True
        entry["error"] = (
            "osv-scanner not on PATH — install from "
            "https://google.github.io/osv-scanner/ to scan pubspec.lock"
        )
        return entry

    lock = root / "pubspec.lock"
    if not lock.is_file():
        entry["skipped"] = True
        entry["error"] = "pubspec.lock missing at repo root"
        return entry

    result = subprocess.run(
        [scanner, "scan", "--format", "json", str(lock)],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if result.returncode not in (0, 1) and not result.stdout.strip():
        entry["ok"] = False
        entry["error"] = result.stderr.strip() or f"osv-scanner exit {result.returncode}"
        return entry

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        entry["ok"] = False
        entry["error"] = f"invalid osv-scanner JSON: {exc}"
        return entry

    counts, findings = parse_osv_results(data)
    entry["counts"] = counts
    entry["vulnerabilities"] = findings
    entry["exit_code"] = result.returncode
    entry["ok"] = counts["total"] == 0
    return entry


def build_state(root: Path, ecosystems: list[dict[str, Any]]) -> dict[str, Any]:
    summary = empty_counts()
    for eco in ecosystems:
        if eco.get("skipped"):
            continue
        merge_counts(summary, eco.get("counts") or {})

    return {
        "version": 1,
        "last_run_at": datetime.now(timezone.utc).isoformat(),
        "git_revision": git_head(root),
        "repo_root": str(root),
        "summary": summary,
        "ecosystems": ecosystems,
        "ok": summary["total"] == 0
        and all(e.get("ok", True) or e.get("skipped") for e in ecosystems),
    }


def save_state(root: Path, state: dict[str, Any]) -> Path:
    path = state_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2), encoding="utf-8")
    return path


def load_state(root: Path) -> dict[str, Any] | None:
    path = state_path(root)
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def run_audit(root: Path | None = None) -> dict[str, Any]:
    root = root or repo_root()
    ecosystems: list[dict[str, Any]] = []
    for project_id, rel_dir in NPM_PROJECTS:
        ecosystems.append(run_npm_audit(root, project_id, rel_dir))
    ecosystems.append(run_osv_scan(root))
    state = build_state(root, ecosystems)
    save_state(root, state)
    return state


def main() -> int:
    root = repo_root()
    state = run_audit(root)
    path = state_path(root)
    summary = state["summary"]
    print(f"Wrote {path}")
    print(
        f"Summary: total={summary['total']} "
        f"(critical={summary['critical']}, high={summary['high']}, "
        f"moderate={summary['moderate']}, low={summary['low']})"
    )
    if not state["ok"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
