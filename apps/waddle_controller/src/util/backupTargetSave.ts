import { pullBackupNow, saveBackupTarget, type BackupTarget } from '@/api/bffBackups';
import type { SavedDisplay } from '@/storage/displays';
import { scheduleFromTarget, type BackupSchedule } from '@/util/backupSchedule';

export async function saveDisplayBackupTarget(
  display: SavedDisplay,
  apiKey: string,
  opts: {
    schedule?: BackupSchedule;
    retentionCount?: number;
    enabled: boolean;
    existingTarget?: BackupTarget | null;
  },
): Promise<BackupTarget> {
  const existing = opts.existingTarget;
  return saveBackupTarget({
    displayId: display.id,
    label: display.label,
    baseUrl: display.baseUrl,
    apiKey,
    schedule: opts.schedule ?? (existing ? scheduleFromTarget(existing.schedule) : undefined),
    retentionCount: opts.retentionCount ?? existing?.retentionCount ?? 3,
    enabled: opts.enabled,
  });
}

export async function pullDisplayBackupNow(
  display: SavedDisplay,
  apiKey: string,
  target: BackupTarget | null,
): Promise<void> {
  let tid = target?.id;
  if (!tid) {
    const created = await saveDisplayBackupTarget(display, apiKey, {
      enabled: target?.enabled ?? true,
      existingTarget: target,
    });
    tid = created.id;
  }
  await pullBackupNow(tid);
}
