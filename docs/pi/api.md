# Waddle View local REST API

## Binding

- Default in development: **`127.0.0.1:8787`** (loopback only).
- For LAN access, bind an explicit address and **firewall** the port; prefer a reverse proxy with TLS for untrusted networks.

## Authentication

Send the deployment key in either header:

- `X-Api-Key: <key>`
- `Authorization: Bearer <key>`

The key is stored in **`WADDLE_API_KEY_FILE`** (default in dev: app support `waddle_api.key`; install template uses **`/etc/waddle-view/api.key`**).

If the key file is **missing or empty**, protected routes return **503** (`api_key_unconfigured`). Invalid keys return **401**.

## Endpoints (MVP)

| Method | Path | Notes |
|--------|------|--------|
| GET | `/v1/health` | No API key required. |
| GET | `/v1/providers` | Lists non-secret provider settings. |
| GET | `/v1/screens` | Display screen definitions from SQLite (`layout_json`, `dwell_ms`, scheduling hints). |
| GET | `/v1/ticker/items` | Current bottom-marquee items (`ordinal`, `kind`, `body`) — in-process snapshot; read-only. |
| GET | `/v1/alerts` | All alerts (no redaction of bodies in MVP; do not store secrets in alerts). |
| POST | `/v1/alerts` | JSON body: `title`, `body`, optional `qr_payload`, `severity`, `priority`, `expires_at` (epoch ms). |
| DELETE | `/v1/alerts/{id}` | Dismisses alert (`dismissed_at` set). |

## Examples

```bash
KEY=$(sudo tr -d '\n' < /etc/waddle-view/api.key)
curl -sS -H "X-Api-Key: $KEY" http://127.0.0.1:8787/v1/health
curl -sS -H "X-Api-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"title":"Door","body":"Open","qr_payload":"https://example.com/ack"}' \
  http://127.0.0.1:8787/v1/alerts
```

Never log or commit the API key.
