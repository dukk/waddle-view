# Linux ARM64 release files

Templates copied into release tarballs by CI (`pi-release.yml`) or manually after `flutter build linux --release`.

- **`install.sh`** — installs bundle under `/opt/waddle-view`, creates `/etc/waddle-view/api.key` on first install, optional systemd user unit.
- **`waddle-view.service`** — example systemd unit; adjust `User`, `DISPLAY`, and paths for your session.

Verify the GitHub Actions runner label **`ubuntu-24.04-arm`** is available on your plan; otherwise use a self-hosted ARM64 runner or build on the Pi.
