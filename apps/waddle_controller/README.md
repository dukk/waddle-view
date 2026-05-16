# waddle_controller

Browser **operator UI** for one or more **`waddle_display`** instances. It signs in with **`POST /v1/auth/login`** and sends **`Authorization: Bearer <session_token>`** on protected `/v1/*` routes.

## Development

From this directory:

```bash
npm ci
npm run dev
```

[Vite](https://vite.dev/) serves the SPA (default **http://127.0.0.1:5173**) and **proxies** `/v1` to **http://127.0.0.1:8787**, so API calls match the dev server origin and **CORS is not required** while you use the proxy.

1. Add a display base URL in the first-run dialog.
2. Sign in on the login dialog (bootstrap: user **`display`**, password = instance id from **`waddle_instance.id`** on the display host).
3. Create a named user in **Settings → Users**. While only the bootstrap **`display`** user exists, the role is fixed to **admin** (and the display API enforces the same) so the first operator account cannot lock you out of user management. After that create succeeds, the controller **signs you in as the new user** (the bootstrap session stops working once the account is disabled).

## Join from a kiosk QR (`/join`)

The display slide type **`controller_invite`** shows a QR that opens **`/join?api=<display REST>&secret=…`** on this SPA. That page adds the display (if needed), lets someone **sign in** with an existing account, or **register** a new **viewer** account when the display has **`WADDLE_VIEWER_REGISTRATION_SECRET`** set and **`WADDLE_HTTP_CORS_ORIGINS`** includes this app’s origin (or you use a dev proxy so the browser origin matches the display). Viewer accounts use the **Programs** and **Account** pages in the controller; the display API grants them **`telemetry.read`** (telemetry + media GETs) for operator data, while profile and password updates use the self-service user routes (no `users.manage`). A named **`power_viewer`** (set in **Settings → Users**) also gets **Data** as a read-only catalog (**`content.catalog_read`**: no suppressed rows, no suppression toggles, no `PATCH /v1/content/*`) and **`navigation.control`** for arrow-key remote control. Profile and password updates still use the self-service user routes (no `users.manage`).

## Production build

```bash
npm ci
npm run build
```

Static files land in **`dist/`**. Serve them from any static host. Configure each saved display with the **real** HTTPS (or HTTP) base URL of the display app.

## Docker (nginx)

From **`apps/waddle_controller`**:

```bash
docker build -t waddle-controller .
docker run --rm -p 8080:80 waddle-controller
```

Set **`WADDLE_HTTP_CORS_ORIGINS`** on the display to include your controller origin.

## Security

- Display list (base URLs) is stored in **`localStorage`**.
- Session tokens are stored in **`sessionStorage`** per display (not exported in display backup JSON).
- Use a dedicated operator browser profile on shared machines.
