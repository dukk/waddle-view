import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { fetchDisplayUpgradeJob, startDisplayUpgrade } from './displayUpgrade';

vi.mock('./client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from './client';

const display = {
  id: 'd1',
  label: 'Test',
  baseUrl: 'https://127.0.0.1:8787',
} as SavedDisplay;

const asset = {
  name: 'waddle-view-linux-arm64-v1.tar.gz',
  browser_download_url: 'https://github.com/example/asset.tar.gz',
  size: 123,
};

describe('displayUpgrade api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
  });

  it('startDisplayUpgrade POSTs download_url', async () => {
    vi.mocked(apiJson).mockResolvedValue({ job_id: 'job-1' });
    const result = await startDisplayUpgrade(display, asset);
    expect(result.job_id).toBe('job-1');
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/display/ops/upgrade', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ download_url: asset.browser_download_url }),
    });
  });

  it('fetchDisplayUpgradeJob GETs encoded job id', async () => {
    vi.mocked(apiJson).mockResolvedValue({ id: 'job-1', status: 'running' });
    const job = await fetchDisplayUpgradeJob(display, 'job/with space');
    expect(job.status).toBe('running');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/display/ops/upgrade/job%2Fwith%20space',
      { method: 'GET' },
    );
  });
});
