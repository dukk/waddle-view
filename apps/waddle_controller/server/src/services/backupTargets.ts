import { randomUUID } from 'node:crypto';
import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
import { decryptDisplayApiKey, encryptDisplayApiKey } from './displaySecrets.js';
import { normalizeDisplayBaseUrl } from '../constants/proxyHeaders.js';
import {
  allocateBackupScheduleForNewTarget,
  controllerBackupTimezone,
  normalizeScheduleInput,
  scheduleToCronExpr,
  type BackupScheduleFields,
  type BackupSchedulePublic,
} from './backupSchedule.js';

export type BackupTargetRow = {
  id: string;
  user_id: string | null;
  display_id: string;
  label: string;
  base_url: string;
  api_key_ciphertext: string;
  api_key_iv: string;
  cron_expr: string;
  schedule_frequency: string;
  schedule_interval: number;
  schedule_day_of_week: number | null;
  schedule_hour: number;
  schedule_minute: number;
  timezone: string;
  retention_count: number;
  enabled: number;
  last_run_at: string | null;
  last_status: string | null;
  last_error: string | null;
  created_at: string;
  updated_at: string;
};

export type BackupTargetPublic = {
  id: string;
  displayId: string;
  label: string;
  baseUrl: string;
  schedule: BackupSchedulePublic;
  timezone: string;
  retentionCount: number;
  enabled: boolean;
  lastRunAt: string | null;
  lastStatus: string | null;
  lastError: string | null;
  createdAt: string;
  updatedAt: string;
};

export function rowScheduleFields(row: BackupTargetRow): BackupScheduleFields {
  return {
    frequency: row.schedule_frequency === 'daily' ? 'daily' : 'weekly',
    interval: row.schedule_interval,
    dayOfWeek: row.schedule_day_of_week,
    hour: row.schedule_hour,
    minute: row.schedule_minute,
  };
}

