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

## Cross-origin browser access (CORS)

When a browser-based client (for example the **`waddle_controller`** SPA hosted on another port or host) calls this API, the browser sends an **`Origin`** header. By default the Shelf stack does **not** emit CORS headers, so those fetches fail unless the client uses a same-origin proxy.

Optional allowlist (comma-separated **exact** origins, no wildcards):

- Set environment variable **`WADDLE_HTTP_CORS_ORIGINS`** (for example `http://127.0.0.1:5173,http://localhost:5173`).
- When the request **`Origin`** matches one of the listed values, responses include **`Access-Control-Allow-Origin`**, **`Access-Control-Allow-Methods`** (`GET,POST,PATCH,PUT,DELETE,OPTIONS`), and **`Access-Control-Allow-Headers`** (`Content-Type`, `X-Api-Key`, `Authorization`). **`OPTIONS`** preflight returns **204** for allowed origins.
- **`/admin`** is not special-cased: if you need CORS for admin HTML, the same allowlist applies to those responses when reached through the root handler.

## Endpoints (MVP)

| Method | Path | Notes |
|--------|------|--------|
| GET | `/v1/health` | No API key required. |
| GET | `/v1/providers` | Lists non-secret provider settings (`id`, `type`, `enabled`, `poll_seconds`, `base_url`, decoded `config_json` / `config_json_schema` / `example_config_json` when stored). |
| GET | `/v1/screens` | Display screen definitions from SQLite (`screen_type`, `config_json`, `dwell_seconds`, scheduling hints, optional `config_json_schema` / `example_config_json`). |
| GET | `/v1/ticker/items` | Current bottom-marquee items (`ordinal`, `kind`, `body`) — in-process snapshot; read-only. |
| GET | `/v1/alerts` | All alerts (no redaction of bodies in MVP; do not store secrets in alerts). |
| POST | `/v1/alerts` | JSON body: `title`, `body`, optional `qr_payload`, `severity`, `priority`, `expires_at` (epoch ms). |
| DELETE | `/v1/alerts/{id}` | Dismisses alert (`dismissed_at` set). |
| GET | `/v1/display/overlays` | Schedules for festive full-screen overlays (`hearts_rain`, `birthday_confetti`, `bouncing_message`). Each row includes `config_json`, `config_json_schema`, and `example_config_json` (decoded as JSON when valid). |
| POST | `/v1/display/overlays` | Upsert a row: `id`, `overlay_kind` (`hearts_rain`, `birthday_confetti`, or `bouncing_message`), `label`, `messages_json` (JSON array of strings or a JSON string), optional `config_json` (JSON object; see README — `{}` for hearts; confetti or bouncing keys for those kinds), `repeat_annually`, optional `year_exact`, `start_month`/`start_day`, optional `end_month`/`end_day`, optional `nth_week_of_month`/`nth_weekday` (both required together). |
| PATCH | `/v1/display/overlays/{id}` | Partial update; merges with the existing row. **404** if missing. |
| DELETE | `/v1/display/overlays/{id}` | Deletes the schedule. **404** if missing. |
| PATCH | `/v1/content/jokes/{id}` | JSON body: `{"suppressed": true}` or `false`. Row kept; hidden from slides/ticker. Returns **404** if id missing. |
| PATCH | `/v1/content/rss-articles/{id}` | Same as jokes. |
| PATCH | `/v1/content/photos/{id}` | Same as jokes. |
| PATCH | `/v1/content/videos/{id}` | Same as jokes. |
| PATCH | `/v1/content/trivia/{id}` | Same as jokes. |

## Operator JSON API (machine clients / `waddle_controller`)

These routes use the same **`X-Api-Key` / `Authorization: Bearer`** auth as other `/v1/*` paths. Prefer JSON **`Content-Type: application/json`** on mutators.

| Method | Path | Notes |
|--------|------|--------|
| GET | `/v1/telemetry/providers` | Query: optional `limit` (default 200, max 2000), `since_ms`. Returns `{"items":[{at_ms, channel, message}, ...]}` — in-process ring buffer (provider + engine lines). |
| GET | `/v1/telemetry/programs` | Query: optional `limit` (default 50, max 500), `since_ms`. Returns `{"items":[{at_ms, reason, slides:[...]}, ...]}` — recent screen programs. |
| GET | `/v1/telemetry/ticker-programs` | Same query shape as programs; `{"items":[{at_ms, items:[...]}, ...]}` for ticker rows. |
| POST | `/v1/display/navigation` | Body: `{"surface":"screen"|"ticker","direction":"back"|"forward"}`. Enqueues UI navigation. **503** `navigation_unavailable` if the display was started without a navigation bus. |
| GET | `/v1/meta/screen-types` | `{"items":[{screen_type, config_json_schema, example_config_json}, ...]}` for schema-driven screen editors. |
| GET | `/v1/ticker/definitions` | Full `ticker_definitions` rows (including `config_json_schema` / `example_config_json` when present). |
| PATCH | `/v1/ticker/definitions/{id}` | JSON body may include `enabled`, `frequency_weight`, `sort_order`, `config_key`. |
| GET | `/v1/curator/settings` | Aggregated curator/display tuning (program duration, history depth, ticker speed, theme, text scales, RSS photo requirement, etc.). |
| PUT | `/v1/curator/settings` | Replaces the same fields; requires at least `program_duration_seconds` and `history_depth` (see implementation for optional keys). |
| PATCH | `/v1/providers/{id}` | Partial update: `enabled`, `poll_seconds`, `base_url`, `config_json` (JSON string or object). |
| POST | `/v1/screens` | Create screen: `id`, `screen_type`, `config_json` (object or string), optional `name`, `description`, `enabled`, `dwell_seconds`, `frequency_weight`, scheduling keys, `data_key`. **409** if `id` exists. |
| PATCH | `/v1/screens/{id}` | Partial update; `config_json` re-validates layout. |
| DELETE | `/v1/screens/{id}` | Deletes row; **404** if missing. |

**Expanded read shape:** `GET /v1/providers` includes `base_url`, decoded `config_json`, `config_json_schema`, and `example_config_json` when stored (omit secrets in client logs).

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

# Example: birthday confetti overlay (fixed date, repeats every year)
curl -sS -H "X-Api-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{
    "id":"birthday_alex",
    "enabled":true,
    "overlay_kind":"birthday_confetti",
    "label":"Alex birthday",
    "messages_json":["Happy birthday, Alex!"],
    "config_json":{
      "shapes":["rect","circle","mix"],
      "colors":["#E05C6C","#FFE356"],
      "density":0.36,
      "message_interval_sec":36,
      "fall_speed":0.14,
      "opacity":0.46
    },
    "repeat_annually":true,
    "start_month":6,
    "start_day":12
  }' \
  http://127.0.0.1:8787/v1/display/overlays

# First-time seed also inserts `default_birthday_example_may_13` (May 13, `birthday_confetti`, disabled).
# PATCH `{"enabled":true}` on that id to turn on the stock example.

# Global overlay kill-switch: SQLite `config_key_values` key `display.overlay.enabled`
# = `false` (no dedicated REST for arbitrary KV rows in MVP).

curl -sS -H "X-Api-Key: $KEY" -H 'Content-Type: application/json' \
  -X PATCH \
  -d '{"suppressed": true}' \
  http://127.0.0.1:8787/v1/content/videos/<video-row-id>
```

Never log or commit the API key.

### Example: remote navigation

```bash
curl -sS -H "X-Api-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"surface":"screen","direction":"forward"}' \
  http://127.0.0.1:8787/v1/display/navigation
```
