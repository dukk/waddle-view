# waddle_controller

Browser **operator UI** for one or more **`waddle_display`** instances. It calls the display’s **`/v1/*`** JSON API with `X-Api-Key` (same secret as `waddle_api.key` on the display host).

## Development

From this directory:

```bash
npm ci
npm run dev
```

[Vite](https://vite.dev/) serves the SPA (default **http://127.0.0.1:5173**) and **proxies** `/v1` and `/admin` to **http://127.0.0.1:8787**, so API calls match the dev server origin and **CORS is not required** while you use the proxy.

Point the first-run dialog at your display base URL (for example `http://127.0.0.1:8787` or `http://<pi-ip>:8787`) and paste the API key.

## Production build

```bash
npm ci
npm run build
```

Static files land in **`dist/`**. Serve them from any static host. Configure each saved display with the **real** HTTPS (or HTTP) base URL of the display app.

GitHub **release** artifacts (Windows `.zip`, Linux `.tar.gz`) also include a **`waddle_controller/`** folder next to `waddle_display` and `waddlectl`, populated from this build output.

## Docker (nginx)

From **`apps/waddle_controller`** (repository root works if build context is this directory):

```bash
docker build -t waddle-controller .
docker run --rm -p 8080:80 waddle-controller
```

Open **http://localhost:8080**. Configure displays to use your real **`waddle_display`** base URL; set **`WADDLE_HTTP_CORS_ORIGINS`** on the display to include `http://localhost:8080` (or your public origin) so browser `fetch` calls succeed.

## Security: `localStorage`

Saved displays (label, base URL, **API key**) are stored under **`waddle_controller_displays_v1`** in the browser’s **localStorage**. That storage is **not encrypted**; anyone with access to the browser profile or disk can read keys. Treat this as **convenient kiosk** security—use a dedicated operator profile or machine for production keys.

You can **export / import** a JSON backup of the display list from **Settings**.

## CORS on the display

If the SPA origin differs from the API origin (typical for a static build on another host/port), the display must allow the browser origin. Set **`WADDLE_HTTP_CORS_ORIGINS`** on the display process to a comma-separated list of exact origins (example: `https://ops.example.com,http://127.0.0.1:5173`). See **[`docs/pi/api.md`](../../docs/pi/api.md)** and **`apps/waddle_display/.env.example`**.

## Quality

```bash
npm run lint
npm run build
```
