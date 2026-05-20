/** Minimum card column width; must match `catalogCardGridSx` minmax first argument. */
export const CATALOG_CARD_MIN_WIDTH_PX = 280;

/** MUI theme spacing units for grid gap; must match `catalogCardGridSx.gap`. */
export const CATALOG_CARD_GRID_GAP_SPACING = 2;

export const catalogCardGridSx = {
  display: 'grid',
  gap: CATALOG_CARD_GRID_GAP_SPACING,
  gridTemplateColumns: `repeat(auto-fill, minmax(${CATALOG_CARD_MIN_WIDTH_PX}px, 1fr))`,
} as const;

/**
 * Column count for `repeat(auto-fill, minmax(280px, 1fr))` at a given container width.
 */
export function catalogCardColumnCount(containerWidthPx: number, gapPx: number): number {
  if (containerWidthPx <= 0) {
    return 1;
  }
  return Math.max(
    1,
    Math.floor((containerWidthPx + gapPx) / (CATALOG_CARD_MIN_WIDTH_PX + gapPx)),
  );
}

/** Width of two card columns plus the gap between them (full-row basis). */
export function catalogTwoCardWidthPx(
  containerWidthPx: number,
  columnCount: number,
  gapPx: number,
): number {
  const n = Math.max(1, columnCount);
  const columnWidth = (containerWidthPx - (n - 1) * gapPx) / n;
  return 2 * columnWidth + gapPx;
}

/** True when the catalog grid can fit more than four cards per row. */
export function catalogSupportsTransferSideRail(columnCount: number): boolean {
  return columnCount > 4;
}
