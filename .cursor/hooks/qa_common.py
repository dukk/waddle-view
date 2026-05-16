#!/usr/bin/env python3
"""Shared helpers for waddle-view QA hooks."""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

STATE_DIR = Path(".cursor/hooks/state")
STATE_PATH = STATE_DIR / "qa-edited-files.json"

SKIP_PATH_PARTS = (
    "/.cursor/hooks/state/",
    "/.git/",
    "/node_modules/",
    "/build/",
    "/.dart_tool/",
    "/coverage/",
)

SKIP_SUFFIXES = (
    ".g.dart",
    ".freezed.dart",
    ".iml",
)


def repo_root() -> Path:
    return Path(os.environ.get("WADDLE_REPO_ROOT", ".")).resolve()


def load_state() -> dict:
    path = repo_root() / STATE_PATH
    if not path.is_file():
        return {"conversations": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"conversations": {}}
    if not isinstance(data, dict):
        return {"conversations": {}}
    data.setdefault("conversations", {})
    return data


def save_state(data: dict) -> None:
    path = repo_root() / STATE_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def should_track_file(file_path: str) -> bool:
    normalized = file_path.replace("\\", "/")
    if any(part in normalized for part in SKIP_PATH_PARTS):
        return False
    if any(normalized.endswith(suffix) for suffix in SKIP_SUFFIXES):
        return False
    # QA targets source under apps/ and packages/, plus root config touched by agents.
    if re.search(r"/(apps|packages)/", normalized):
        return True
    name = Path(normalized).name
    return name in {
        "pubspec.yaml",
        "pubspec.lock",
        "analysis_options.yaml",
        "AGENTS.md",
    }


def conversation_id(payload: dict) -> str:
    return (
        payload.get("conversation_id")
        or payload.get("session_id")
        or "default"
    )


def read_stdin_json() -> dict:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return {}
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}
