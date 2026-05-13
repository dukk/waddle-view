# Linux ARM64 release files

Templates copied into release tarballs by CI (`release-pi.yml`) or manually after `flutter build linux --release`.

- **`install.sh`** — installs bundle under `/opt/waddle-view`, creates `/etc/waddle-view/api.key` on first install, optional systemd user unit.
- **`waddle-view.service`** — example systemd unit; adjust `User`, `DISPLAY`, and paths for your session.

Release CI runs on **`ubuntu-22.04-arm`** inside a **`debian:bookworm-slim`** job container so the binary matches **Raspberry Pi OS Bookworm** for both **glibc** (see **`release-pi.yml`** assert) and **runtime SONAMEs** (for example **`libmpv.so.2`** from **`libmpv2`**). Building only on Ubuntu 22.04 linked **`libmpv.so.1`**, which Bookworm does not ship. If the **`ubuntu-22.04-arm`** label is unavailable on your plan, use a self-hosted ARM64 runner on Bookworm or build on the Pi.

To pull the newest matching **`.tar.gz`** from [GitHub Releases](https://github.com/dukk/waddle-view/releases) and run `install.sh`, use **[`../install-latest-release.sh`](../install-latest-release.sh)** (documented under **`docs/pi/using-the-image.md`**).
