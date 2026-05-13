#!/usr/bin/env python3
"""Fetch the Pi linux-arm64 release tarball and upgrade /opt/waddle-view over SSH.

Requires Python 3.9+, OpenSSH client (ssh, scp), and for GitHub Actions artifacts
a token in GITHUB_TOKEN or GH_TOKEN with ``actions:read`` scope.

Cross-platform: Windows, macOS, Linux (stdlib only).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import secrets
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path
from typing import Any, Callable, Mapping, Optional, Tuple
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen

GITHUB_API = "https://api.github.com"
API_HEADERS_BASE: dict[str, str] = {
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "waddle-view-pi-remote-upgrade",
}

TARBALL_NAME_RE = re.compile(r"^waddle-view-linux-arm64-.+\.tar\.gz$")
TARBALL_LABEL_RE = re.compile(r"^waddle-view-linux-arm64-(.+)\.tar\.gz$")
ARTIFACT_NAME_PREFIX = "linux-arm64-bundle"
WORKFLOW_FILE = "release-pi.yml"
REMOTE_VERSION_FILE = "/opt/waddle-view/bundle/data/flutter_assets/version.json"
REMOTE_INSTALL_ROOT = "/opt/waddle-view"


class NoMatchingReleaseAsset(Exception):
    """Latest GitHub release exists but has no Pi arm64 tarball asset."""


def _token() -> Optional[str]:
    return os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")


def github_request(
    path_or_url: str,
    *,
    token: Optional[str],
    method: str = "GET",
    data: Optional[bytes] = None,
) -> tuple[int, bytes]:
    """HTTP(S) request to GitHub API or absolute URL. Returns (status, body)."""
    url = path_or_url if path_or_url.startswith("http") else f"{GITHUB_API}{path_or_url}"
    headers = dict(API_HEADERS_BASE)
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(req, timeout=120) as resp:
            return resp.getcode(), resp.read()
    except HTTPError as e:
        body = e.read() if e.fp else b""
        return e.code, body


def pick_pi_tarball_asset_info(
    release_json: Mapping[str, Any],
) -> Optional[Tuple[str, str]]:
    """Return ``(browser_download_url, asset_name)`` for the Pi tarball, or None."""
    for asset in release_json.get("assets") or []:
        name = asset.get("name") or ""
        if TARBALL_NAME_RE.match(name):
            url = asset.get("browser_download_url")
            if isinstance(url, str):
                return url, name
    return None


def pick_pi_tarball_asset(release_json: Mapping[str, Any]) -> Optional[str]:
    """Return ``browser_download_url`` for the Pi tarball asset, or None."""
    info = pick_pi_tarball_asset_info(release_json)
    return info[0] if info else None


def tarball_label_from_filename(filename: str) -> str:
    """Human-readable version label from ``waddle-view-linux-arm64-<label>.tar.gz``."""
    m = TARBALL_LABEL_RE.match(filename)
    return m.group(1) if m else filename


def format_installed_version_json(raw: str) -> str:
    """Format Flutter ``version.json`` body for display, or a fallback string."""
    text = raw.strip()
    if not text or text == "{}":
        return "(not installed or no version.json on Pi)"
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return f"(invalid version.json: {text[:80]!r})"
    if not isinstance(data, dict):
        return str(data)
    ver = data.get("version")
    build = data.get("build_number")
    if isinstance(ver, str) and ver:
        if isinstance(build, str) and build:
            return f"{ver}+{build}"
        if isinstance(build, int):
            return f"{ver}+{build}"
        return ver
    return text[:120]


def fetch_latest_release_json(repo: str, token: Optional[str]) -> dict[str, Any]:
    owner, name = repo.split("/", 1)
    code, body = github_request(f"/repos/{owner}/{name}/releases/latest", token=token)
    if code != 200:
        raise SystemExit(
            f"GitHub releases/latest failed HTTP {code}: {body[:500]!r}"
        )
    data = json.loads(body.decode())
    if not isinstance(data, dict):
        raise SystemExit("Unexpected releases/latest JSON shape.")
    return data


def fetch_workflow_runs_json(
    repo: str, token: str, branch: str
) -> dict[str, Any]:
    owner, name = repo.split("/", 1)
    wf_path = f"/repos/{owner}/{name}/actions/workflows/{WORKFLOW_FILE}/runs"
    query = (
        f"?branch={quote(branch, safe='')}&status=success&per_page=20"
        "&exclude_pull_requests=true"
    )
    code, body = github_request(wf_path + query, token=token)
    if code != 200:
        raise SystemExit(
            f"GitHub workflow runs failed HTTP {code}: {body[:800]!r}"
        )
    data = json.loads(body.decode())
    if not isinstance(data, dict):
        raise SystemExit("Unexpected workflow runs JSON shape.")
    return data


def peek_new_version_label(
    *,
    bundle: Optional[Path],
    source: str,
    repo: str,
    branch: str,
    token: Optional[str],
) -> str:
    """Resolve a display label for the target version without downloading the tarball."""
    if bundle is not None:
        return tarball_label_from_filename(bundle.name)

    if source == "release":
        data = fetch_latest_release_json(repo, token)
        info = pick_pi_tarball_asset_info(data)
        if not info:
            raise NoMatchingReleaseAsset(
                "No asset matching waddle-view-linux-arm64-*.tar.gz on latest release."
            )
        return tarball_label_from_filename(info[1])

    if source == "actions":
        if not token:
            raise SystemExit(
                "Resolving Actions target requires GITHUB_TOKEN or GH_TOKEN "
                "(actions:read)."
            )
        runs_data = fetch_workflow_runs_json(repo, token, branch)
        run_id = newest_successful_run_id(runs_data)
        if run_id is None:
            raise SystemExit(
                f"No successful runs found for {WORKFLOW_FILE} on branch {branch!r}."
            )
        return f"{ARTIFACT_NAME_PREFIX} (workflow run {run_id}, branch {branch})"

    # auto
    data = fetch_latest_release_json(repo, token)
    info = pick_pi_tarball_asset_info(data)
    if info:
        return tarball_label_from_filename(info[1])
    if not token:
        raise SystemExit(
            "Latest release has no Pi tarball; resolving Actions fallback requires "
            "GITHUB_TOKEN or GH_TOKEN (actions:read)."
        )
    runs_data = fetch_workflow_runs_json(repo, token, branch)
    run_id = newest_successful_run_id(runs_data)
    if run_id is None:
        raise SystemExit(
            f"No successful runs found for {WORKFLOW_FILE} on branch {branch!r}."
        )
    return f"{ARTIFACT_NAME_PREFIX} (workflow run {run_id}, branch {branch})"


def ssh_run(
    target: str,
    remote_command: str,
    *,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
    check: bool = False,
) -> subprocess.CompletedProcess:
    ssh_cmd = ssh_base_args(
        target, port=port, identity=identity, batch_mode=batch_mode
    )
    return subprocess.run(
        ssh_cmd + ["bash", "-lc", remote_command],
        capture_output=True,
        text=True,
        check=check,
    )


def read_remote_installed_version_label(
    target: str,
    *,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
) -> str:
    """Read ``version`` + ``build_number`` from the Pi bundle via SSH (may use sudo)."""
    cmd = (
        f"sudo test -f {REMOTE_VERSION_FILE!r} && "
        f"sudo cat {REMOTE_VERSION_FILE!r} || echo '{{}}'"
    )
    proc = ssh_run(
        target,
        cmd,
        port=port,
        identity=identity,
        batch_mode=batch_mode,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip()
        return f"(could not read remote version: {err or 'ssh failed'})"
    return format_installed_version_json(proc.stdout or "{}")


def prompt_upgrade_confirmation(
    *,
    ssh_target: str,
    current: str,
    new: str,
    yes: bool,
) -> None:
    if yes:
        return
    print()
    print("Upgrade Waddle View")
    print(f"  SSH target:      {ssh_target}")
    print(f"  Current version: {current}")
    print(f"  New version:     {new}")
    print()
    print(
        "A backup of the installed bundle will be created on the Pi before replacing "
        "it, as:"
    )
    print(
        f"  {REMOTE_INSTALL_ROOT}/bundle.backup.<timestamp> "
        "(omitted if no bundle directory exists yet)"
    )
    print()
    answer = input("Proceed with upgrade? [y/N]: ").strip().lower()
    if answer not in ("y", "yes"):
        raise SystemExit("Aborted.")


def newest_successful_run_id(runs_json: Mapping[str, Any]) -> Optional[int]:
    """Pick the newest workflow run by ``created_at`` among listed runs."""
    runs = runs_json.get("workflow_runs") or []
    if not runs:
        return None

    def key(r: Mapping[str, Any]) -> str:
        return str(r.get("created_at") or "")

    sorted_runs = sorted(runs, key=key, reverse=True)
    first = sorted_runs[0]
    rid = first.get("id")
    if isinstance(rid, int):
        return rid
    if isinstance(rid, str) and rid.isdigit():
        return int(rid)
    return None


def pick_linux_arm64_artifact(artifacts_json: Mapping[str, Any]) -> Optional[dict[str, Any]]:
    """Pick the Pi arm64 workflow artifact (``linux-arm64-bundle`` or ``linux-arm64-bundle-<build>``)."""
    prefix = ARTIFACT_NAME_PREFIX
    candidates: list[dict[str, Any]] = []
    for art in artifacts_json.get("artifacts") or []:
        if not isinstance(art, dict):
            continue
        n = art.get("name")
        if not isinstance(n, str):
            continue
        if n == prefix or n.startswith(prefix + "-"):
            candidates.append(art)
    if not candidates:
        return None
    if len(candidates) == 1:
        return dict(candidates[0])

    def rank(art: dict[str, Any]) -> tuple[int, str]:
        n = str(art.get("name") or "")
        tail = n[len(prefix) :]
        if tail == "":
            return (0, n)
        if tail.startswith("-") and tail[1:].isdigit():
            return (2, n)
        if tail.startswith("-"):
            return (1, n)
        return (0, n)

    candidates.sort(key=rank, reverse=True)
    return dict(candidates[0])


def download_release_tarball(repo: str, token: Optional[str]) -> Path:
    data = fetch_latest_release_json(repo, token)
    info = pick_pi_tarball_asset_info(data)
    if not info:
        raise NoMatchingReleaseAsset(
            "No asset matching waddle-view-linux-arm64-*.tar.gz on latest release."
        )
    url = info[0]
    code, blob = github_request(url, token=token)
    if code != 200:
        raise SystemExit(f"Release asset download failed HTTP {code}")
    fd, path = tempfile.mkstemp(suffix=".tar.gz", prefix="waddle-pi-")
    os.close(fd)
    tmp = Path(path)
    tmp.write_bytes(blob)
    return tmp


def download_actions_tarball(
    repo: str,
    token: str,
    branch: str,
    opener: Optional[Callable[..., Any]] = None,
) -> Path:
    """Download Pi arm64 bundle zip from latest successful workflow run, extract tarball."""
    owner, name = repo.split("/", 1)
    runs_data = fetch_workflow_runs_json(repo, token, branch)
    run_id = newest_successful_run_id(runs_data)
    if run_id is None:
        raise SystemExit(
            f"No successful runs found for {WORKFLOW_FILE} on branch {branch!r}."
        )

    art_path = f"/repos/{owner}/{name}/actions/runs/{run_id}/artifacts"
    code, body = github_request(art_path, token=token)
    if code != 200:
        raise SystemExit(f"List artifacts failed HTTP {code}: {body[:500]!r}")
    art = pick_linux_arm64_artifact(json.loads(body.decode()))
    if not art:
        raise SystemExit(
            f"No workflow artifact matching {ARTIFACT_NAME_PREFIX!r} or "
            f"{ARTIFACT_NAME_PREFIX!r}-<build_number> on run {run_id}."
        )
    archive_url = art.get("archive_download_url")
    if not isinstance(archive_url, str):
        raise SystemExit("Artifact missing archive_download_url.")

    req = Request(
        archive_url,
        headers={
            **API_HEADERS_BASE,
            "Authorization": f"Bearer {token}",
        },
        method="GET",
    )
    open_fn = opener or urlopen
    with open_fn(req, timeout=300) as resp:
        zip_bytes = resp.read()

    tmpdir = tempfile.mkdtemp(prefix="waddle-pi-artifact-")
    try:
        zpath = Path(tmpdir) / "bundle.zip"
        zpath.write_bytes(zip_bytes)
        with zipfile.ZipFile(zpath) as zf:
            names = zf.namelist()
            tgz_members = [n for n in names if n.endswith(".tar.gz")]
            if not tgz_members:
                raise SystemExit(f"No .tar.gz inside artifact zip: {names!r}")
            member = tgz_members[0]
            fd, out_path = tempfile.mkstemp(suffix=".tar.gz", prefix="waddle-pi-")
            os.close(fd)
            out = Path(out_path)
            with zf.open(member) as src, open(out, "wb") as dst:
                shutil.copyfileobj(src, dst)
            return out
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def resolve_tarball(
    *,
    bundle: Optional[Path],
    source: str,
    repo: str,
    branch: str,
    token: Optional[str],
    opener: Optional[Callable[..., Any]] = None,
) -> Path:
    if bundle is not None:
        p = bundle.expanduser().resolve()
        if not p.is_file():
            raise SystemExit(f"--bundle not a file: {p}")
        return p

    if source == "release":
        try:
            return download_release_tarball(repo, token)
        except NoMatchingReleaseAsset as e:
            raise SystemExit(str(e)) from None

    if source == "actions":
        if not token:
            raise SystemExit(
                "Downloading Actions artifacts requires GITHUB_TOKEN or GH_TOKEN "
                "in the environment (scope: actions:read)."
            )
        return download_actions_tarball(repo, token, branch, opener=opener)

    # auto
    try:
        return download_release_tarball(repo, token)
    except NoMatchingReleaseAsset:
        if not token:
            raise SystemExit(
                "Latest release has no Pi tarball; falling back to Actions requires "
                "GITHUB_TOKEN or GH_TOKEN (actions:read)."
            ) from None
        return download_actions_tarball(repo, token, branch, opener=opener)


def ssh_base_args(
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


def scp_to_remote(
    local: Path,
    remote_path: str,
    target: str,
    *,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
) -> None:
    cmd = ["scp"]
    if batch_mode:
        cmd.extend(["-o", "BatchMode=yes"])
    if port is not None:
        cmd.extend(["-P", str(port)])
    if identity is not None:
        cmd.extend(["-i", str(identity.expanduser().resolve())])
    cmd.extend([str(local), f"{target}:{remote_path}"])
    subprocess.run(cmd, check=True)


def remote_upgrade_script(remote_tar: str) -> str:
    """Bash script run on the Pi (single quoted heredoc-safe segments only)."""
    return f"""set -eu
