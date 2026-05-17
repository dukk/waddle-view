import type { AppDatabase } from '../db/database.js';
import { countUsers } from './users.js';
import { isUserManagementEnabled } from './settings.js';

export function needsBootstrap(db: AppDatabase, authEnabled: boolean): boolean {
  if (!authEnabled) return false;
  return isUserManagementEnabled(db) && countUsers(db) === 0;
}
