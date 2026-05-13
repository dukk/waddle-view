#!/usr/bin/env python3
"""Push ``waddle-view-linux-arm64-main.tar.gz`` from this folder to a Pi and install.

Delegates to ``deploy/pi-remote-upgrade.py`` (OpenSSH ``ssh``/``scp``, Python 3.9+).

Default SSH destination: ``dukk@10.2.0.10``. Run from repo root or any cwd.

Examples::

    python deploy/dev-pi/install_main_to_pi.py
    python deploy/dev-pi/install_main_to_pi.py --ssh pi@192.168.1.50
    python deploy/dev-pi/install_main_to_pi.py --dry-run
    python deploy/dev-pi/install_main_to_pi.py -y
    python deploy/dev-pi/install_main_to_pi.py --sync-local-dev
    python deploy/dev-pi/install_main_to_pi.py --sync-local-dev --db C:\\path\\waddle_view.sqlite

``--sync-local-dev`` copies your desktop **SQLite** file (``waddle_view.sqlite``), the
**``media/``** tree used by ``FileSystemBlobStore`` (same parent directory as the DB), to the Pi
under ``/home/<ssh-user>/.local/share/com.waddleview.waddle_display/`` (same layout as Flutter Linux
``path_provider``) and copies ``apps/waddle_display/.env.development`` to
``/opt/waddle-view/bundle/.env.development`` so a **debug** build with systemd
``WorkingDirectory=/opt/waddle-view/bundle`` can load provider keys via ``loadDevDotenvFromFilesystem``.
Release/profile binaries do **not** read that file (Dart only merges dev dotenv in ``kDebugMode``);
the SQLite file is used in all modes.

Remote paths use ``/home/<ssh-user>/.local/...`` (and ``/root`` for ``root@``), with no
``~`` or ``$HOME`` in the ``ssh`` command string — Windows OpenSSH can drop those and leave
``mkdir`` with no operand.
"""
from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Optional

DEV_PI_DIR = Path(__file__).resolve().parent
REPO_ROOT = DEV_PI_DIR.parent.parent
APP_PACKAGE_DIR = REPO_ROOT / "apps" / "waddle_display"
DEFAULT_TARBALL = DEV_PI_DIR / "waddle-view-linux-arm64-main.tar.gz"
UPGRADE_SCRIPT = DEV_PI_DIR.parent / "pi-remote-upgrade.py"
DEFAULT_SSH = "dukk@10.2.0.10"

REMOTE_APP_SUPPORT_REL = Path(".local/share/com.waddleview.waddle_display")
REMOTE_SQLITE_NAME = "waddle_view.sqlite"
REMOTE_BUNDLE_ENV = "/opt/waddle-view/bundle/.env.development"


def ssh_user_from_target(target: str) -> str:
    if "@" in target:
        return target.split("@", 1)[0]
    return target


def remote_unix_home_from_ssh_target(target: str) -> str:
    """Infer remote login home without ``~`` or ``$`` (Windows OpenSSH can mangle those in ``-c``)."""
    user = ssh_user_from_target(target)
    if user == "root":
        return "/root"
    return f"/home/{user}"


def default_local_sqlite_candidates(
    *,
    home: Path,
    appdata_roaming: Optional[Path],
    is_windows: bool,
    is_darwin: bool,
) -> list[Path]:
    """Paths ``path_provider`` uses for this app (same order as practical lookup)."""
    candidates: list[Path] = []
    if is_windows and appdata_roaming is not None:
        candidates.append(
            appdata_roaming / "com.waddleview" / "waddle_display" / REMOTE_SQLITE_NAME
        )
    if is_darwin:
        candidates.append(
            home
            / "Library/Application Support/com.waddleview.waddle_display"
            / REMOTE_SQLITE_NAME
        )
    candidates.append(home / REMOTE_APP_SUPPORT_REL / REMOTE_SQLITE_NAME)
    return candidates


