# Waddle View local REST API

## Binding

- Default in development: **`127.0.0.1:8787`** (loopback only).
- Optional bind override: set **`WADDLE_HTTP_BIND`** (for example `0.0.0.0`) and optional **`WADDLE_HTTP_PORT`**.
- For LAN access, bind an explicit address and **firewall** the port; prefer a reverse proxy with TLS for untrusted networks.

## Authentication

Protected routes require a **user session** from `POST /v1/auth/login`:

```json
{"username":"display","password":"<instance-id>"}
```

Response includes `session_token`. Send it on later requests:

- `Authorization: Bearer <session_token>`

**Bootstrap user:** reserved username `display` with password equal to the display **instance id** (see below). Enabled only until the first **named** user is created via `POST /v1/users` (admin role). After that, bootstrap login returns **403** `bootstrap_admin_disabled`.

**Roles:** `admin`, `operator`, `viewer` — each maps to a fixed permission set. `GET /v1/auth/me` returns `permissions` for the signed-in user.

**Instance id file** (not a shared API secret):

- local/dev: app support `waddle_instance.id` (created on first launch; legacy `waddle_api.key` is renamed on upgrade)
- packaged install reference: `/etc/waddle-view/instance.id`

Invalid or missing session → **401** `unauthorized`. Authenticated but lacking permission → **403** `forbidden`.

### Auth endpoints

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| POST | `/v1/auth/login` | public | Returns `session_token`, `user`, `permissions`, `warnings` |
| POST | `/v1/auth/logout` | session | Invalidates token |
| GET | `/v1/auth/me` | session | Current user + permissions |
| GET | `/v1/users` | `users.manage` | List users |
| POST | `/v1/users` | `users.manage` | Create named user (disables bootstrap) |
| PATCH | `/v1/users/{id}` | `users.manage` | Update role / disable |
| POST | `/v1/users/{id}/password` | self or `users.manage` | Change password |
| DELETE | `/v1/users/{id}` | `users.manage` | Soft-disable user |

## Cross-origin browser access (CORS)

When a browser-based client (for example the **`waddle_controller`** SPA hosted on another port or host) calls this API, the browser sends an **`Origin`** header. By default the Shelf stack does **not** emit CORS headers, so those fetches fail unless the client uses a same-origin proxy.

Optional allowlist (comma-separated **exact** origins, no wildcards):

- Set environment variable **`WADDLE_HTTP_CORS_ORIGINS`** (for example `http://127.0.0.1:5173,http://localhost:5173`).
- When the request **`Origin`** matches one of the listed values, responses include **`Access-Control-Allow-Origin`**, **`Access-Control-Allow-Methods`** (`GET,POST,PATCH,PUT,DELETE,OPTIONS`), and **`Access-Control-Allow-Headers`** (`Content-Type`, `Authorization`). **`OPTIONS`** preflight returns **204** for allowed origins.

## Endpoints (MVP)

| Method | Path | Notes |
|--------|------|--------|
| GET | `/v1/health` | No auth required. |
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

These routes use the same **Bearer session** auth as other protected `/v1/*` paths. Prefer JSON **`Content-Type: application/json`** on mutators.

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

## Examples

```bash
INSTANCE_ID=$(sudo tr -d '\n' < /etc/waddle-view/instance.id)
TOKEN=$(curl -sS -H 'Content-Type: application/json' \
  -d "{\"username\":\"display\",\"password\":\"$INSTANCE_ID\"}" \
  http://127.0.0.1:8787/v1/auth/login | jq -r .session_token)
curl -sS -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8787/v1/health
curl -sS -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Door","body":"Open","qr_payload":"https://example.com/ack"}' \
  http://127.0.0.1:8787/v1/alerts

# Example: birthday confetti overlay (fixed date, repeats every year)
curl -sS -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
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

curl -sS -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -X PATCH \
  -d '{"suppressed": true}' \
  http://127.0.0.1:8787/v1/content/videos/<video-row-id>
```

Never log or commit the API key.

### Example: remote navigation

```bash
curl -sS -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"surface":"screen","direction":"forward"}' \
  http://127.0.0.1:8787/v1/display/navigation
```
