#!/bin/sh
# Point this repo's Git hooks at .githooks/ (pre-push test gate).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git config core.hooksPath .githooks
chmod +x .githooks/pre-push 2>/dev/null || true
git update-index --chmod=+x .githooks/pre-push 2>/dev/null || true
echo "Installed Git hooks: core.hooksPath=.githooks"
echo "Pre-push will run scripts/pre_push_checks.py"
echo "Skip once: git push --no-verify"
echo "Skip via env: WADDLE_SKIP_PREPUSH_CHECKS=1 git push"
