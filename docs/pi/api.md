# Waddle View local REST API

## Binding

- Default in development: **`https://127.0.0.1:8787`** (loopback only, **TLS on** with a self-signed cert under app-support `tls/`).
- Optional bind override: set **`WADDLE_HTTP_BIND`** (for example `0.0.0.0`) and optional **`WADDLE_HTTP_PORT`**.
- **`WADDLE_HTTP_TLS`**: `1` by default; set `0` for plain HTTP. Override cert paths with **`WADDLE_HTTP_TLS_DIR`**, **`WADDLE_HTTP_TLS_CERT`**, **`WADDLE_HTTP_TLS_KEY`**.
- For LAN access, bind an explicit address and **firewall** the port. The embedded server can serve HTTPS directly; for untrusted networks you may still prefer a reverse proxy with a publicly trusted certificate.

## Authentication

**Public routes:** `GET /v1/health`, `POST /v1/adoption/request`, `POST /v1/adoption/confirm`.

All other `/v1/*` routes require an **adopted API key**:

- `Authorization: Bearer <api_key>`

### Adoption (device-style pairing)

1. **`POST /v1/adoption/request`** (public) — body: `identifier` (required string, caller label), optional `role` (`admin`, `operator`, `power_viewer`, `viewer`; default **`operator`**). Creates a kiosk **security** alert (shield icon) naming the requested role and an **8-character challenge** formatted **`XXXX-XXXX`** (valid **5 minutes**). The challenge is **shown only on the display** — the HTTP response is `{ "expires_at_ms", "identifier", "role" }` (no `challenge_code`). With **`Authorization: Bearer <admin api_key>`** and the same body, an **admin** client is granted instantly (no challenge): response is `{ "api_key", "identifier", "role", "permissions" }`. Non-admin keys → **403**.
2. Operator reads the challenge on the display (alert overlay) and enters it on the controller in the same **`XXXX-XXXX`** form (hyphens optional on confirm).
3. **`POST /v1/adoption/confirm`** (public) — body: `identifier`, `challenge_code` (8 Crockford characters; hyphens stripped). On success returns `{ "api_key", "identifier", "role", "permissions" }`. The API key is derived from the display **instance id**, challenge, and identifier; only a **SHA-256 hash** is stored in SQLite (`api_clients`).
4. Use the API key on protected routes. Re-adopting the same **identifier** **rotates** the key.

**503** `adoption_unavailable` when `waddle_instance.id` is missing. **401** `invalid_challenge` on bad/expired confirm.

**Roles:** same four roles as before; each maps to a fixed permission set on protected routes. **`viewer`** has **`telemetry.read`** only. **`power_viewer`** adds **`navigation.control`** and **`content.catalog_read`**. **`content.moderate`** is required for **`PATCH /v1/content/*`**, suppression filters, and **`suppressed`** in catalog JSON.

**Instance id file** (HMAC secret for adoption; not sent as the API key):

- local/dev: app support `waddle_instance.id` (created on first launch; legacy `waddle_api.key` is renamed on upgrade)
- packaged install reference: `/etc/waddle-view/instance.id`

Invalid or missing API key → **401** `unauthorized`. Authenticated but lacking permission → **403** `forbidden`.

### Adoption endpoints

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| POST | `/v1/adoption/request` | public (or admin bearer) | Start challenge, or instant grant when admin key present |
| POST | `/v1/adoption/confirm` | public | Exchange code for `api_key` |

Send the controller’s browser origin on adoption calls so the display can allow later API traffic: standard **`Origin`**, or **`Referer`** when the browser omits `Origin`. On successful **confirm** (or admin instant **request**), the normalized origin is stored in SQLite **`cors_allowed_origins`** (`source: adoption`).

## Cross-origin browser access (CORS)

Browser clients (for example **`waddle_controller`**) send an **`Origin`** header (or parsed **`Referer`** as fallback). CORS is **always** evaluated (not gated on env configuration).

**Adoption routes** (`/v1/adoption/*`): permissive LAN policy — allow origins whose host is loopback, RFC1918/link-local, ends with **`.local`**, or whose DNS lookup (cached ~5 minutes) resolves **only** to private addresses. Public IPs and lookup failures are denied.

