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
    python deploy/dev-pi/install_main_to_pi.py --sync-local-dev --db C:\\path\\waddle_display.db

After a successful upgrade the script installs a **systemd user unit** for
``waddle-view`` under ``~/.config/systemd/user/`` (from ``deploy/linux-arm64/waddle-view.service``),
merging ``Environment=`` entries from the template, any existing remote user unit, and every
``KEY=value`` assignment in local ``apps/waddle_display/.env.development`` when that file exists
(or ``--env-development``). Values already on the Pi unit are kept; local dotenv only adds keys
the unit does not have yet. Legacy ``WADDLE_*`` names are rewritten to ``WADDLE_DISPLAY_*`` (and
deprecated keys such as ``WADDLE_HTTP_BIND`` / ``WADDLE_API_KEY_FILE`` are dropped). It runs
``daemon-reload``, ``enable``, and ``restart`` (or ``start`` if not yet running), enables **linger**
for the SSH user when ``loginctl`` is available, and removes any legacy installer's ``~/.bashrc``
block that used to ``source`` a remote dotenv file.

``--sync-local-dev`` copies your desktop **SQLite** file (``waddle_display.db``), the
**``media/``** tree used by ``FileSystemBlobStore`` (same parent directory as the DB), to the Pi
under ``/home/<ssh-user>/.local/share/com.waddleview.waddle_display/`` (same layout as Flutter Linux
``path_provider`` / ``APPLICATION_ID``) and copies ``apps/waddle_display/.env.development`` to
``/opt/waddle-view/bundle/.env.development`` so a **debug** build with systemd
``WorkingDirectory=/opt/waddle-view/bundle`` can load provider keys via ``loadDevDotenvFromFilesystem``.
Release/profile binaries do **not** read that file (Dart only merges dev dotenv in ``kDebugMode``);
the SQLite file is used in all modes.

Remote paths use ``/home/<ssh-user>/.local/...`` (and ``/root`` for ``root@``), with no
``~`` or ``$HOME`` in the ``ssh`` command string — Windows OpenSSH can drop those and leave
``mkdir`` with no operand.

``ssh`` forwards the remote command as one line; the server ``sh -c`` splits on spaces unless
the script for ``bash -lc`` is a single quoted word. Passing ``bash``, ``-lc``, and
``mkdir -p /path`` as separate argv tokens becomes ``bash -lc mkdir -p /path`` with no inner
quotes, so ``-c`` only sees ``mkdir`` and the path is dropped (``mkdir: missing operand``).
Use :func:`_ssh_remote_bash_lc` so the whole script is one ``-c`` argument.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Optional

DEV_PI_DIR = Path(__file__).resolve().parent
REPO_ROOT = DEV_PI_DIR.parent.parent
APP_PACKAGE_DIR = REPO_ROOT / "apps" / "waddle_display"
DEFAULT_TARBALL = DEV_PI_DIR / "waddle-view-linux-arm64-main.tar.gz"
UPGRADE_SCRIPT = DEV_PI_DIR.parent / "pi-remote-upgrade.py"
UNIT_TEMPLATE = REPO_ROOT / "deploy" / "linux-arm64" / "waddle-view.service"
DEFAULT_SSH = "dukk@10.2.0.10"
SYSTEMD_USER_UNIT_NAME = "waddle-view"

REMOTE_APP_SUPPORT_REL = Path(".local/share/com.waddleview.waddle_display")
REMOTE_SQLITE_NAME = "waddle_display.db"
REMOTE_BUNDLE_ENV = "/opt/waddle-view/bundle/.env.development"

# Legacy ~/.bashrc block from older installer versions (removed on each run).
SHELL_RC_BLOCK_BEGIN = "# WADDLE_VIEW_INSTALL_MAIN_TO_PI_BEGIN"
SHELL_RC_BLOCK_END = "# WADDLE_VIEW_INSTALL_MAIN_TO_PI_END"

