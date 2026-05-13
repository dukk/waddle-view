#!/usr/bin/env python3
"""
Extract portrait / full-body preview cards from the composite icon sheet PNG,
then emit Flutter platform launcher assets (Windows .ico, iOS/macOS PNG sets).

Near-white pixels that connect to the image edge (card background and padding)
are made transparent; opaque platform outputs are preserved under
``<app-root>/branding/generated_icons_backup_white_opaque/`` the first time each
file would be overwritten (use ``--no-backup`` to skip).

Requires Pillow: pip install pillow

Example (from repo root):

  python tool/generate_app_icons.py ^
    --sheet apps/waddle_display/branding/icon_sheet.png ^
    --app-root apps/waddle_display
"""

from __future__ import annotations

import argparse
from collections import deque
import shutil
import sys
from pathlib import Path

from PIL import Image

_BACKUP_DIR = Path("branding") / "generated_icons_backup_white_opaque"


def _maybe_backup(app: Path, dest: Path, *, enable: bool) -> None:
    """If ``dest`` exists and no backup exists yet, copy it under ``_BACKUP_DIR``."""
    if not enable or not dest.is_file():
        return
    rel = dest.relative_to(app)
    backup = app / _BACKUP_DIR / rel
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.is_file():
        shutil.copy2(dest, backup)


def _transparent_edge_connected_white(im: Image.Image, threshold: int = 245) -> Image.Image:
    """
    Set alpha to 0 for near-white pixels (RGB >= threshold) that are 4-connected
    to the image border. Interior whites (e.g. highlights) stay opaque.
    """
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    white: list[list[bool]] = [[False for _ in range(w)] for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            white[y][x] = r >= threshold and g >= threshold and b >= threshold

    seen: list[list[bool]] = [[False for _ in range(w)] for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if white[y][x] and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if white[y][x] and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))

    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or nx >= w or ny < 0 or ny >= h:
                continue
            if seen[ny][nx] or not white[ny][nx]:
                continue
            seen[ny][nx] = True
            q.append((nx, ny))

    out = rgba.copy()
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if seen[y][x]:
                r, g, b, _ = opx[x, y]
                opx[x, y] = (r, g, b, 0)
    return out


