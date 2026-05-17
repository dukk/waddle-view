"""Unit tests for scripts/waddle_check_common.py helpers."""
from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


def _load_common():
    root = Path(__file__).resolve().parent.parent
    path = root / "scripts" / "waddle_check_common.py"
    name = "waddle_check_common_test"
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


class TestWaddleCheckCommon(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.common = _load_common()
        cls.root = Path(__file__).resolve().parent.parent

    def test_needs_pub_get_true_for_pubspec_change(self):
        c = self.common
        self.assertTrue(c.needs_pub_get(["apps/waddle_display/pubspec.yaml"]))
        self.assertTrue(c.needs_pub_get(None))

    def test_needs_pub_get_false_for_lib_only(self):
        c = self.common
        self.assertFalse(
            c.needs_pub_get(["apps/waddle_display/lib/foo.dart"]),
        )

    def test_needs_build_runner_true_for_tables(self):
        c = self.common
        self.assertTrue(
            c.needs_build_runner(
                ["packages/waddle_shared/lib/persistence/tables.dart"],
            ),
        )

    def test_needs_build_runner_false_for_display_lib(self):
        c = self.common
        self.assertFalse(
            c.needs_build_runner(["apps/waddle_display/lib/main.dart"]),
        )

    def test_changed_dart_packages_display_only(self):
        c = self.common
        packages = c.changed_dart_packages(
            ["apps/waddle_display/lib/foo.dart"],
        )
        self.assertEqual(packages, {"display"})

    def test_lib_path_to_test_candidate(self):
        c = self.common
        repo = self.root
        lib = "apps/waddle_display/lib/util/html_entity_decode.dart"
        candidate = c.lib_path_to_test_candidate(repo, lib)
        self.assertIsNotNone(candidate)
        assert candidate is not None
        self.assertTrue(candidate.is_file())
        self.assertTrue(
            str(candidate).replace("\\", "/").endswith(
                "test/util/html_entity_decode_test.dart",
            ),
        )

    def test_infer_scoped_test_paths_from_lib_change(self):
        c = self.common
        scoped = c.infer_scoped_test_paths(
            self.root,
            ["apps/waddle_display/lib/util/html_entity_decode.dart"],
        )
        self.assertIn("display", scoped)
        self.assertTrue(
            any("html_entity_decode_test.dart" in p for p in scoped["display"]),
        )

    def test_flutter_test_argv_includes_concurrency(self):
        c = self.common
        argv = c.flutter_test_argv(coverage=False, concurrency=3, test_paths=None)
        self.assertIn("--concurrency=3", argv)
        self.assertNotIn("--coverage", argv)

    def test_flutter_test_argv_coverage_full_tier(self):
        c = self.common
        argv = c.flutter_test_argv(coverage=True, concurrency=2, test_paths=["test/a_test.dart"])
        self.assertIn("--coverage", argv)
        self.assertIn("test/a_test.dart", argv)


if __name__ == "__main__":
    unittest.main()
