#!/usr/bin/env bash
set -euo pipefail

ROOT="${WADDLE_INSTALL_ROOT:-/opt/waddle-view}"
KEY_DIR="${WADDLE_API_KEY_DIR:-/etc/waddle-view}"
KEY_FILE="${WADDLE_API_KEY_FILE:-$KEY_DIR/api.key}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Waddle View bundle to $ROOT"
sudo mkdir -p "$ROOT"
sudo rsync -a --delete "$SRC_DIR/bundle/" "$ROOT/bundle/"

sudo mkdir -p "$KEY_DIR"
if [[ ! -f "$KEY_FILE" ]]; then
  echo "Creating API key at $KEY_FILE (mode 600)"
  sudo sh -c "umask 077; openssl rand -hex 32 > \"$KEY_FILE\""
fi

echo "Done. Configure autostart or systemd (see waddle-view.service template)."
