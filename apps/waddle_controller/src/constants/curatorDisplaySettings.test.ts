import { describe, expect, it } from 'vitest';
import { curatorTextScaleIds, curatorThemeIds } from './curatorDisplaySettings';

describe('curatorDisplaySettings constants', () => {
  it('exposes theme and text scale options', () => {
    expect(curatorThemeIds.length).toBeGreaterThan(0);
    expect(curatorTextScaleIds).toContain('normal');
    expect(curatorThemeIds[0]).toMatchObject({ id: expect.any(String), label: expect.any(String) });
  });
});