**All other `/v1/*` routes**: allow origins in **`cors_allowed_origins`** (adoption + env seed) **or** the static env list below.

Optional env seed (comma-separated **exact** origins, no wildcards):

- **`WADDLE_HTTP_CORS_ORIGINS`** (for example `http://127.0.0.1:5173,http://localhost:5173`) — inserted at startup with `source: env` (idempotent).

Allowed responses include **`Access-Control-Allow-Origin`** (mirrored origin), **`Access-Control-Allow-Methods`** (`GET,POST,PATCH,PUT,DELETE,OPTIONS`), and **`Access-Control-Allow-Headers`** (`Content-Type`, `Authorization`). **`OPTIONS`** preflight returns **204** when allowed.

## Endpoints (MVP)

| Method | Path | Notes |
|--------|------|--------|
| GET | `/v1/health` | No auth required. |
| GET | `/v1/integrations` | Lists non-secret integration settings (`id`, `integration_type`, `enabled`, `poll_seconds`, `base_url`, decoded `config_json` / `config_json_schema` / `example_config_json` when stored). |
| GET | `/v1/screens` | Display screen definitions from SQLite table **`screens`** (`screen_type`, `config_json`, `dwell_seconds`, scheduling hints, optional `config_json_schema` / `example_config_json`). |
| GET | `/v1/ticker/items` | Current bottom-marquee items (`ordinal`, `kind`, `body`) — in-process snapshot; read-only. |
| GET | `/v1/alerts` | All operator alerts from SQLite **`alerts`** (no redaction of bodies in MVP; do not store secrets in alerts). |
| POST | `/v1/alerts` | JSON body: `title`, `body`, optional `qr_payload`, `severity`, `priority`, `expires_at` (epoch ms). |
| DELETE | `/v1/alerts/{id}` | Dismisses alert (`dismissed_at` set). |
| GET | `/v1/display/overlays` | Schedules for festive full-screen overlays. SQLite table `overlays`: `overlay_type` (semantic id, like `screen_type`), `config_json` (includes `messages` string array), plus `config_json_schema` / `example_config_json` when stored (decoded as JSON when valid). Built-in renderers: `hearts_rain`, `birthday_confetti`, `bouncing_message`; other types are stored for forward use. |
| POST | `/v1/display/overlays` | Upsert a row: `id`, `overlay_type`, `label`, `config_json` (object; phrases live under `messages`), `repeat_annually`, optional `year_exact`, `start_month`/`start_day`, optional `end_month`/`end_day`, optional `nth_week_of_month`/`nth_weekday` (both required together). Legacy clients may still send `overlay_kind` and `messages_json`; the server maps them into `overlay_type` / merges `messages_json` into `config_json.messages`. |
| PATCH | `/v1/display/overlays/{id}` | Partial update; merges with the existing row. **404** if missing. |
| DELETE | `/v1/display/overlays/{id}` | Deletes the schedule. **404** if missing. |
| PATCH | `/v1/content/jokes/{id}` | JSON body: `{"suppressed": true}` or `false`. Row kept; hidden from slides/ticker. Returns **404** if id missing. |
| PATCH | `/v1/content/rss-articles/{id}` | Same as jokes. |
| PATCH | `/v1/content/photos/{id}` | Same as jokes. |
| PATCH | `/v1/content/videos/{id}` | Same as jokes. |
| PATCH | `/v1/content/trivia/{id}` | Same as jokes. |

## Ingested content catalog (paginated browse)

**Access:** `GET /v1/catalog/*` requires **`content.catalog_read`** or **`content.moderate`**. **`content.moderate`** alone unlocks optional **`suppressed`** filters, the **`suppressed`** field in JSON, and **`PATCH /v1/content/*`**. Callers with only **`content.catalog_read`** (for example **`power_viewer`**) always receive active (non-suppressed) rows only, omit **`suppressed`** from item objects, and get **403** if they pass **`suppressed=true`**. Query parameters are shared where applicable: `limit` (default **25**, max **100**), `offset` (default **0**), optional **`suppressed`** (`true` / `false`) on jokes, trivia, RSS articles, photos, and videos when permitted.

