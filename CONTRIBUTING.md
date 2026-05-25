# Contributing to Waddle View

Thank you for your interest in contributing. This document is for human contributors; automated agents should also read [AGENTS.md](AGENTS.md).

## License

By contributing, you agree that your contributions are licensed under the [Open Non-Commercial License (ONC) v1.0](LICENSE). Commercial use requires a separate agreement with the copyright holder.

## How to contribute

1. Fork the repository and create a branch from `main`.
2. Make focused changes with tests for new behavior (see [AGENTS.md](AGENTS.md) — tests first for new features).
3. Run quality checks before opening a pull request.
4. Open a PR with a clear description and test plan.

## Quality checks

From the **repository root**:

**Fast** (inner loop, no coverage):

```bash
python scripts/waddle_checks.py fast
python scripts/waddle_checks.py fast --from-git   # only packages touched in git diff
```

**CI parity** (before merge):

```bash
python scripts/waddle_checks.py full
python scripts/waddle_checks.py full --controller   # when apps/waddle_controller changed
```

Manual equivalents: [`.cursor/skills/run-waddle-checks/SKILL.md`](.cursor/skills/run-waddle-checks/SKILL.md).

Coverage floor: **≥ 80%** line coverage on `apps/waddle_display`, `packages/waddle_shared`, and `packages/waddle_plugin_sdk` (see `apps/waddle_display/tool/coverage_check.dart`). **90%** is the aspirational target (warn only).

After Dart edits, run scoped analyze/tests:

```bash
python scripts/qa_scoped_tests.py --files path/to/your_file.dart
```

## Drift schema changes

Any change under `packages/waddle_shared/lib/persistence/` must include migration logic and tests in the same PR. See [AGENTS.md](AGENTS.md) for migration pitfalls.

## Controller (TypeScript)

From `apps/waddle_controller`:

```bash
npm ci          # after package.json / lockfile changes; stop npm run dev first on Windows
npm run lint
npm run test:coverage
npm run coverage:check
npm run build
npm run build:server
```

## Security and dependencies

- Never commit secrets (`.env`, instance id files, API keys, backup archives). See [SECURITY.md](SECURITY.md).
- Before a release, maintainers run `python scripts/security_audit.py` and address critical/high npm or Dart advisories.
- [Dependabot](.github/dependabot.yml) opens update PRs for npm and pub ecosystems.

## Cursor-specific files

The [`.cursor/`](.cursor/) directory holds optional Cursor rules, skills, and agent definitions. Runtime hook state under `.cursor/hooks/state/` is **gitignored**. You do not need Cursor to build or test the project.

## Releasing (maintainers)

1. Ensure `main` is green in GitHub Actions.
2. Run `python scripts/waddle_checks.py full` and `python scripts/waddle_checks.py full --controller`.
3. Run `python scripts/security_audit.py` and review findings.
4. Update [CHANGELOG.md](CHANGELOG.md) for the new version.
5. Align `version:` in app `pubspec.yaml` / `package.json` if needed.
6. Create and push an annotated tag:

   ```bash
   git tag -a v1.0.0 -m "v1.0.0"
   git push origin v1.0.0
   ```

7. Wait for the **Release** workflow, then verify assets on GitHub Releases (including `SHA256SUMS.txt` when published).
8. Smoke-test Pi install per [`docs/pi/using-the-image.md`](docs/pi/using-the-image.md).

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). Report conduct concerns to **dukk@dukk.org**.
