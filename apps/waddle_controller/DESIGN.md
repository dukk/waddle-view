# waddle_controller — design language

Human-facing guide for contributors adding operator UI, dialogs, or BFF features. **Setup and env vars** live in [`README.md`](README.md). **Enforcement** for agents and CI is in [`.cursor/rules/waddle-controller.mdc`](../../.cursor/rules/waddle-controller.mdc); step-by-step checklists stay in [`.cursor/skills/`](../../.cursor/skills/).

## Purpose

Browser **operator UI** for one or more **`waddle_display`** instances. The SPA never calls a display origin directly: all display REST goes through **`/bff/v1/proxy/*`** so the BFF can reach displays with self-signed TLS. An optional **BFF** (Hono + SQLite under `server/`) can gate SPA access and manage local operator accounts when `WADDLE_CONTROLLER_AUTH_ENABLED=1`.

## Layering (SOLID)

| Layer | Location | Responsibility |
|-------|----------|----------------|
| API clients | `src/api/` | Typed fetch to BFF and proxied display routes |
| Persistence | `src/storage/` | `localStorage`, schema cache, layout preferences |
| Auth | `src/auth/` | Roles, permissions (sync with `waddle_shared`) |
| Pure helpers | `src/util/` | Dialog save, schema form builders, list pipelines |
| Server | `server/src/` | BFF routes, SQLite, proxy, sessions |
| UI | `src/pages/`, `src/components/`, `src/context/` | Compose the layers above |

**Rules:** keep fetch and storage out of page components when a helper exists; add failing Vitest tests under gated paths (`auth/`, `api/`, `storage/`, `util/*.ts`, `constants/`, `server/src/**`) before production changes.

## Security and roles

- **Never** store plaintext passwords in SQLite (Argon2 hashes only).
- Display **API keys** and adopted roles live in **`localStorage`** per display id; with controller auth on, keys are also encrypted in SQLite **`user_displays`**.
- Display base URLs: **`localStorage`** only.
- Keep [`src/auth/rolePermissions.ts`](src/auth/rolePermissions.ts) in sync with [`packages/waddle_shared/lib/auth/role_permissions.dart`](../../packages/waddle_shared/lib/auth/role_permissions.dart).

## Operator UX — three pillars

### 1. Catalog lists

Any page that shows a **collection** of rows from the display API or BFF (Screens, Integrations, Overlays, Data, Activity, Users, etc.) uses the shared data-view toolkit.

**Exempt** (no full toolbar contract): Remote, Account, Display settings (except nested tables), login/bootstrap/join.

| Piece | Module |
|-------|--------|
| Toolbar | [`DataViewToolbar`](src/components/dataView/DataViewToolbar.tsx) — search, sort, reload, card/table toggle; optional `filterSlot` |
| Client paging | [`useClientDataView`](src/hooks/useClientDataView.ts) + [`DataViewPagination`](src/components/dataView/DataViewPagination.tsx) |
| Server paging | [`useServerDataView`](src/hooks/useServerDataView.ts) — pass `q`, `sort`, `order`, `limit`, `offset` into API params |
| Layout memory | [`useListLayoutPreference`](src/hooks/useListLayoutPreference.ts) + keys in [`listLayoutPreference.ts`](src/storage/listLayoutPreference.ts) |
| Empty states | [`DataViewEmptyState`](src/components/dataView/DataViewEmptyState.tsx) — “no data” vs “no matches” |

**Toolbar layout:** `[Search] [filterSlot…] [Sort] [Order?] [Reload] [Card|Table] [page actions]` — pagination below the list.

**Conventions:**

- Implement **both** card and table layouts over the same `displayRows` / `paginated.items`.
- Reset page index when search, sort, or filter changes.
- Sort labels: operator-visible fields only (name, label, type, dates) — **no “ID” sort** in the UI.
- `onReload` → page `load`; `reloadDisabled` while `useDisplayRefresh().loading` (or page `loading` for BFF-only pages).

Full checklist: [`.cursor/skills/controller-data-view/SKILL.md`](../../.cursor/skills/controller-data-view/SKILL.md).

### 2. Catalog dialogs

Create/edit dialogs for **screens**, **overlays**, and **ticker tapes** share a fixed field order:

1. **Label** (required on create; id derived server-side — preview with [`catalogIdFromLabel.ts`](src/util/catalogIdFromLabel.ts))
2. **Description** (optional multiline)
3. **Type** (empty `Select` + “Select … type” on create only; on edit show read-only type label — no disabled select)
4. Scheduling / shell fields (dwell, weight, enabled, …)
5. Type config via [`SchemaConfigForm`](src/components/config/SchemaConfigForm.tsx) or bespoke overlay panels — **never** pasted JSON

**Never** show raw **id** fields or monospace **`config_json`** text areas in catalog add/edit dialogs.

**Config field UX:** enum and option fields use human labels (`x-waddle-enum-labels` / [`clockEnumLabels.ts`](src/constants/clockEnumLabels.ts)), not stored slugs. Categories, locations, and stock symbols are chosen by **display name** or ticker symbol, not internal ids. Theme accent fields use swatches from the active display theme (`theme-accent` widget).

Canonical examples: [`ScreenDialog.tsx`](src/components/screens/ScreenDialog.tsx), [`OverlaysPage.tsx`](src/pages/OverlaysPage.tsx) (`OverlayDialog`), [`TickerPage.tsx`](src/pages/TickerPage.tsx).

### 3. Async submit

Any MUI `Dialog` (or modal) whose primary action calls an async API:

