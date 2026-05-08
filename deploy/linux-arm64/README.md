# Linux ARM64 release files

Templates copied into release tarballs by CI (`release-pi.yml`) or manually after `flutter build linux --release`.

- **`install.sh`** — installs bundle under `/opt/waddle-view`, creates `/etc/waddle-view/api.key` on first install, optional systemd user unit.
- **`waddle-view.service`** — example systemd unit; adjust `User`, `DISPLAY`, and paths for your session.

Release CI uses **`ubuntu-22.04-arm`** so the binary matches **Raspberry Pi OS Bookworm** glibc. If that label is unavailable on your plan, use a self-hosted ARM64 runner on Bookworm/22.04-era glibc or build on the Pi.
