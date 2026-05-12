"""Unit tests for deploy/pi-remote-upgrade.py (stdlib + importlib)."""
from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path


def _load_pi_remote_upgrade():
    root = Path(__file__).resolve().parent
    path = root / "pi-remote-upgrade.py"
    spec = importlib.util.spec_from_file_location("pi_remote_upgrade", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TestPiRemoteUpgradeHelpers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pru = _load_pi_remote_upgrade()

    def test_pick_pi_tarball_asset_match(self):
        pru = self.pru
        release = {
            "assets": [
                {"name": "other.zip", "browser_download_url": "https://x/a.zip"},
                {
                    "name": "waddle-view-linux-arm64-v1.0.0.tar.gz",
                    "browser_download_url": "https://example.com/pi.tar.gz",
                },
            ],
        }
        self.assertEqual(
            pru.pick_pi_tarball_asset(release),
            "https://example.com/pi.tar.gz",
        )

    def test_pick_pi_tarball_rejects_non_pi_names(self):
        pru = self.pru
        release = {
            "assets": [
                {
                    "name": "waddle-view-linux-x64-v1.0.0.tar.gz",
                    "browser_download_url": "https://example.com/x64.tar.gz",
                },
            ],
        }
        self.assertIsNone(pru.pick_pi_tarball_asset(release))

    def test_pick_pi_tarball_asset_empty(self):
        self.assertIsNone(self.pru.pick_pi_tarball_asset({"assets": []}))

    def test_pick_pi_tarball_asset_info(self):
        pru = self.pru
        release = {
            "assets": [
                {
                    "name": "waddle-view-linux-arm64-v2.0.0.tar.gz",
                    "browser_download_url": "https://example.com/pi2.tar.gz",
                },
            ],
        }
        info = pru.pick_pi_tarball_asset_info(release)
        self.assertEqual(
            info,
            ("https://example.com/pi2.tar.gz", "waddle-view-linux-arm64-v2.0.0.tar.gz"),
        )

    def test_tarball_label_from_filename(self):
        pru = self.pru
        self.assertEqual(
            pru.tarball_label_from_filename(
                "waddle-view-linux-arm64-v1.2.3.tar.gz",
            ),
            "v1.2.3",
        )
        self.assertEqual(
            pru.tarball_label_from_filename("waddle-view-linux-arm64-main.tar.gz"),
            "main",
        )

    def test_format_installed_version_json(self):
        pru = self.pru
        self.assertEqual(
            pru.format_installed_version_json(
                '{"version":"1.0.0","build_number":"42"}',
            ),
            "1.0.0+42",
        )
        self.assertEqual(
            pru.format_installed_version_json(
                '{"version":"2.1.0","build_number":7}',
            ),
            "2.1.0+7",
        )
        self.assertEqual(
            pru.format_installed_version_json("{}"),
            "(not installed or no version.json on Pi)",
        )

    def test_newest_successful_run_id(self):
        pru = self.pru
        data = {
            "workflow_runs": [
                {"id": 1, "created_at": "2020-01-02T00:00:00Z"},
                {"id": 99, "created_at": "2020-01-03T00:00:00Z"},
                {"id": 50, "created_at": "2020-01-03T12:00:00Z"},
            ],
        }
        self.assertEqual(pru.newest_successful_run_id(data), 50)

    def test_newest_successful_run_id_string_id(self):
        pru = self.pru
        data = {
            "workflow_runs": [
                {"id": "42", "created_at": "2020-01-01T00:00:00Z"},
            ],
        }
        self.assertEqual(pru.newest_successful_run_id(data), 42)

    def test_newest_successful_run_id_empty(self):
        self.assertIsNone(self.pru.newest_successful_run_id({"workflow_runs": []}))

    def test_pick_linux_arm64_artifact(self):
        pru = self.pru
        data = {
            "artifacts": [
                {
                    "name": "linux-arm64-bundle",
                    "archive_download_url": "https://api.github.com/a/zip",
                },
            ],
        }
        art = pru.pick_linux_arm64_artifact(data)
        self.assertIsNotNone(art)
        assert art is not None
        self.assertEqual(
            art["archive_download_url"],
            "https://api.github.com/a/zip",
        )

    def test_resolve_auto_falls_back_to_actions(self):
        pru = self.pru
        created: list[Path] = []

        def fake_release(*_a, **_k):
            raise pru.NoMatchingReleaseAsset("no arm64 asset on release")

        def fake_actions(_repo, _token, _branch, opener=None):
            fd, path = tempfile.mkstemp(suffix=".tar.gz")
            os.close(fd)
            p = Path(path)
            p.write_bytes(b"x")
            created.append(p)
            return p

        orig_r, orig_a = pru.download_release_tarball, pru.download_actions_tarball
        try:
            pru.download_release_tarball = fake_release
            pru.download_actions_tarball = fake_actions
            out = pru.resolve_tarball(
                bundle=None,
                source="auto",
                repo="o/r",
                branch="main",
                token="tok",
            )
            self.assertEqual(out, created[0])
        finally:
            pru.download_release_tarball = orig_r
            pru.download_actions_tarball = orig_a
            for p in created:
                p.unlink(missing_ok=True)

    def test_resolve_release_exits_without_asset(self):
        pru = self.pru

        def boom(*_a, **_k):
            raise pru.NoMatchingReleaseAsset("no")

        orig = pru.download_release_tarball
        try:
            pru.download_release_tarball = boom
            with self.assertRaises(SystemExit):
                pru.resolve_tarball(
                    bundle=None,
                    source="release",
                    repo="x/y",
                    branch="main",
                    token=None,
                )
        finally:
            pru.download_release_tarball = orig

    def test_resolve_actions_requires_token(self):
        pru = self.pru
        with self.assertRaises(SystemExit) as ctx:
            pru.resolve_tarball(
                bundle=None,
                source="actions",
                repo="x/y",
                branch="main",
                token=None,
            )
        self.assertIn("GITHUB_TOKEN", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
