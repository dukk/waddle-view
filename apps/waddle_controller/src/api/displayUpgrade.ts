import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { GitHubReleaseAsset } from '@/api/githubReleases';

export type DisplayUpgradeJob = {
  id: string;
  status: string;
  download_url?: string;
  error?: string;
  started_at_utc?: string;
  completed_at_utc?: string;
};

export async function startDisplayUpgrade(
  display: SavedDisplay,
  asset: GitHubReleaseAsset,
): Promise<{ job_id: string }> {
  return apiJson<{ job_id: string }>(display, '/v1/display/ops/upgrade', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      download_url: asset.browser_download_url,
    }),
  });
}

export async function fetchDisplayUpgradeJob(
  display: SavedDisplay,
  jobId: string,
): Promise<DisplayUpgradeJob> {
  return apiJson<DisplayUpgradeJob>(
    display,
    `/v1/display/ops/upgrade/${encodeURIComponent(jobId)}`,
    { method: 'GET' },
  );
}
