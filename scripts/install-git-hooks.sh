#!/bin/sh
# Point this repo's Git hooks at .githooks/ (pre-push test gate).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git config core.hooksPath .githooks
chmod +x .githooks/pre-push .githooks/post-commit 2>/dev/null || true
git update-index --chmod=+x .githooks/pre-push .githooks/post-commit 2>/dev/null || true
echo "Installed Git hooks: core.hooksPath=.githooks"
echo "Pre-push will run scripts/pre_push_checks.py"
echo "Post-commit will run scripts/post_commit_gate.py (build + tests)"
echo "Skip once: git push --no-verify"
echo "Skip via env: WADDLE_SKIP_PREPUSH_CHECKS=1 git push"
echo "Skip post-commit: WADDLE_SKIP_POST_COMMIT_CHECKS=1 git commit"
