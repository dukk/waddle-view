# Point this repo's Git hooks at .githooks/ (pre-push test gate).
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root
git config core.hooksPath .githooks
git update-index --chmod=+x .githooks/pre-push 2>$null
git update-index --chmod=+x .githooks/post-commit 2>$null
Write-Host "Installed Git hooks: core.hooksPath=.githooks"
Write-Host "Pre-push will run scripts/pre_push_checks.py"
Write-Host "Post-commit will run scripts/post_commit_gate.py (build + tests)"
Write-Host "Skip once: git push --no-verify"
Write-Host "Skip via env: `$env:WADDLE_SKIP_PREPUSH_CHECKS=1; git push"
Write-Host "Skip post-commit: `$env:WADDLE_SKIP_POST_COMMIT_CHECKS=1; git commit"
