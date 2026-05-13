#!/usr/bin/env bash
# Download and install the latest published GitHub Release for this Linux
# architecture (x86_64 or arm64). See docs/pi/using-the-image.md for the
# curl | bash one-liner.
#
# Environment:
#   WADDLE_INSTALL_ROOT   install root (default /opt/waddle-view; install.sh honors this)
#   WADDLE_INSTALL_YES=1  skip the upgrade confirmation prompt (non-interactive)
#   WADDLE_INSTALL_RUNTIME_PACKAGES=1  forward to install.sh: apt-install listed runtime libs on Debian/apt hosts
#
# Usage:
#   bash install-latest-release.sh
#   bash install-latest-release.sh --yes

set -euo pipefail

REPO_OWNER="dukk"
REPO_NAME="waddle-view"
ROOT="${WADDLE_INSTALL_ROOT:-/opt/waddle-view}"
ASSUME_YES="${WADDLE_INSTALL_YES:-}"
work=""

usage() {
  cat <<'EOF'
Download and install the latest waddle-view GitHub Release for Linux x86_64 or arm64.

Environment:
  WADDLE_INSTALL_ROOT   install root (default /opt/waddle-view)
  WADDLE_INSTALL_YES=1  skip upgrade confirmation

Options:
  --yes, -y    skip confirmation when upgrading an existing install
  --help, -h   show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --help | -h)
      usage
      exit 0
      ;;
    --yes | -y)
      ASSUME_YES=1
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

tmp_json="$(mktemp)"
tmp_resolve="$(mktemp)"

cleanup() {
  rm -f "$tmp_json" "$tmp_resolve"
  if [[ -n "$work" ]]; then
    rm -rf "$work"
  fi
}
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "This script requires '$1' on PATH." >&2
    exit 1
  }
}

need_cmd curl
need_cmd tar
need_cmd sudo
need_cmd python3

os="$(uname -s)"
arch="$(uname -m)"
if [[ "$os" != "Linux" ]]; then
  echo "This installer only supports Linux (found OS: $os)." >&2
  echo "For other platforms, open https://github.com/${REPO_OWNER}/${REPO_NAME}/releases" >&2
  exit 1
fi

case "$arch" in
  x86_64 | amd64)
    ASSET_PREFIX="waddle-view-linux-x64"
    ;;
  aarch64 | arm64)
    ASSET_PREFIX="waddle-view-linux-arm64"
    ;;
  *)
    echo "Unsupported CPU architecture: $arch (need x86_64/amd64 or aarch64/arm64)." >&2
    exit 1
    ;;
esac

curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: waddle-view-install-script" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases?per_page=30" \
  -o "$tmp_json"

python3 - "$ASSET_PREFIX" "$tmp_json" >"$tmp_resolve" <<'PY'
import json
import sys

prefix = sys.argv[1]
path = sys.argv[2]
with open(path, encoding="utf-8") as f:
    releases = json.load(f)
want = ".tar.gz"
for rel in releases:
    if rel.get("draft"):
        continue
    tag = rel["tag_name"]
    name = f"{prefix}-{tag}{want}"
    for a in rel.get("assets") or []:
        if a.get("name") == name and a.get("browser_download_url"):
            print(a["browser_download_url"])
            print(tag)
            sys.exit(0)
sys.stderr.write(
    f"No non-draft release asset named {prefix}-<tag>.tar.gz found "
    "(checked newest releases).\n"
)
sys.exit(1)
PY

url=$(head -n 1 "$tmp_resolve")
tag=$(head -n 2 "$tmp_resolve" | tail -n 1)
if [[ -z "$url" || -z "$tag" ]]; then
  echo "Failed to resolve a release download URL." >&2
  exit 1
fi

echo "Latest matching release asset: $ASSET_PREFIX-$tag.tar.gz"
echo "Install root: $ROOT"

if [[ -d "$ROOT/bundle" ]]; then
  echo "An existing installation was found at $ROOT/bundle."
  if [[ -z "$ASSUME_YES" ]]; then
    read -r -p "Upgrade: current bundle will be moved to a timestamped backup, then replaced. Continue? [y/N] " reply || true
    case "$reply" in
      y | Y | yes | YES | Yes) ;;
      *)
        echo "Aborted."
        exit 0
        ;;
    esac
  fi
  backup="${ROOT}/bundle.backup.$(date +%Y%m%d%H%M%S)"
  echo "Moving existing bundle to $backup (sudo required)..."
  sudo mv "$ROOT/bundle" "$backup"
fi

work="$(mktemp -d)"

echo "Downloading release tarball (sudo not required)..."
curl -fsSL "$url" -o "$work/bundle.tar.gz"

echo "Extracting..."
tar xzf "$work/bundle.tar.gz" -C "$work"

shopt -s nullglob
candidates=("$work"/"$ASSET_PREFIX"-*)
if [[ ${#candidates[@]} -ne 1 || ! -d "${candidates[0]}" ]]; then
  echo "Expected exactly one top-level directory matching ${ASSET_PREFIX}-* inside the tarball." >&2
  exit 1
fi
src="${candidates[0]}"
if [[ ! -f "$src/install.sh" ]]; then
  echo "Missing install.sh in extracted directory: $src" >&2
  exit 1
fi

echo "Running bundled install.sh (sudo required)..."
(
  cd "$src"
  sudo env WADDLE_INSTALL_ROOT="$ROOT" WADDLE_INSTALL_RUNTIME_PACKAGES="${WADDLE_INSTALL_RUNTIME_PACKAGES:-}" bash ./install.sh
)

echo "Installed $tag under $ROOT. See deploy/linux-arm64/waddle-view.service for systemd hints."
