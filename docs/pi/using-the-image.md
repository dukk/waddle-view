# Using the Waddle View Linux bundle

## Tier 1: tarball from CI

1. Download the **`waddle-view-linux-arm64-<tag>.tar.gz`** artifact from GitHub Releases (or CI artifacts).
2. Verify the published **SHA256** checksum when provided.
3. On the Raspberry Pi (64-bit Raspberry Pi OS), extract and run install:

```bash
tar xzf waddle-view-linux-arm64-v1.0.0.tar.gz
cd waddle-view-linux-arm64-v1.0.0
sudo bash install.sh
```

4. The installer creates **`/etc/waddle-view/api.key`** on first install (random hex, mode `0600`). Do not commit this file.
5. Configure **autostart** (`~/.config/autostart/*.desktop`) or install the sample **`waddle-view.service`** (edit `User`, `DISPLAY`, and paths).
6. **Disable screen blanking** for kiosk use (`xset s off`, `xset -dpms`, or Wayland equivalents).

## Tier 2: flashable SD card image (Docker builder)

For a single **`.img`** you can write with **Raspberry Pi Imager** or **balenaEtcher**, use the privileged Docker workflow under **[`deploy/pi-image/README.md`](../../deploy/pi-image/README.md)**. You still need a **pre-built ARM64 Linux bundle** (Tier 1 produces the same `bundle/` tree); the Docker builder downloads official **Raspberry Pi OS arm64**, installs the bundle into **`/opt/waddle-view`**, creates **`/etc/waddle-view/api.key`**, enables **LightDM auto-login** for the configured user (default **`pi`**), and adds an **`/etc/xdg/autostart`** entry for **`waddle_display`**.

**Redistribution**: That image is **third-party customized Raspberry Pi OS**. Follow Raspberry Pi **trademark** and licensing expectations if you ship images outside your own devices; for internal or factory-style provisioning, keep checksums and OS URLs pinned as documented.

## Data locations

- **SQLite** and **`media/`** live under the Flutter app support directory for the user running the app (see `path_provider` / `XDG` paths on Linux).

## Troubleshooting

- **Black window**: confirm a graphical session is active and `DISPLAY` is set for systemd.
- **Secret storage errors**: ensure a Secret Service provider is available, or follow fallback guidance in `development.md`.
