import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import {
  downloadDisplayBackupToBrowser,
  restoreDisplayBackupFromFile,
} from '@/util/displayBackupActions';

vi.mock('@/api/displayBackups', () => ({
  createDisplayBackupJob: vi.fn(),
  fetchDisplayBackupJob: vi.fn(),
  downloadDisplayBackupJob: vi.fn(),
  restoreDisplayBackupFile: vi.fn(),
}));

import {
  createDisplayBackupJob,
  downloadDisplayBackupJob,
  fetchDisplayBackupJob,
} from '@/api/displayBackups';

const display: SavedDisplay = {
  id: 'd_dl',
  label: 'Download test',
  baseUrl: 'https://display.test',
};

describe('displayBackupActions', () => {
  beforeEach(() => {
    vi.mocked(createDisplayBackupJob).mockReset();
    vi.mocked(fetchDisplayBackupJob).mockReset();
    vi.mocked(downloadDisplayBackupJob).mockReset();
  });

  it('downloadDisplayBackupToBrowser polls until ready then triggers download', async () => {
    vi.mocked(createDisplayBackupJob).mockResolvedValue({ job_id: 'job-1' });
    vi.mocked(fetchDisplayBackupJob)
      .mockResolvedValueOnce({ job_id: 'job-1', status: 'pending', error: null })
      .mockResolvedValueOnce({ job_id: 'job-1', status: 'ready', error: null });
    vi.mocked(downloadDisplayBackupJob).mockResolvedValue(new Blob([0x50, 0x4b]));

    const createUrl = vi.fn(() => 'blob:test');
    const revoke = vi.fn();
    vi.stubGlobal('URL', { createObjectURL: createUrl, revokeObjectURL: revoke });

    const click = vi.fn();
    vi.spyOn(document, 'createElement').mockReturnValue({
      href: '',
      download: '',
      click,
    } as HTMLAnchorElement);

    vi.useFakeTimers();
    const pending = downloadDisplayBackupToBrowser(display);
    await vi.advanceTimersByTimeAsync(1500);
    await pending;
    vi.useRealTimers();

    expect(createDisplayBackupJob).toHaveBeenCalledWith(display);
    expect(downloadDisplayBackupJob).toHaveBeenCalledWith(display, 'job-1');
    expect(click).toHaveBeenCalled();
    expect(revoke).toHaveBeenCalledWith('blob:test');
  });

  it('downloadDisplayBackupToBrowser throws when job fails', async () => {
    vi.mocked(createDisplayBackupJob).mockResolvedValue({ job_id: 'job-2' });
    vi.mocked(fetchDisplayBackupJob).mockResolvedValue({
      job_id: 'job-2',
      status: 'failed',
      error: 'disk full',
    });

    vi.useFakeTimers();
    const pending = downloadDisplayBackupToBrowser(display);
    const rejection = expect(pending).rejects.toThrow('disk full');
    await vi.advanceTimersByTimeAsync(500);
    await rejection;
    vi.useRealTimers();
  });

  it('restoreDisplayBackupFromFile delegates to displayBackups API', async () => {
    const { restoreDisplayBackupFile } = await import('@/api/displayBackups');
    vi.mocked(restoreDisplayBackupFile).mockResolvedValue(undefined);
    const file = new File([new Uint8Array([0x50])], 'restore.zip', {
      type: 'application/zip',
    });
    await restoreDisplayBackupFromFile(display, file);
    expect(restoreDisplayBackupFile).toHaveBeenCalledWith(display, file);
  });
});
