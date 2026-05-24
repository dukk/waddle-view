import type { AppConfig } from '../config.js';
import type { DbClient } from '../db/client.js';
import { countUsers } from './users.js';
import { isEffectiveUserMode } from './userMode.js';

export async function needsBootstrap(db: DbClient, config: AppConfig): Promise<boolean> {
  if (!(await isEffectiveUserMode(config, db))) return false;
  return (await countUsers(db)) === 0;
}
