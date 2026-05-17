import { describe, expect, it } from 'vitest';
import {
  DISPLAY_TIMEZONE_OPTIONS,
  displayTimezoneSelectOptions,
  filterDisplayTimezoneOptions,
  formatDisplayTimezoneLabel,
  getAllDisplayTimezoneOptions,
} from './displayTimezoneOptions';

describe('getAllDisplayTimezoneOptions', () => {
  it('includes a broad IANA set when Intl.supportedValuesOf is available', () => {
    const opts = getAllDisplayTimezoneOptions();
    if (typeof Intl.supportedValuesOf === 'function') {
      expect(opts.length).toBeGreaterThan(300);
    } else {
      expect(opts.length).toBeGreaterThanOrEqual(5);
    }
    expect(opts.some((o) => o.id === 'America/New_York')).toBe(true);
    expect(opts.some((o) => o.id === 'America/Chicago')).toBe(true);
  });

  it('DISPLAY_TIMEZONE_OPTIONS matches getAllDisplayTimezoneOptions', () => {
    expect(DISPLAY_TIMEZONE_OPTIONS).toBe(getAllDisplayTimezoneOptions());
  });
});

describe('formatDisplayTimezoneLabel', () => {
  it('includes offset for valid zones', () => {
    const label = formatDisplayTimezoneLabel('UTC');
    expect(label).toContain('UTC');
  });
});

describe('displayTimezoneSelectOptions', () => {
  it('includes known zones', () => {
    expect(
      displayTimezoneSelectOptions('America/Chicago').some((o) => o.id === 'America/Chicago'),
    ).toBe(true);
  });

  it('prepends custom id when not in IANA list', () => {
    const opts = displayTimezoneSelectOptions('America/Indiana/Indianapolis');
    expect(opts[0]?.id).toBe('America/Indiana/Indianapolis');
    expect(opts[0]?.label).toContain('custom');
  });
});

describe('filterDisplayTimezoneOptions', () => {
  const sample = [
    { id: 'America/Chicago', label: 'America/Chicago (GMT-5)' },
    { id: 'Europe/London', label: 'Europe/London (GMT)' },
  ];

  it('returns all options when query is empty', () => {
    expect(filterDisplayTimezoneOptions(sample, '')).toHaveLength(2);
    expect(filterDisplayTimezoneOptions(sample, '   ')).toHaveLength(2);
  });

  it('matches id and label case-insensitively', () => {
    expect(filterDisplayTimezoneOptions(sample, 'chicago').map((o) => o.id)).toEqual([
      'America/Chicago',
    ]);
    expect(filterDisplayTimezoneOptions(sample, 'gmt').map((o) => o.id)).toEqual([
      'America/Chicago',
      'Europe/London',
    ]);
  });
});
