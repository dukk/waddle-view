# Waddle View local REST API

## Binding

- Default in development: **`127.0.0.1:8787`** (loopback only).
- Optional bind override: set **`WADDLE_HTTP_BIND`** (for example `0.0.0.0`) and optional **`WADDLE_HTTP_PORT`**.
- For LAN access, bind an explicit address and **firewall** the port; prefer a reverse proxy with TLS for untrusted networks.

## Authentication

Send the deployment key in either header:

- `X-Api-Key: <key>`
- `Authorization: Bearer <key>`

The app currently reads the key from its runtime key file:

- local/dev default: app support `waddle_api.key` (created on first launch)
- packaged install reference copy: `/etc/waddle-view/api.key`

There is no app env var for the admin/install password source in the current Flutter app runtime.

If the key file is **missing or empty**, protected routes return **503** (`api_key_unconfigured`). Invalid keys return **401**.

## Endpoints (MVP)

| Method | Path | Notes |
|--------|------|--------|
| GET | `/v1/health` | No API key required. |
| GET | `/v1/providers` | Lists non-secret provider settings. |
| GET | `/v1/screens` | Display screen definitions from SQLite (`screen_type`, `config_json`, `dwell_seconds`, scheduling hints, optional `config_json_schema` / `example_config_json`). |
| GET | `/v1/ticker/items` | Current bottom-marquee items (`ordinal`, `kind`, `body`) — in-process snapshot; read-only. |
| GET | `/v1/alerts` | All alerts (no redaction of bodies in MVP; do not store secrets in alerts). |
| POST | `/v1/alerts` | JSON body: `title`, `body`, optional `qr_payload`, `severity`, `priority`, `expires_at` (epoch ms). |
| DELETE | `/v1/alerts/{id}` | Dismisses alert (`dismissed_at` set). |
| GET | `/v1/display/overlays` | Schedules for festive full-screen overlays (`hearts_rain`, …). |
| POST | `/v1/display/overlays` | Upsert a row: `id`, `overlay_kind` (`hearts_rain`), `label`, `messages_json` (JSON array of strings or a JSON string), `repeat_annually`, optional `year_exact`, `start_month`/`start_day`, optional `end_month`/`end_day`, optional `nth_week_of_month`/`nth_weekday` (both required together). |
| PATCH | `/v1/display/overlays/{id}` | Partial update; merges with the existing row. **404** if missing. |
| DELETE | `/v1/display/overlays/{id}` | Deletes the schedule. **404** if missing. |
| PATCH | `/v1/content/jokes/{id}` | JSON body: `{"suppressed": true}` or `false`. Row kept; hidden from slides/ticker. Returns **404** if id missing. |
| PATCH | `/v1/content/rss-articles/{id}` | Same as jokes. |
| PATCH | `/v1/content/photos/{id}` | Same as jokes. |
| PATCH | `/v1/content/videos/{id}` | Same as jokes. |
| PATCH | `/v1/content/trivia/{id}` | Same as jokes. |

## Admin web UI

- Browser UI is served from **`/admin`** on the same server/port.
- Login password is the install-time random key from `waddle_api.key` until it is rotated.
- On first login, users are forced to change password.
- Rotating the admin password rewrites `waddle_api.key`, so API clients must update their key.
- After first-time password rotation, setup status is marked complete and the `admin_setup` TV screen is disabled.

## Examples

```bash
KEY=$(sudo tr -d '\n' < /etc/waddle-view/api.key)
curl -sS -H "X-Api-Key: $KEY" http://127.0.0.1:8787/v1/health
curl -sS -H "X-Api-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"title":"Door","body":"Open","qr_payload":"https://example.com/ack"}' \
  http://127.0.0.1:8787/v1/alerts

# Example: add a single-day birthday overlay (fixed date, repeats every year)
curl -sS -H "X-Api-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{
    "id":"birthday_alex",
    "enabled":true,
    "overlay_kind":"hearts_rain",
    "label":"Alex birthday",
    "messages_json":["Happy birthday, Alex!"],
    "repeat_annually":true,
    "start_month":6,
    "start_day":12
  }' \
  http://127.0.0.1:8787/v1/display/overlays

# Global overlay kill-switch: SQLite `config_key_values` key `display.overlay.enabled`
# = `false` (no dedicated REST for arbitrary KV rows in MVP).

curl -sS -H "X-Api-Key: $KEY" -H 'Content-Type: application/json' \
  -X PATCH \
  -d '{"suppressed": true}' \
  http://127.0.0.1:8787/v1/content/videos/<video-row-id>
```

Never log or commit the API key.