def _white_mask(im: Image.Image, threshold: int = 245) -> tuple[int, int, list[list[bool]]]:
    rgb = im.convert("RGB")
    w, h = rgb.size
    mask = [[False for _ in range(w)] for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b = rgb.getpixel((x, y))
            if r >= threshold and g >= threshold and b >= threshold:
                mask[y][x] = True
    return w, h, mask


def _connected_components(mask: list[list[bool]]) -> list[tuple[int, int, int, int, int]]:
    """
    Return (minx, miny, maxx, maxy, area) per white connected component.
    Coordinates are mask-local and max bounds are inclusive.
    """
    h = len(mask)
    w = len(mask[0]) if h else 0
    seen = [[False for _ in range(w)] for _ in range(h)]
    out: list[tuple[int, int, int, int, int]] = []

    for sy in range(h):
        for sx in range(w):
            if not mask[sy][sx] or seen[sy][sx]:
                continue
            q: deque[tuple[int, int]] = deque([(sx, sy)])
            seen[sy][sx] = True
            minx = maxx = sx
            miny = maxy = sy
            area = 0
            while q:
                x, y = q.popleft()
                area += 1
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                if y < miny:
                    miny = y
                if y > maxy:
                    maxy = y
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    if seen[ny][nx] or not mask[ny][nx]:
                        continue
                    seen[ny][nx] = True
                    q.append((nx, ny))
            out.append((minx, miny, maxx, maxy, area))
    return out


def _find_master_card_bboxes(im: Image.Image) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    """
    Detect the first-row master portrait/full-body white icon cards.
    Returns two absolute bboxes (x0, y0, x1, y1), with x1/y1 exclusive.
    """
    w, h = im.size
    # Ignore ruler strip and focus on the left panel where master cards live.
    roi = (0, max(20, h // 25), min(max(460, w // 2), w), min(max(360, h - 1), h))
    sub = im.crop(roi)
    _, _, mask = _white_mask(sub, threshold=245)
    comps = _connected_components(mask)

    candidates: list[tuple[int, int, int, int, int]] = []
    for minx, miny, maxx, maxy, area in comps:
        cw = maxx - minx + 1
        ch = maxy - miny + 1
        if area < 8000:
            continue
        if cw < 130 or ch < 130:
            continue
        ratio = cw / ch
        if ratio < 0.75 or ratio > 1.35:
            continue
        candidates.append((minx, miny, maxx, maxy, area))

    if not candidates:
        raise ValueError("Could not detect master portrait icon card from sheet")

    # Portrait card is the left-most large white square in the top row.
    candidates.sort(key=lambda c: (c[0], c[1]))
    p = candidates[0]
    rx0, ry0, _, _ = roi
    portrait_bbox = (rx0 + p[0], ry0 + p[1], rx0 + p[2] + 1, ry0 + p[3] + 1)

    # Full-body card can be non-white inside, so detect by "not background" near portrait.
    rgb = im.convert("RGB")
    bg_samples: list[tuple[int, int, int]] = []
    for yy in range(max(0, h // 50), max(0, h // 12)):
        for xx in range(max(0, w - 140), max(0, w - 20)):
            bg_samples.append(rgb.getpixel((xx, yy)))
    if not bg_samples:
        raise ValueError("Could not sample background color from sheet")
    bg_r = sorted(v[0] for v in bg_samples)[len(bg_samples) // 2]
    bg_g = sorted(v[1] for v in bg_samples)[len(bg_samples) // 2]
    bg_b = sorted(v[2] for v in bg_samples)[len(bg_samples) // 2]

    px0, py0, px1, py1 = portrait_bbox
    search = (
        min(w - 1, px1 + 8),
        max(0, py0 - 8),
        min(w, px1 + (px1 - px0) + 80),
        min(h, py1 + 30),
    )
    sx0, sy0, sx1, sy1 = search
    sub2 = rgb.crop(search)
    sw, sh = sub2.size
    diff_mask = [[False for _ in range(sw)] for _ in range(sh)]
    for y2 in range(sh):
        for x2 in range(sw):
            r, g, b = sub2.getpixel((x2, y2))
            # Sum absolute difference from sampled page background.
            if abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b) > 30:
                diff_mask[y2][x2] = True

    comps2 = _connected_components(diff_mask)
    best: tuple[int, int, int, int, int] | None = None
    for minx, miny, maxx, maxy, area in comps2:
        cw = maxx - minx + 1
        ch = maxy - miny + 1
        if area < 4000:
            continue
        if cw < 90 or ch < 90:
            continue
        if best is None or area > best[4]:
            best = (minx, miny, maxx, maxy, area)

    # Keep full-body crop in the same top-row card band as portrait so label text is excluded.
    pw = px1 - px0
    ph = py1 - py0
    if best is None:
        # Fallback to fixed offset if the non-background detect fails.
        fullbody_bbox = (px1 + 20, py0, min(w, px1 + 20 + pw), min(h, py0 + ph))
    else:
        minx, _, maxx, _, _ = best
        bx0 = sx0 + minx
        bx1 = sx0 + maxx + 1
        cx = (bx0 + bx1) // 2
        fx0 = max(0, cx - pw // 2)
        fx1 = min(w, fx0 + pw)
        # If clamped at right edge, keep width stable.
        fx0 = max(0, fx1 - pw)
        fullbody_bbox = (fx0, py0, fx1, min(h, py0 + ph))
    return portrait_bbox, fullbody_bbox


def _square_paste(src: Image.Image, side: int, fill: tuple[int, int, int, int]) -> Image.Image:
    w, h = src.size
    canvas = Image.new("RGBA", (side, side), fill)
    ox = (side - w) // 2
    oy = (side - h) // 2
    canvas.paste(src, (ox, oy))
    return canvas


def extract_square_card(im: Image.Image, bbox: tuple[int, int, int, int]) -> Image.Image:
    """Crop rounded-rect card in `bbox` (x0,y0,x1,y1) and return a square RGBA with transparent surround."""
    card = im.crop(bbox).convert("RGBA")
    cw, ch = card.size
    side = max(cw, ch)
    sq = _square_paste(card, side, (0, 0, 0, 0))
    return _transparent_edge_connected_white(sq)


def resize_png(src: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = src.resize((size, size), Image.Resampling.LANCZOS)
    if out.mode not in ("RGB", "RGBA"):
        out = out.convert("RGBA")
    out.save(path, format="PNG")


def write_windows_ico(src1024: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    base = src1024.convert("RGBA")
    # Pillow resizes from `base` for each entry in `sizes` (see ICO format docs).
    base.save(
        path,
        format="ICO",
        sizes=[(256, 256), (48, 48), (32, 32), (16, 16)],
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--sheet", type=Path, required=True, help="Composite PNG (1024-wide sheet).")
    p.add_argument(
        "--app-root",
        type=Path,
        default=Path("apps/waddle_display"),
        help="Path to the Flutter app package root.",
    )
    p.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not copy existing outputs to branding/generated_icons_backup_white_opaque/.",
    )
    args = p.parse_args()

    if not args.sheet.is_file():
        print(f"Missing sheet: {args.sheet}", file=sys.stderr)
        return 1

    app = args.app_root.resolve()
    sheet = Image.open(args.sheet).convert("RGBA")
    w, h = sheet.size
    if w < 512 or h < 400:
        print(f"Unexpected sheet size {w}x{h}; expected the 1024-wide reference.", file=sys.stderr)
        return 1

    # Detect master portrait / full-body cards from the sheet itself.
    portrait_bbox, fullbody_bbox = _find_master_card_bboxes(sheet)
    portrait_sq = extract_square_card(sheet, portrait_bbox)
    fullbody_sq = extract_square_card(sheet, fullbody_bbox)

    master_side = 512
    portrait_master = portrait_sq.resize((master_side, master_side), Image.Resampling.LANCZOS)
    fullbody_master = fullbody_sq.resize((master_side, master_side), Image.Resampling.LANCZOS)

    do_backup = not args.no_backup
    icons_dir = app / "assets" / "icons"
    icons_dir.mkdir(parents=True, exist_ok=True)
    for out in (
        icons_dir / "master_portrait.png",
        icons_dir / "master_full_body.png",
        icons_dir / "icon_256x256.png",
        icons_dir / "icon_128x128.png",
        icons_dir / "icon_64x64.png",
        icons_dir / "icon_48x48.png",
        icons_dir / "icon_32x32.png",
        icons_dir / "icon_16x16.png",
    ):
        _maybe_backup(app, out, enable=do_backup)
    portrait_master.save(icons_dir / "master_portrait.png", format="PNG")
    fullbody_master.save(icons_dir / "master_full_body.png", format="PNG")
    for name, side in [
        ("icon_256x256.png", 256),
        ("icon_128x128.png", 128),
        ("icon_64x64.png", 64),
        ("icon_48x48.png", 48),
        ("icon_32x32.png", 32),
        ("icon_16x16.png", 16),
    ]:
        resize_png(portrait_master, icons_dir / name, side)

    src1024 = portrait_master.resize((1024, 1024), Image.Resampling.LANCZOS)

    # Windows
    win_ico = app / "windows" / "runner" / "resources" / "app_icon.ico"
    _maybe_backup(app, win_ico, enable=do_backup)
    write_windows_ico(src1024, win_ico)

    # macOS (see AppIcon.appiconset/Contents.json)
    mac = app / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for side, name in [
        (16, "app_icon_16.png"),
        (32, "app_icon_32.png"),
        (64, "app_icon_64.png"),
        (128, "app_icon_128.png"),
        (256, "app_icon_256.png"),
        (512, "app_icon_512.png"),
        (1024, "app_icon_1024.png"),
    ]:
        mac_path = mac / name
        _maybe_backup(app, mac_path, enable=do_backup)
        resize_png(src1024, mac_path, side)

    # iOS (see AppIcon.appiconset/Contents.json; shared filenames between idiom entries).
    ios = app / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_side_by_file: dict[str, int] = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for fname, side in ios_side_by_file.items():
        ios_path = ios / fname
        _maybe_backup(app, ios_path, enable=do_backup)
        resize_png(src1024, ios_path, side)

    print(f"Wrote icons under {app} (assets/icons, windows/.../app_icon.ico, macOS, iOS).")
    if do_backup:
        print(f"Prior opaque outputs (if any) copied once to {app / _BACKUP_DIR}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
