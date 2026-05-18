#!/usr/bin/env python3
"""
Generate Waddle launcher icons and web favicons from mascot SVG/PNG sources.

Portrait (headshot) drives launcher sizes and web favicons; full-body uses a
separate source (typically the full mascot SVG). Raster outputs remove only
edge-connected near-white padding (the blue/teal headshot disc is kept).
Shared files are always copied with ``shutil.copy2`` (never symlinks).

Requires Pillow: pip install pillow

Rasterize SVG via the first available CLI: resvg, rsvg-convert, magick, inkscape.
If SVG rasterization fails, a same-stem ``.png`` next to the SVG is used when
present.

Examples (from repo root):

  python tool/generate_app_icons.py \\
    --app-root apps/waddle_display \\
    --web-root apps/waddle_controller

  python tool/generate_app_icons.py \\
    --sheet apps/waddle_display/branding/icon_sheet.png \\
    --app-root apps/waddle_display

Legacy sheet mode extracts portrait/full-body cards from the composite PNG.
"""

from __future__ import annotations

import argparse
from collections import deque
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

_REPO_ROOT = Path(__file__).resolve().parent.parent
_DEFAULT_PORTRAIT = _REPO_ROOT / "assets" / "waddle-view-mascot-headshot-2.svg"
_DEFAULT_FULL_BODY = _REPO_ROOT / "assets" / "waddle-view-mascot.svg"
_BACKUP_DIR = Path("branding") / "generated_icons_backup_white_opaque"
_RASTER_SIZE = 1024
_MASTER_SIDE = 512
# Below teal disc channels (~116, 177, 182) but clears near-white export padding.
_WHITE_BG_THRESHOLD = 240


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


