import { bffFetch, bffJson } from '@/api/bffClient';

export type BackupTarget = {
  id: string;
  displayId: string;
  label: string;
  baseUrl: string;
  cronExpr: string;
  timezone: string;
  retentionCount: number;
  enabled: boolean;
  lastRunAt: string | null;
  lastStatus: string | null;
  lastError: string | null;
  createdAt: string;
  updatedAt: string;
};

export type BackupSnapshot = {
  id: string;
  targetId: string;
  displayId: string;
  fileName: string;
  byteSize: number;
  manifest: Record<string, unknown> | null;
  source: string;
  createdAt: string;
};

export async function listBackupTargets(): Promise<BackupTarget[]> {
  const body = await bffJson<{ targets: BackupTarget[] }>('/backup-targets');
  return body.targets;
}

export async function saveBackupTarget(input: {
  displayId: string;
  label: string;
  baseUrl: string;
  apiKey: string;
  cronExpr: string;
  timezone: string;
  retentionCount: number;
  enabled: boolean;
}): Promise<BackupTarget> {
  const body = await bffJson<{ target: BackupTarget }>('/backup-targets', {
    method: 'PUT',
    body: JSON.stringify(input),
  });
  return body.target;
}

export async function deleteBackupTarget(id: string): Promise<void> {
  await bffJson(`/backup-targets/${encodeURIComponent(id)}`, { method: 'DELETE' });
}

export async function listBackupSnapshots(targetId: string): Promise<BackupSnapshot[]> {
  const body = await bffJson<{ snapshots: BackupSnapshot[] }>(
    `/backup-targets/${encodeURIComponent(targetId)}/snapshots`,
  );
  return body.snapshots;
}

export async function pullBackupNow(targetId: string): Promise<{ snapshotId: string; byteSize: number }> {
  return bffJson(`/backup-targets/${encodeURIComponent(targetId)}/pull-now`, {
    method: 'POST',
    body: '{}',
  });
}

export async function restoreBackupSnapshot(snapshotId: string): Promise<void> {
  await bffJson(`/backup-snapshots/${encodeURIComponent(snapshotId)}/restore`, {
    method: 'POST',
    body: '{}',
  });
}

export async function deleteBackupSnapshot(snapshotId: string): Promise<void> {
  await bffJson(`/backup-snapshots/${encodeURIComponent(snapshotId)}`, { method: 'DELETE' });
}

export function backupSnapshotDownloadUrl(snapshotId: string): string {
  return `/bff/v1/backup-snapshots/${encodeURIComponent(snapshotId)}/download`;
}

export async function uploadBackupArchive(targetId: string, file: File): Promise<BackupSnapshot> {
  const res = await bffFetch(`/backup-targets/${encodeURIComponent(targetId)}/upload`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/zip' },
    body: file,
  });
  const body = (await res.json()) as { snapshot: BackupSnapshot };
  return body.snapshot;
}
