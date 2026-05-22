import { beforeEach, describe, expect, it, vi } from 'vitest';
import { setDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import { createDisplayBackupJob, downloadDisplayBackupJob } from '@/api/displayBackups';
import { saveSession, type DisplaySession } from '@/storage/sessions';
import type { SavedDisplay } from '@/storage/displays';

const display: SavedDisplay = {
  id: 'd-backup',
  label: 'Backup test',
  baseUrl: 'https://display.test',
};

const session: DisplaySession = {
  apiKey: 'wk_admin_test',
  expiresAtMs: Date.now() + 60_000,
  identifier: 'controller-test',
  role: 'admin',
  permissions: ['display.maintenance'],
};

describe('displayBackups', () => {
  beforeEach(() => {
    localStorage.clear();
    setDisplayProxyAuthEnabled(false);
    saveSession(display.id, session);
  });

  it('createDisplayBackupJob sends Bearer when proxy auth mode is off', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ job_id: 'job-1' }), {
        status: 202,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const result = await createDisplayBackupJob(display);
    expect(result).toEqual({ job_id: 'job-1' });

    const headers = fetchMock.mock.calls[0]![1]!.headers as Headers;
    expect(headers.get('Authorization')).toBe('Bearer wk_admin_test');
    expect(fetchMock.mock.calls[0]![0]).toContain('/bff/v1/proxy/v1/display/backup/jobs');
  });

  it('downloadDisplayBackupJob sends Bearer when proxy auth mode is off', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(new Uint8Array([0x50, 0x4b]), {
        status: 200,
        headers: { 'Content-Type': 'application/zip' },
      }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const blob = await downloadDisplayBackupJob(display, 'job-1');
    expect(blob.size).toBe(2);

    const headers = fetchMock.mock.calls[0]![1]!.headers as Headers;
    expect(headers.get('Authorization')).toBe('Bearer wk_admin_test');
    expect(fetchMock.mock.calls[0]![0]).toContain(
      '/bff/v1/proxy/v1/display/backup/jobs/job-1/download',
    );
  });
});
