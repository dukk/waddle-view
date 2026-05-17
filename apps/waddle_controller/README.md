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

### Optional controller authentication (BFF)

| Variable | Default | Purpose |
|----------|---------|---------|
| `WADDLE_CONTROLLER_AUTH_ENABLED` | `0` | Require sign-in before using the SPA |
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

1. Sign in at `/controller-login` when auth is enabled.
2. In **Settings → Controller access**, an admin can enable **user management**.
3. The first time user management is turned on with no accounts, the UI forces **Create admin account** (`POST /bff/v1/bootstrap/admin`).
4. Manage accounts under **Users** (nav) when user management is enabled.

BFF API base path: **`/bff/v1/*`** (status, auth, settings, users, bootstrap, user-displays, display proxy).

When **`WADDLE_CONTROLLER_AUTH_ENABLED=1`**, adopted displays and encrypted API keys are stored in SQLite (`user_displays`) per operator account, synced on login, and used by the proxy when the SPA omits the target URL header.

### Display pairing

1. Add a display in the first-run dialog (base URL only), or open **Manage displays**.
2. On **Displays**, enter the display REST root, then open **Advanced** for **client identifier** and **role** if needed, and **Request adoption**. Confirm the **challenge code** shown on the display alert.
3. The browser sends **`Origin`** and **`Referer`** through the BFF proxy so the display can allow this origin on protected routes after pairing.
4. Use the **display menu** (top-left) to switch displays; each display keeps its API key and adopted role in **`localStorage`** (and in **`user_displays`** when controller auth is on).

If a display loses its session, use **Adopt display** in the app bar (or complete adoption again on **Displays**).

### Interests

Use **Interests** (Config nav, between Integrations and Data) to manage what the display collects: weather locations, RSS feeds, stock symbols, joke categories, and trivia categories. Changes call `GET` / `POST` / `PATCH` / `DELETE` on `/v1/interests/*` on the active display (requires **`interests.write`**; **`interests.read`** for view-only, including power_viewer filter dropdowns on **Data**). Joke and trivia category ids must match an existing **Curators → Categories** slug.

## Join from a display QR (`/join`)

The display slide type **`controller_invite`** can open **`/join?api=<display REST>`** on this SPA. That page runs **viewer** adoption (challenge on the display, then confirm). For other roles, use **Manage displays**.

Cross-origin calls require the controller origin to pass the display’s **adoption CORS** rules (LAN/private) during pairing; after confirm, the origin is stored on the display. You can also set **`WADDLE_DISPLAY_HTTP_CORS_ORIGINS`** on the display for static seeds.

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
