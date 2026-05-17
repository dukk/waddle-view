import type { AppDatabase } from '../db/database.js';

const USER_MANAGEMENT_KEY = 'user_management_enabled';

export function isUserManagementEnabled(db: AppDatabase): boolean {
  const row = db
    .prepare('SELECT value FROM settings WHERE key = ?')
    .get(USER_MANAGEMENT_KEY) as { value: string } | undefined;
  return row?.value === 'true' || row?.value === '1';
}

export function setUserManagementEnabled(db: AppDatabase, enabled: boolean): void {
  db.prepare(
    `INSERT INTO settings (key, value) VALUES (?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
  ).run(USER_MANAGEMENT_KEY, enabled ? 'true' : 'false');
}
