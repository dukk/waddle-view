import { displayProxyFetch } from '@/api/displayProxy';
import type { SavedDisplay } from '@/storage/displays';
import { readProxyErrorMessage } from '@/util/proxyErrorBody';
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
  const res = await displayProxyFetch(
    '/v1/display/ops/upgrade',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        download_url: asset.browser_download_url,
      }),
    },
    { display },
  );
  if (!res.ok) {
    throw new Error(await readProxyErrorMessage(res, `Upgrade failed (${res.status})`));
  }
  return (await res.json()) as { job_id: string };
}

export async function fetchDisplayUpgradeJob(
  display: SavedDisplay,
  jobId: string,
): Promise<DisplayUpgradeJob> {
  const res = await displayProxyFetch(
    `/v1/display/ops/upgrade/${encodeURIComponent(jobId)}`,
    { method: 'GET' },
    { display },
  );
  if (!res.ok) {
    throw new Error(await readProxyErrorMessage(res, `Upgrade status failed (${res.status})`));
  }
  return (await res.json()) as DisplayUpgradeJob;
}
