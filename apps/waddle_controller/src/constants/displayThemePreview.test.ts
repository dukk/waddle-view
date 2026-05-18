import { describe, expect, it } from 'vitest';

import { curatorThemeIds } from './curatorDisplaySettings';
import {
  displayThemePreviewById,
  flattenDisplayThemePreview,
} from './displayThemePreview';

describe('displayThemePreview', () => {
  it('defines preview groups for all curator themes', () => {
    for (const theme of curatorThemeIds) {
      expect(displayThemePreviewById[theme.id]).toBeDefined();
      expect(theme.preview.accents.length).toBeGreaterThanOrEqual(3);
      expect(theme.colors.length).toBeGreaterThanOrEqual(6);
      expect(flattenDisplayThemePreview(theme.preview)).toEqual(theme.colors);
    }
  });

  it('navy_coral includes four accents in preview', () => {
    const navy = displayThemePreviewById.navy_coral;
    expect(navy?.accents).toHaveLength(4);
    expect(navy?.display.length).toBeGreaterThanOrEqual(2);
  });
});
