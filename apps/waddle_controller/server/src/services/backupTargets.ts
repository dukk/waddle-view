import { randomUUID } from 'node:crypto';
import type { AppConfig } from '../config.js';
import type { DbClient } from '../db/client.js';
import { decryptDisplayApiKey, encryptDisplayApiKey } from './displaySecrets.js';
import { normalizeDisplayBaseUrl } from '../constants/proxyHeaders.js';
import { sqlActiveFlag, sqlBool } from '../db/sqlDialect.js';
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
  enabled: number | boolean;
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

function isEnabledFlag(value: number | boolean): boolean {
  return value === true || value === 1;
}

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
    enabled: isEnabledFlag(row.enabled),
    lastRunAt: row.last_run_at,
    lastStatus: row.last_status,
    lastError: row.last_error,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listBackupTargets(
  db: DbClient,
  userId: string | null,
): Promise<BackupTargetPublic[]> {
  const rows = userId
    ? await db.query<BackupTargetRow>(
        'SELECT * FROM backup_targets WHERE user_id = ? ORDER BY updated_at DESC',
        [userId],
      )
    : await db.query<BackupTargetRow>(
        'SELECT * FROM backup_targets WHERE user_id IS NULL ORDER BY updated_at DESC',
      );
  return rows.map(toPublic);
}

export async function findBackupTarget(
  db: DbClient,
  id: string,
  userId: string | null,
): Promise<BackupTargetRow | null> {
  const row = await db.queryOne<BackupTargetRow>('SELECT * FROM backup_targets WHERE id = ?', [id]);
  if (!row) return null;
  if (userId != null && row.user_id !== userId) return null;
  if (userId == null && row.user_id != null) return null;
  return row;
}

export async function findBackupTargetByDisplayId(
  db: DbClient,
  displayId: string,
  userId: string | null,
): Promise<BackupTargetRow | null> {
  const row = userId
    ? await db.queryOne<BackupTargetRow>(
        'SELECT * FROM backup_targets WHERE display_id = ? AND user_id = ? LIMIT 1',
        [displayId, userId],
      )
    : await db.queryOne<BackupTargetRow>(
        'SELECT * FROM backup_targets WHERE display_id = ? AND user_id IS NULL LIMIT 1',
        [displayId],
      );
  return row ?? null;
}

export async function upsertBackupTarget(
  config: Pick<AppConfig, 'sessionSecret'>,
  db: DbClient,
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
): Promise<BackupTargetPublic> {
  const now = new Date().toISOString();
  const baseUrl = normalizeDisplayBaseUrl(input.baseUrl);
  const { ciphertext, iv } = encryptDisplayApiKey(config.sessionSecret, input.apiKey);
  const existing = await findBackupTargetByDisplayId(db, input.displayId, input.userId);

  const existingSchedules = (await listBackupTargets(db, input.userId)).map((t) => t.schedule);
  const scheduleFallback = existing
    ? rowScheduleFields(existing)
    : allocateBackupScheduleForNewTarget(existingSchedules);
  const schedule = normalizeScheduleInput(input.schedule, scheduleFallback);
  const cronExpr = scheduleToCronExpr(schedule);
  const tz = controllerBackupTimezone();
  const retention = Math.max(1, Math.min(100, input.retentionCount));

  if (existing) {
    await db.run(
      `UPDATE backup_targets SET
        label = ?, base_url = ?, api_key_ciphertext = ?, api_key_iv = ?,
        cron_expr = ?, schedule_frequency = ?, schedule_interval = ?,
        schedule_day_of_week = ?, schedule_hour = ?, schedule_minute = ?,
        timezone = ?, retention_count = ?, enabled = ?, updated_at = ?
       WHERE id = ?`,
      [
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
        sqlBool(db.dialect, input.enabled),
        now,
        existing.id,
      ],
    );
    const row = await findBackupTarget(db, existing.id, input.userId);
    if (!row) throw new Error('Backup target not found after update');
    return toPublic(row);
  }

  const id = randomUUID();
  await db.run(
    `INSERT INTO backup_targets (
      id, user_id, display_id, label, base_url, api_key_ciphertext, api_key_iv,
      cron_expr, schedule_frequency, schedule_interval, schedule_day_of_week,
      schedule_hour, schedule_minute, timezone, retention_count, enabled, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
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
      sqlBool(db.dialect, input.enabled),
      now,
      now,
    ],
  );
  const row = await findBackupTarget(db, id, input.userId);
  if (!row) throw new Error('Backup target not found after insert');
  return toPublic(row);
}

export async function deleteBackupTarget(
  db: DbClient,
  id: string,
  userId: string | null,
): Promise<boolean> {
  const row = await findBackupTarget(db, id, userId);
  if (!row) return false;
  await db.run('DELETE FROM backup_targets WHERE id = ?', [id]);
  return true;
}

export async function listEnabledBackupTargets(db: DbClient): Promise<BackupTargetRow[]> {
  return db.query<BackupTargetRow>('SELECT * FROM backup_targets WHERE enabled = ?', [
    sqlActiveFlag(db.dialect),
  ]);
}

export function getDecryptedApiKey(
  config: Pick<AppConfig, 'sessionSecret'>,
  row: BackupTargetRow,
): string {
  return decryptDisplayApiKey(config.sessionSecret, row.api_key_ciphertext, row.api_key_iv);
}

export async function updateBackupTargetRunStatus(
  db: DbClient,
  id: string,
  status: 'ok' | 'error',
  error: string | null,
): Promise<void> {
  const now = new Date().toISOString();
  await db.run(
    'UPDATE backup_targets SET last_run_at = ?, last_status = ?, last_error = ?, updated_at = ? WHERE id = ?',
    [now, status, error, now, id],
  );
}