# Remote shell dotenv layout (legacy bashrc installer; helpers kept for tests and removal).
REMOTE_SHELL_DOTENV_DIR_REL = Path(".local/share/waddle_display")
REMOTE_SHELL_DOTENV_EXAMPLE_NAME = ".env.example"
REMOTE_SHELL_DOTENV_ENV_NAME = ".env"

_DOTENV_LINE_RE = re.compile(
    r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$"
)

# Legacy waddle_display env names → current ``WADDLE_DISPLAY_*`` (see display_env.dart /
# provider_access_token_env.dart). Applied when building the systemd unit.
DISPLAY_ENV_LEGACY_TO_CURRENT: dict[str, str] = {
    "WADDLE_HTTP_BIND": "WADDLE_DISPLAY_HTTP_BIND_IP",
    "WADDLE_HTTP_PORT": "WADDLE_DISPLAY_HTTP_PORT",
    "WADDLE_HTTP_TLS": "WADDLE_DISPLAY_HTTP_TLS",
    "WADDLE_HTTP_TLS_DIR": "WADDLE_DISPLAY_HTTP_TLS_DIR",
    "WADDLE_HTTP_TLS_CERT": "WADDLE_DISPLAY_HTTP_TLS_CERT",
    "WADDLE_HTTP_TLS_KEY": "WADDLE_DISPLAY_HTTP_TLS_KEY",
    "WADDLE_HTTP_CORS_ORIGINS": "WADDLE_DISPLAY_HTTP_CORS_ORIGINS",
    "WADDLE_CONTROLLER_PUBLIC_URL": "WADDLE_DISPLAY_CONTROLLER_PUBLIC_URL",
    "WADDLE_VIEWER_REGISTRATION_SECRET": "WADDLE_DISPLAY_VIEWER_REGISTRATION_SECRET",
    "WADDLE_PEXELS_VIDEO_MAX_TEXTURE_PIXELS": "WADDLE_DISPLAY_PEXELS_VIDEO_MAX_TEXTURE_PIXELS",
    "WADDLE_OPENAI_API_KEY": "WADDLE_DISPLAY_OPENAI_API_KEY",
    "WADDLE_OPEN_WEATHER_MAP_API_KEY": "WADDLE_DISPLAY_OPEN_WEATHER_MAP_API_KEY",
    "WADDLE_PEXELS_API_KEY": "WADDLE_DISPLAY_PEXELS_API_KEY",
    "WADDLE_FLICKR_API_KEY": "WADDLE_DISPLAY_FLICKR_API_KEY",
    "WADDLE_FINHUB_API_KEY": "WADDLE_DISPLAY_FINHUB_API_KEY",
    "WADDLE_MICROSOFT_GRAPH_CLIENT_ID": "WADDLE_DISPLAY_MICROSOFT_GRAPH_CLIENT_ID",
    "WADDLE_GOOGLE_CLIENT_ID": "WADDLE_DISPLAY_GOOGLE_CLIENT_ID",
    "WADDLE_APPLE_CLIENT_ID": "WADDLE_DISPLAY_APPLE_CLIENT_ID",
    "WADDLE_PEXELS_VIDEO_HWDEC": "WADDLE_DISPLAY_PEXELS_VIDEO_HWDEC",
    "WADDLE_PEXELS_MAX_VIDEO_DOWNLOAD_WIDTH": "WADDLE_DISPLAY_PEXELS_MAX_VIDEO_DOWNLOAD_WIDTH",
}

DEPRECATED_DISPLAY_ENV_KEYS = frozenset({"WADDLE_API_KEY_FILE"})


def remote_shell_dotenv_dir(remote_home: str) -> str:
    """Absolute POSIX path to ``~/.local/share/waddle_display`` on the remote."""
    return str(PurePosixPath(remote_home).joinpath(*REMOTE_SHELL_DOTENV_DIR_REL.parts))


