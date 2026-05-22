#!/usr/bin/env bash
# In-band Pi upgrade helper invoked by waddle_display POST /v1/display/ops/upgrade.
# Requires passwordless sudo for install steps. See docs/pi/using-the-image.md.
set -euo pipefail

DOWNLOAD_URL=""
SHA256=""
ASSUME_YES="${WADDLE_UPGRADE_YES:-}"

usage() {
  cat <<'EOF'
Usage: waddle-view-upgrade.sh --download-url URL [--sha256 HEX] [--yes]

Downloads a waddle-view-linux-arm64-*.tar.gz release and replaces /opt/waddle-view/bundle.

Environment:
  WADDLE_INSTALL_ROOT   install root (default /opt/waddle-view)
  WADDLE_UPGRADE_YES=1  skip confirmation
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help | -h)
      usage
      exit 0
      ;;
    --yes | -y)
      ASSUME_YES=1
      shift
      ;;
    --download-url)
      DOWNLOAD_URL="${2:-}"
      shift 2
      ;;
    --download-url=*)
      DOWNLOAD_URL="${1#*=}"
      shift
      ;;
    --sha256)
      SHA256="${2:-}"
      shift 2
      ;;
    --sha256=*)
      SHA256="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "--download-url is required" >&2
  exit 2
fi

ROOT="${WADDLE_INSTALL_ROOT:-/opt/waddle-view}"
BUNDLE="$ROOT/bundle"

if [[ -z "$ASSUME_YES" ]]; then
  echo "This will upgrade Waddle View at $ROOT from:"
  echo "  $DOWNLOAD_URL"
  read -r -p "Continue? [y/N] " ans
  case "$ans" in
    y | Y | yes | YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd tar
need_cmd sudo

WORKDIR=$(mktemp -d)
REMOTE_TAR="$WORKDIR/bundle.tar.gz"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "Downloading release tarball…"
curl -fsSL -o "$REMOTE_TAR" "$DOWNLOAD_URL"

if [[ -n "$SHA256" ]]; then
  need_cmd sha256sum
  echo "$SHA256  $REMOTE_TAR" | sha256sum -c -
fi

systemctl --user stop waddle-view 2>/dev/null || true

if [[ -d "$BUNDLE" ]]; then
  BACKUP="$ROOT/bundle.backup.$(date +%Y%m%d%H%M%S)"
  echo "Backing up $BUNDLE to $BACKUP"
  sudo cp -a "$BUNDLE" "$BACKUP"
fi

tar xzf "$REMOTE_TAR" -C "$WORKDIR"
SUB=$(find "$WORKDIR" -maxdepth 1 -type d -name 'waddle-view-linux-arm64-*' | head -n 1)
if [[ -z "$SUB" ]]; then
  echo "Expected waddle-view-linux-arm64-* directory inside tarball." >&2
  exit 1
fi

cd "$SUB"
if [[ -f install.sh ]]; then
  sudo env WADDLE_INSTALL_ROOT="$ROOT" WADDLE_INSTALL_YES=1 bash install.sh
else
  echo "install.sh missing from release bundle." >&2
  exit 1
fi

systemctl --user start waddle-view 2>/dev/null || true
echo "Upgrade finished."
