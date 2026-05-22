import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  backupSnapshotDownloadUrl,
  deleteBackupSnapshot,
  deleteBackupTarget,
  listAllBackupSnapshots,
  listBackupSnapshots,
  listBackupTargets,
  pullBackupNow,
  restoreBackupSnapshot,
  saveBackupTarget,
  uploadBackupArchive,
} from '@/api/bffBackups';

vi.mock('@/api/bffClient', () => ({
  bffJson: vi.fn(),
  bffFetch: vi.fn(),
}));

import { bffFetch, bffJson } from '@/api/bffClient';

const target = {
  id: 't1',
  displayId: 'd1',
  label: 'Lab',
  baseUrl: 'https://127.0.0.1:8787',
  schedule: {
    frequency: 'weekly' as const,
    interval: 1,
    dayOfWeek: 1,
    hour: 2,
    minute: 0,
  },
  timezone: 'UTC',
  retentionCount: 3,
  enabled: true,
  lastRunAt: null,
  lastStatus: null,
  lastError: null,
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
};

const snapshot = {
  id: 's1',
  targetId: 't1',
  displayId: 'd1',
  displayLabel: 'Lab',
  fileName: 'backup.zip',
  byteSize: 4,
  manifest: null,
  source: 'manual',
  createdAt: '2026-01-01T00:00:00.000Z',
};

describe('bffBackups', () => {
  afterEach(() => {
    vi.mocked(bffJson).mockReset();
    vi.mocked(bffFetch).mockReset();
  });

  it('listBackupTargets calls GET /backup-targets', async () => {
    vi.mocked(bffJson).mockResolvedValue({ targets: [target] });
    const rows = await listBackupTargets();
    expect(rows).toEqual([target]);
    expect(bffJson).toHaveBeenCalledWith('/backup-targets');
  });

  it('saveBackupTarget PUTs payload', async () => {
    vi.mocked(bffJson).mockResolvedValue({ target });
    const saved = await saveBackupTarget({
      displayId: 'd1',
      label: 'Lab',
      baseUrl: 'https://127.0.0.1:8787',
      apiKey: 'key',
      schedule: target.schedule,
      retentionCount: 3,
      enabled: true,
    });
    expect(saved).toEqual(target);
    expect(bffJson).toHaveBeenCalledWith('/backup-targets', {
      method: 'PUT',
      body: expect.stringContaining('d1'),
    });
  });

  it('deleteBackupTarget DELETEs by id', async () => {
    vi.mocked(bffJson).mockResolvedValue({});
    await deleteBackupTarget('t1');
    expect(bffJson).toHaveBeenCalledWith('/backup-targets/t1', { method: 'DELETE' });
  });

  it('lists and deletes snapshots', async () => {
    vi.mocked(bffJson)
      .mockResolvedValueOnce({ snapshots: [snapshot] })
      .mockResolvedValueOnce({ snapshots: [snapshot] })
      .mockResolvedValueOnce({});
    expect(await listAllBackupSnapshots()).toEqual([snapshot]);
    expect(await listBackupSnapshots('t1')).toEqual([snapshot]);
    await deleteBackupSnapshot('s1');
    expect(bffJson).toHaveBeenCalledWith('/backup-snapshots/s1', { method: 'DELETE' });
  });

  it('pullBackupNow and restoreBackupSnapshot POST', async () => {
    vi.mocked(bffJson)
      .mockResolvedValueOnce({ snapshotId: 's1', byteSize: 4 })
      .mockResolvedValueOnce({});
    const pull = await pullBackupNow('t1');
    expect(pull).toEqual({ snapshotId: 's1', byteSize: 4 });
    await restoreBackupSnapshot('s1');
    expect(bffJson).toHaveBeenCalledWith('/backup-targets/t1/pull-now', {
      method: 'POST',
      body: '{}',
    });
    expect(bffJson).toHaveBeenCalledWith('/backup-snapshots/s1/restore', {
      method: 'POST',
      body: '{}',
    });
  });

  it('backupSnapshotDownloadUrl encodes snapshot id', () => {
    expect(backupSnapshotDownloadUrl('snap/id')).toBe(
      '/bff/v1/backup-snapshots/snap%2Fid/download',
    );
  });

  it('uploadBackupArchive posts file body', async () => {
    const file = new File([new Uint8Array([0x50, 0x4b])], 'backup.zip', {
      type: 'application/zip',
    });
    vi.mocked(bffFetch).mockResolvedValue({
      json: async () => ({ snapshot }),
    } as Response);
    const result = await uploadBackupArchive('t1', file);
    expect(result).toEqual(snapshot);
    expect(bffFetch).toHaveBeenCalledWith('/backup-targets/t1/upload', {
      method: 'POST',
      headers: { 'Content-Type': 'application/zip' },
      body: file,
    });
  });
});