def _platform_sqlite_context() -> tuple[Path, Optional[Path], bool, bool]:
    home = Path.home()
    is_windows = sys.platform == "win32"
    is_darwin = sys.platform == "darwin"
    appdata: Optional[Path] = None
    if is_windows:
        roaming = os.environ.get("APPDATA")
        if roaming:
            appdata = Path(roaming)
    return home, appdata, is_windows, is_darwin


def resolve_local_sqlite_path(
    explicit: Optional[Path],
    *,
    home: Optional[Path] = None,
    appdata_roaming: Optional[Path] = None,
    is_windows: Optional[bool] = None,
    is_darwin: Optional[bool] = None,
) -> Path:
    if explicit is not None:
        p = explicit.expanduser().resolve()
        if not p.is_file():
            raise SystemExit(f"SQLite file not found: {p}")
        return p

    h, ar, win, dar = _platform_sqlite_context()
    if home is not None:
        h = home
    if is_windows is not None:
        win = is_windows
    if is_darwin is not None:
        dar = is_darwin
    if appdata_roaming is not None:
        ar = appdata_roaming

    for c in default_local_sqlite_candidates(
        home=h, appdata_roaming=ar, is_windows=win, is_darwin=dar
    ):
        if c.is_file():
            return c.resolve()

    searched = ", ".join(
        str(p)
        for p in default_local_sqlite_candidates(
            home=h, appdata_roaming=ar, is_windows=win, is_darwin=dar
        )
    )
    raise SystemExit(
        "Could not find local waddle_view.sqlite. Run the app once on this machine, "
        f"or pass --db PATH. Searched: {searched}"
    )


def resolve_dev_env_path(
    explicit: Optional[Path],
    *,
    app_package_dir: Path = APP_PACKAGE_DIR,
) -> Path:
    if explicit is not None:
        p = explicit.expanduser().resolve()
        if not p.is_file():
            raise SystemExit(f".env.development not found: {p}")
        return p
    p = (app_package_dir / ".env.development").resolve()
    if not p.is_file():
        raise SystemExit(
            f"Missing {p}\n"
            "Create it next to the Flutter package (not committed) or pass "
            "--env-development PATH."
        )
    return p


def _ssh_base_args(
    target: str,
    *,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
) -> list[str]:
    args = ["ssh"]
    if batch_mode:
        args.extend(["-o", "BatchMode=yes"])
    if port is not None:
        args.extend(["-p", str(port)])
    if identity is not None:
        args.extend(["-i", str(identity.expanduser().resolve())])
    args.append(target)
    return args


def _scp_push(
    local: Path,
    remote_path: str,
    target: str,
    *,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
) -> list[str]:
    cmd = ["scp"]
    if batch_mode:
        cmd.extend(["-o", "BatchMode=yes"])
    if port is not None:
        cmd.extend(["-P", str(port)])
    if identity is not None:
        cmd.extend(["-i", str(identity.expanduser().resolve())])
    cmd.extend([str(local), f"{target}:{remote_path}"])
    return cmd


def _sqlite_sidecar_paths(main_db: Path) -> list[Path]:
    out = [main_db]
    for suffix in ("-wal", "-shm"):
        p = main_db.with_name(main_db.name + suffix)
        if p.is_file():
            out.append(p)
    return out


def local_blob_media_dir(sqlite_path: Path) -> Path:
    """``media/`` next to ``waddle_view.sqlite`` (same layout as ``main.dart`` blob store)."""
    return sqlite_path.parent / "media"


def _scp_push_dir_contents(
    local_dir: Path,
    remote_dir: str,
    target: str,
    *,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
) -> list[str]:
    """Recursive ``scp`` of *contents* of ``local_dir`` into existing remote ``remote_dir``."""
    cmd = ["scp"]
    if batch_mode:
        cmd.extend(["-o", "BatchMode=yes"])
    if port is not None:
        cmd.extend(["-P", str(port)])
    if identity is not None:
        cmd.extend(["-i", str(identity.expanduser().resolve())])
    local_src = local_dir.resolve().as_posix() + "/."
    cmd.extend(["-r", local_src, f"{target}:{remote_dir}"])
    return cmd


