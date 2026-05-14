#!/usr/bin/env bash
# Installs the Flutter bundle under WADDLE_INSTALL_ROOT (default /opt/waddle-view).
# Optional: WADDLE_INSTALL_RUNTIME_PACKAGES=1 — on apt-based hosts, if ldd reports
# missing libraries, install packages listed in runtime-apt-packages.txt (same dir).
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

APP="$ROOT/bundle/waddle_display"
if [[ ! -x "$APP" ]]; then
  echo "ERROR: expected executable at $APP" >&2
  exit 1
fi

# ldd exits non-zero when libraries are missing; do not let that abort under set -e.
ldd_tmp="$(mktemp)"
set +e
ldd "$APP" >"$ldd_tmp" 2>&1
set -e

if grep -q 'not found' "$ldd_tmp"; then
  echo "ERROR: system libraries required by Waddle View are missing. ldd reports:" >&2
  grep 'not found' "$ldd_tmp" >&2 || true
  echo >&2
  echo "On Raspberry Pi OS / Debian, install typical runtime packages, for example:" >&2
  echo "  sudo apt update && sudo apt install -y --no-install-recommends libmpv2 mpv libgtk-3-0 libsecret-1-0" >&2
  echo >&2
  if [[ "${WADDLE_INSTALL_RUNTIME_PACKAGES:-}" == "1" ]] && command -v apt-get >/dev/null 2>&1; then
    rt_file="$SRC_DIR/runtime-apt-packages.txt"
    if [[ ! -f "$rt_file" ]]; then
      echo "ERROR: $rt_file missing from install bundle." >&2
      rm -f "$ldd_tmp"
      exit 1
    fi
    echo "WADDLE_INSTALL_RUNTIME_PACKAGES=1: installing packages listed in $rt_file …"
    sudo apt-get update
    grep -v '^\s*#' "$rt_file" | grep -v '^\s*$' | xargs sudo apt-get install -y --no-install-recommends
    rm -f "$ldd_tmp"
    ldd_tmp2="$(mktemp)"
    set +e
    ldd "$APP" >"$ldd_tmp2" 2>&1
    set -e
    if grep -q 'not found' "$ldd_tmp2"; then
      echo "ERROR: still missing libraries after apt install:" >&2
      grep 'not found' "$ldd_tmp2" >&2 || true
      rm -f "$ldd_tmp2"
      exit 1
    fi
    rm -f "$ldd_tmp2"
  else
    echo "Or re-run this installer with:" >&2
    echo "  sudo env WADDLE_INSTALL_RUNTIME_PACKAGES=1 bash $SRC_DIR/install.sh" >&2
    rm -f "$ldd_tmp"
    exit 1
  fi
else
  rm -f "$ldd_tmp"
fi

WCTL="$ROOT/bundle/waddlectl/bin/waddlectl"
if [[ -x "$WCTL" ]]; then
  echo "Operator CLI (waddlectl): $WCTL"
else
  echo "Note: waddlectl not found at $WCTL (optional; older release bundles may omit it)."
fi

echo "Done. Configure autostart or systemd (see waddle-view.service template)."
