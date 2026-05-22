import {
  createDisplayBackupJob,
  downloadDisplayBackupJob,
  fetchDisplayBackupJob,
  restoreDisplayBackupFile,
} from '@/api/displayBackups';
import type { SavedDisplay } from '@/storage/displays';

const POLL_MS = 500;
const MAX_POLLS = 60;

export async function downloadDisplayBackupToBrowser(display: SavedDisplay): Promise<void> {
  const { job_id } = await createDisplayBackupJob(display);
  let status = 'pending';
  for (let i = 0; i < MAX_POLLS && status !== 'ready' && status !== 'failed'; i++) {
    await new Promise((r) => setTimeout(r, POLL_MS));
    const job = await fetchDisplayBackupJob(display, job_id);
    status = job.status;
    if (status === 'failed') {
      throw new Error(job.error ?? 'backup failed');
    }
  }
  if (status !== 'ready') {
    throw new Error('Timed out waiting for backup');
  }
  const blob = await downloadDisplayBackupJob(display, job_id);
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `waddle_backup_${display.id}.zip`;
  a.click();
  URL.revokeObjectURL(url);
}

export async function restoreDisplayBackupFromFile(
  display: SavedDisplay,
  file: File,
): Promise<void> {
  await restoreDisplayBackupFile(display, file);
}
