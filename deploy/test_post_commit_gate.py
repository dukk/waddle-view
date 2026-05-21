"""Unit tests for post-commit gate helpers (stdlib + importlib)."""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


def _load_module(name: str, rel_path: str):
    root = Path(__file__).resolve().parent.parent
    path = root / rel_path
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod, root


class TestCollectCommitChangedFiles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.wcc, cls.root = _load_module(
            "waddle_check_common_pcg",
            "scripts/waddle_check_common.py",
        )

    def test_no_parent_returns_none(self):
        wcc = self.wcc
        with mock.patch.object(wcc, "git_commit_parent_sha", return_value=None):
            with mock.patch.object(wcc, "git_head_sha", return_value="abc"):
                self.assertIsNone(wcc.collect_commit_changed_files(self.root))

    def test_with_parent_uses_git_changed_files(self):
        wcc = self.wcc
        with mock.patch.object(wcc, "git_commit_parent_sha", return_value="parent"):
            with mock.patch.object(wcc, "git_head_sha", return_value="head"):
                with mock.patch.object(
                    wcc,
                    "git_changed_files",
                    return_value=["apps/waddle_display/lib/a.dart"],
                ) as diff:
                    files = wcc.collect_commit_changed_files(self.root)
                    diff.assert_called_once_with(self.root, "parent", "head")
                    self.assertEqual(files, ["apps/waddle_display/lib/a.dart"])


class TestPostCommitBuildSteps(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.wcc, cls.root = _load_module(
            "waddle_check_common_pcg2",
            "scripts/waddle_check_common.py",
        )

    def test_controller_scope_includes_build_server(self):
        wcc = self.wcc
        steps = wcc.build_post_commit_build_steps(
            self.root,
            {"controller"},
            ["apps/waddle_controller/src/foo.ts"],
        )
        labels = [s.label for s in steps]
        self.assertIn("npm run build (waddle_controller)", labels)
        self.assertIn("npm run build:server (waddle_controller)", labels)

    def test_dart_workspace_includes_dart_analyze_and_flutter_analyze(self):
        wcc = self.wcc
        with mock.patch.object(wcc, "needs_pub_get", return_value=False):
            with mock.patch.object(wcc, "needs_build_runner", return_value=False):
                steps = wcc.build_post_commit_build_steps(
                    self.root,
                    {"dart_workspace"},
                    None,
                )
        labels = [s.label for s in steps]
        self.assertIn("dart analyze (waddle_shared)", labels)
        self.assertIn("dart analyze (waddle_integrations)", labels)
        self.assertIn("flutter analyze (waddle_display)", labels)


class TestCommitFailureReports(unittest.TestCase):
    def test_build_failure_round_trip_and_prompt(self):
        mod, root = _load_module(
            "commit_build_failure_report_test",
            "scripts/commit_build_failure_report.py",
        )
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            mod.write_failure(
                repo,
                label="flutter analyze (waddle_display)",
                cwd=repo / "apps" / "waddle_display",
                argv=["flutter", "analyze"],
                exit_code=1,
                output="error",
                scopes=["dart_workspace"],
                commit_sha="deadbeef",
            )
            data = mod.read_failure(repo)
            assert data is not None
            self.assertEqual(data.get("phase"), "build")
            prompt = mod.build_autofix_prompt(data)
            self.assertIn("/build-fix FIX", prompt)
            mod.clear_failure(repo)
            self.assertIsNone(mod.read_failure(repo))

    def test_test_failure_round_trip_and_prompt(self):
        mod, root = _load_module(
            "commit_test_failure_report_test",
            "scripts/commit_test_failure_report.py",
        )
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            mod.write_failure(
                repo,
                label="flutter test (waddle_display)",
                cwd=repo / "apps" / "waddle_display",
                argv=["flutter", "test"],
                exit_code=1,
                output="FAILED",
                scopes=["dart_workspace"],
                commit_sha="cafe",
            )
            data = mod.read_failure(repo)
            assert data is not None
            prompt = mod.build_autofix_prompt(data)
            self.assertIn("/test-fix FIX", prompt)


class TestCommitFixLoop(unittest.TestCase):
    def test_wall_clock_exceeded(self):
        mod, _root = _load_module("commit_fix_loop_test", "scripts/commit_fix_loop.py")
        with mock.patch.object(mod, "max_wall_ms", return_value=1000):
            state = {"started_at_ms": int(time.time() * 1000) - 2000}
            self.assertTrue(mod.wall_clock_exceeded(state))

    def test_ensure_loop_started_resets_on_new_commit(self):
        mod, _root = _load_module("commit_fix_loop_test2", "scripts/commit_fix_loop.py")
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            first = mod.ensure_loop_started(repo, "aaa")
            self.assertEqual(first["commit_sha"], "aaa")
            second = mod.ensure_loop_started(repo, "bbb")
            self.assertEqual(second["commit_sha"], "bbb")
            self.assertNotEqual(first["started_at_ms"], second["started_at_ms"])


class TestPostCommitTestStepFilter(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pcg, cls.root = _load_module(
            "post_commit_gate_test",
            "scripts/post_commit_gate.py",
        )

    def test_build_steps_excluded_from_test_phase(self):
        pcg = self.pcg
        from waddle_check_common import Step

        fake_steps = [
            Step("npm run build (waddle_controller)", ["npm", "run", "build"], self.root),
            Step("npm run lint (waddle_controller)", ["npm", "run", "lint"], self.root),
            Step("flutter test (waddle_display)", ["flutter", "test"], self.root),
        ]
        with mock.patch("pre_push_checks.build_steps", return_value=fake_steps):
            steps = pcg.build_test_steps(self.root, {"controller", "dart_workspace"}, [])
        labels = [s.label for s in steps]
        self.assertNotIn("npm run build (waddle_controller)", labels)
        self.assertIn("npm run lint (waddle_controller)", labels)
        self.assertIn("flutter test (waddle_display)", labels)


if __name__ == "__main__":
    unittest.main()
