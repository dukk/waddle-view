#!/usr/bin/env python3
"""After the agent stops, run scoped tests and invoke qa/docs subagents."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from hook_common import conversation_id, load_state, read_stdin_json, repo_root, save_state


def _load_qa_failure_helpers(root: Path):
    scripts = str(root / "scripts")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    from qa_test_failure_report import build_qa_autofix_prompt, read_failure

    return build_qa_autofix_prompt, read_failure


def run_qa_scoped_tests_hook(root: Path, files: list[str]) -> int:
    if os.environ.get("WADDLE_SKIP_QA_HOOK_TESTS", "").strip() in {"1", "true", "yes"}:
        return 0
    script = root / "scripts" / "qa_scoped_tests.py"
    env = os.environ.copy()
    env["WADDLE_REPO_ROOT"] = str(root)
    result = subprocess.run(
        [sys.executable, str(script), "--files-json", json.dumps(files)],
        cwd=root,
        env=env,
    )
    return result.returncode


def main() -> None:
    payload = read_stdin_json()
    status = payload.get("status")
    loop_count = payload.get("loop_count", 0)

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
    dep_files = entry.get("dependency_files") or []
    if not files and not dep_files:
        print("{}")
        sys.exit(0)

    def format_list(paths: list[str]) -> str:
        lines = "\n".join(f"- `{path}`" for path in paths[:30])
        if len(paths) > 30:
            lines += f"\n- …and {len(paths) - 30} more"
        return lines

    root = repo_root()
    sections: list[str] = []
    tests_failed = False

    if files:
        file_list = format_list(files)
        test_exit = run_qa_scoped_tests_hook(root, files)
        tests_failed = test_exit != 0

        if test_exit != 0:
            try:
                build_prompt, read_failure = _load_qa_failure_helpers(root)
                failure = read_failure(root)
                if failure:
                    sections.append(build_prompt(failure))
                else:
                    sections.append(
                        "---\n\n"
                        "/qa FIX\n\n"
                        f"Scoped unit tests failed after edits.\n\n"
                        f"Edited files:\n{file_list}\n\n"
                        "Read test output from the hook log, fix failures with minimal diffs, "
                        "and re-run `python scripts/qa_scoped_tests.py` with the same files."
                    )
            except Exception:
                sections.append(
                    "---\n\n"
                    "/qa FIX\n\n"
                    f"Scoped unit tests failed.\n\nEdited files:\n{file_list}"
                )
        else:
            sections.extend(
                [
                    "---\n\n"
                    "/qa REVIEW\n\n"
                    "Review the agent's recent code changes.\n\n"
                    f"Edited files:\n{file_list}\n\n"
                    "Verify correctness, tests, migrations, and AGENTS.md conventions. "
                    "Report PASS / PASS WITH NOTES / FAIL with severity-tagged issues. "
                    "Do not re-implement unless a critical fix is required.",
                    "---\n\n"
                    "/docs Check documentation is up to date for the same changes.\n\n"
                    f"Edited files:\n{file_list}\n\n"
                    "Update README, .env.example, AGENTS.md, deploy docs, or skills when "
                    "behavior, config, env vars, endpoints, or operator workflows changed. "
                    "Report UP TO DATE / UPDATED / GAPS FOUND.",
                ]
            )

    if dep_files and not tests_failed:
        dep_list = format_list(dep_files)
        sections.append(
            "---\n\n"
            "/deps-security Audit dependency security for these manifest changes.\n\n"
            f"Dependency files:\n{dep_list}\n\n"
            "Run `python scripts/security_audit.py`, read "
            "`.cursor/hooks/state/security-audit.json`, and report CLEAN / "
            "ISSUES FOUND / INCOMPLETE with severities and recommended upgrades."
        )

    if not sections:
        print("{}")
        sys.exit(0)

    intro = (
        "The agent just finished editing tracked files. Run the subagents below "
        "(in parallel when supported):\n\n"
    )
    followup = intro + "\n\n".join(sections)

    print(json.dumps({"followup_message": followup}))
    sys.exit(0)


if __name__ == "__main__":
    main()
