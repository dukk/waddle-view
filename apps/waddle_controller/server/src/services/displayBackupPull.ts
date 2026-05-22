import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
import { insecureNodeFetch, DisplayUpstreamError } from './insecureFetch.js';
import {
  getDecryptedApiKey,
  updateBackupTargetRunStatus,
  type BackupTargetRow,
} from './backupTargets.js';
import { insertSnapshot, pruneSnapshotsForTarget } from './backupSnapshots.js';

const BACKUP_POLL_MS = 500;
const BACKUP_MAX_WAIT_MS = 30 * 60 * 1000;
const BACKUP_JOB_TIMEOUT_MS = 10 * 60 * 1000;

function parseJsonSafe(text: string): Record<string, unknown> | null {
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export async function pullBackupFromDisplay(
  config: AppConfig,
  db: AppDatabase,
  target: BackupTargetRow,
  source: 'scheduled' | 'manual',
): Promise<{ snapshotId: string; byteSize: number }> {
  const apiKey = getDecryptedApiKey(config, target);
  const base = target.base_url.replace(/\/$/, '');
  const auth = `Bearer ${apiKey}`;

  const createRes = await insecureNodeFetch(`${base}/v1/display/backup/jobs`, {
    method: 'POST',
    headers: new Headers({ Authorization: auth }),
    timeoutMs: BACKUP_JOB_TIMEOUT_MS,
  });
  if (!createRes.ok) {
    const err = await createRes.text();
    throw new DisplayUpstreamError(
      `Backup job start failed (${createRes.status}): ${err}`,
      'backup_job_start_failed',
      base,
    );
  }
  const created = parseJsonSafe(await createRes.text());
  const jobId = created?.job_id;
  if (typeof jobId !== 'string' || !jobId) {
    throw new Error('Display backup job response missing job_id');
  }

  const deadline = Date.now() + BACKUP_MAX_WAIT_MS;
  let status = 'pending';
  let manifest: Record<string, unknown> | null = null;
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, BACKUP_POLL_MS));
    const pollRes = await insecureNodeFetch(`${base}/v1/display/backup/jobs/${jobId}`, {
      method: 'GET',
      headers: new Headers({ Authorization: auth }),
      timeoutMs: BACKUP_JOB_TIMEOUT_MS,
    });
    if (!pollRes.ok) {
      throw new DisplayUpstreamError(
        `Backup job poll failed (${pollRes.status})`,
        'backup_job_poll_failed',
        base,
      );
    }
    const body = parseJsonSafe(await pollRes.text());
    status = String(body?.status ?? '');
    if (status === 'failed') {
      throw new Error(String(body?.error ?? 'display backup job failed'));
    }
    if (status === 'ready') {
      manifest =
        body?.manifest && typeof body.manifest === 'object'
          ? (body.manifest as Record<string, unknown>)
          : null;
      break;
    }
  }
  if (status !== 'ready') {
    throw new Error('Timed out waiting for display backup job');
  }

  const dlRes = await insecureNodeFetch(
    `${base}/v1/display/backup/jobs/${jobId}/download`,
    {
      method: 'GET',
      headers: new Headers({ Authorization: auth }),
      timeoutMs: BACKUP_JOB_TIMEOUT_MS,
    },
  );
  if (!dlRes.ok) {
    throw new DisplayUpstreamError(
      `Backup download failed (${dlRes.status})`,
      'backup_download_failed',
      base,
    );
  }
  const buf = Buffer.from(await dlRes.arrayBuffer());
  const maxBytes = Number(process.env.WADDLE_CONTROLLER_BACKUP_MAX_BYTES ?? 0);
  if (maxBytes > 0 && buf.length > maxBytes) {
    throw new Error(`Backup exceeds WADDLE_CONTROLLER_BACKUP_MAX_BYTES (${maxBytes})`);
  }

  const snap = insertSnapshot(db, config, {
    targetId: target.id,
    displayId: target.display_id,
    bytes: buf,
    fileName: `waddle_backup_${target.display_id}.zip`,
    source,
    manifest,
  });
  pruneSnapshotsForTarget(db, target.id, target.retention_count);
  updateBackupTargetRunStatus(db, target.id, 'ok', null);
  return { snapshotId: snap.id, byteSize: snap.byteSize };
}

export async function restoreSnapshotToDisplay(
  config: AppConfig,
  db: AppDatabase,
  snapshotId: string,
  target: BackupTargetRow,
): Promise<void> {
  const { findSnapshot, readSnapshotBytes } = await import('./backupSnapshots.js');
  const row = findSnapshot(db, snapshotId);
  if (!row || row.target_id !== target.id) {
    throw new Error('Snapshot not found for target');
  }
  const bytes = readSnapshotBytes(row);
  const apiKey = getDecryptedApiKey(config, target);
  const base = target.base_url.replace(/\/$/, '');
  const res = await insecureNodeFetch(`${base}/v1/display/backup/restore?confirm=yes`, {
    method: 'POST',
    headers: new Headers({
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/zip',
    }),
    body: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength),
    timeoutMs: BACKUP_JOB_TIMEOUT_MS,
  });
  if (!res.ok) {
    const err = await res.text();
    throw new DisplayUpstreamError(
      `Restore failed (${res.status}): ${err}`,
      'backup_restore_failed',
      base,
    );
  }
}
