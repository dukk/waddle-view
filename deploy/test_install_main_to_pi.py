"""Unit tests for deploy/dev-pi/install_main_to_pi.py helpers (stdlib + importlib)."""
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


def _load_install_main_to_pi():
    root = Path(__file__).resolve().parent
    path = root / "dev-pi" / "install_main_to_pi.py"
    spec = importlib.util.spec_from_file_location("install_main_to_pi", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TestInstallMainToPiHelpers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.im = _load_install_main_to_pi()

    def test_ssh_user_from_target(self):
        im = self.im
        self.assertEqual(im.ssh_user_from_target("pi@10.0.0.1"), "pi")
        self.assertEqual(im.ssh_user_from_target("dukk@host"), "dukk")

    def test_remote_unix_home_from_ssh_target(self):
        im = self.im
        self.assertEqual(im.remote_unix_home_from_ssh_target("dukk@10.2.0.10"), "/home/dukk")
        self.assertEqual(im.remote_unix_home_from_ssh_target("root@host"), "/root")

    def test_pick_remote_shell_rc_path(self):
        im = self.im
        h = "/home/pi"
        self.assertEqual(
            im.pick_remote_shell_rc_path(h, bashrc_exists=True, bash_profile_exists=True),
            f"{h}/.bashrc",
        )
        self.assertEqual(
            im.pick_remote_shell_rc_path(h, bashrc_exists=False, bash_profile_exists=True),
            f"{h}/.bash_profile",
        )
        self.assertEqual(
            im.pick_remote_shell_rc_path(h, bashrc_exists=False, bash_profile_exists=False),
            f"{h}/.bashrc",
        )

    def test_remote_shell_dotenv_dir(self):
        im = self.im
        self.assertEqual(
            im.remote_shell_dotenv_dir("/home/pi"),
            "/home/pi/.config/waddle_view",
        )

    def test_shell_env_bashrc_block_paths(self):
        im = self.im
        block = im.shell_env_bashrc_block("/home/pi")
        self.assertIn(im.SHELL_RC_BLOCK_BEGIN, block)
        self.assertIn(im.SHELL_RC_BLOCK_END, block)
        self.assertIn("'/home/pi/.config/waddle_view/.env'", block)
        self.assertNotIn(".env.example", block)

    def test_resolve_env_example_path(self):
        im = self.im
        with tempfile.TemporaryDirectory() as tmp:
            app_dir = Path(tmp) / "waddle_display"
            app_dir.mkdir()
            with self.assertRaises(SystemExit):
                im.resolve_env_example_path(app_package_dir=app_dir)
            (app_dir / ".env.example").write_text("# x\n", encoding="utf-8")
            self.assertEqual(
                im.resolve_env_example_path(app_package_dir=app_dir),
                (app_dir / ".env.example").resolve(),
            )

    def test_optional_local_env_development_path(self):
        im = self.im
        with tempfile.TemporaryDirectory() as tmp:
            app_dir = Path(tmp) / "waddle_display"
            app_dir.mkdir()
            self.assertIsNone(
                im.optional_local_env_development_path(None, app_package_dir=app_dir)
            )
            missing = app_dir / "nope.env"
            with self.assertRaises(SystemExit):
                im.optional_local_env_development_path(missing, app_package_dir=app_dir)
            dev = app_dir / ".env.development"
            dev.write_text("K=v\n", encoding="utf-8")
            self.assertEqual(
                im.optional_local_env_development_path(None, app_package_dir=app_dir),
                dev.resolve(),
            )

    def test_remote_gnu_sed_strip_cr_inplace(self):
        im = self.im
        self.assertEqual(
            im._remote_gnu_sed_strip_cr_inplace("'/tmp/f'"),
            "sed -i 's/\\r$//' '/tmp/f'",
        )

    def test_default_local_sqlite_candidates_linux_shape(self):
        im = self.im
        home = Path("/home/tester")
        paths = im.default_local_sqlite_candidates(
            home=home,
            appdata_roaming=None,
            is_windows=False,
            is_darwin=False,
        )
        self.assertIn(
            home / ".local/share/com.waddleview.waddle_display/waddle_view.sqlite",
            paths,
        )

    def test_default_local_sqlite_candidates_windows_shape(self):
        im = self.im
        home = Path("C:/Users/x")
        appdata = Path("C:/Users/x/AppData/Roaming")
        paths = im.default_local_sqlite_candidates(
            home=home,
            appdata_roaming=appdata,
            is_windows=True,
            is_darwin=False,
        )
        self.assertTrue(
            any(
                str(p).replace("\\", "/").endswith(
                    "com.waddleview/waddle_display/waddle_view.sqlite"
                )
                for p in paths
            )
        )

    def test_default_local_sqlite_candidates_macos_shape(self):
        im = self.im
        home = Path("/Users/x")
        paths = im.default_local_sqlite_candidates(
            home=home,
            appdata_roaming=None,
            is_windows=False,
            is_darwin=True,
        )
        self.assertIn(
            home
            / "Library/Application Support/com.waddleview.waddle_display/waddle_view.sqlite",
            paths,
        )

    def test_local_blob_media_dir(self):
        im = self.im
        db = Path("/tmp/waddle_view.sqlite")
        self.assertEqual(
            im.local_blob_media_dir(db),
            Path("/tmp/media"),
        )

    def test_posix_sh_single_quote(self):
        im = self.im
        self.assertEqual(im._posix_sh_single_quote("a"), "'a'")
        q = im._posix_sh_single_quote("a'b")
        self.assertTrue(q.startswith("'") and q.endswith("'"))
        self.assertIn("a", q)
        self.assertIn("b", q)

    def test_remote_gnu_sed_strip_cr_inplace(self):
        im = self.im
        self.assertEqual(
            im._remote_gnu_sed_strip_cr_inplace("'/tmp/f'"),
            "sed -i 's/\\r$//' '/tmp/f'",
        )

    def test_ssh_remote_bash_lc_quotes_full_script(self):
        im = self.im
        script = "mkdir -p " + im._posix_sh_single_quote("/home/u/.local/share/x")
        remote = im._ssh_remote_bash_lc(script)
        self.assertTrue(remote.startswith("bash -lc "))
        self.assertIn("mkdir -p ", remote)
        self.assertIn("/home/u/.local/share/x", remote)
        # Inner script must be one -c word: path quoted, whole script outer-quoted.
        self.assertTrue(remote.endswith("'"))

    def test_resolve_local_sqlite_path_explicit(self):
        im = self.im
        with tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False) as tf:
            tf.write(b"")
            p = Path(tf.name)
        try:
            self.assertEqual(
                im.resolve_local_sqlite_path(explicit=p, home=Path.home()),
                p.resolve(),
            )
        finally:
            p.unlink(missing_ok=True)

    def test_resolve_local_sqlite_path_missing(self):
        im = self.im
        with self.assertRaises(SystemExit) as ctx:
            im.resolve_local_sqlite_path(
                explicit=None,
                home=Path("/nonexistent-home-xyz"),
                appdata_roaming=None,
                is_windows=False,
                is_darwin=False,
            )
        self.assertIn("waddle_view.sqlite", str(ctx.exception))

    def test_resolve_dev_env_path_default_under_repo(self):
        im = self.im
        with tempfile.TemporaryDirectory() as tmp:
            app_dir = Path(tmp) / "apps" / "waddle_display"
            app_dir.mkdir(parents=True)
            with self.assertRaises(SystemExit):
                im.resolve_dev_env_path(explicit=None, app_package_dir=app_dir)

            env_file = app_dir / ".env.development"
            env_file.write_text("X=1\n", encoding="utf-8")
            self.assertEqual(
                im.resolve_dev_env_path(explicit=None, app_package_dir=app_dir),
                env_file,
            )


if __name__ == "__main__":
    unittest.main()
