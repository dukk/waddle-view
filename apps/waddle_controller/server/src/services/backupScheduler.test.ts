import { describe, expect, it, vi, afterEach, beforeEach } from 'vitest';
import { createTestApp } from '../testHelpers.js';
import { upsertBackupTarget, findBackupTarget } from './backupTargets.js';
import {
  resetSchedulerStateForTests,
  startBackupScheduler,
  stopBackupScheduler,
} from './backupScheduler.js';
import * as displayBackupPull from './displayBackupPull.js';

describe('backupScheduler', () => {
  let cleanup: (() => void) | undefined;
  const priorTz = process.env.TZ;

  afterEach(() => {
    stopBackupScheduler();
    resetSchedulerStateForTests();
    vi.restoreAllMocks();
    if (priorTz === undefined) {
      delete process.env.TZ;
    } else {
      process.env.TZ = priorTz;
    }
    cleanup?.();
    cleanup = undefined;
  });

  beforeEach(() => {
    process.env.TZ = 'UTC';
  });

  it('runs scheduled pull when target is due', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const now = new Date('2026-05-22T03:15:00.000Z');
    upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_sched',
      label: 'Sched',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'sched-key',
      schedule: {
        frequency: 'daily',
        interval: 1,
        dayOfWeek: null,
        hour: 3,
        minute: 15,
      },
      retentionCount: 3,
      enabled: true,
    });

    const pullMock = vi.spyOn(displayBackupPull, 'pullBackupFromDisplay').mockResolvedValue({
      snapshotId: 'snap-1',
      byteSize: 4,
    });

    vi.useFakeTimers({ now });
    startBackupScheduler(t.config, t.db);
    await vi.advanceTimersByTimeAsync(60_000);
    vi.useRealTimers();
    stopBackupScheduler();

    expect(pullMock).toHaveBeenCalledWith(
      t.config,
      t.db,
      expect.objectContaining({ display_id: 'd_sched' }),
      'scheduled',
    );
  });

  it('records error when scheduled pull fails', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;

    const now = new Date('2026-05-22T04:00:00.000Z');
    const created = upsertBackupTarget(t.config, t.db, {
      userId: null,
      displayId: 'd_sched_err',
      label: 'Sched err',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'sched-key',
      schedule: {
        frequency: 'daily',
        interval: 1,
        dayOfWeek: null,
        hour: 4,
        minute: 0,
      },
      retentionCount: 3,
      enabled: true,
    });

    vi.spyOn(displayBackupPull, 'pullBackupFromDisplay').mockRejectedValue(
      new Error('display offline'),
    );

    vi.useFakeTimers({ now });
    startBackupScheduler(t.config, t.db);
    await vi.advanceTimersByTimeAsync(60_000);
    vi.useRealTimers();
    stopBackupScheduler();

    const row = findBackupTarget(t.db, created.id, null)!;
    expect(row.last_status).toBe('error');
    expect(row.last_error).toBe('display offline');
  });
});
