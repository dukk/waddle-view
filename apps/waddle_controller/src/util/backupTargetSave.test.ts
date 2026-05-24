import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { pullDisplayBackupNow, saveDisplayBackupTarget } from './backupTargetSave';

vi.mock('@/api/bffBackups', () => ({
  saveBackupTarget: vi.fn(),
  pullBackupNow: vi.fn(),
}));

import { pullBackupNow, saveBackupTarget } from '@/api/bffBackups';

const display = {
  id: 'd1',
  label: 'Lab Display',
  baseUrl: 'https://127.0.0.1:8787',
} as SavedDisplay;

const existingTarget = {
  id: 't1',
  displayId: 'd1',
  label: 'Lab Display',
  baseUrl: 'https://127.0.0.1:8787',
  schedule: {
    frequency: 'weekly' as const,
    interval: 1,
    dayOfWeek: 1,
    hour: 3,
    minute: 30,
  },
  timezone: 'UTC',
  retentionCount: 5,
  enabled: true,
  lastRunAt: null,
  lastStatus: null,
  lastError: null,
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
};

describe('saveDisplayBackupTarget', () => {
  beforeEach(() => {
    vi.mocked(saveBackupTarget).mockReset();
    vi.mocked(pullBackupNow).mockReset();
  });

  it('passes display fields and uses existing schedule/retention when omitted', async () => {
    vi.mocked(saveBackupTarget).mockResolvedValue(existingTarget);
    await saveDisplayBackupTarget(display, 'secret-key', {
      enabled: true,
      existingTarget,
    });
    expect(saveBackupTarget).toHaveBeenCalledWith({
      displayId: 'd1',
      label: 'Lab Display',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'secret-key',
      schedule: {
        frequency: 'weekly',
        interval: 1,
        dayOfWeek: 1,
        hour: 3,
        minute: 30,
      },
      retentionCount: 5,
      enabled: true,
    });
  });

  it('uses explicit schedule and retention when provided', async () => {
    vi.mocked(saveBackupTarget).mockResolvedValue(existingTarget);
    const schedule = {
      frequency: 'daily' as const,
      interval: 1,
      dayOfWeek: null,
      hour: 4,
      minute: 0,
    };
    await saveDisplayBackupTarget(display, 'key', {
      enabled: false,
      schedule,
      retentionCount: 10,
    });
    expect(saveBackupTarget).toHaveBeenCalledWith(
      expect.objectContaining({
        schedule,
        retentionCount: 10,
        enabled: false,
      }),
    );
  });
});

describe('pullDisplayBackupNow', () => {
  beforeEach(() => {
    vi.mocked(saveBackupTarget).mockReset();
    vi.mocked(pullBackupNow).mockReset();
  });

  it('calls pullBackupNow when target has id', async () => {
    vi.mocked(pullBackupNow).mockResolvedValue(undefined);
    await pullDisplayBackupNow(display, 'key', existingTarget);
    expect(pullBackupNow).toHaveBeenCalledWith('t1');
    expect(saveBackupTarget).not.toHaveBeenCalled();
  });

  it('creates target then pulls when id missing', async () => {
    vi.mocked(saveBackupTarget).mockResolvedValue({ ...existingTarget, id: 't-new' });
    vi.mocked(pullBackupNow).mockResolvedValue(undefined);
    await pullDisplayBackupNow(display, 'key', { ...existingTarget, id: '' });
    expect(saveBackupTarget).toHaveBeenCalled();
    expect(pullBackupNow).toHaveBeenCalledWith('t-new');
  });
});
