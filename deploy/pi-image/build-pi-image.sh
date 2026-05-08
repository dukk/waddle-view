#!/usr/bin/env bash
# Customize an official Raspberry Pi OS arm64 image with the Waddle Display bundle.
# Intended to run inside the Docker image from deploy/pi-image/Dockerfile (--privileged).

set -euo pipefail

DEFAULT_RPI_OS_IMAGE_XZ_URL='https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64.img.xz'
DEFAULT_RPI_OS_IMAGE_SHA256='ea6e68c48d14c3d78af5471c0b288bbf6522fdd775241f74d8295d106d344300'

usage() {
  sed -n '1,120p' <<'EOF'
Usage: build-pi-image.sh [options]

Build a flashable Raspberry Pi OS arm64 image containing /opt/waddle-view/bundle (Flutter linux).

Environment (common):
  BUNDLE_DIR              Host-mounted Flutter bundle directory (default: /bundle)
  OUT_DIR                 Output directory for the final .img (default: /out)
  RPI_OS_IMAGE_XZ_URL     Base Raspberry Pi OS image .img.xz URL
  RPI_OS_IMAGE_SHA256     Expected sha256 of the .xz file (hex, optional if companion .sha256 downloads)
  CACHE_DIR               Download cache directory (default: /work/cache)
  WADDLE_AUTOLOGIN_USER   Desktop auto-login user (default: pi)
  OUTPUT_BASENAME         Output filename (default: waddle-display-pi-YYYYMMDD.img)

Flags:
  --help                  Show this help
  --skip-checksum         Skip SHA256 verification (not recommended)

Requires Docker --privileged for losetup/mount/chroot.
EOF
}

SKIP_CHECKSUM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --skip-checksum)
      SKIP_CHECKSUM=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

RPI_OS_IMAGE_XZ_URL="${RPI_OS_IMAGE_XZ_URL:-$DEFAULT_RPI_OS_IMAGE_XZ_URL}"
RPI_OS_IMAGE_SHA256="${RPI_OS_IMAGE_SHA256:-}"
if [[ -z "$RPI_OS_IMAGE_SHA256" && "$RPI_OS_IMAGE_XZ_URL" == "$DEFAULT_RPI_OS_IMAGE_XZ_URL" ]]; then
  RPI_OS_IMAGE_SHA256="$DEFAULT_RPI_OS_IMAGE_SHA256"
fi

BUNDLE_DIR="${BUNDLE_DIR:-/bundle}"
OUT_DIR="${OUT_DIR:-/out}"
CACHE_DIR="${CACHE_DIR:-/work/cache}"
WORK_DIR="${WORK_DIR:-/work/imgbuild}"
WADDLE_AUTOLOGIN_USER="${WADDLE_AUTOLOGIN_USER:-pi}"
OUTPUT_BASENAME="${OUTPUT_BASENAME:-waddle-display-pi-$(date -u +%Y%m%d).img}"

ROOT_MOUNT="${WORK_DIR}/rootfs"
IMG_CUSTOM="${WORK_DIR}/raspios-custom.img"
LOOPDEV=""
HOST_ARCH="$(uname -m)"

log() {
  echo "[build-pi-image] $*"
}

die() {
  echo "[build-pi-image] ERROR: $*" >&2
  exit 1
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "This script must run as root inside the container."
}

cleanup() {
  set +e
  local needs_cleanup=false
  if [[ -n "${ROOT_MOUNT:-}" ]] && mountpoint -q "${ROOT_MOUNT}"; then
    needs_cleanup=true
  fi
  if [[ -n "${LOOPDEV:-}" ]]; then
    needs_cleanup=true
  fi
  if [[ "$needs_cleanup" == true ]]; then
    log "Cleaning up mounts…"
    rm -f "${ROOT_MOUNT}/usr/bin/qemu-aarch64-static" 2>/dev/null || true
    umount -R "${ROOT_MOUNT}" 2>/dev/null || true
    losetup -d "${LOOPDEV}" 2>/dev/null || true
  fi
  rm -f "${WORK_DIR}/qemu-aarch64-static.copied" 2>/dev/null || true
}

trap cleanup EXIT

require_root

