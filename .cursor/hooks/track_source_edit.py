#!/usr/bin/env python3
"""Record agent-edited source files for post-agent follow-ups (afterFileEdit hook)."""

from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from hook_common import (
    conversation_id,
    is_dependency_file,
    load_state,
    read_stdin_json,
    save_state,
    should_track_file,
)


def main() -> None:
    payload = read_stdin_json()
    file_path = payload.get("file_path")
    if not isinstance(file_path, str) or not file_path:
        sys.exit(0)

    track_source = should_track_file(file_path)
    track_deps = is_dependency_file(file_path)
    if not track_source and not track_deps:
        sys.exit(0)

    conv_id = conversation_id(payload)
    state = load_state()
    conversations = state["conversations"]
    entry = conversations.setdefault(
        conv_id,
        {"files": [], "dependency_files": [], "updated_at": None},
    )

    if track_source:
        files: list[str] = entry.setdefault("files", [])
        if file_path not in files:
            files.append(file_path)

    if track_deps:
        dep_files: list[str] = entry.setdefault("dependency_files", [])
        if file_path not in dep_files:
            dep_files.append(file_path)

    entry["updated_at"] = datetime.now(timezone.utc).isoformat()
    save_state(state)
    sys.exit(0)


if __name__ == "__main__":
    main()
