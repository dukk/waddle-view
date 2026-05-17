#!/usr/bin/env python3
"""Shared pre-push autofix helpers for Cursor hooks."""

from __future__ import annotations

import sys
from pathlib import Path


def load_prepush_failure_module(root: Path):
    path = str(root / "scripts")
    if path not in sys.path:
        sys.path.insert(0, path)
    import prepush_failure_report

    return prepush_failure_report


def build_prepush_autofix_message(root: Path) -> str | None:
    mod = load_prepush_failure_module(root)
    failure = mod.read_failure(root)
    if not failure:
        return None
    return mod.build_autofix_prompt(failure)