| Concern | Pattern |
|---------|---------|
| Submit state | `saving` or `busy` — set **after** client validation passes |
| Initial fetch | Separate `loading` — **never** reuse for submit |
| Primary button | `disabled={saving \|\| …}` and `{saving ? 'Saving…' : 'Save'}` (`Creating…` / `Confirming…` for create/confirm) |
| Success | [`completeDialogSave(onSaved, onClose)`](src/util/dialogSave.ts) — await refresh then close |
| Failure | Keep dialog open; show `Alert` with error |
| Children | Pass `disabled={saving}` to config forms where supported |

```ts
setSaving(true);
try {
  await apiFetch(/* … */);
  await completeDialogSave(onSaved, onClose);
} catch (e) {
  setErr(/* … */);
} finally {
  setSaving(false);
}
```

Full checklist: [`.cursor/skills/controller-dialog-submit/SKILL.md`](../../.cursor/skills/controller-dialog-submit/SKILL.md).

## Config editing

Prefer **[`SchemaConfigForm`](src/components/config/SchemaConfigForm.tsx)** when the shape is documented in [`packages/waddle_shared/lib/persistence/config_json_documentation.dart`](../../packages/waddle_shared/lib/persistence/config_json_documentation.dart). Type-level schemas load once per display connect via `GET /v1/meta/config-schemas` into [`configSchemaCache.ts`](src/storage/configSchemaCache.ts).

| Schema signal | UI control |
|---------------|------------|
| `type: boolean` | MUI `Switch` (`WaddleSwitchWidget`) |
| `integer` / `number` + `minimum` / `maximum` | MUI `Slider` (`WaddleSliderWidget`); optional `x-waddle-widget: slider` |
| `x-waddle-widget: duration` | [`DurationInputField`](src/components/DurationInputField.tsx) — values stored as **seconds**; unit picker defaults to **minutes**; lists use [`formatIntervalDisplay`](src/util/durationInput.ts) for human-readable labels |
| `format: waddle-overlay-blob-key` on array items | `OverlayBlobKeysField` — upload via `POST /v1/display/overlays/blobs` |
| `enum` | RJSF select |

Use **bespoke** panels only when RJSF is insufficient (Outlook calendar section, complex overlay branches in [`OverlayConfigPanel.tsx`](src/components/config/OverlayConfigPanel.tsx)). Inside dialogs, pass `disabled={saving}` while submit is in-flight.

New built-in overlay types: DB sync via `ensureOverlayTypes` in `waddle_shared` plus a cache prefix bump in `configSchemaCache.ts` — see [add-display-overlay](../../.cursor/skills/add-display-overlay/SKILL.md).

## Cross-display catalog copy

When multiple displays are paired, **Screens**, **Overlays**, and **Ticker tapes** support **Copy between displays** (requires `screens.write`, `overlays.write`, or `ticker.write`).

| Mode | Behavior |
|------|----------|
| Import into [active] | Copy one item from another display onto the header-selected display |
| Send from [active] | Copy one item to one or more targets (checkboxes; Select all / Clear) |
| On conflict | **Skip**, **Overwrite**, or **Use new id** (optional new label for overlays; same new id for all targets when sending to many) |

**Overlay images:** configs with blob keys (`falling_images`, etc.) are **re-uploaded** to each target.

**Not copied:** curator program membership, integrations, RSS/calendar/photo content, or screen `data_key` targets — verify feeds and integrations on each display after copy.

Details: [`README.md`](README.md#copy-screens-overlays-and-ticker-tapes-between-displays).

## Anti-patterns

- Native `alert()`, `confirm()`, or `prompt()` — use [`useConfirmDialog`](src/hooks/useConfirmDialog.tsx) / [`ConfirmDialog`](src/components/ConfirmDialog.tsx) for destructive or irreversible actions.
- `disabled={loading}` on Save when `loading` only tracks fetch-on-open (use `saving`).
- Omitting `finally { setSaving(false) }` after errors.
- Closing the dialog before the API succeeds (except explicit auth flows).
- Raw `config_json` text areas or visible id fields in catalog dialogs.
- “ID” sort options in list toolbars.
- Embedding `fetch` / `localStorage` in pages when `src/api/` or `src/storage/` helpers exist.

## Extension index

Use skills for full checklists; this table is the entry point.

| Task | Skill |
|------|--------|
| New overlay type (controller UI) | [add-display-overlay](../../.cursor/skills/add-display-overlay/SKILL.md) |
| List / catalog page | [controller-data-view](../../.cursor/skills/controller-data-view/SKILL.md) |
| Save / Create / Confirm dialog | [controller-dialog-submit](../../.cursor/skills/controller-dialog-submit/SKILL.md) |
| Destructive confirm (delete, revoke) | [`useConfirmDialog`](src/hooks/useConfirmDialog.tsx) |
| Schema-driven `config_json` form | [schema-config-form](../../.cursor/skills/schema-config-form/SKILL.md) |
| New REST route on display (proxy consumer) | [add-rest-route](../../.cursor/skills/add-rest-route/SKILL.md) |

## Quality bar

From `apps/waddle_controller`:

```bash
npm run lint          # zero issues (warnings count in CI)
npm run test:coverage
npm run coverage:check  # ≥ 80% lines on gated paths; 90% aspirational warn
npm run build
npm run build:server
```

UI shells (`pages/`, `layout/`, `components/`, `context/`, `App.tsx`, `main.tsx`) are outside the coverage floor until covered with React Testing Library. See [`.cursor/rules/waddle-controller-tests.mdc`](../../.cursor/rules/waddle-controller-tests.mdc).
