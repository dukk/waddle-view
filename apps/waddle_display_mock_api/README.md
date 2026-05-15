# waddle_display_mock_api

Lightweight **mock HTTP API** for the **`/v1/*`** routes that **`waddle_controller`** (and scripts) expect from **`waddle_display`**. Use it when you do not want to run the Flutter app but still need JSON responses.

## Behaviour

- **Base URL**: same path layout as the real app (`/v1/health`, `/v1/screens`, `/v1/telemetry/...`, etc.).
- **API key**: by default the server expects **`X-Api-Key: dev-mock-key`**. Override with **`MOCK_API_KEY`**. Set **`MOCK_SKIP_AUTH=1`** to skip auth (except the `unauthorized` scenario below).
- **Scenarios** (shape of responses / status codes), driven by:
  - query **`?scenario=`** (`default` | `empty` | `error` | `unauthorized`), or
  - header **`X-Mock-Scenario`** (same values).  
  Query wins if both are set.

| Scenario        | Effect |
|-----------------|--------|
| `default`       | Non-empty lists and plausible JSON for major routes. |
| `empty`         | `items: []` (or similar) for list endpoints. |
| `error`         | Some endpoints return **4xx/5xx** (for client error handling tests). |
| `unauthorized`  | Protected routes return **401** (even with a valid key). |

## Run locally (Node)

```bash
cd apps/waddle_display_mock_api
npm ci
MOCK_API_KEY=my-secret npm run dev
```

Server listens on **`PORT`** (default **3000**).

## Docker (nginx + Node)

Build and run (**public port 80** in the container; map host **8080** → **80**):

```bash
cd apps/waddle_display_mock_api
docker build -t waddle-display-mock-api .
docker run --rm -p 8080:80 -e MOCK_API_KEY=dev-mock-key waddle-display-mock-api
```

Point **`waddle_controller`** at **`http://localhost:8080`** with API key **`dev-mock-key`** (or your **`MOCK_API_KEY`**). No CORS friction when the SPA talks to the same origin you opened in the browser.

## npm scripts

| Script | Purpose |
|--------|---------|
| `npm run dev` | `tsx watch` on `src/index.ts` |
| `npm run build` | Emit `dist/` |
| `npm run start` | `node dist/index.js` |
| `npm run docker:build` / `docker:run` | Convenience wrappers |

## Quality

```bash
npm run lint
npm run build
```
