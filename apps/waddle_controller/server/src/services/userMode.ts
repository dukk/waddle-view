import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
import { isUserManagementEnabled, setUserManagementEnabled } from './settings.js';

/** Runtime user mode flag in SQLite (stored as `user_management_enabled`). */
export function isUserModeEnabled(db: AppDatabase): boolean {
  return isUserManagementEnabled(db);
}

export function setUserModeEnabled(db: AppDatabase, enabled: boolean): void {
  setUserManagementEnabled(db, enabled);
}

/** Sign-in and per-user display proxy require env auth capability and user mode on. */
export function isEffectiveUserMode(config: AppConfig, db: AppDatabase): boolean {
  return config.authEnabled && isUserModeEnabled(db);
}

export function countUserDisplays(db: AppDatabase): number {
  const row = db.prepare('SELECT COUNT(*) AS c FROM user_displays').get() as { c: number };
  return row.c;
}

/** One-time export of server-stored displays after user mode was turned off. */
export function isRecoveryExportAvailable(config: AppConfig, db: AppDatabase): boolean {
  return config.authEnabled && !isUserModeEnabled(db) && countUserDisplays(db) > 0;
}