**Text filters:** each list supports optional substring query parameters on its text columns (`%` / `_` wildcards are stripped from the needle). Multiple parameters **AND** together. Every catalog item includes **`integration_type`**: the collector id / provider string (for example `joke_openai`, `news_rss`, `media_pexels`, `stock_finnhub`, `weather_openweathermap`, `weather_nws_alerts`). Trivia rows use the stored `integration_id` when present (`trivia_openai`, `trivia_opentdb`). Operator **`alerts`** use `integration_type` equal to the row `source` string.

| Method | Path | Optional text filters (substring) |
|--------|------|-----------------------------------|
| GET | `/v1/catalog/jokes` | `setup`, `punchline`. Also optional `category` = `category_id`. |
| GET | `/v1/catalog/trivia` | `question`, `option_a`, `option_b`, `option_c`, `option_d`, `integration_type`. Also optional `category`. |
| GET | `/v1/catalog/rss-articles` | `title`, `summary`, `link`, `guid`. Optional `feed_id`. |
| GET | `/v1/catalog/rss-feeds` | Small list of RSS sources (`id`, `url`, `title`, `category`) for filter UI. |
| GET | `/v1/catalog/photos` | `alt_text`, `photographer_name`, `data_provider`. Optional `category`. |
| GET | `/v1/catalog/videos` | `alt_text`, `photographer_name`, `data_provider`. Optional `category`. |
| GET | `/v1/catalog/stock-quotes` | `symbol`, `display_name` (ticker symbol row; both AND when both set). |
| GET | `/v1/catalog/weather-current` | `description` (current conditions text), `location_name` (matches configured location names). Optional `location_id`. |
| GET | `/v1/catalog/weather-alerts` | `event`, `headline`, `severity`, `excerpt` (description excerpt), `location_name`. Optional `location_id`. |
| GET | `/v1/catalog/alerts` | `title`, `body`, `source`, `severity`. |
| GET | `/v1/catalog/weather-locations` | All configured weather locations (for filter dropdowns). |

Response shape (except `rss-feeds` and `weather-locations`): `{"items":[...], "total": <int>, "limit": <int>, "offset": <int>}`.

## Operator JSON API (machine clients / `waddle_controller`)

These routes use the same **Bearer session** auth as other protected `/v1/*` paths. Prefer JSON **`Content-Type: application/json`** on mutators.