def sync_local_dev_to_pi(
    target: str,
    *,
    local_sqlite: Path,
    dev_env: Path,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
    dry_run: bool,
) -> None:
    """Stop waddle-view, push DB (+ WAL/SHM), ``media/`` blobs, ``.env.development``, restart."""
    ssh_u = ssh_user_from_target(target)
    ssh_cmd = _ssh_base_args(
        target, port=port, identity=identity, batch_mode=batch_mode
    )
    rel_support = REMOTE_APP_SUPPORT_REL.as_posix()
    remote_support = str(
        PurePosixPath(remote_unix_home_from_ssh_target(target)) / rel_support
    )

    def maybe_run(cmd: list[str]) -> None:
        print("+", " ".join(cmd), flush=True)
        if not dry_run:
            subprocess.run(cmd, check=True)

    maybe_run(
        ssh_cmd
        + [
            "bash",
            "-lc",
            f"mkdir -p {shlex.quote(remote_support)}",
        ]
    )
    maybe_run(
        ssh_cmd
        + ["bash", "-lc", "systemctl --user stop waddle-view 2>/dev/null || true"]
    )

    for f in _sqlite_sidecar_paths(local_sqlite):
        remote_name = f.name
        dest = f"/tmp/waddle-sync-{os.getpid()}-{remote_name}"
        maybe_run(
            _scp_push(
                f,
                dest,
                target,
                port=port,
                identity=identity,
                batch_mode=batch_mode,
            )
        )
        dest_q = shlex.quote(dest)
        dest_remote = shlex.quote(f"{remote_support}/{remote_name}")
        maybe_run(ssh_cmd + ["bash", "-lc", f"mv -f {dest_q} {dest_remote}"])

    media_dir = local_blob_media_dir(local_sqlite)
    if media_dir.is_dir():
        media_root = str(PurePosixPath(remote_support) / "media")
        maybe_run(
            ssh_cmd
            + [
                "bash",
                "-lc",
                f"rm -rf {shlex.quote(media_root)} && mkdir -p {shlex.quote(media_root)}",
            ]
        )
        remote_media = media_root + "/"
        maybe_run(
            _scp_push_dir_contents(
                media_dir,
                remote_media,
                target,
                port=port,
                identity=identity,
                batch_mode=batch_mode,
            )
        )
    elif media_dir.exists():
        print(
            f"Skipping blob sync: expected a directory at {media_dir}, found a file.",
            file=sys.stderr,
            flush=True,
        )
    else:
        print(
            f"No local blob store at {media_dir} (skipping media/ sync).",
            file=sys.stderr,
            flush=True,
        )

    tmp_env = f"/tmp/waddle-env-dev-{os.getpid()}.env"
    maybe_run(
        _scp_push(
            dev_env,
            tmp_env,
            target,
            port=port,
            identity=identity,
            batch_mode=batch_mode,
        )
    )
    # Bundle CWD (systemd WorkingDirectory) so loadDevDotenvFromFilesystem finds it in kDebugMode.
    tmp_q = shlex.quote(tmp_env)
    bundle_q = shlex.quote(REMOTE_BUNDLE_ENV)
    remote_install = (
        f"sudo cp {tmp_q} {bundle_q} && "
        f"sudo chown {shlex.quote(ssh_u + ':' + ssh_u)} {bundle_q} && "
        f"sudo chmod 600 {bundle_q} && "
        f"rm -f {tmp_q}"
    )
    maybe_run(ssh_cmd + ["bash", "-lc", remote_install])

    maybe_run(
        ssh_cmd
        + ["bash", "-lc", "systemctl --user start waddle-view 2>/dev/null || true"]
    )


