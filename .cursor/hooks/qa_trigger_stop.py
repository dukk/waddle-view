#!/usr/bin/env python3
"""After the agent stops, invoke the qa subagent if source files were edited."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from qa_common import conversation_id, load_state, read_stdin_json, save_state


def main() -> None:
    payload = read_stdin_json()
    status = payload.get("status")
    loop_count = payload.get("loop_count", 0)

    # Only follow up on a successful agent turn; respect loop cap (default 5 in Cursor).
    if status != "completed" or not isinstance(loop_count, int) or loop_count >= 4:
        print("{}")
        sys.exit(0)

    conv_id = conversation_id(payload)
    state = load_state()
    entry = state["conversations"].pop(conv_id, None)
    save_state(state)

    if not entry:
        print("{}")
        sys.exit(0)

    files = entry.get("files") or []
    if not files:
        print("{}")
        sys.exit(0)

    file_list = "\n".join(f"- `{path}`" for path in files[:30])
    if len(files) > 30:
        file_list += f"\n- …and {len(files) - 30} more"

    followup = (
        "/qa Review the agent's recent code changes.\n\n"
        "Edited files:\n"
        f"{file_list}\n\n"
        "Verify correctness, tests, migrations, and [AGENTS.md](../../AGENTS.md) "
        "conventions. Report PASS / PASS WITH NOTES / FAIL with severity-tagged issues. "
        "Do not re-implement unless a critical fix is required."
    )

    print(json.dumps({"followup_message": followup}))
    sys.exit(0)


if __name__ == "__main__":
    main()
