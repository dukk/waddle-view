import { describe, expect, it } from 'vitest';

import {
  buildDisplayStops,
  inferDisplayBackgroundMode,
  joinContainerGroup,
  splitContainerGroup,
} from '@/util/displayThemeChromeForm';

describe('displayThemeChromeForm', () => {
  it('infers solid display from duplicate stops', () => {
    expect(inferDisplayBackgroundMode(['#0D1B2A', '#0D1B2A'])).toBe('solid');
    expect(inferDisplayBackgroundMode(['#0D1B2A', '#1B263B'])).toBe('gradient');
  });

  it('buildDisplayStops encodes solid as duplicate', () => {
    expect(buildDisplayStops('solid', '#112233', [])).toEqual(['#112233', '#112233']);
  });

  it('splitContainerGroup separates foreground from chrome', () => {
    const split = splitContainerGroup(['#FFFFFF', '#111111', '#222222']);
    expect(split.foreground).toBe('#FFFFFF');
    expect(split.chromeStops).toEqual(['#111111', '#222222']);
  });

  it('joinContainerGroup restores primaryContainer shape', () => {
    expect(joinContainerGroup('#FFFFFF', ['#111111'])).toEqual(['#FFFFFF', '#111111']);
  });
});