def pick_remote_shell_rc_path(
    remote_home: str,
    *,
    bashrc_exists: bool,
    bash_profile_exists: bool,
) -> str:
    """Match remote login-shell practice: prefer ``.bashrc``, else ``.bash_profile``, else ``.bashrc``."""
    br = str(PurePosixPath(remote_home) / ".bashrc")
    bp = str(PurePosixPath(remote_home) / ".bash_profile")
    if bashrc_exists:
        return br
    if bash_profile_exists:
        return bp
    return br


def shell_env_bashrc_block(remote_home: str) -> str:
    """Lines (with markers) appended to the remote user's rc file; *remote_home* is absolute POSIX."""
    dev = str(
        PurePosixPath(remote_shell_dotenv_dir(remote_home)) / REMOTE_SHELL_DOTENV_ENV_NAME
    )
    lines = [
        SHELL_RC_BLOCK_BEGIN,
        "# Waddle Display dotenv (sourced for ssh sessions; Flutter uses its own paths).",
        f"if [ -f {_posix_sh_single_quote(dev)} ]; then",
        "  set -a",
        f"  . {_posix_sh_single_quote(dev)}",
        "  set +a",
        "fi",
        SHELL_RC_BLOCK_END,
    ]
    return "\n".join(lines) + "\n"


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
            appdata_roaming
            / "com.waddleview"
            / "waddle_display"
            / REMOTE_SQLITE_NAME
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
        "Could not find local waddle_display.db. Run the app once on this machine, "
        f"or pass --db PATH. Searched: {searched}"
    )


def resolve_env_example_path(
    *,
    app_package_dir: Path = APP_PACKAGE_DIR,
) -> Path:
    p = (app_package_dir / ".env.example").resolve()
    if not p.is_file():
        raise SystemExit(f"Missing {p}")
    return p


def resolve_unit_template_path(
    *,
    unit_template: Path = UNIT_TEMPLATE,
) -> Path:
    p = unit_template.resolve()
    if not p.is_file():
        raise SystemExit(f"Missing systemd unit template: {p}")
    return p


def parse_dotenv_file(path: Path) -> dict[str, str]:
    """Parse ``KEY=value`` assignments from a dotenv file (comments and blanks skipped)."""
    text = path.read_text(encoding="utf-8")
    out: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip().rstrip("\r")
        if not line or line.startswith("#"):
            continue
        match = _DOTENV_LINE_RE.match(line)
        if not match:
            continue
        key, value = match.group(1), match.group(2)
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        out[key] = value
    return out


def normalize_display_environment(
    env: dict[str, str],
) -> tuple[dict[str, str], list[str]]:
    """Rewrite legacy display env keys to ``WADDLE_DISPLAY_*``; drop deprecated entries."""
    out = dict(env)
    notes: list[str] = []
    for old, new in DISPLAY_ENV_LEGACY_TO_CURRENT.items():
        if old not in out:
            continue
        legacy_val = out.pop(old)
        if new in out and str(out[new]).strip():
            notes.append(f"dropped legacy {old} ({new} already set)")
            continue
        out[new] = legacy_val
        notes.append(f"{old} -> {new}")
    for key in DEPRECATED_DISPLAY_ENV_KEYS:
        if key in out:
            out.pop(key)
            notes.append(f"removed deprecated {key}")
    for key in list(out):
        if key.startswith("WADDLE_") and not key.startswith("WADDLE_DISPLAY_"):
            out.pop(key)
            notes.append(f"removed unrecognized {key}")
    return out, notes


def merge_install_unit_environment(
    local_dotenv: dict[str, str],
    remote_dotenv: dict[str, str],
) -> tuple[dict[str, str], list[str]]:
    """Merge env for a Pi upgrade: fill gaps from local, never overwrite remote values.

    Each side is normalized (legacy ``WADDLE_*`` → ``WADDLE_DISPLAY_*``) before merge.
    On duplicate canonical keys, **remote** (existing unit) wins so upgrades keep Pi secrets.
    """
    local_norm, local_notes = normalize_display_environment(local_dotenv)
    remote_norm, remote_notes = normalize_display_environment(remote_dotenv)
    merged = {**local_norm, **remote_norm}
    return merged, local_notes + remote_notes


