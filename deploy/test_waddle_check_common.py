"""Unit tests for scripts/waddle_check_common.py helpers."""
from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


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

    def test_flutter_test_argv_includes_no_pub_on_windows(self):
        c = self.common
        with mock.patch.object(c.sys, "platform", "win32"):
            argv = c.flutter_test_argv(coverage=False, concurrency=1)
        self.assertIn("--no-pub", argv)

    def test_test_concurrency_windows_defaults_to_one(self):
        c = self.common
        with mock.patch.object(c.sys, "platform", "win32"):
            with mock.patch.dict(os.environ, {}, clear=True):
                self.assertEqual(c.test_concurrency(), 1)

    def test_test_concurrency_env_override_on_windows(self):
        c = self.common
        with mock.patch.object(c.sys, "platform", "win32"):
            with mock.patch.dict(os.environ, {"WADDLE_TEST_CONCURRENCY": "4"}):
                self.assertEqual(c.test_concurrency(), 4)

    def test_clean_windows_flutter_native_assets_removes_stale_build_dir(self):
        c = self.common
        with tempfile.TemporaryDirectory() as tmp:
            pkg = Path(tmp) / "waddle_shared"
            native = pkg / "build" / "native_assets" / "windows"
            native.mkdir(parents=True)
            (native / "sqlite3.dll").write_bytes(b"stub")
            bundled = pkg / ".dart_tool" / "lib"
            bundled.mkdir(parents=True)
            (bundled / "sqlite3.dll").write_bytes(b"stub")
            with mock.patch.object(c.sys, "platform", "win32"):
                c.clean_windows_flutter_native_assets(pkg)
            self.assertFalse((pkg / "build" / "native_assets").exists())
            self.assertFalse((bundled / "sqlite3.dll").exists())

    def test_clean_windows_flutter_native_assets_noop_off_windows(self):
        c = self.common
        with tempfile.TemporaryDirectory() as tmp:
            pkg = Path(tmp) / "pkg"
            native = pkg / "build" / "native_assets" / "windows"
            native.mkdir(parents=True)
            with mock.patch.object(c.sys, "platform", "linux"):
                c.clean_windows_flutter_native_assets(pkg)
            self.assertTrue(native.is_dir())

    def test_subprocess_env_prefers_node_before_augment_for_controller(self):
        c = self.common
        c._path_augmented = False
        c._node_bin_dir_before_augment = None
        with tempfile.TemporaryDirectory() as tmp:
            preferred = Path(tmp) / "node22"
            preferred.mkdir()
            fake_node = preferred / ("node.exe" if os.name == "nt" else "node")
            fake_node.write_text("", encoding="utf-8")
            with mock.patch.object(c.shutil, "which", return_value=str(fake_node)):
                c.augment_path_for_tooling()
            controller = self.root / "apps" / "waddle_controller"
            env = c._subprocess_env_for_cwd(controller)
            self.assertIsNotNone(env)
            assert env is not None
            self.assertTrue(env["PATH"].startswith(str(preferred)))
            other = self.root / "apps" / "waddle_display"
            self.assertIsNone(c._subprocess_env_for_cwd(other))


if __name__ == "__main__":
    unittest.main()
