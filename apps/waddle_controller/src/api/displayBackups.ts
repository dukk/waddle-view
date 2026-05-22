import { apiFetch, apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

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
  return apiJson<{ job_id: string }>(
    display,
    `/v1/display/backup/jobs?format=${format}`,
    { method: 'POST' },
  );
}

export async function fetchDisplayBackupJob(
  display: SavedDisplay,
  jobId: string,
): Promise<DisplayBackupJob> {
  return apiJson<DisplayBackupJob>(
    display,
    `/v1/display/backup/jobs/${encodeURIComponent(jobId)}`,
    { method: 'GET' },
  );
}

export async function downloadDisplayBackupJob(
  display: SavedDisplay,
  jobId: string,
): Promise<Blob> {
  const res = await apiFetch(
    display,
    `/v1/display/backup/jobs/${encodeURIComponent(jobId)}/download`,
    { method: 'GET' },
  );
  return res.blob();
}

export async function restoreDisplayBackupFile(
  display: SavedDisplay,
  file: Blob,
): Promise<void> {
  await apiFetch(display, '/v1/display/backup/restore?confirm=yes', {
    method: 'POST',
    headers: { 'Content-Type': 'application/zip' },
    body: file,
  });
}
