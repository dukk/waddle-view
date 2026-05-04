# Add REST route (Shelf)

## Preconditions

- Route maps to an existing **repository** or **application service** port.
- API key middleware applies to mutating routes.

## Steps

1. Add handler in `lib/api/` wired through `shelf_router`.
2. Add integration test in `test/api/` using `HttpClient` + temp API key file.
3. Update `docs/pi/api.md` with `curl` example.

## Done criteria

- `flutter analyze` clean; tests pass; no API key in logs.
