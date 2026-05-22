import { displayProxyFetch } from '@/api/displayProxy';
import type { SavedDisplay } from '@/storage/displays';
import { readProxyErrorMessage } from '@/util/proxyErrorBody';

export type DisplayBackupJob = {
  id: string;
  status: string;
  byte_size?: number;
  error?: string;
  manifest?: Record<string, unknown>;
};

export async function createDisplayBackupJob(
  display: SavedDisplay,
  options?: { format?: 'zip' | 'tgz' },
): Promise<{ job_id: string }> {
  const format = options?.format ?? 'zip';
  const res = await displayProxyFetch(
    `/v1/display/backup/jobs?format=${format}`,
    { method: 'POST' },
    { display },
  );
  if (!res.ok) {
    throw new Error(await readProxyErrorMessage(res, `Backup start failed (${res.status})`));
  }
  return (await res.json()) as { job_id: string };
}

export async function fetchDisplayBackupJob(
  display: SavedDisplay,
  jobId: string,
): Promise<DisplayBackupJob> {
  const res = await displayProxyFetch(
    `/v1/display/backup/jobs/${encodeURIComponent(jobId)}`,
    { method: 'GET' },
    { display },
  );
  if (!res.ok) {
    throw new Error(await readProxyErrorMessage(res, `Backup status failed (${res.status})`));
  }
  return (await res.json()) as DisplayBackupJob;
}

export async function downloadDisplayBackupJob(
  display: SavedDisplay,
  jobId: string,
): Promise<Blob> {
  const res = await displayProxyFetch(
    `/v1/display/backup/jobs/${encodeURIComponent(jobId)}/download`,
    { method: 'GET' },
    { display },
  );
  if (!res.ok) {
    throw new Error(await readProxyErrorMessage(res, `Backup download failed (${res.status})`));
  }
  return res.blob();
}

export async function restoreDisplayBackupFile(
  display: SavedDisplay,
  file: Blob,
): Promise<void> {
  const res = await displayProxyFetch(
    '/v1/display/backup/restore?confirm=yes',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/zip' },
      body: file,
    },
    { display },
  );
  if (!res.ok) {
    throw new Error(await readProxyErrorMessage(res, `Restore failed (${res.status})`));
  }
}
