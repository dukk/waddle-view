import { describe, expect, it } from 'vitest';

import { curatorThemeIds } from '@/constants/curatorDisplaySettings';
import { mergeBuiltinAndCustomThemes, displayThemeOptionById } from '@/util/displayThemeOptions';

describe('displayThemeOptions', () => {
  it('merges builtin and custom themes', () => {
    const merged = mergeBuiltinAndCustomThemes(curatorThemeIds, [
      {
        id: 'custom_test',
        label: 'My theme',
        preview: {
          display: ['#000000', '#111111'],
          primaryContainer: ['#FFFFFF', '#222222'],
          secondaryContainer: ['#FFFFFF', '#333333'],
          accents: ['#444444', '#555555', '#666666', '#777777'],
        },
      },
    ]);
    expect(merged.length).toBe(curatorThemeIds.length + 1);
    expect(merged.some((t) => t.id === 'custom_test' && t.isCustom)).toBe(true);
    expect(displayThemeOptionById(merged, 'navy_coral')?.isCustom).toBe(false);
  });
});
