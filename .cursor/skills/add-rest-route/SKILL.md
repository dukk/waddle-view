---
name: add-rest-route
description: >-
  Adds a Shelf HTTP route to the waddle-display local REST API with tests and
  docs. Use when exposing a new endpoint, handler, or pi API route.
disable-model-invocation: true
---

# Add REST route (Shelf)

Repo constraints: [AGENTS.md](../../../AGENTS.md) (default app **`apps/waddle-display/`**; tests-first; coverage; deployment API keys must not be committed—document paths only).

## Forbidden

- Do not edit other `apps/*` packages unless the task explicitly names them.

## Preconditions

- Route maps to an existing **repository** or **application service** port.
- API key middleware applies to mutating routes.

## Steps

1. Add handler under `apps/waddle-display/lib/api/` wired through `shelf_router` (see existing handlers in that directory).
2. Add integration test under `apps/waddle-display/test/api/` using `HttpClient` and a temp API key file (match existing tests).
3. Update [`docs/pi/api.md`](../../../docs/pi/api.md) with a `curl` example.

## Done criteria

- `flutter analyze` clean; tests pass; no API key material in logs or commits.

## Verification

From `apps/waddle-display`: `flutter analyze`, `flutter test test/api/`.
