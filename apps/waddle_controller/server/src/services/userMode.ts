import type { AppConfig } from '../config.js';
import type { DbClient } from '../db/client.js';
import { isUserManagementEnabled, setUserManagementEnabled } from './settings.js';

/** Runtime user mode flag in SQLite (stored as `user_management_enabled`). */
export async function isUserModeEnabled(db: DbClient): Promise<boolean> {
  return isUserManagementEnabled(db);
}

export async function setUserModeEnabled(db: DbClient, enabled: boolean): Promise<void> {
  await setUserManagementEnabled(db, enabled);
}

/** Sign-in and per-user display proxy require env auth capability and user mode on. */
export async function isEffectiveUserMode(config: AppConfig, db: DbClient): Promise<boolean> {
  return config.authEnabled && (await isUserModeEnabled(db));
}

export async function countUserDisplays(db: DbClient): Promise<number> {
  const row = await db.queryOne<{ c: number }>('SELECT COUNT(*) AS c FROM user_displays');
  return row?.c ?? 0;
}

/** One-time export of server-stored displays after user mode was turned off. */
export async function isRecoveryExportAvailable(
  config: AppConfig,
  db: DbClient,
): Promise<boolean> {
  return config.authEnabled && !(await isUserModeEnabled(db)) && (await countUserDisplays(db)) > 0;
}
