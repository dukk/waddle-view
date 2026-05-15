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
3. Create a named user in **Settings → Users** (admin role).

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