def parse_unit_service_environment(template: str) -> dict[str, str]:
    """Extract ``Environment=`` / ``Environment="K=V"`` assignments from the unit template."""
    env: dict[str, str] = {}
    for line in template.splitlines():
        stripped = line.strip()
        if not stripped.startswith("Environment="):
            continue
        payload = stripped.removeprefix("Environment=").strip()
        if payload.startswith('"') and payload.endswith('"'):
            payload = payload[1:-1].replace('\\"', '"').replace("\\\\", "\\")
        if "=" not in payload:
            continue
        key, value = payload.split("=", 1)
        env[key] = value
    return env


def systemd_environment_line(key: str, value: str) -> str:
    """One ``Environment=`` directive safe for systemd unit files."""
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
        raise ValueError(f"invalid environment variable name: {key!r}")
    if re.search(r'[\s"\\#]', value):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'Environment="{key}={escaped}"'
    return f"Environment={key}={value}"


def build_user_unit_content(template: str, dotenv: dict[str, str]) -> str:
    """Return unit text with merged ``Environment=`` lines ([dotenv] overrides template defaults)."""
    merged, _ = normalize_display_environment(
        {**parse_unit_service_environment(template), **dotenv}
    )
    result: list[str] = []
    section: Optional[str] = None
    service_other: list[str] = []

    for line in template.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if section == "Service":
                for key in sorted(merged):
                    result.append(systemd_environment_line(key, merged[key]))
                result.extend(service_other)
                service_other = []
            section = stripped[1:-1]
            result.append(line)
            continue
        if section == "Service":
            if stripped.startswith("Environment"):
                continue
            service_other.append(line)
        else:
            result.append(line)

    if section == "Service":
        for key in sorted(merged):
            result.append(systemd_environment_line(key, merged[key]))
        result.extend(service_other)

    text = "\n".join(result)
    return text if text.endswith("\n") else text + "\n"