REMOTE_TAR={remote_tar!r}
systemctl --user stop waddle-view 2>/dev/null || true
ROOT="${{WADDLE_INSTALL_ROOT:-/opt/waddle-view}}"
BUNDLE="$ROOT/bundle"
if [ -d "$BUNDLE" ]; then
  BACKUP="$ROOT/bundle.backup.$(date +%Y%m%d%H%M%S)"
  echo "Backing up $BUNDLE to $BACKUP"
  sudo cp -a "$BUNDLE" "$BACKUP"
fi
WORKDIR=$(mktemp -d)
cleanup() {{ rm -rf "$WORKDIR"; rm -f "$REMOTE_TAR"; }}
trap cleanup EXIT
cp "$REMOTE_TAR" "$WORKDIR/bundle.tar.gz"
tar xzf "$WORKDIR/bundle.tar.gz" -C "$WORKDIR"
cd "$WORKDIR"
SUB=$(find . -maxdepth 1 -type d -name 'waddle-view-linux-arm64-*' | head -n 1)
if [ -z "$SUB" ]; then
  echo "Expected waddle-view-linux-arm64-* directory inside tarball." >&2
  exit 1
fi
cd "$SUB"
sudo bash install.sh
systemctl --user start waddle-view 2>/dev/null || true
echo "Upgrade finished."
"""


def run_remote_upgrade(
    target: str,
    local_tarball: Path,
    *,
    port: Optional[int],
    identity: Optional[Path],
    batch_mode: bool,
    dry_run: bool,
) -> None:
    token_hex = secrets.token_hex(4)
    remote_tar = f"/tmp/waddle-view-upgrade-{os.getpid()}-{token_hex}.tar.gz"
    if dry_run:
        print(f"Would: scp {local_tarball} -> {target}:{remote_tar}")
        print(
            "Would: ssh ... backup /opt/waddle-view/bundle, extract, "
            "sudo bash install.sh, systemd start."
        )
        return

    scp_to_remote(
        local_tarball,
        remote_tar,
        target,
        port=port,
        identity=identity,
        batch_mode=batch_mode,
    )

    script = remote_upgrade_script(remote_tar)
    ssh_cmd = ssh_base_args(
        target, port=port, identity=identity, batch_mode=batch_mode
    )
    subprocess.run(
        ssh_cmd + ["bash", "-lc", script],
        check=True,
    )


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Upgrade Waddle View on a Raspberry Pi over SSH.",
    )
    p.add_argument(
        "ssh_target",
        nargs="?",
        help="user@host (optional if --ssh is set).",
    )
    p.add_argument(
        "--ssh",
        metavar="USER@HOST",
        help="SSH destination (overrides positional ssh_target).",
    )
    p.add_argument(
        "-i",
        "--identity",
        type=Path,
        help="SSH private key file (passed to ssh/scp -i).",
    )
    p.add_argument(
        "-p",
        "--port",
        type=int,
        default=None,
        help="SSH port.",
    )
    p.add_argument(
        "--bundle",
        type=Path,
        default=None,
        help="Local path to waddle-view-linux-arm64-*.tar.gz (skip download).",
    )
    p.add_argument(
        "--source",
        choices=("auto", "release", "actions"),
        default="auto",
        help="Where to fetch the tarball if --bundle is omitted (default: auto).",
    )
    p.add_argument(
        "--repo",
        default="dukk/waddle-view",
        help="GitHub owner/repo for release/actions download.",
    )
    p.add_argument(
        "--branch",
        default="main",
        help="Branch filter for Actions runs (default: main).",
    )
    p.add_argument(
        "--no-batch",
        action="store_true",
        help="Do not pass ssh BatchMode=yes (allows keyboard-interactive SSH auth).",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions only; do not scp/ssh or download.",
    )
    p.add_argument(
        "--yes",
        "-y",
        action="store_true",
        help="Skip interactive confirmation (for automation).",
    )
    ns = p.parse_args(argv)
    target = ns.ssh or ns.ssh_target
    if not target:
        p.error("Provide ssh_target or --ssh USER@HOST.")
    ns.ssh_target_resolved = target
    return ns


def main(argv: Optional[list[str]] = None) -> None:
    args = parse_args(argv)
    token = _token()
    batch_mode = not args.no_batch
    target = args.ssh_target_resolved

    if args.dry_run:
        try:
            new_label = peek_new_version_label(
                bundle=args.bundle,
                source=args.source,
                repo=args.repo,
                branch=args.branch,
                token=token,
            )
        except NoMatchingReleaseAsset as e:
            new_label = str(e)
        except Exception as e:
            new_label = f"(could not resolve new version: {type(e).__name__}: {e})"
        current = read_remote_installed_version_label(
            target,
            port=args.port,
            identity=args.identity,
            batch_mode=batch_mode,
        )
        print("Dry run — would prompt:")
        print(f"  Current version: {current}")
        print(f"  New version:     {new_label}")
        print(
            "  Backup on Pi:    "
            f"{REMOTE_INSTALL_ROOT}/bundle.backup.<timestamp> (if bundle exists)"
        )
        if args.bundle:
            tb = args.bundle.expanduser().resolve()
            run_remote_upgrade(
                target,
                tb,
                port=args.port,
                identity=args.identity,
                batch_mode=batch_mode,
                dry_run=True,
            )
        else:
            print(
                f"Would download tarball (--source {args.source}, repo {args.repo}, "
                f"branch {args.branch!r})."
            )
            if args.source in ("auto", "actions") and not token:
                print(
                    "Note: set GITHUB_TOKEN or GH_TOKEN for Actions or auto fallback."
                )
            print(
                f"Would: scp <tarball> -> {target}:/tmp/waddle-view-upgrade-*.tar.gz"
            )
            print(
                "Would: ssh ... backup bundle, extract, sudo bash install.sh, "
                "systemctl --user start waddle-view"
            )
        return

    try:
        new_label = peek_new_version_label(
            bundle=args.bundle,
            source=args.source,
            repo=args.repo,
            branch=args.branch,
            token=token,
        )
    except NoMatchingReleaseAsset as e:
        raise SystemExit(str(e)) from None

    current = read_remote_installed_version_label(
        target,
        port=args.port,
        identity=args.identity,
        batch_mode=batch_mode,
    )
    prompt_upgrade_confirmation(
        ssh_target=target,
        current=current,
        new=new_label,
        yes=args.yes,
    )

    tarball = resolve_tarball(
        bundle=args.bundle,
        source=args.source,
        repo=args.repo,
        branch=args.branch,
        token=token,
    )
    try:
        run_remote_upgrade(
            target,
            tarball,
            port=args.port,
            identity=args.identity,
            batch_mode=batch_mode,
            dry_run=False,
        )
    finally:
        if args.bundle is None and tarball.exists():
            try:
                tarball.unlink()
            except OSError:
                pass


if __name__ == "__main__":
    main()