[[ -d "$BUNDLE_DIR" ]] || die "BUNDLE_DIR is not a directory: $BUNDLE_DIR"
[[ -f "$BUNDLE_DIR/waddle_display" ]] || die "Missing $BUNDLE_DIR/waddle_display (build Flutter linux arm64 bundle first)."
if file -b "$BUNDLE_DIR/waddle_display" | grep -qi aarch64; then
  :
elif file -b "$BUNDLE_DIR/waddle_display" | grep -qi arm64; then
  :
else
  die "Bundle binary does not look like aarch64/arm64: $(file -b "$BUNDLE_DIR/waddle_display")"
fi

mkdir -p "$OUT_DIR" "$CACHE_DIR" "$WORK_DIR" "$ROOT_MOUNT"

XZ_LOCAL="$CACHE_DIR/$(basename "$RPI_OS_IMAGE_XZ_URL")"
log "Ensuring base image archive at $XZ_LOCAL"
if [[ ! -f "$XZ_LOCAL" ]]; then
  mkdir -p "$CACHE_DIR"
  curl -fL --retry 4 --retry-delay 3 -o "$XZ_LOCAL.part" "$RPI_OS_IMAGE_XZ_URL"
  mv -f "$XZ_LOCAL.part" "$XZ_LOCAL"
fi

if [[ "$SKIP_CHECKSUM" -eq 1 ]]; then
  log "WARNING: skipping SHA256 verification (--skip-checksum)."
else
  EXPECTED="$RPI_OS_IMAGE_SHA256"
  if [[ -z "$EXPECTED" ]]; then
    SUM_URL="${RPI_OS_IMAGE_XZ_URL}.sha256"
    log "Fetching checksum from $SUM_URL"
    SUM_FILE="$CACHE_DIR/$(basename "$SUM_URL")"
    curl -fL --retry 4 --retry-delay 3 -o "$SUM_FILE" "$SUM_URL"
    EXPECTED="$(awk '{print $1}' "$SUM_FILE")"
  fi
  [[ -n "$EXPECTED" ]] || die "Could not determine expected SHA256; set RPI_OS_IMAGE_SHA256."
  echo "$EXPECTED  $XZ_LOCAL" | sha256sum -c -
fi

log "Decompressing base image (this uses significant disk space)…"
rm -f "$IMG_CUSTOM"
xz -dc "$XZ_LOCAL" >"$IMG_CUSTOM"

pick_loop_root_partition() {
  local loop_base="$1"
  local best="" best_bytes=0
  local part sz fst
  shopt -s nullglob
  for part in "${loop_base}"p*; do
    [[ -b "$part" ]] || continue
    fst="$(blkid -o value -s TYPE "$part" 2>/dev/null || true)"
    [[ "$fst" == "ext4" ]] || continue
    sz="$(blockdev --getsize64 "$part" 2>/dev/null || echo 0)"
    if (( sz > best_bytes )); then
      best_bytes="$sz"
      best="$part"
    fi
  done
  shopt -u nullglob
  [[ -n "$best" ]] || die "Could not find an ext4 root partition on $loop_base"
  printf '%s\n' "$best"
}

log "Attaching loop device…"
LOOPDEV="$(losetup -f --show -P "$IMG_CUSTOM")"
ROOT_PART="$(pick_loop_root_partition "$LOOPDEV")"
log "Using root partition $ROOT_PART"

mount "$ROOT_PART" "$ROOT_MOUNT"

# Bind mounts for chroot.
mount --bind /proc "$ROOT_MOUNT/proc"
mount --bind /sys "$ROOT_MOUNT/sys"
mount --bind /dev "$ROOT_MOUNT/dev"
mkdir -p "$ROOT_MOUNT/dev/pts"
mount --bind /dev/pts "$ROOT_MOUNT/dev/pts"

if [[ ! -f "$ROOT_MOUNT/etc/resolv.conf" ]] || [[ ! -s "$ROOT_MOUNT/etc/resolv.conf" ]]; then
  mkdir -p "$ROOT_MOUNT/etc"
  printf 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' >"$ROOT_MOUNT/etc/resolv.conf"
fi

