import { describe, expect, it } from 'vitest';
import { curatorThemeById, curatorThemeIds } from './curatorDisplaySettings';

describe('curatorThemeIds', () => {
  it('each theme has preview hex colors', () => {
    expect(curatorThemeIds.length).toBeGreaterThanOrEqual(12);
    for (const theme of curatorThemeIds) {
      expect(theme.colors.length).toBeGreaterThanOrEqual(5);
      for (const hex of theme.colors) {
        expect(hex).toMatch(/^#[0-9A-Fa-f]{6}$/);
      }
    }
  });

  it('curatorThemeById resolves known ids', () => {
    expect(curatorThemeById('navy_coral')?.label).toContain('Navy');
    expect(curatorThemeById('unknown_theme')).toBeUndefined();
  });
});