def fetch_remote_unit_environment(
    target: str,
    *,
    remote_home: str,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
    dry_run: bool,
) -> dict[str, str]:
    """Read ``Environment=`` from an existing user unit on the Pi (empty when missing)."""
    if dry_run:
        return {}
    unit_path = str(
        PurePosixPath(remote_home) / ".config/systemd/user" / f"{SYSTEMD_USER_UNIT_NAME}.service"
    )
    unit_path_q = _posix_sh_single_quote(unit_path)
    ssh_cmd = _ssh_base_args(target, port=port, identity=identity, batch_mode=batch_mode)
    proc = subprocess.run(
        ssh_cmd + [_ssh_remote_bash_lc(f"cat {unit_path_q} 2>/dev/null || true")],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return {}
    return parse_unit_service_environment(proc.stdout)


def remote_remove_legacy_bashrc_block_script(remote_home: str) -> str:
    """Remove a prior installer's marked block from ``.bashrc`` / ``.bash_profile``."""
    br = _posix_sh_single_quote(str(PurePosixPath(remote_home) / ".bashrc"))
    bp = _posix_sh_single_quote(str(PurePosixPath(remote_home) / ".bash_profile"))
    begin = SHELL_RC_BLOCK_BEGIN.replace("/", "\\/")
    end = SHELL_RC_BLOCK_END.replace("/", "\\/")
    return (
        f"for RC in {br} {bp}; do "
        f'[ -f "$RC" ] && sed -i "/{begin}/,/{end}/d" "$RC" || true; '
        "done"
    )


def install_systemd_user_unit_and_restart(
    target: str,
    *,
    env_development: Optional[Path],
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
    dry_run: bool,
) -> None:
    """Install ``waddle-view.service`` under the SSH user's systemd user dir; enable and restart."""
    ssh_cmd = _ssh_base_args(
        target, port=port, identity=identity, batch_mode=batch_mode
    )
    remote_home = remote_unix_home_from_ssh_target(target)
    unit_dir = str(PurePosixPath(remote_home) / ".config/systemd/user")
    unit_path = str(PurePosixPath(unit_dir) / f"{SYSTEMD_USER_UNIT_NAME}.service")
    dev_local = optional_local_env_development_path(env_development)
    local_dotenv = parse_dotenv_file(dev_local) if dev_local is not None else {}
    remote_dotenv = fetch_remote_unit_environment(
        target,
        remote_home=remote_home,
        port=port,
        identity=identity,
        batch_mode=batch_mode,
        dry_run=dry_run,
    )
    # Local fills missing keys only; existing Pi unit values are never overwritten.
    normalized, migrate_notes = merge_install_unit_environment(local_dotenv, remote_dotenv)
    if migrate_notes:
        print("Display environment normalization:", flush=True)
        for note in migrate_notes:
            print(f"  {note}", flush=True)
    template = resolve_unit_template_path().read_text(encoding="utf-8")
    unit_body = build_user_unit_content(template, normalized)

    def maybe_run(cmd: list[str]) -> None:
        print("+", " ".join(cmd), flush=True)
        if not dry_run:
            subprocess.run(cmd, check=True)

    pid = os.getpid()
    frag_local = Path(tempfile.gettempdir()) / f"waddle-view-unit-{pid}.service"
    try:
        frag_local.write_text(unit_body, encoding="utf-8", newline="\n")
    except OSError as exc:
        raise SystemExit(f"Could not write local unit fragment: {exc}") from exc

    frag_remote = f"/tmp/waddle-view-unit-{pid}.service"
    frag_remote_q = _posix_sh_single_quote(frag_remote)
    unit_dir_q = _posix_sh_single_quote(unit_dir)
    unit_path_q = _posix_sh_single_quote(unit_path)
    unit_name_q = _posix_sh_single_quote(SYSTEMD_USER_UNIT_NAME)

    if dry_run:
        env_src = str(dev_local) if dev_local is not None else "(none)"
        env_count = len(parse_unit_service_environment(unit_body))
        print(
            f"Would: install {unit_path} with {env_count} Environment= entries "
            f"(remote unit + {env_src}), remove legacy bashrc block, "
            f"systemctl --user enable, loginctl enable-linger, restart {SYSTEMD_USER_UNIT_NAME}",
            flush=True,
        )
        frag_local.unlink(missing_ok=True)
        return

    maybe_run(
        _scp_push(
            frag_local,
            frag_remote,
            target,
            port=port,
            identity=identity,
            batch_mode=batch_mode,
        )
    )
    frag_local.unlink(missing_ok=True)

    remote_install = (
        f"set -eu; "
        f"{remote_remove_legacy_bashrc_block_script(remote_home)}; "
        f"mkdir -p {unit_dir_q}; "
        f"mv -f {frag_remote_q} {unit_path_q}; "
        f"chmod 644 {unit_path_q}; "
        "systemctl --user daemon-reload; "
        f"systemctl --user enable {unit_name_q}; "
        "loginctl enable-linger \"$(id -un)\" 2>/dev/null || true; "
        f"systemctl --user stop {unit_name_q} 2>/dev/null || true; "
        "pkill -x waddle_display 2>/dev/null || true; "
        f"systemctl --user restart {unit_name_q} 2>/dev/null || "
        f"systemctl --user start {unit_name_q}"
    )
    maybe_run(ssh_cmd + [_ssh_remote_bash_lc(remote_install)])
    if dev_local is None:
        print(
            "No local apps/waddle_display/.env.development — systemd unit uses template "
            "Environment= only (pass --env-development PATH to merge provider keys).",
            file=sys.stderr,
            flush=True,
        )


def optional_local_env_development_path(
    explicit: Optional[Path],
    *,
    app_package_dir: Path = APP_PACKAGE_DIR,
) -> Optional[Path]:
    """Return a local ``.env.development`` path if present; do not require the file."""
    if explicit is not None:
        p = explicit.expanduser().resolve()
        if not p.is_file():
            raise SystemExit(f".env.development not found: {p}")
        return p
    p = (app_package_dir / ".env.development").resolve()
    return p if p.is_file() else None


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


def _posix_sh_single_quote(s: str) -> str:
    """Return *s* as a POSIX ``sh`` single-quoted literal (including the outer quotes)."""
    return "'" + s.replace("'", "'\"'\"'") + "'"


def _remote_gnu_sed_strip_cr_inplace(quoted_path: str) -> str:
    """Remote GNU ``sed -i`` to drop Windows ``\\r`` before ``\\n`` (path must already be shell-quoted)."""
    return f"sed -i 's/\\r$//' {quoted_path}"


def _ssh_remote_bash_lc(script: str) -> str:
    """One ``ssh`` argv after ``user@host``: ``bash -lc '<script>'`` for the remote shell."""
    return "bash -lc " + _posix_sh_single_quote(script)


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
    """``media/`` next to ``waddle_display.db`` (same layout as ``main.dart`` blob store)."""
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
            _ssh_remote_bash_lc(
                "mkdir -p " + _posix_sh_single_quote(remote_support),
            ),
        ]
    )
    unit_q = _posix_sh_single_quote(SYSTEMD_USER_UNIT_NAME)
    maybe_run(
        ssh_cmd
        + [
            _ssh_remote_bash_lc(
                f"systemctl --user stop {unit_q} 2>/dev/null || true; "
                "pkill -x waddle_display 2>/dev/null || true",
            ),
        ]
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
        dest_q = _posix_sh_single_quote(dest)
        dest_remote = _posix_sh_single_quote(f"{remote_support}/{remote_name}")
        maybe_run(
            ssh_cmd
            + [_ssh_remote_bash_lc(f"mv -f {dest_q} {dest_remote}")],
        )

    media_dir = local_blob_media_dir(local_sqlite)
    if media_dir.is_dir():
        media_root = str(PurePosixPath(remote_support) / "media")
        media_q = _posix_sh_single_quote(media_root)
        maybe_run(
            ssh_cmd
            + [
                _ssh_remote_bash_lc(f"rm -rf {media_q} && mkdir -p {media_q}"),
            ],
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
    tmp_q = _posix_sh_single_quote(tmp_env)
    bundle_q = _posix_sh_single_quote(REMOTE_BUNDLE_ENV)
    owner_q = _posix_sh_single_quote(f"{ssh_u}:{ssh_u}")
    remote_install = (
        f"sudo cp {tmp_q} {bundle_q} && "
        f"sudo chown {owner_q} {bundle_q} && "
        f"sudo chmod 600 {bundle_q} && "
        f"sudo sed -i 's/\\r$//' {bundle_q} && "
        f"rm -f {tmp_q}"
    )
    maybe_run(ssh_cmd + [_ssh_remote_bash_lc(remote_install)])

    unit_q = _posix_sh_single_quote(SYSTEMD_USER_UNIT_NAME)
    maybe_run(
        ssh_cmd
        + [
            _ssh_remote_bash_lc(
                f"systemctl --user restart {unit_q} 2>/dev/null || "
                f"systemctl --user start {unit_q} 2>/dev/null || true",
            ),
        ]
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
            "After a successful upgrade, copy local waddle_display.db (+ WAL/SHM if present), "
            "the sibling media/ blob tree, and apps/waddle_display/.env.development to the Pi "
            "(see module docstring). The dev env file must exist (default path or --env-development)."
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
        help=(
            "Path to .env.development. Merged into the systemd unit as Environment= lines when "
            "present. Required for --sync-local-dev (also copies to the bundle for debug builds)."
        ),
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

    install_systemd_user_unit_and_restart(
        target,
        env_development=args.env_development,
        port=args.port,
        identity=args.identity,
        batch_mode=batch_mode,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