def parse_args(argv: Optional[list[str]]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=(
            "SCP the dev-pi main arm64 tarball to a Raspberry Pi and run install.sh "
            "via pi-remote-upgrade.py."
        ),
    )
    p.add_argument(
        "ssh_target",
        nargs="?",
        default=None,
        help=f"user@host (default: {DEFAULT_SSH!r}).",
    )
    p.add_argument(
        "--ssh",
        metavar="USER@HOST",
        default=None,
        help="SSH destination (overrides positional ssh_target).",
    )
    p.add_argument(
        "--bundle",
        type=Path,
        default=DEFAULT_TARBALL,
        help=f"Tarball path (default: {DEFAULT_TARBALL.name} next to this script).",
    )
    p.add_argument(
        "-i",
        "--identity",
        type=Path,
        default=None,
        help="SSH private key (passed through to pi-remote-upgrade).",
    )
    p.add_argument(
        "-p",
        "--port",
        type=int,
        default=None,
        help="SSH port.",
    )
    p.add_argument(
        "--no-batch",
        action="store_true",
        help="Allow keyboard-interactive SSH (passes --no-batch).",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions only; no scp/ssh.",
    )
    p.add_argument(
        "-y",
        "--yes",
        action="store_true",
        help="Skip upgrade confirmation prompt.",
    )
    p.add_argument(
        "--sync-local-dev",
        action="store_true",
        help=(
            "After a successful upgrade, copy local waddle_view.sqlite (+ WAL/SHM if present), "
            "the sibling media/ blob tree, and apps/waddle_display/.env.development to the Pi "
            "(see module docstring)."
        ),
    )
    p.add_argument(
        "--db",
        type=Path,
        default=None,
        help="Override local SQLite file (used with --sync-local-dev).",
    )
    p.add_argument(
        "--env-development",
        type=Path,
        default=None,
        metavar="PATH",
        help="Override path to .env.development (default: apps/waddle_display/.env.development).",
    )
    p.add_argument(
        "passthrough",
        nargs=argparse.REMAINDER,
        help="Extra args forwarded to pi-remote-upgrade.py (use after --).",
    )
    return p.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> None:
    args = parse_args(argv)
    target = args.ssh or args.ssh_target or DEFAULT_SSH
    bundle = args.bundle.expanduser().resolve()

    if not UPGRADE_SCRIPT.is_file():
        raise SystemExit(f"Missing upgrade script: {UPGRADE_SCRIPT}")
    if not bundle.is_file():
        raise SystemExit(
            f"Tarball not found: {bundle}\n"
            "Place waddle-view-linux-arm64-main.tar.gz next to this script or pass "
            "--bundle PATH."
        )

    cmd: list[str] = [
        sys.executable,
        str(UPGRADE_SCRIPT),
        "--ssh",
        target,
        "--bundle",
        str(bundle),
    ]
    if args.identity is not None:
        cmd.extend(["-i", str(args.identity.expanduser().resolve())])
    if args.port is not None:
        cmd.extend(["-p", str(args.port)])
    if args.no_batch:
        cmd.append("--no-batch")
    if args.dry_run:
        cmd.append("--dry-run")
    if args.yes:
        cmd.extend(["--yes"])
    extra = args.passthrough or []
    if extra and extra[0] == "--":
        extra = extra[1:]
    cmd.extend(extra)

    batch_mode = not args.no_batch
    exit_code = subprocess.call(cmd)
    if exit_code != 0:
        raise SystemExit(exit_code)

    if args.sync_local_dev:
        local_db = resolve_local_sqlite_path(args.db)
        env_path = resolve_dev_env_path(args.env_development)
        sync_local_dev_to_pi(
            target,
            local_sqlite=local_db,
            dev_env=env_path,
            port=args.port,
            identity=args.identity,
            batch_mode=batch_mode,
            dry_run=args.dry_run,
        )


if __name__ == "__main__":
    main()
