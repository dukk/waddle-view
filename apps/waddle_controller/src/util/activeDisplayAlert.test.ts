import { describe, expect, it } from 'vitest';
import { pickActiveDisplayAlert, type DisplayAlertRow } from '@/util/activeDisplayAlert';

const row = (partial: Partial<DisplayAlertRow> & Pick<DisplayAlertRow, 'id'>): DisplayAlertRow => ({
  priority: 0,
  created_at_ms: 0,
  ...partial,
});

describe('pickActiveDisplayAlert', () => {
  it('picks highest priority non-expired non-dismissed', () => {
    const now = 1_000_000;
    const picked = pickActiveDisplayAlert(
      [
        row({ id: 1, priority: 1, created_at_ms: 1 }),
        row({ id: 2, priority: 5, created_at_ms: 2 }),
      ],
      now,
    );
    expect(picked?.id).toBe(2);
  });

  it('respects expires_at_ms', () => {
    const now = 1_000_000;
    expect(
      pickActiveDisplayAlert(
        [row({ id: 1, priority: 9, created_at_ms: 1, expires_at_ms: now - 1 })],
        now,
      ),
    ).toBeNull();
  });

  it('skips dismissed rows', () => {
    const now = 1_000_000;
    expect(
      pickActiveDisplayAlert(
        [row({ id: 1, priority: 9, created_at_ms: 1, dismissed_at_ms: now - 500 })],
        now,
      ),
    ).toBeNull();
  });
});
