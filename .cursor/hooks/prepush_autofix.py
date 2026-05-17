#!/usr/bin/env python3
"""Shared pre-push autofix helpers for Cursor hooks."""

from __future__ import annotations

import sys
from pathlib import Path
from types import ModuleType


def load_prepush_failure_module(root: Path) -> ModuleType | None:
    path = str(root / "scripts")
    if path not in sys.path:
        sys.path.insert(0, path)
    try:
        import prepush_failure_report
    except Exception:
        return None
    return prepush_failure_report


def build_prepush_autofix_message(root: Path) -> str | None:
    try:
        mod = load_prepush_failure_module(root)
        if mod is None:
            return None
        read_failure = getattr(mod, "read_failure", None)
        build_autofix_prompt = getattr(mod, "build_autofix_prompt", None)
        if not callable(read_failure) or not callable(build_autofix_prompt):
            return None
        failure = read_failure(root)
        if not failure:
            return None
        return build_autofix_prompt(failure)
    except Exception:
        return None