function toPublic(row: BackupTargetRow): BackupTargetPublic {
  return {
    id: row.id,
    displayId: row.display_id,
    label: row.label,
    baseUrl: row.base_url,
    schedule: rowScheduleFields(row),
    timezone: row.timezone,
    retentionCount: row.retention_count,
    enabled: row.enabled === 1,
    lastRunAt: row.last_run_at,
    lastStatus: row.last_status,
    lastError: row.last_error,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function listBackupTargets(
  db: AppDatabase,
  userId: string | null,
): BackupTargetPublic[] {
  const rows = userId
    ? (db
        .prepare(
          'SELECT * FROM backup_targets WHERE user_id = ? ORDER BY updated_at DESC',
        )
        .all(userId) as BackupTargetRow[])
    : (db
        .prepare('SELECT * FROM backup_targets WHERE user_id IS NULL ORDER BY updated_at DESC')
        .all() as BackupTargetRow[]);
  return rows.map(toPublic);
}

export function findBackupTarget(
  db: AppDatabase,
  id: string,
  userId: string | null,
): BackupTargetRow | null {
  const row = db.prepare('SELECT * FROM backup_targets WHERE id = ?').get(id) as
    | BackupTargetRow
    | undefined;
  if (!row) return null;
  if (userId != null && row.user_id !== userId) return null;
  if (userId == null && row.user_id != null) return null;
  return row;
}

export function findBackupTargetByDisplayId(
  db: AppDatabase,
  displayId: string,
  userId: string | null,
): BackupTargetRow | null {
  const row = userId
    ? (db
        .prepare(
          'SELECT * FROM backup_targets WHERE display_id = ? AND user_id = ? LIMIT 1',
        )
        .get(displayId, userId) as BackupTargetRow | undefined)
    : (db
        .prepare(
          'SELECT * FROM backup_targets WHERE display_id = ? AND user_id IS NULL LIMIT 1',
        )
        .get(displayId) as BackupTargetRow | undefined);
  return row ?? null;
}

export function upsertBackupTarget(
  config: Pick<AppConfig, 'sessionSecret'>,
  db: AppDatabase,
  input: {
    userId: string | null;
    displayId: string;
    label: string;
    baseUrl: string;
    apiKey: string;
    schedule?: Partial<BackupScheduleFields>;
    timezone?: string;
    retentionCount: number;
    enabled: boolean;
  },
): BackupTargetPublic {
  const now = new Date().toISOString();
  const baseUrl = normalizeDisplayBaseUrl(input.baseUrl);
  const { ciphertext, iv } = encryptDisplayApiKey(config.sessionSecret, input.apiKey);
  const existing = findBackupTargetByDisplayId(db, input.displayId, input.userId);

  const existingSchedules = listBackupTargets(db, input.userId).map((t) => t.schedule);
  const scheduleFallback = existing
    ? rowScheduleFields(existing)
    : allocateBackupScheduleForNewTarget(existingSchedules);
  const schedule = normalizeScheduleInput(input.schedule, scheduleFallback);
  const cronExpr = scheduleToCronExpr(schedule);
  const tz = controllerBackupTimezone();
  const retention = Math.max(1, Math.min(100, input.retentionCount));

  if (existing) {
    db.prepare(
      `UPDATE backup_targets SET
        label = ?, base_url = ?, api_key_ciphertext = ?, api_key_iv = ?,
        cron_expr = ?, schedule_frequency = ?, schedule_interval = ?,
        schedule_day_of_week = ?, schedule_hour = ?, schedule_minute = ?,
        timezone = ?, retention_count = ?, enabled = ?, updated_at = ?
       WHERE id = ?`,
    ).run(
      input.label,
      baseUrl,
      ciphertext,
      iv,
      cronExpr,
      schedule.frequency,
      schedule.interval,
      schedule.dayOfWeek,
      schedule.hour,
      schedule.minute,
      tz,
      retention,
      input.enabled ? 1 : 0,
      now,
      existing.id,
    );
    return toPublic(findBackupTarget(db, existing.id, input.userId)!);
  }

  const id = randomUUID();
  db.prepare(
    `INSERT INTO backup_targets (
      id, user_id, display_id, label, base_url, api_key_ciphertext, api_key_iv,
      cron_expr, schedule_frequency, schedule_interval, schedule_day_of_week,
      schedule_hour, schedule_minute, timezone, retention_count, enabled, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    input.userId,
    input.displayId,
    input.label,
    baseUrl,
    ciphertext,
    iv,
    cronExpr,
    schedule.frequency,
    schedule.interval,
    schedule.dayOfWeek,
    schedule.hour,
    schedule.minute,
    tz,
    retention,
    input.enabled ? 1 : 0,
    now,
    now,
  );
  return toPublic(findBackupTarget(db, id, input.userId)!);
}

export function deleteBackupTarget(
  db: AppDatabase,
  id: string,
  userId: string | null,
): boolean {
  const row = findBackupTarget(db, id, userId);
  if (!row) return false;
  db.prepare('DELETE FROM backup_targets WHERE id = ?').run(id);
  return true;
}

export function listEnabledBackupTargets(db: AppDatabase): BackupTargetRow[] {
  return db
    .prepare('SELECT * FROM backup_targets WHERE enabled = 1')
    .all() as BackupTargetRow[];
}

export function getDecryptedApiKey(
  config: Pick<AppConfig, 'sessionSecret'>,
  row: BackupTargetRow,
): string {
  return decryptDisplayApiKey(config.sessionSecret, row.api_key_ciphertext, row.api_key_iv);
}

export function updateBackupTargetRunStatus(
  db: AppDatabase,
  id: string,
  status: 'ok' | 'error',
  error: string | null,
): void {
  const now = new Date().toISOString();
  db.prepare(
    'UPDATE backup_targets SET last_run_at = ?, last_status = ?, last_error = ?, updated_at = ? WHERE id = ?',
  ).run(now, status, error, now, id);
}
