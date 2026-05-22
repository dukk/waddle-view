import { describe, expect, it } from 'vitest';
import { isDailyCronDue } from './cronDue.js';

describe('isDailyCronDue', () => {
  it('matches minute and hour in UTC', () => {
    const now = new Date('2026-05-22T02:30:00.000Z');
    expect(isDailyCronDue('30 2 * * *', 'UTC', now)).toBe(true);
    expect(isDailyCronDue('0 2 * * *', 'UTC', now)).toBe(false);
  });

  it('rejects non-daily cron', () => {
    const now = new Date('2026-05-22T02:30:00.000Z');
    expect(isDailyCronDue('30 2 * * 1', 'UTC', now)).toBe(false);
  });
});
