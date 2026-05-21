import { describe, expect, it } from 'vitest';
import {
  overlayIdFromLabel,
  screenIdFromLabel,
  tickerTapeIdFromLabel,
} from './catalogIdFromLabel';

describe('catalogIdFromLabel', () => {
  it('screenIdFromLabel slugifies and dedupes', () => {
    expect(screenIdFromLabel("Mother's Day", [])).toBe('mother_s_day');
    expect(screenIdFromLabel("Mother's Day", ['mother_s_day'])).toBe('mother_s_day_2');
  });

  it('tickerTapeIdFromLabel prefixes non-alpha starts', () => {
    expect(tickerTapeIdFromLabel('123 party', [])).toBe('t_123_party');
  });

  it('overlayIdFromLabel prefixes non-alpha starts', () => {
    expect(overlayIdFromLabel('123 party', [])).toBe('o_123_party');
  });
});
