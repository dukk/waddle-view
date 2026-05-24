import { describe, expect, it } from 'vitest';
import {
  tickerDisplayDefaultDateTimeLabel,
  tickerTimeFormatPresetForControllerTimeFormat,
  tickerTimeFormatPresetLabel,
} from './tickerTimeFormat';

describe('tickerTimeFormatPresetForControllerTimeFormat', () => {
  it('maps display 12h/24h to live marquee presets with seconds', () => {
    expect(tickerTimeFormatPresetForControllerTimeFormat('12h')).toBe('12h_hms_ampm');
    expect(tickerTimeFormatPresetForControllerTimeFormat('24h')).toBe('24h_hms');
  });
});

describe('tickerDisplayDefaultDateTimeLabel', () => {
  it('formats medium date and short time from display prefs', () => {
    const label = tickerDisplayDefaultDateTimeLabel({
      timeFormat: '12h',
      dateOrder: 'mdy',
    });
    expect(label).toMatch(/May/);
    expect(label).toMatch(/PM|AM/);
  });

  it('uses 24-hour time when configured', () => {
    const label = tickerDisplayDefaultDateTimeLabel({
      timeFormat: '24h',
      dateOrder: 'dmy',
    });
    expect(label).not.toMatch(/PM|AM/);
    expect(label.length).toBeGreaterThan(5);
  });
});

describe('tickerTimeFormatPresetLabel', () => {
  it('returns human label for known presets', () => {
    expect(tickerTimeFormatPresetLabel('24h_hms')).toContain('24-hour');
    expect(tickerTimeFormatPresetLabel('12h_hm_ampm')).toContain('12-hour');
  });

  it('passes through unknown preset ids', () => {
    expect(tickerTimeFormatPresetLabel('custom_preset')).toBe('custom_preset');
  });
});
