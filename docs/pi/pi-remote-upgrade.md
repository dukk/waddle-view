# Upgrading Waddle View

## Remote upgrade script (from your dev machine)

The repo includes [`deploy/pi-remote-upgrade.py`](../../deploy/pi-remote-upgrade.py) (Python 3.9+, stdlib only). It resolves the **current** app version on the Pi (from `/opt/waddle-view/bundle/data/flutter_assets/version.json` when present) and the **target** version (from your `--bundle` filename, from the GitHub Release asset name, or from the latest successful `release-pi.yml` run for `--source actions` / `auto`), then **prompts** you to confirm upgrading from current to new. On the Pi it **backs up** the existing bundle to `/opt/waddle-view/bundle.backup.<timestamp>` (when `/opt/waddle-view/bundle` exists) before running `install.sh`. Use **`--yes` / `-y`** to skip the prompt for automation. **OpenSSH** (`ssh`, `scp`) must be on your `PATH` (Windows: optional OpenSSH Client feature).

**Authentication**

- **SSH**: key-based auth is recommended; the script passes **`BatchMode=yes`** by default (non-interactive). Use **`--no-batch`** if you rely on keyboard-interactive SSH login.
- **GitHub**: set **`GITHUB_TOKEN`** or **`GH_TOKEN`**. Downloading the **`linux-arm64-bundle-<build_number>`** workflow artifact (or legacy **`linux-arm64-bundle`**) **requires** a token with **`actions:read`**. Downloading a tarball attached to the **latest GitHub Release** works without a token on public repos (a token still helps with rate limits).

**Examples**

```bash
# Use a tarball you already downloaded
python3 deploy/pi-remote-upgrade.py pi@raspberrypi.local --bundle ./waddle-view-linux-arm64-v1.0.0.tar.gz

# Prefer latest Release asset, else latest successful run of release-pi.yml on main
export GITHUB_TOKEN=ghp_...
python3 deploy/pi-remote-upgrade.py --ssh pi@raspberrypi.local --source auto

# Force Actions artifact only
python3 deploy/pi-remote-upgrade.py pi@raspberrypi.local --source actions --repo dukk/waddle-view

# Preview (shows would-be versions; may call GitHub API and SSH)
python3 deploy/pi-remote-upgrade.py pi@raspberrypi.local --dry-run

# Non-interactive (no confirmation prompt)
python3 deploy/pi-remote-upgrade.py pi@raspberrypi.local --bundle ./waddle-view-linux-arm64-v1.0.0.tar.gz --yes
```

Optional flags: **`-i` / `--identity`** (private key), **`-p` / `--port`**, **`--branch`** (for Actions run filter, default `main`), **`--yes` / `-y`** (skip confirmation).

1. Stop the app (`systemctl --user stop waddle-view` or close the session).
2. Replace the **`bundle/`** tree under `/opt/waddle-view` with the new release (preserve **`/etc/waddle-view/api.key`** unless rotating).
3. Start the app again.
4. **Drift** runs migrations on startup (`schemaVersion` in `packages/waddle_shared/lib/persistence/database.dart`); back up the SQLite file before major upgrades.

## API key rotation

1. Generate a new key: `sudo sh -c 'umask 077; openssl rand -hex 32 > /etc/waddle-view/api.key.new'`.
2. Atomically replace: `sudo mv /etc/waddle-view/api.key.new /etc/waddle-view/api.key`.
3. Restart the service. Update any automation that embeds the old key.
