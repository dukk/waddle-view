# Raspberry Pi flashable image (Docker)

Build a customized **64-bit Raspberry Pi OS** disk image that includes the **Waddle Display** Flutter Linux bundle under `/opt/waddle-view`, desktop **auto-login**, and an **XDG autostart** entry. The output `.img` can be written with **Raspberry Pi Imager**, **balenaEtcher**, or `dd`.

## Prerequisites

1. **Docker Desktop** (Windows, macOS, or Linux) with enough free disk space (**about 15–25 GB** recommended while the image is being decompressed and customized).
2. A **release ARM64 Linux bundle** from `flutter build linux --release` (layout includes `waddle_display` next to `lib/` and `data/`). Build on **ARM64 Linux** with **glibc and system libraries compatible with Raspberry Pi OS Bookworm** (for example the Pi itself, Debian Bookworm, or CI matching **[`release-pi.yml`](../../.github/workflows/release-pi.yml)**: **`ubuntu-22.04-arm`** host with **`debian:bookworm-slim`** container). **`ubuntu-24.04-arm` produces GLIBC_2.38+ binaries that will not run on Bookworm.** Stock Flutter on Windows does **not** produce an ARM64 Linux binary.
3. Run the container `**--privileged`** so the builder can use **loop devices**, `**mount`**, and `**chroot**`.

## Security

- On first boot, **`waddle_display`** creates **`waddle_instance.id`** in the app support directory. That value is the bootstrap password for reserved user **`display`** until an operator creates a named user via the controller. Treat flashed images like secrets if you rely on that bootstrap password.
- Official Raspberry Pi OS images ship with **known-default credentials** until you change them on first boot. Rotate passwords before exposing the device to a network.
- You are producing a **derivative** of Raspberry Pi OS. Follow [Raspberry Pi trademark & redistribution guidance](https://www.raspberrypi.com/trademark-rules/) if you distribute images outside your organization.

## Build the Docker image

From the repository root:

```bash
docker build -t waddle-display-pi-image deploy/pi-image
```

## Produce an `.img`

Mount your ARM64 `**bundle**` directory read-only and an empty output directory read-write.

### Linux / macOS

```bash
mkdir -p dist/pi-img-out
docker run --rm --privileged \
  -v "$(pwd)/apps/waddle_display/build/linux/arm64/release/bundle:/bundle:ro" \
  -v "$(pwd)/dist/pi-img-out:/out" \
  -e OUTPUT_BASENAME="waddle-display-pi-custom.img" \
  waddle-display-pi-image
```

### Windows (PowerShell, Docker Desktop)

Use **forward slashes** in `-v` paths. Adjust the bundle path if yours differs.

```powershell
New-Item -ItemType Directory -Force dist/pi-img-out | Out-Null
docker run --rm --privileged `
  -v "//c/dev/waddle-view/apps/waddle_display/build/linux/arm64/release/bundle:/bundle:ro" `
  -v "//c/dev/waddle-view/dist/pi-img-out:/out" `
  -e OUTPUT_BASENAME=waddle-display-pi-custom.img `
  waddle-display-pi-image
```

If `docker run` reports mount errors, share the drive/folder in Docker Desktop (**Settings → Resources → File sharing**) or switch to a path under your user profile.

## Environment variables


| Variable                | Default                          | Meaning                                                                                                           |
| ----------------------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `BUNDLE_DIR`            | `/bundle`                        | Flutter Linux bundle root inside the container (normally bind-mounted).                                           |
| `OUT_DIR`               | `/out`                           | Output directory for the final `.img`.                                                                            |
| `RPI_OS_IMAGE_XZ_URL`   | Bookworm `2024-11-19` arm64 URL  | Official Raspberry Pi OS `.img.xz` URL.                                                                           |
| `RPI_OS_IMAGE_SHA256`   | Set when URL is default          | Expected SHA-256 of the `**.xz`** file. If unset for other URLs, the script downloads the sibling `.sha256` file. |
| `CACHE_DIR`             | `/work/cache`                    | Cached download location (mount a volume here to persist downloads across runs).                                  |
| `WADDLE_AUTOLOGIN_USER` | `pi`                             | LightDM auto-login user (must exist on the base image).                                                           |
| `OUTPUT_BASENAME`       | `waddle-display-pi-YYYYMMDD.img` | Final filename under `OUT_DIR`.                                                                                   |


Pass `**--skip-checksum**` only for local experimentation (not recommended).

Example with a **pinned** OS image and checksum:

```bash
docker run --rm --privileged \
  -e RPI_OS_IMAGE_XZ_URL="https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2026-04-21/2026-04-21-raspios-trixie-arm64.img.xz" \
  -e RPI_OS_IMAGE_SHA256="<paste from .sha256 file>" \
  -v "$(pwd)/bundle:/bundle:ro" \
  -v "$(pwd)/out:/out" \
  waddle-display-pi-image
```

## Flashing

1. Write `**dist/pi-img-out/<your>.img**` with Raspberry Pi Imager or balenaEtcher (whole-card write).
2. Boot the Pi with keyboard/display at least once; verify the desktop session starts **Waddle Display**.
3. For display use, disable screen blanking (`xset`, DPMS, or Wayland equivalents) as described in `docs/pi/using-the-image.md`.

## Troubleshooting

- `**Could not find an ext4 root partition`**: The base `.img` layout may differ; try another official Raspberry Pi OS arm64 build or report an issue with the exact URL.
- `**losetup` / mount failures**: Confirm `**--privileged`** and that Docker Desktop is using Linux containers (not Windows containers).
- `**Secret storage errors` / keyring**: The image installs `**gnome-keyring`** and `**dbus-user-session**`; headless or broken D-Bus setups may still need operator tweaks—see `docs/pi/development.md`.

## Implementation notes

- The builder script is `[build-pi-image.sh](build-pi-image.sh)`. On **x86_64** hosts it copies `**qemu-user-static`** into the target root for `**apt**` under emulation and removes it before unmounting.
- Runtime packages mirror GTK, SQLite, Secret Service, and `**mpv**` expectations for the Linux desktop embedder and `**media_kit**`.

