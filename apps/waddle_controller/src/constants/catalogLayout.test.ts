import { describe, expect, it } from 'vitest';
import {
  CATALOG_CARD_MIN_WIDTH_PX,
  catalogCardColumnCount,
  catalogSupportsTransferSideRail,
  catalogTwoCardWidthPx,
} from './catalogLayout';

const GAP_PX = 16;

describe('catalogCardColumnCount', () => {
  it('returns 1 for zero or negative width', () => {
    expect(catalogCardColumnCount(0, GAP_PX)).toBe(1);
    expect(catalogCardColumnCount(-10, GAP_PX)).toBe(1);
  });

  it('fits 4 columns at 1168px with 16px gap', () => {
    // 4 * 280 + 3 * 16 = 1168
    expect(catalogCardColumnCount(1168, GAP_PX)).toBe(4);
    expect(catalogSupportsTransferSideRail(4)).toBe(false);
  });

  it('still fits 4 columns just below 5-column threshold', () => {
    expect(catalogCardColumnCount(1463, GAP_PX)).toBe(4);
  });

  it('fits 5 columns at 1464px with 16px gap', () => {
    // 5 * 280 + 4 * 16 = 1464
    expect(catalogCardColumnCount(1464, GAP_PX)).toBe(5);
    expect(catalogSupportsTransferSideRail(5)).toBe(true);
  });
});

describe('catalogTwoCardWidthPx', () => {
  it('equals two card widths plus one gap at 5 columns', () => {
    const width = 1464;
    const n = 5;
    const columnWidth = (width - (n - 1) * GAP_PX) / n;
    expect(catalogTwoCardWidthPx(width, n, GAP_PX)).toBe(2 * columnWidth + GAP_PX);
  });

  it('uses at least one column when columnCount is invalid', () => {
    expect(catalogTwoCardWidthPx(400, 0, GAP_PX)).toBe(
      catalogTwoCardWidthPx(400, 1, GAP_PX),
    );
  });
});

describe('catalogLayout constants', () => {
  it('keeps min width at 280px', () => {
    expect(CATALOG_CARD_MIN_WIDTH_PX).toBe(280);
  });
});
