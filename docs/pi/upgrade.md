# Upgrading Waddle View

1. Stop the app (`systemctl --user stop waddle-view` or close the session).
2. Replace the **`bundle/`** tree under `/opt/waddle-view` with the new release (preserve **`/etc/waddle-view/api.key`** unless rotating).
3. Start the app again.
4. **Drift** runs migrations on startup (`schemaVersion` in `lib/persistence/database.dart`); back up the SQLite file before major upgrades.

## API key rotation

1. Generate a new key: `sudo sh -c 'umask 077; openssl rand -hex 32 > /etc/waddle-view/api.key.new'`.
2. Atomically replace: `sudo mv /etc/waddle-view/api.key.new /etc/waddle-view/api.key`.
3. Restart the service. Update any automation that embeds the old key.
