# waddlectl

Command-line operator helper bundled with **Linux release tarballs** (`/opt/waddle-view/bundle/waddlectl/bin/waddlectl`). It talks to the local **SQLite** database used by `waddle_display` on the same machine.

## Typical uses

- **Backup / restore** — create or restore display archives (`backup create`, `backup restore`)
- **OAuth secrets** — set Google / Microsoft tokens when the graphical UI is unavailable (`secrets set`)
- **Reject terms** — manage curator word lists (`reject list`, `reject add`, …)
- **Database utilities** — seed, migrate, or inspect (see `waddlectl --help`)

Run from a shell as the same user that owns the display database (usually the Pi desktop user):

```bash
/opt/waddle-view/bundle/waddlectl/bin/waddlectl --help
```

For remote REST operations (pairing, content, integrations), use **`waddle_controller`** or curl against the display API — see [`docs/pi/api.md`](../../docs/pi/api.md).

## Development

From the repository root:

```bash
cd apps/waddlectl
flutter pub get
flutter test
```

CI runs `waddlectl` tests as part of **CI — waddle_display** ([`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)).
