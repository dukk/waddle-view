# Using the Waddle View Linux bundle

## Tier 0: one-line install (Linux x86_64 or arm64)

From a machine that matches a published release asset (**`waddle-view-linux-x64-<tag>.tar.gz`** or **`waddle-view-linux-arm64-<tag>.tar.gz`** from [GitHub Releases](https://github.com/dukk/waddle-view/releases)), you can download and run the installer maintained in this repo:

```bash
curl -fsSL https://raw.githubusercontent.com/dukk/waddle-view/main/deploy/install-latest-release.sh | bash
```

Non-interactive upgrades (skip the confirmation prompt when replacing an existing `/opt/waddle-view/bundle`):

```bash
curl -fsSL https://raw.githubusercontent.com/dukk/waddle-view/main/deploy/install-latest-release.sh | bash -s -- --yes
# or: WADDLE_INSTALL_YES=1 curl -fsSL ... | bash
```

The script resolves the newest **non-draft** release that ships the tarball for your CPU, prompts before moving an existing bundle aside, then runs the bundled `install.sh` (same layout as Tier 1). Pin the script to a tag or commit SHA in the URL if you do not want `main` to move. To **apt-install** common runtime libraries on Debian/Raspberry Pi OS when the bundle’s **`ldd`** check fails, set **`WADDLE_INSTALL_RUNTIME_PACKAGES=1`** (forwarded through **`sudo`** to **`install.sh`**), for example: **`WADDLE_INSTALL_RUNTIME_PACKAGES=1 curl -fsSL … | bash`**.

## Tier 1: tarball from CI

1. Download the **`waddle-view-linux-arm64-<tag>.tar.gz`** artifact from GitHub Releases (or CI artifacts).
2. Verify the published **SHA256** checksum when provided.
3. On the Raspberry Pi (64-bit Raspberry Pi OS), extract and run install:

```bash
tar xzf waddle-view-linux-arm64-v1.0.0.tar.gz
cd waddle-view-linux-arm64-v1.0.0
sudo bash install.sh
```

4. On first launch, **`waddle_display`** creates **`waddle_instance.id`** in the app support directory (bootstrap password for user **`display`** until a named operator is created). Use **`POST /v1/auth/login`** and **`Authorization: Bearer <session_token>`** from the controller or other REST clients. Do not commit instance id files or session tokens.
5. **System libraries (mpv, GTK, Secret Service, AT-SPI):** the bundle does not ship Debian `.deb` dependencies. If **`./waddle_display`** fails with **`libmpv.so.2`** (or other `not found` from **`ldd`**), run **`sudo apt update && sudo apt install -y --no-install-recommends at-spi2-core libmpv2 mpv libgtk-3-0 libsecret-1-0`**, or re-run **`install.sh`** with **`WADDLE_INSTALL_RUNTIME_PACKAGES=1`** so it installs the list in **`runtime-apt-packages.txt`** (same directory as **`install.sh`**). One-liner install: **`WADDLE_INSTALL_RUNTIME_PACKAGES=1 curl -fsSL … | bash`** (see Tier 0).
6. Configure **autostart** (`~/.config/autostart/*.desktop`) or install the sample **`waddle-view.service`** (edit `User`, `DISPLAY`, and paths).
7. **Disable screen blanking** for display use (`xset s off`, `xset -dpms`, or Wayland equivalents).

## Tier 2: flashable SD card image (Docker builder)

For a single **`.img`** you can write with **Raspberry Pi Imager** or **balenaEtcher**, use the privileged Docker workflow under **[`deploy/pi-image/README.md`](../../deploy/pi-image/README.md)**. You still need a **pre-built ARM64 Linux bundle** (Tier 1 produces the same `bundle/` tree); the Docker builder downloads official **Raspberry Pi OS arm64**, installs the bundle into **`/opt/waddle-view`**, enables **LightDM auto-login** for the configured user (default **`pi`**), and adds an **`/etc/xdg/autostart`** entry for **`waddle_display`**.

**Redistribution**: That image is **third-party customized Raspberry Pi OS**. Follow Raspberry Pi **trademark** and licensing expectations if you ship images outside your own devices; for internal or factory-style provisioning, keep checksums and OS URLs pinned as documented.

## Data locations

- **SQLite** and **`media/`** live under the Flutter app support directory for the user running the app (see `path_provider` / `XDG` paths on Linux).

## Troubleshooting

- **`libmpv.so.2: cannot open shared object file`**: the app needs the **system** **`libmpv2`** package (the tarball does not include it). Install with **`sudo apt update && sudo apt install -y --no-install-recommends libmpv2 mpv`**, or use **`WADDLE_INSTALL_RUNTIME_PACKAGES=1`** with **`install.sh`** / the Tier 0 curl installer so **`runtime-apt-packages.txt`** is applied. Run **`ldd /opt/waddle-view/bundle/waddle_display`** to see any other missing `*.so`.
- **`Atk-CRITICAL` / `atk_socket_embed` / `org.a11y.Bus`**: install **`at-spi2-core`** (included in **`runtime-apt-packages.txt`**). Minimal images often omit it even though GTK expects the accessibility D-Bus service.
- **`Gdk-Message: Unable to load  from the cursor theme`**: usually a **harmless GTK quirk** (empty cursor name) with Flutter on Linux; the app can still run. If it bothers you, try another cursor theme (**`gsettings set org.gnome.desktop.interface cursor-theme Adwaita`**) or ignore when **`media_kit_libs_linux registered.`** appears right after.
- **`libmpv.so.1: cannot open shared object file`**: older ARM64 GitHub bundles were linked against **`libmpv.so.1`** (Ubuntu 22.04 build roots), while Raspberry Pi OS Bookworm only ships **`libmpv.so.2`** via **`libmpv2`**. Ensure **`sudo apt install libmpv2 mpv`** is installed; if the error persists, upgrade to a **newer release tarball** built with the Bookworm-aligned **`release-pi.yml`** job container (`debian:bookworm-slim`).
- **Black window**: confirm a graphical session is active and `DISPLAY` is set for systemd.
- **Secret storage errors**: ensure a Secret Service provider is available, or follow fallback guidance in `development.md`.
