import type { DbClient } from '../db/client.js';

export const USER_MANAGEMENT_KEY = 'user_management_enabled';

export async function isUserManagementEnabled(db: DbClient): Promise<boolean> {
  const row = await db.queryOne<{ value: string }>(
    'SELECT value FROM settings WHERE key = ?',
    [USER_MANAGEMENT_KEY],
  );
  return row?.value === 'true' || row?.value === '1';
}

export async function setUserManagementEnabled(db: DbClient, enabled: boolean): Promise<void> {
  await db.run(
    `INSERT INTO settings (key, value) VALUES (?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
    [USER_MANAGEMENT_KEY, enabled ? 'true' : 'false'],
  );
}
