"""Unit tests for QA scoped test inference and failure reports."""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import time
import unittest
from pathlib import Path


def _load_module(name: str, rel_path: str):
    root = Path(__file__).resolve().parent.parent
    path = root / rel_path
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod, root


class TestQaScopedInference(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.wcc, cls.root = _load_module(
            "waddle_check_common_qa_test",
            "scripts/waddle_check_common.py",
        )

    def test_infer_controller_test_paths_maps_src_to_test(self):
        wcc = self.wcc
        repo = self.root
        rel = "apps/waddle_controller/src/util/dialogSave.test.ts"
        self.assertTrue((repo / rel).is_file())
        paths = wcc.infer_controller_test_paths(
            repo,
            ["apps/waddle_controller/src/util/dialogSave.ts"],
        )
        self.assertIn("src/util/dialogSave.test.ts", paths)

    def test_infer_controller_test_paths_skips_pages(self):
        wcc = self.wcc
        paths = wcc.infer_controller_test_paths(
            self.root,
            ["apps/waddle_controller/src/pages/ScreensPage.tsx"],
        )
        self.assertEqual(paths, [])

    def test_lib_path_to_test_candidate_display(self):
        wcc = self.wcc
        repo = self.root
        lib = "apps/waddle_display/lib/stub_data_provider.dart"
        candidate = wcc.lib_path_to_test_candidate(repo, lib)
        self.assertIsNotNone(candidate)
        self.assertTrue(candidate.name.endswith("_test.dart"))

    def test_qa_widen_shared_tests_for_persistence(self):
        wcc = self.wcc
        self.assertTrue(
            wcc.qa_widen_shared_tests(
                ["packages/waddle_shared/lib/persistence/tables.dart"],
            )
        )
        self.assertFalse(
            wcc.qa_widen_shared_tests(
                ["apps/waddle_controller/src/api/client.ts"],
            )
        )

    def test_build_qa_scoped_test_steps_skips_unmappable_controller(self):
        wcc = self.wcc
        steps = wcc.build_qa_scoped_test_steps(
            self.root,
            ["apps/waddle_controller/src/pages/FooPage.tsx"],
        )
        self.assertEqual(steps, [])

    def test_build_qa_scoped_test_steps_includes_controller_test(self):
        wcc = self.wcc
        steps = wcc.build_qa_scoped_test_steps(
            self.root,
            ["apps/waddle_controller/src/util/dialogSave.ts"],
        )
        self.assertEqual(len(steps), 1)
        self.assertIn("npm", steps[0].argv)
        self.assertTrue(
            any("dialogSave.test.ts" in arg for arg in steps[0].argv),
        )

    def test_build_qa_scoped_analyze_steps_shared_widens_display(self):
        wcc = self.wcc
        steps = wcc.build_qa_scoped_analyze_steps(
            self.root,
            ["packages/waddle_shared/lib/seed/catalog_defaults_reset.dart"],
        )
        labels = [s.label for s in steps]
        self.assertIn("dart analyze (waddle_shared)", labels)
        self.assertIn("flutter analyze (waddle_display)", labels)

    def test_build_qa_scoped_analyze_steps_display_only(self):
        wcc = self.wcc
        steps = wcc.build_qa_scoped_analyze_steps(
            self.root,
            ["apps/waddle_display/lib/config/display_env.dart"],
        )
        labels = [s.label for s in steps]
        self.assertEqual(labels, ["flutter analyze (waddle_display)"])

    def test_build_qa_scoped_analyze_steps_skips_controller_ts(self):
        wcc = self.wcc
        steps = wcc.build_qa_scoped_analyze_steps(
            self.root,
            ["apps/waddle_controller/src/pages/FooPage.tsx"],
        )
        self.assertEqual(steps, [])


class TestQaFailureReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.wcc, cls.root = _load_module(
            "waddle_check_common_failure_test",
            "scripts/waddle_check_common.py",
        )
        cls.qa_report, _ = _load_module(
            "qa_test_failure_report_unittest",
            "scripts/qa_test_failure_report.py",
        )

    def test_write_read_and_clear_failure(self):
        qa = self.qa_report
        wcc = self.wcc
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = wcc.QaScopedTestResult(
                exit_code=1,
                skipped=False,
                edited_files=["apps/waddle_controller/src/a.ts"],
                test_paths=["src/a.test.ts"],
                failure_label="scoped test",
                failure_cwd=root / "apps" / "waddle_controller",
                failure_argv=["npm", "run", "test"],
                failure_output="AssertionError",
            )
            qa.write_failure(root, result)
            data = qa.read_failure(root)
            self.assertIsNotNone(data)
            self.assertEqual(data.get("exit_code"), 1)
            self.assertIn("AssertionError", data.get("output_tail", ""))
            qa.clear_failure(root)
            self.assertIsNone(qa.read_failure(root))

    def test_read_failure_expires(self):
        qa = self.qa_report
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = qa.failure_path(root)
            path.parent.mkdir(parents=True, exist_ok=True)
            stale_ms = int(time.time() * 1000) - qa.FAILURE_MAX_AGE_MS - 60_000
            path.write_text(
                json.dumps({"failed_at_ms": stale_ms, "label": "old"}),
                encoding="utf-8",
            )
            self.assertIsNone(qa.read_failure(root))

    def test_build_qa_autofix_prompt_contains_fix_mode(self):
        qa = self.qa_report
        prompt = qa.build_qa_autofix_prompt(
            {
                "label": "scoped test (controller)",
                "exit_code": 1,
                "cwd": "/repo/apps/waddle_controller",
                "argv": ["npm", "run", "test", "--", "src/foo.test.ts"],
                "edited_files": ["apps/waddle_controller/src/foo.ts"],
                "test_paths": ["src/foo.test.ts"],
                "output_tail": "FAIL expected true",
            }
        )
        self.assertIn("FIX", prompt)
        self.assertIn("/qa FIX", prompt)
        self.assertIn("FAIL expected true", prompt)

    def test_build_qa_autofix_prompt_analyze_failure(self):
        qa = self.qa_report
        prompt = qa.build_qa_autofix_prompt(
            {
                "label": "dart analyze (waddle_shared)",
                "exit_code": 1,
                "cwd": "/repo/packages/waddle_shared",
                "argv": ["dart", "analyze"],
                "edited_files": ["packages/waddle_shared/lib/foo.dart"],
                "test_paths": [],
                "output_tail": "unused_import",
            }
        )
        self.assertIn("analyze", prompt.lower())
        self.assertIn("unused", prompt.lower())
        self.assertIn("/qa FIX", prompt)


if __name__ == "__main__":
    unittest.main()
