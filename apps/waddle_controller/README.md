# waddle_controller

Browser **operator UI** for one or more **`waddle_display`** instances. Pair each display with the **adoption API** (`POST /v1/adoption/request` + `POST /v1/adoption/confirm`), then send **`Authorization: Bearer <api_key>`** on protected `/v1/*` routes.

A colocated **BFF** (`server/`, Hono + SQLite) can optionally gate access to the controller SPA and manage local operator accounts. All display REST traffic goes through **`/bff/v1/proxy/*`** so the BFF can reach displays with self-signed TLS; the browser never talks to the display origin directly.

## Development

From this directory:

```bash
npm ci
npm run dev
```

`npm run dev` starts **Vite** (default **https://127.0.0.1:5173**) and the **BFF** (**https://127.0.0.1:5199**). Both use **self-signed TLS by default** (accept the browser warning once). Vite proxies **`/bff`** to the BFF, which forwards display API calls to each display URL. Set **`WADDLE_CONTROLLER_TLS=0`** (and restart) to use plain HTTP everywhere in dev.

Run only the SPA or only the BFF:

```bash
npm run dev:spa
npm run dev:server
```

### Mascot assets (favicons and in-app branding)

Favicons under `public/` and SVGs under `public/brand/` (`headshot.svg`, `mascot.svg`) are generated from the repo root `assets/` sources. After changing mascot artwork, regenerate from the repository root:

```bash
python tool/generate_app_icons.py --web-root apps/waddle_controller
```

Commit the updated files under `public/` so Docker builds (which only copy this app directory) include the latest branding.

### Optional controller authentication (BFF)

| Variable | Default | Purpose |
|----------|---------|---------|
| `WADDLE_CONTROLLER_AUTH_ENABLED` | `0` | Enable BFF sign-in capability (user mode is toggled in Settings) |
| `WADDLE_CONTROLLER_SESSION_SECRET` | — | Required when auth is enabled (session signing) |
| `WADDLE_CONTROLLER_DATA_DIR` | `./data` | SQLite directory (`waddle_controller.db`) |
| `WADDLE_CONTROLLER_BIND` | `127.0.0.1` | BFF listen host |
| `PORT` / `WADDLE_CONTROLLER_PORT` | `5199` | BFF listen port |
| `WADDLE_CONTROLLER_TLS` | `1` | Self-signed HTTPS on the BFF (`0` = plain HTTP) |
| `WADDLE_CONTROLLER_TLS_DIR` | `{data}/tls` | Auto-generated cert storage |
| `WADDLE_CONTROLLER_TLS_CERT` / `_KEY` | — | Override PEM paths |
| `WADDLE_CONTROLLER_SECURE_COOKIES` | mirrors TLS | `1` when TLS is on; set explicitly to override |
| `WADDLE_CONTROLLER_CLIENT_IDENTIFIER` | — | Fixed adoption client id (read-only in UI when set) |

Example (local):

```bash
export WADDLE_CONTROLLER_AUTH_ENABLED=1
export WADDLE_CONTROLLER_SESSION_SECRET=change-me-in-production
npm run dev
```

1. Set `WADDLE_CONTROLLER_AUTH_ENABLED=1` on the BFF (deployment prerequisite).
2. In **Settings → Users**, an admin turns on **User mode** (runtime toggle in SQLite).
3. The first time user mode is enabled with no accounts, the UI forces **Create admin account** (`POST /bff/v1/bootstrap/admin`).
4. Manage accounts on the **Users** tab: set passwords, roles, require password change on next sign-in, and view last login time.
5. Sign in at `/controller-login` when user mode is on. Users flagged for password change land on `/controller-change-password` first.

BFF API base path: **`/bff/v1/*`** (status, auth, settings, users, bootstrap, user-displays, recovery, display proxy).

When **user mode** is on, adopted displays and encrypted API keys are stored in SQLite (`user_displays`) per account. The browser keeps a local cache synced from the server on login and after imports. **Display list backup** (export/import JSON) works in user mode; exports pull from the server first.

When **user mode** is turned off, sign-in is disabled but server data remains. Use **Recover display settings to this browser** on the Displays tab (`POST /bff/v1/recovery/export-displays`) to sign in once and copy an account’s displays into `localStorage`.

**`WADDLE_CONTROLLER_PROXY_UPSTREAM_TIMEOUT_MS`** (default **180000**) caps how long the BFF waits for a proxied display HTTP response before returning **502** with `display_timeout`. Raise on slow hardware if read endpoints still time out during heavy display refresh; mutating routes should return quickly once the display defers post-save refresh work.

### Display pairing

1. Add a display in the first-run dialog (base URL only), or open **Manage displays**.
2. On **Displays**, enter the display REST root, then open **Advanced** for **client identifier** and **role** if needed, and **Request adoption**. Confirm the **challenge code** shown on the display alert.
3. The browser sends **`Origin`** and **`Referer`** through the BFF proxy so the display can allow this origin on protected routes after pairing.
4. Use the **display menu** (top-left) to switch displays; each display keeps its API key and adopted role in **`localStorage`** (and in **`user_displays`** when controller auth is on).

If a display loses its session, use **Adopt display** in the app bar (or complete adoption again on **Displays**).

### Copy screens, overlays, and ticker tapes between displays

When more than one display is paired, **Screens**, **Overlays**, and **Ticker tapes** show **Copy between displays** (requires **`screens.write`**, **`overlays.write`**, or **`ticker.write`** on the active session). On a wide viewport (more than four catalog card columns would fit in a row), the panel sits in a right column capped at two card widths with the page toolbar and catalog list to its left; on narrower widths the toolbar, list, and panel stack vertically.

- **Import into [active]** — pick another display and a catalog item; copies onto the display selected in the header menu.
- **Send from [active]** — pick an item from this display and one or more target displays (checkboxes; **Select all** / **Clear**).
- **On conflict** — **Skip** (leave existing row), **Overwrite** (replace on target), or **Use new id** (optional new label for overlays). The same new id is used for every target when sending to multiple displays.
- **Overlay images** — `falling_images` and other configs that reference blob keys are re-uploaded to each target display.
- **Not copied** — curator program membership, integrations, RSS/calendar/photo content, or screen `data_key` targets. Verify feeds and integrations exist on each display after copying.

Offline displays are disabled in the picker; the transfer is blocked if the source or any selected target is unreachable.

### Integrations

On **Integrations**, enable collectors and edit configuration per integration type. **iCal / ICS Calendar** uses a dedicated form: one-click **Suggested calendars (WebCal.Guru)** shortcuts (U.S. elections, awareness days, holidays, and more), a link to **sign up at WebCal.Guru** for additional calendars, manual feed URL entry, optional label per feed, and a **Category** dropdown (from **Curators → Categories** on the display). Feed ids are generated automatically; the sync window is always 30 days past and future (not shown in the form).

### Interests

Use **Interests** (Config nav, between Integrations and Data) to manage what the display collects: weather locations, RSS feeds, stock symbols, joke categories, and trivia categories. Changes call `GET` / `POST` / `PATCH` / `DELETE` on `/v1/interests/*` on the active display (requires **`interests.write`**; **`interests.read`** for view-only, including power_viewer filter dropdowns on **Data**). Joke and trivia category ids must match an existing **Curators → Categories** slug.

### Data (collected content browser)

**Data** lists ingested rows from `GET /v1/catalog/*` (requires **`content.catalog_read`** or **`content.moderate`**). With **`curator.write`**, use **Add** on the Calendar, Jokes, Photos, Trivia, or Videos tab to upload or enter content manually (provenance **Manual entry**; `POST /v1/curator/manual/*` on the display). With **`content.moderate`** (adopted display role **operator** or **admin**), you can suppress jokes/news/photos/videos/trivia (`PATCH /v1/content/*`) or permanently delete any tab’s row (`DELETE /v1/content/*`; dashboard alerts use `DELETE /v1/alerts/{id}`). **power_viewer** can browse but not delete or suppress.

## Join from a display QR (`/join`)

The display slide type **`controller_invite`** can open **`/join?api=<display REST>`** on this SPA. That page runs **viewer** adoption (challenge on the display, then confirm). For other roles, use **Manage displays**.

Cross-origin calls require the controller origin to pass the display’s **adoption CORS** rules (LAN/private) during pairing; after confirm, the origin is stored on the display. You can also set **`WADDLE_DISPLAY_HTTP_CORS_ORIGINS`** on the display for static seeds.

## UI conventions

### List and catalog pages

Operator list pages (Screens, Integrations, Data, Activity, Users, etc.) share **`DataViewToolbar`** (`src/components/dataView/DataViewToolbar.tsx`): **search**, **sort**, **reload**, **card/table** toggle (persisted per page in `localStorage`), optional extra filters in `filterSlot`, and **`DataViewPagination`** below the list. Client-side lists use **`useClientDataView`**; server-paged lists (Integrations, Data tabs) use **`useServerDataView`** or existing offset/limit query params. See [`.cursor/skills/controller-data-view/SKILL.md`](../../.cursor/skills/controller-data-view/SKILL.md).

### Dialog submit

Dialogs that **Save**, **Create**, or **Add** via an API call must show in-flight feedback: disable the primary button, change its label (`Saving…`, `Creating…`, etc.), keep the dialog open on error, and close on success (typically via `completeDialogSave` in `src/util/dialogSave.ts`). Use a separate flag for initial fetch vs submit. See [`.cursor/skills/controller-dialog-submit/SKILL.md`](../../.cursor/skills/controller-dialog-submit/SKILL.md).

### Screens, overlays, and ticker tapes (add/edit)

Catalog add/edit dialogs use a fixed field order: **label** (required; row id is derived from the label on create), **description** (optional), **type** (choose explicitly on create), then scheduling fields and schema-driven configuration. Operators do not edit raw JSON or type ids. Durations are entered in seconds/minutes/hours (stored as seconds in the display database).

## Tests

Unit tests use [Vitest](https://vitest.dev/) with **jsdom** for the SPA and Node for `server/`. Co-locate tests as `src/**/*.test.ts` and `server/src/**/*.test.ts`.

```bash
npm ci
npm run test              # single run
npm run test:watch        # watch mode
npm run test:coverage     # lcov under coverage/
npm run coverage:check    # CI floor: ≥ 80% lines on auth, api, storage, util/*.ts, constants, server/src
```

CI also runs `npm run lint`, `npm run build`, and `npm run build:server`. Prefer extracting testable logic out of large page components into `src/util/`, `src/storage/`, or `src/api/` so coverage stays maintainable.

## Production build

```bash
npm ci
npm run build
npm run build:server
```

Static files land in **`dist/`**. The BFF compiles to **`server/dist/`**. Linux/Windows release bundles still ship **static `dist/` only** (no Node BFF). Use Docker (below) or run the BFF beside your static host and proxy `/bff` to it.

## Docker (nginx + BFF)

From the **repository root**:

```bash
docker build -f apps/waddle_controller/Dockerfile -t waddle-controller .
docker run --rm -p 8443:443 \
  -v waddle-controller-data:/var/lib/waddle-controller \
  -e WADDLE_CONTROLLER_AUTH_ENABLED=1 \
  -e WADDLE_CONTROLLER_SESSION_SECRET=change-me \
  waddle-controller
```

nginx serves the SPA over **HTTPS** (self-signed cert generated on first start) and proxies **`/bff/`** to the embedded Node BFF on loopback HTTP. Persist **`WADDLE_CONTROLLER_DATA_DIR`** with a volume.

After adoption, the display remembers your controller origin. Optionally set **`WADDLE_DISPLAY_HTTP_CORS_ORIGINS`** on the display for additional static origins.

## Security

- Display list (base URLs, labels, and adopted **API keys** / **roles** when paired) is stored in **`localStorage`** per display row.
- Display backup JSON export/import includes adoption fields for adopted displays.
- Controller BFF sessions use **httpOnly** cookies; only **password hashes** live in BFF SQLite.
- Use a dedicated operator browser profile on shared machines.
- Protect **admin** display API keys; admins can grant new keys without a display challenge.
