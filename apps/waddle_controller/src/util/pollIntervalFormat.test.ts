import { describe, expect, it } from 'vitest';
import { formatPollInterval } from './pollIntervalFormat';

describe('formatPollInterval', () => {
  it('formats zero as 0 seconds', () => {
    expect(formatPollInterval(0)).toBe('0 seconds');
  });

  it('formats seconds only', () => {
    expect(formatPollInterval(45)).toBe('45 seconds');
  });

  it('formats minutes and seconds', () => {
    expect(formatPollInterval(125)).toBe('2 minutes 5 seconds');
  });

  it('formats hours, minutes, and seconds', () => {
    expect(formatPollInterval(3661)).toBe('1 hour 1 minute 1 second');
  });

  it('formats days and hours', () => {
    expect(formatPollInterval(90_000)).toBe('1 day 1 hour');
  });

  it('formats months, days, and seconds', () => {
    const twoMonthsOneDay = 2 * 30 * 86_400 + 86_400 + 30;
    expect(formatPollInterval(twoMonthsOneDay)).toBe('2 months 1 day 30 seconds');
  });

  it('rounds fractional seconds', () => {
    expect(formatPollInterval(59.6)).toBe('1 minute');
    expect(formatPollInterval(59.4)).toBe('59 seconds');
  });
});