copy_qemu_static_if_needed() {
  if [[ "$HOST_ARCH" != "x86_64" && "$HOST_ARCH" != "amd64" ]]; then
    log "Host arch is $HOST_ARCH — assuming native arm64 chroot (no qemu-user-static copy)."
    return 0
  fi
  local src="/usr/bin/qemu-aarch64-static"
  [[ -f "$src" ]] || die "Missing $src (install qemu-user-static in the image)."
  cp -f "$src" "$ROOT_MOUNT/usr/bin/qemu-aarch64-static"
  chmod +x "$ROOT_MOUNT/usr/bin/qemu-aarch64-static"
  touch "${WORK_DIR}/qemu-aarch64-static.copied"
}

remove_qemu_static_if_copied() {
  if [[ -f "${WORK_DIR}/qemu-aarch64-static.copied" ]]; then
    rm -f "$ROOT_MOUNT/usr/bin/qemu-aarch64-static"
    rm -f "${WORK_DIR}/qemu-aarch64-static.copied"
  fi
}

copy_qemu_static_if_needed

chroot_run() {
  chroot "$ROOT_MOUNT" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 "$@"
}

log "Installing runtime packages inside image…"
chroot_run apt-get update -qq

# Runtime libraries for Flutter Linux GTK embedder, sqlite3, secrets (DBus), media_kit (mpv).
chroot_run apt-get install -y --no-install-recommends \
  ca-certificates \
  dbus-user-session \
  dmsetup \
  fontconfig \
  gnome-keyring \
  libayatana-appindicator3-1 \
  libayatana-ido3-0.4-0 \
  libblkid1 \
  libdbusmenu-gtk3-4 \
  libfontconfig1 \
  libgdk-pixbuf-2.0-0 \
  libglib2.0-0 \
  libgtk-3-0 \
  liblzma5 \
  libmpv2 \
  libsecret-1-0 \
  libsqlite3-0 \
  libstdc++6 \
  libudev1 \
  locales \
  mpv \
  openssl \
  xdg-utils

chroot_run apt-get clean -qq

log "Installing Waddle bundle to /opt/waddle-view/bundle…"
mkdir -p "$ROOT_MOUNT/opt/waddle-view"
rsync -a --delete "$BUNDLE_DIR/" "$ROOT_MOUNT/opt/waddle-view/bundle/"
chmod +x "$ROOT_MOUNT/opt/waddle-view/bundle/waddle_display"

log "Ensuring /etc/waddle-view/api.key…"
mkdir -p "$ROOT_MOUNT/etc/waddle-view"
if [[ ! -s "$ROOT_MOUNT/etc/waddle-view/api.key" ]]; then
  openssl rand -hex 32 >"$ROOT_MOUNT/etc/waddle-view/api.key"
fi
chmod 600 "$ROOT_MOUNT/etc/waddle-view/api.key"

mkdir -p "$ROOT_MOUNT/etc/xdg/autostart"
cat >"$ROOT_MOUNT/etc/xdg/autostart/waddle-display.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Waddle Display
Comment=Waddle Display TV dashboard
Exec=env DISPLAY=:0 WADDLE_API_KEY_FILE=/etc/waddle-view/api.key /opt/waddle-view/bundle/waddle_display
Path=/opt/waddle-view/bundle
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF
chmod 644 "$ROOT_MOUNT/etc/xdg/autostart/waddle-display.desktop"

mkdir -p "$ROOT_MOUNT/etc/lightdm/lightdm.conf.d"
cat >"$ROOT_MOUNT/etc/lightdm/lightdm.conf.d/012-waddle-autologin.conf" <<EOF
[Seat:*]
autologin-user=${WADDLE_AUTOLOGIN_USER}
autologin-user-timeout=0
EOF
chmod 644 "$ROOT_MOUNT/etc/lightdm/lightdm.conf.d/012-waddle-autologin.conf"

remove_qemu_static_if_copied

log "Unmounting…"
umount -R "$ROOT_MOUNT"
LOOPDEV_DETACH="$LOOPDEV"
LOOPDEV=""
losetup -d "$LOOPDEV_DETACH"

OUT_IMG="$OUT_DIR/$OUTPUT_BASENAME"
log "Writing output image to $OUT_IMG"
cp -f --sparse=always "$IMG_CUSTOM" "$OUT_IMG"
sync

log "Done."
