import { describe, expect, it } from 'vitest';
import { tickerTimeFormatPresetForControllerTimeFormat } from './tickerTimeFormat';

describe('tickerTimeFormatPresetForControllerTimeFormat', () => {
  it('maps display 12h/24h to live marquee presets with seconds', () => {
    expect(tickerTimeFormatPresetForControllerTimeFormat('12h')).toBe('12h_hms_ampm');
    expect(tickerTimeFormatPresetForControllerTimeFormat('24h')).toBe('24h_hms');
  });
});
