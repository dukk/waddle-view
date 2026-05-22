import { describe, expect, it } from 'vitest';
import {
  backupScheduleSearchMatches,
  buildBackupScheduleRows,
} from './backupScheduleRows';
import type { BackupTarget } from '@/api/bffBackups';
import type { SavedDisplay } from '@/storage/displays';

const display: SavedDisplay = {
  id: 'd1',
  label: 'Kitchen',
  baseUrl: 'https://127.0.0.1:8787',
};

const target: BackupTarget = {
  id: 't1',
  displayId: 'd1',
  label: 'Kitchen',
  baseUrl: 'https://127.0.0.1:8787',
  schedule: {
    frequency: 'weekly',
    interval: 1,
    dayOfWeek: 0,
    hour: 2,
    minute: 5,
  },
  timezone: 'UTC',
  retentionCount: 3,
  enabled: true,
  lastRunAt: '2026-05-01T12:00:00.000Z',
  lastStatus: 'ok',
  lastError: null,
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
};

describe('backupScheduleRows', () => {
  it('buildBackupScheduleRows maps targets and summaries', () => {
    const rows = buildBackupScheduleRows(
      [display],
      new Map([[display.id, target]]),
      {},
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]!.scheduleSummary).toContain('Sunday');
    expect(rows[0]!.enabled).toBe(true);
    expect(rows[0]!.lastRunLabel).toContain('ok');
  });

  it('backupScheduleSearchMatches finds label and status', () => {
    const row = buildBackupScheduleRows(
      [display],
      new Map([[display.id, target]]),
      {},
    )[0]!;
    expect(backupScheduleSearchMatches(row, 'kitchen')).toBe(true);
    expect(backupScheduleSearchMatches(row, 'nope')).toBe(false);
  });
});
