# waddle_controller

Browser **operator UI** for one or more **`waddle_display`** instances. Pair each display with the **adoption API** (`POST /v1/adoption/request` + `POST /v1/adoption/confirm`), then send **`Authorization: Bearer <api_key>`** on protected `/v1/*` routes.

A colocated **BFF** (`server/`, Hono + SQLite) can optionally gate access to the controller SPA and manage local operator accounts. **Display adoption is unchanged** — each kiosk still uses its own API key in `sessionStorage`.

## Development

From this directory:

```bash
npm ci
npm run dev
```

`npm run dev` starts **Vite** (default **http://127.0.0.1:5173**) and the **BFF** (**http://127.0.0.1:5199**). Vite proxies `/bff` to the BFF and `/v1` to **http://127.0.0.1:8787** (display REST), so the browser stays same-origin and **CORS is not required** during local dev.

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
| `WADDLE_CONTROLLER_DATA_DIR` | `./data` | SQLite directory (`controller.db`) |
| `WADDLE_CONTROLLER_BIND` | `127.0.0.1` | BFF listen host |
| `PORT` / `WADDLE_CONTROLLER_PORT` | `5199` | BFF listen port |
| `WADDLE_CONTROLLER_SECURE_COOKIES` | `0` | Set `1` behind HTTPS |

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

BFF API base path: **`/bff/v1/*`** (status, auth, settings, users, bootstrap).

### Display pairing

1. Add a display in the first-run dialog (base URL only), or open **Manage displays**.
2. On **Displays**, enter the kiosk REST root, a **client identifier**, and **role**, then **Request adoption**. Confirm the **challenge code** shown on the kiosk alert.
3. The browser sends **`Origin`** and **`Referer`** so the display can allow this origin on protected routes after pairing.
4. Use the **display menu** (top-left) to switch kiosks; each display keeps its own API key in **`sessionStorage`**.

If a display loses its session, use **Adopt display** in the app bar (or complete adoption again on **Displays**).

## Join from a kiosk QR (`/join`)

The display slide type **`controller_invite`** can open **`/join?api=<display REST>`** on this SPA. That page runs **viewer** adoption (challenge on the kiosk, then confirm). For other roles, use **Manage displays**.

Cross-origin calls require the controller origin to pass the display’s **adoption CORS** rules (LAN/private) during pairing; after confirm, the origin is stored on the display. You can also set **`WADDLE_HTTP_CORS_ORIGINS`** on the display for static seeds.

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

From **`apps/waddle_controller`**:

```bash
docker build -t waddle-controller .
docker run --rm -p 8080:80 \
  -v waddle-controller-data:/var/lib/waddle-controller \
  -e WADDLE_CONTROLLER_AUTH_ENABLED=1 \
  -e WADDLE_CONTROLLER_SESSION_SECRET=change-me \
  waddle-controller
```

nginx serves the SPA and proxies **`/bff/`** to the embedded Node BFF. Persist **`WADDLE_CONTROLLER_DATA_DIR`** with a volume.

After adoption, the display remembers your controller origin. Optionally set **`WADDLE_HTTP_CORS_ORIGINS`** on the display for additional static origins.

## Security

- Display list (base URLs and labels) is stored in **`localStorage`**.
- Display API keys are stored in **`sessionStorage`** per display (not exported in display backup JSON).
- Controller BFF sessions use **httpOnly** cookies; only **password hashes** live in BFF SQLite.
- Use a dedicated operator browser profile on shared machines.
- Protect **admin** display API keys; admins can grant new keys without a kiosk challenge.
