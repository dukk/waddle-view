#!/usr/bin/env bash
# Creates .local/waddle-display-appdata -> OS application-support dir for waddle_display.
# VS Code/Cursor do not expand ${env:...} in multi-root workspace folder paths.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
link_path="$repo_root/.local/waddle-display-appdata"

if [[ "$(uname -s)" == "Darwin" ]]; then
  target_path="${HOME}/Library/Application Support/com.waddleview/waddle_display"
else
  target_path="${XDG_DATA_HOME:-${HOME}/.local/share}/com.waddleview.waddle_display"
fi

mkdir -p "$(dirname "$link_path")" "$target_path"

if [[ -e "$link_path" || -L "$link_path" ]]; then
  if [[ -L "$link_path" ]]; then
    echo "Symlink already exists: $link_path -> $(readlink "$link_path")"
    exit 0
  fi
  echo "Refusing to overwrite non-symlink path: $link_path" >&2
  exit 1
fi

ln -s "$target_path" "$link_path"
echo "Linked $link_path -> $target_path"
