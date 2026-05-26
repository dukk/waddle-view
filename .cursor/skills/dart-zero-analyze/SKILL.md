---
name: dart-zero-analyze
description: >-
  Keep Dart/Flutter workspace packages analyzer-clean after edits (zero issues;
  warnings fail CI). Use when fixing unused imports, scoped analyze failures, or
  before claiming a Dart task is done.
disable-model-invocation: true
---

# Dart zero-analyze (after edits)

CI and the Cursor stop hook require **zero** analyzer issues per touched package. **Warnings count** (e.g. `unused_import`, `unused_local_variable`).

## Commands by package

From repo root (or use [`scripts/qa_scoped_tests.py`](../../../scripts/qa_scoped_tests.py) with `--files` for the hook's scoped sequence):

| Package | Directory | Command |
| --- | --- | --- |
| waddle_shared | `packages/waddle_shared` | `dart analyze` |
| waddle_integrations | `packages/waddle_integrations` | `dart analyze` |
| waddle_plugin_sdk | `packages/waddle_plugin_sdk` | `dart analyze` |
| waddlectl | `apps/waddlectl` | `dart analyze` |
| waddle_display | `apps/waddle_display` | `flutter analyze` |

After editing **shared**, **integrations**, or **plugin_sdk**, also run **`flutter analyze`** in **`apps/waddle_display`** (downstream imports).

Git-scoped local gate: `python scripts/waddle_checks.py fast --from-git` from repo root.

## While coding

- Use the IDE **ReadLints** tool on each edited `.dart` file before ending the turn.
- Prefer removing dead imports/locals over `// ignore:` (only ignore with a one-line justification).
- Safe cleanup: `dart fix --apply` in the package directory, then re-run `dart analyze`.

## Hook skip (discouraged)

- `WADDLE_SKIP_QA_HOOK_ANALYZE=1`: analyze only
- `WADDLE_SKIP_QA_HOOK_TESTS=1`: analyze and tests

See [AGENTS.md](../../../AGENTS.md) and [`run-waddle-checks`](../run-waddle-checks/SKILL.md).