| Method | Path | Notes |
|--------|------|--------|
| GET | `/v1/telemetry/integrations` | Query: optional `limit` (default 200, max 2000), `since_ms`. Returns `{"items":[{at_ms, channel, message}, ...]}` — in-process ring buffer (`integration` + `engine` lines). |
| GET | `/v1/telemetry/programs` | Query: optional `limit` (default 50, max 500), `since_ms`. Returns `{"items":[{at_ms, reason, slides:[...]}, ...]}` — recent screen programs. |
| GET | `/v1/telemetry/ticker-programs` | Same query shape as programs; `{"items":[{at_ms, items:[...]}, ...]}` for ticker rows. |
| GET | `/v1/media/blob-by-key` | Query: **`key`** = `blob_metadata.blob_key` (URL-encoded). Returns raw bytes with `Content-Type` from metadata (or `application/octet-stream`). **404** when metadata or backing file is missing. Requires `telemetry.read`. Used by `waddle_controller` Programs view to show cached RSS/photo/video bytes. |
| GET | `/v1/media/rss-articles/{id}` | JSON: `id`, `feed_id`, `title`, `summary`, `link`, `image_blob_key`, `published_at_ms`. **404** if missing or suppressed. |
| GET | `/v1/media/weather-at-location/{location_id}` | JSON: `location_id`, `location_name`, `latitude`, `longitude`, `enabled`, optional `observed_at_ms`, `current_temp_c`, `current_description`, `current_icon_blob_key` from `weather_locations` / `weather_current`. **404** if the location row does not exist. Requires `telemetry.read` (Programs slide previews). |
| GET | `/v1/media/photos/{id}` | JSON metadata for `photos` row (`media_blob_key`, `alt_text`, photographer + Pexels URLs). **404** if missing or suppressed. |
| GET | `/v1/media/videos/{id}` | Same shape as photos plus `duration_seconds`. **404** if missing or suppressed. |
| GET | `/v1/media/jokes/{id}` | JSON: `setup`, `punchline`, `category_id`. **404** if missing or suppressed. |
| GET | `/v1/media/trivia/{id}` | JSON: `question`, `option_a`…`option_d`, `correct_option`, `category_id`. **404** if missing or suppressed. |
| POST | `/v1/display/navigation` | Body: `{"surface":"screen"|"ticker","direction":"back"|"forward"}`. Enqueues UI navigation. **503** `navigation_unavailable` if the display was started without a navigation bus. |
| GET | `/v1/meta/screen-types` | `{"items":[{screen_type, config_json_schema, example_config_json}, ...]}` for schema-driven screen editors. |
| GET | `/v1/meta/ticker-types` | `{"items":[{ticker_type, config_json_schema, example_config_json}, ...]}` for ticker tape editors. |
| GET | `/v1/ticker/tapes` | Full `ticker_tapes` rows: `config_json` plus `config_json_schema` / `example_config_json` when present. |
| POST | `/v1/ticker/tapes` | Create tape: `id`, `ticker_type`, optional `name`, `description`, `enabled`, `frequency_weight`, `sort_order`, `config_key`, `config_json`. **400** on unknown type; **409** if `id` exists. |
| PATCH | `/v1/ticker/tapes/{id}` | JSON body may include `enabled`, `frequency_weight`, `sort_order`, `config_key`, `config_json`, `name`, `description`, `ticker_type`. |
| DELETE | `/v1/ticker/tapes/{id}` | Deletes row; **404** if missing. |
| GET | `/v1/curator/settings` | Aggregated curator/display tuning (program duration, history depth, ticker speed, theme, text scales, RSS photo requirement, resolved `display_timezone`, etc.). |
| PUT | `/v1/curator/settings` | Partial update: include only keys to change among `program_duration_seconds`, `history_depth`, `ticker_pixels_per_second`, `require_news_photo_for_screens`, `display_theme_id`, `display_text_scale_screen`, `display_text_scale_ticker`, `display_timezone` (IANA id for SQLite `display.timezone`; empty string removes the row so the display falls back to its default). **400** `no_curator_settings_fields` if the body is empty or has no recognized keys. |
| GET | `/v1/config/key-values` | `{"items":[{key,value},...]}` — all rows in SQLite `config_key_values`, sorted by `key`. |
| PUT | `/v1/config/key-values` | Upsert one row: JSON `{"key":"...","value":"..."}`. **400** `key_required` / `key_too_long` / `value_too_long` when out of range. |
| DELETE | `/v1/config/key-values` | Query **`key`** (required): deletes that row. **404** `not_found` when absent. |
| GET | `/v1/curator/categories` | `{"items":[{id,label,material_icon_name,icon_blob_key,reserved},...]}` — shared category slugs (SQLite `curator_categories`, renamed from `content_categories`). |
| POST | `/v1/curator/categories` | Create: `id` (lowercase slug), `label`, optional `material_icon_name`, optional `icon_blob_key`. **400** invalid id/label; **409** id exists. |
| PATCH | `/v1/curator/categories/{id}` | Update `label`, `material_icon_name`, `icon_blob_key` (null clears optional icon fields). |
| DELETE | `/v1/curator/categories/{id}` | **403** `reserved_category` for seeded defaults; **409** `category_in_use_calendar` when calendar events reference the id. |
| PATCH | `/v1/integrations/{id}` | Partial update: `enabled`, `poll_seconds`, `base_url`, `config_json` (JSON string or object). |
| POST | `/v1/screens` | Create screen: `id`, `screen_type`, `config_json` (object or string), optional `name`, `description`, `enabled`, `dwell_seconds`, `frequency_weight`, scheduling keys, `data_key`. **409** if `id` exists. |
| PATCH | `/v1/screens/{id}` | Partial update; `config_json` re-validates layout. |
| DELETE | `/v1/screens/{id}` | Deletes row; **404** if missing. |

**Expanded read shape:** `GET /v1/integrations` includes `base_url`, decoded `config_json`, `config_json_schema`, and `example_config_json` when stored (omit secrets in client logs).

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
    "overlay_type":"birthday_confetti",
    "label":"Alex birthday",
    "config_json":{
      "messages":["Happy birthday, Alex!"],
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
# = `false`, or use `GET`/`PUT`/`DELETE /v1/config/key-values` for arbitrary keys (same permission as curator read/write).

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
