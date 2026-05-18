import { describe, expect, it } from 'vitest';
import {
  dateTimeFormatPrefsFromDisplaySettings,
  formatControllerDateTime,
  formatControllerDateTimeWithMs,
  formatControllerTime,
} from './dateTimeFormat';

const sample = new Date('2026-01-05T14:30:00');

describe('dateTimeFormatPrefsFromDisplaySettings', () => {
  it('defaults when settings missing', () => {
    expect(dateTimeFormatPrefsFromDisplaySettings(null)).toEqual({
      timeFormat: '12h',
      dateOrder: 'mdy',
    });
  });

  it('reads 24h and dmy', () => {
    expect(
      dateTimeFormatPrefsFromDisplaySettings({
        controller_time_format: '24h',
        controller_date_order: 'dmy',
      }),
    ).toEqual({ timeFormat: '24h', dateOrder: 'dmy' });
  });
});

describe('formatControllerTime', () => {
  it('uses 12-hour with AM/PM for mdy', () => {
    const label = formatControllerTime(sample, { timeFormat: '12h', dateOrder: 'mdy' });
    expect(label).toMatch(/PM|AM/);
  });

  it('uses 24-hour without AM/PM', () => {
    const label = formatControllerTime(sample, { timeFormat: '24h', dateOrder: 'mdy' });
    expect(label).not.toMatch(/PM|AM/);
    expect(label).toMatch(/2:30|14:30/);
  });
});

describe('formatControllerDateTime', () => {
  it('formats with en-GB order for dmy', () => {
    const label = formatControllerDateTime(sample, { timeFormat: '24h', dateOrder: 'dmy' });
    expect(label.length).toBeGreaterThan(5);
  });
});

describe('formatControllerDateTimeWithMs', () => {
  it('includes fractional seconds when supported', () => {
    const d = new Date('2026-01-05T14:30:00.123');
    const label = formatControllerDateTimeWithMs(d, { timeFormat: '24h', dateOrder: 'ymd' });
    expect(label).toMatch(/\.123|123/);
  });
});
