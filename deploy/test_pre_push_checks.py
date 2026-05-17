"""Unit tests for scripts/pre_push_checks.py helpers (stdlib + importlib)."""
from __future__ import annotations

import importlib.util
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


def _load_pre_push_checks():
    root = Path(__file__).resolve().parent.parent
    path = root / "scripts" / "pre_push_checks.py"
    name = "pre_push_checks_test"
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


class TestPrePushChecksHelpers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ppc = _load_pre_push_checks()

    def test_npm_lockfile_satisfied_when_stamp_is_newer(self):
        ppc = self.ppc
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            lock = project / "package-lock.json"
            nm = project / "node_modules"
            nm.mkdir()
            lock.write_text("{}", encoding="utf-8")
            stamp = nm / ".package-lock.json"
            stamp.write_text("{}", encoding="utf-8")
            time.sleep(0.05)
            stamp.touch()
            self.assertTrue(ppc._npm_lockfile_satisfied(project))

    def test_npm_lockfile_not_satisfied_when_lock_is_newer(self):
        ppc = self.ppc
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            lock = project / "package-lock.json"
            nm = project / "node_modules"
            nm.mkdir()
            stamp = nm / ".package-lock.json"
            stamp.write_text("{}", encoding="utf-8")
            time.sleep(0.05)
            lock.write_text("{\"v\":2}", encoding="utf-8")
            self.assertFalse(ppc._npm_lockfile_satisfied(project))

    def test_controller_lockfile_stale_warning_none_when_fresh(self):
        ppc = self.ppc
        with tempfile.TemporaryDirectory() as tmp:
            controller = Path(tmp) / "apps" / "waddle_controller"
            nm = controller / "node_modules"
            nm.mkdir(parents=True)
            (controller / "package-lock.json").write_text("{}", encoding="utf-8")
            (nm / ".package-lock.json").write_text("{}", encoding="utf-8")
            time.sleep(0.05)
            (nm / ".package-lock.json").touch()
            with mock.patch.object(ppc, "_controller_dev_server_running", return_value=False):
                self.assertIsNone(ppc.controller_lockfile_stale_warning(controller))

    def test_controller_lockfile_stale_warning_when_lock_newer(self):
        ppc = self.ppc
        with tempfile.TemporaryDirectory() as tmp:
            controller = Path(tmp) / "apps" / "waddle_controller"
            nm = controller / "node_modules"
            nm.mkdir(parents=True)
            stamp = nm / ".package-lock.json"
            stamp.write_text("{}", encoding="utf-8")
            time.sleep(0.05)
            (controller / "package-lock.json").write_text("{\"v\":2}", encoding="utf-8")
            with mock.patch.object(ppc, "_controller_dev_server_running", return_value=False):
                msg = ppc.controller_lockfile_stale_warning(controller)
            self.assertIsNotNone(msg)
            self.assertIn("waddle_controller", msg)
            self.assertIn("npm ci", msg)

    def test_controller_lockfile_stale_warning_dev_server_hint(self):
        ppc = self.ppc
        with tempfile.TemporaryDirectory() as tmp:
            controller = Path(tmp) / "apps" / "waddle_controller"
            nm = controller / "node_modules"
            nm.mkdir(parents=True)
            stamp = nm / ".package-lock.json"
            stamp.write_text("{}", encoding="utf-8")
            time.sleep(0.05)
            (controller / "package-lock.json").write_text("{\"v\":2}", encoding="utf-8")
            with mock.patch.object(ppc, "_controller_dev_server_running", return_value=True):
                msg = ppc.controller_lockfile_stale_warning(controller)
            self.assertIsNotNone(msg)
            self.assertIn("npm run dev", msg)

    def test_controller_dev_server_running_matches_vite_cmdline(self):
        ppc = self.ppc
        with tempfile.TemporaryDirectory() as tmp:
            controller = Path(tmp) / "apps" / "waddle_controller"
            controller.mkdir(parents=True)
            vite = f'node "{controller / "node_modules/vite/bin/vite.js"}"'
            with mock.patch("subprocess.run") as run:
                run.return_value = mock.Mock(returncode=0, stdout=vite)
                self.assertTrue(ppc._controller_dev_server_running(controller))

    def test_build_steps_never_runs_npm_ci_for_controller(self):
        ppc = self.ppc
        root = Path(__file__).resolve().parent.parent
        steps = ppc.build_steps(root, {"controller"})
        labels = [s.label for s in steps]
        self.assertNotIn("npm ci (waddle_controller)", labels)
        self.assertIn("npm run build (waddle_controller)", labels)
        self.assertIn("npm run lint (waddle_controller)", labels)

    def test_controller_dev_server_running_ignores_unrelated_node(self):
        ppc = self.ppc
        with tempfile.TemporaryDirectory() as tmp:
            controller = Path(tmp) / "apps" / "waddle_controller"
            controller.mkdir(parents=True)
            with mock.patch("subprocess.run") as run:
                run.return_value = mock.Mock(
                    returncode=0, stdout="node /other/project/server.js"
                )
                self.assertFalse(ppc._controller_dev_server_running(controller))


if __name__ == "__main__":
    unittest.main()