def _white_mask(im: Image.Image, threshold: int = _WHITE_BG_THRESHOLD) -> tuple[int, int, list[list[bool]]]:
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
    w, h = im.size
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

    candidates.sort(key=lambda c: (c[0], c[1]))
    p = candidates[0]
    rx0, ry0, _, _ = roi
    portrait_bbox = (rx0 + p[0], ry0 + p[1], rx0 + p[2] + 1, ry0 + p[3] + 1)

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

    pw = px1 - px0
    ph = py1 - py0
    if best is None:
        fullbody_bbox = (px1 + 20, py0, min(w, px1 + 20 + pw), min(h, py0 + ph))
    else:
        minx, _, maxx, _, _ = best
        bx0 = sx0 + minx
        bx1 = sx0 + maxx + 1
        cx = (bx0 + bx1) // 2
        fx0 = max(0, cx - pw // 2)
        fx1 = min(w, fx0 + pw)
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
    card = im.crop(bbox).convert("RGBA")
    cw, ch = card.size
    side = max(cw, ch)
    sq = _square_paste(card, side, (0, 0, 0, 0))
    return _transparent_edge_connected_white(sq)


def _square_master(im: Image.Image, side: int = _MASTER_SIDE) -> Image.Image:
    rgba = im.convert("RGBA")
    w, h = rgba.size
    if w == h:
        sq = rgba
    else:
        sq = _square_paste(rgba, max(w, h), (0, 0, 0, 0))
    if sq.size != (side, side):
        sq = sq.resize((side, side), Image.Resampling.LANCZOS)
    return sq


def _png_fallback_for(path: Path) -> Path | None:
    if path.suffix.lower() != ".svg":
        return None
    candidate = path.with_suffix(".png")
    return candidate if candidate.is_file() else None


def _rasterize_svg_cli(svg: Path, out_png: Path, size: int) -> bool:
    attempts: list[list[str]] = [
        ["resvg", str(svg), "-w", str(size), "-h", str(size), "-o", str(out_png)],
        [
            "rsvg-convert",
            "-w",
            str(size),
            "-h",
            str(size),
            "-o",
            str(out_png),
            str(svg),
        ],
        [
            "magick",
            "-background",
            "none",
            "-density",
            "288",
            str(svg),
            "-resize",
            f"{size}x{size}",
            str(out_png),
        ],
        [
            "inkscape",
            str(svg),
            "--export-type=png",
            f"--export-filename={out_png}",
            f"--export-width={size}",
            f"--export-height={size}",
            "--export-background-opacity=0",
        ],
    ]
    for cmd in attempts:
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
        except FileNotFoundError:
            continue
        if proc.returncode == 0 and out_png.is_file():
            return True
    return False


def load_raster_source(path: Path, *, size: int = _RASTER_SIZE) -> Image.Image:
    """Load PNG or rasterize SVG to a square RGBA image."""
    path = path.resolve()
    if not path.is_file():
        raise FileNotFoundError(f"Missing source: {path}")

    suffix = path.suffix.lower()
    if suffix == ".png":
        im = Image.open(path).convert("RGBA")
    elif suffix == ".svg":
        with tempfile.TemporaryDirectory() as tmp:
            out_png = Path(tmp) / "raster.png"
            if not _rasterize_svg_cli(path, out_png, size):
                fallback = _png_fallback_for(path)
                if fallback is None:
                    raise RuntimeError(
                        f"Could not rasterize {path}. Install resvg, rsvg-convert, "
                        "ImageMagick (magick), or Inkscape, or provide a same-stem .png file."
                    )
                print(
                    f"Note: using PNG fallback {fallback} (no SVG rasterizer found).",
                    file=sys.stderr,
                )
                im = Image.open(fallback).convert("RGBA")
            else:
                im = Image.open(out_png).convert("RGBA")
    else:
        raise ValueError(f"Unsupported source type: {path}")

    squared = _square_master(im.resize((size, size), Image.Resampling.LANCZOS), side=size)
    return _transparent_edge_connected_white(squared, threshold=_WHITE_BG_THRESHOLD)


def resize_png(src: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = src.resize((size, size), Image.Resampling.LANCZOS)
    if out.mode not in ("RGB", "RGBA"):
        out = out.convert("RGBA")
    out.save(path, format="PNG")


def write_windows_ico(src1024: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    base = src1024.convert("RGBA")
    base.save(
        path,
        format="ICO",
        sizes=[(256, 256), (48, 48), (32, 32), (16, 16)],
    )


def write_display_icons(
    portrait_master: Image.Image,
    fullbody_master: Image.Image,
    app: Path,
    *,
    do_backup: bool,
) -> Image.Image:
    """Write Flutter assets and platform icons; return 1024 portrait for web."""
    icons_dir = app / "assets" / "icons"
    icons_dir.mkdir(parents=True, exist_ok=True)
    outputs = [
        icons_dir / "master_portrait.png",
        icons_dir / "master_full_body.png",
        icons_dir / "icon_256x256.png",
        icons_dir / "icon_128x128.png",
        icons_dir / "icon_64x64.png",
        icons_dir / "icon_48x48.png",
        icons_dir / "icon_32x32.png",
        icons_dir / "icon_16x16.png",
    ]
    for out in outputs:
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

    src1024 = portrait_master.resize((_RASTER_SIZE, _RASTER_SIZE), Image.Resampling.LANCZOS)

    win_ico = app / "windows" / "runner" / "resources" / "app_icon.ico"
    _maybe_backup(app, win_ico, enable=do_backup)
    write_windows_ico(src1024, win_ico)

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

    return src1024


def _resolve_svg_source(source: Path, fallback: Path) -> Path | None:
    src = source.resolve()
    if src.suffix.lower() == ".svg" and src.is_file():
        return src
    sibling = src.with_suffix(".svg")
    if sibling.is_file():
        return sibling
    fb = fallback.resolve()
    if fb.is_file() and fb.suffix.lower() == ".svg":
        return fb
    return None


def write_web_brand_assets(
    portrait_source: Path,
    fullbody_source: Path,
    web_root: Path,
) -> None:
    """Copy mascot SVGs into <web-root>/public/brand/ for in-app branding."""
    brand_dir = web_root / "public" / "brand"
    brand_dir.mkdir(parents=True, exist_ok=True)

    headshot_svg = _resolve_svg_source(portrait_source, _DEFAULT_PORTRAIT)
    if headshot_svg is not None:
        shutil.copy2(headshot_svg, brand_dir / "headshot.svg")
    else:
        print("Note: no SVG for public/brand/headshot.svg.", file=sys.stderr)

    mascot_svg = _resolve_svg_source(fullbody_source, _DEFAULT_FULL_BODY)
    if mascot_svg is not None:
        shutil.copy2(mascot_svg, brand_dir / "mascot.svg")
    else:
        print("Note: no SVG for public/brand/mascot.svg.", file=sys.stderr)


def write_web_favicons(
    portrait1024: Image.Image,
    portrait_source: Path,
    web_root: Path,
    *,
    fullbody_source: Path | None = None,
) -> None:
    public = web_root / "public"
    public.mkdir(parents=True, exist_ok=True)

    resize_png(portrait1024, public / "favicon-32x32.png", 32)
    resize_png(portrait1024, public / "apple-touch-icon.png", 180)
    write_windows_ico(portrait1024, public / "favicon.ico")

    svg_src = _resolve_svg_source(portrait_source, _DEFAULT_PORTRAIT)
    if svg_src is not None:
        shutil.copy2(svg_src, public / "favicon.svg")
    else:
        print("Note: no SVG available for favicon.svg; raster favicons only.", file=sys.stderr)

    write_web_brand_assets(
        portrait_source,
        fullbody_source or _DEFAULT_FULL_BODY,
        web_root,
    )


def refresh_assets_png(
    portrait_source: Path,
    fullbody_source: Path,
    portrait1024: Image.Image,
    fullbody_master: Image.Image,
) -> None:
    """Update committed PNG fallbacks under assets/ from generated masters."""
    portrait_png = portrait_source.with_suffix(".png")
    fullbody_png = fullbody_source.with_suffix(".png")
    portrait1024.save(portrait_png, format="PNG")
    fullbody1024 = fullbody_master.resize((_RASTER_SIZE, _RASTER_SIZE), Image.Resampling.LANCZOS)
    fullbody1024.save(fullbody_png, format="PNG")


def _run_sheet_mode(args: argparse.Namespace) -> int:
    if not args.sheet.is_file():
        print(f"Missing sheet: {args.sheet}", file=sys.stderr)
        return 1

    app = args.app_root.resolve()
    sheet = Image.open(args.sheet).convert("RGBA")
    w, h = sheet.size
    if w < 512 or h < 400:
        print(f"Unexpected sheet size {w}x{h}; expected the 1024-wide reference.", file=sys.stderr)
        return 1

    portrait_bbox, fullbody_bbox = _find_master_card_bboxes(sheet)
    portrait_sq = extract_square_card(sheet, portrait_bbox)
    fullbody_sq = extract_square_card(sheet, fullbody_bbox)
    portrait_master = portrait_sq.resize((_MASTER_SIDE, _MASTER_SIDE), Image.Resampling.LANCZOS)
    fullbody_master = fullbody_sq.resize((_MASTER_SIDE, _MASTER_SIDE), Image.Resampling.LANCZOS)

    do_backup = not args.no_backup
    portrait1024 = write_display_icons(portrait_master, fullbody_master, app, do_backup=do_backup)

    if args.web_root is not None:
        write_web_favicons(
            portrait1024,
            args.portrait if args.portrait is not None else _DEFAULT_PORTRAIT,
            args.web_root.resolve(),
            fullbody_source=args.full_body or _DEFAULT_FULL_BODY,
        )

    print(f"Wrote icons under {app} (assets/icons, windows/.../app_icon.ico, macOS, iOS).")
    if do_backup:
        print(f"Prior opaque outputs (if any) copied once to {app / _BACKUP_DIR}.")
    return 0


def _run_source_mode(args: argparse.Namespace) -> int:
    portrait_path = (args.portrait or _DEFAULT_PORTRAIT).resolve()
    fullbody_path = (args.full_body or _DEFAULT_FULL_BODY).resolve()

    portrait_raster = load_raster_source(portrait_path)
    fullbody_raster = load_raster_source(fullbody_path)
    portrait_master = _square_master(portrait_raster, side=_MASTER_SIDE)
    fullbody_master = _square_master(fullbody_raster, side=_MASTER_SIDE)

    app = args.app_root.resolve()
    do_backup = not args.no_backup
    portrait1024 = write_display_icons(portrait_master, fullbody_master, app, do_backup=do_backup)

    if args.web_root is not None:
        write_web_favicons(
            portrait1024,
            portrait_path,
            args.web_root.resolve(),
            fullbody_source=fullbody_path,
        )

    if args.refresh_assets_png:
        refresh_assets_png(portrait_path, fullbody_path, portrait1024, fullbody_master)

    lines = [f"Wrote icons under {app} (assets/icons, windows/.../app_icon.ico, macOS, iOS)."]
    if args.web_root is not None:
        web_public = args.web_root.resolve() / "public"
        lines.append(f"Wrote web favicons and brand SVGs under {web_public}.")
    if args.refresh_assets_png:
        lines.append(f"Refreshed PNG fallbacks for {portrait_path.with_suffix('.png')} and "
                      f"{fullbody_path.with_suffix('.png')}.")
    print("\n".join(lines))
    if do_backup:
        print(f"Prior opaque outputs (if any) copied once to {app / _BACKUP_DIR}.")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--sheet",
        type=Path,
        help="Legacy composite PNG (1024-wide sheet); mutually exclusive with default source mode.",
    )
    p.add_argument(
        "--portrait",
        type=Path,
        help=f"Headshot SVG/PNG (default: {_DEFAULT_PORTRAIT}).",
    )
    p.add_argument(
        "--full-body",
        type=Path,
        help=f"Full mascot SVG/PNG (default: {_DEFAULT_FULL_BODY}).",
    )
    p.add_argument(
        "--app-root",
        type=Path,
        default=Path("apps/waddle_display"),
        help="Path to the Flutter app package root.",
    )
    p.add_argument(
        "--web-root",
        type=Path,
        help="Emit favicons into <web-root>/public/ (e.g. apps/waddle_controller).",
    )
    p.add_argument(
        "--refresh-assets-png",
        action="store_true",
        help="Write 1024 PNG fallbacks next to portrait/full-body sources under assets/.",
    )
    p.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not copy existing outputs to branding/generated_icons_backup_white_opaque/.",
    )
    args = p.parse_args()

    if args.sheet is not None:
        return _run_sheet_mode(args)
    if not args.refresh_assets_png:
        args.refresh_assets_png = True
    return _run_source_mode(args)


if __name__ == "__main__":
    raise SystemExit(main())
