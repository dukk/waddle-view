import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
import { countUsers } from './users.js';
import { isEffectiveUserMode } from './userMode.js';

export function needsBootstrap(db: AppDatabase, config: AppConfig): boolean {
  if (!isEffectiveUserMode(config, db)) return false;
  return countUsers(db) === 0;
}
