import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
import {
  findUserDisplayByDisplayId,
  getDecryptedApiKey,
  listUserDisplays,
} from './userDisplays.js';

export type RecoveryDisplayRow = {
  id: string;
  label: string;
  baseUrl: string;
  apiKey?: string;
  role?: string;
  identifier?: string;
};

export type RecoverySessionRow = {
  apiKey: string;
  identifier: string;
  role: string;
  permissions: string[];
  expiresAtMs: number;
};

export type RecoveryExportPayload = {
  displays: RecoveryDisplayRow[];
  sessions: Record<string, RecoverySessionRow>;
};

export function buildRecoveryExport(
  config: AppConfig,
  db: AppDatabase,
  userId: string,
): RecoveryExportPayload {
  const displays: RecoveryDisplayRow[] = [];
  const sessions: Record<string, RecoverySessionRow> = {};
  const expiresAtMs = Date.now() + 365 * 24 * 60 * 60 * 1000;

  for (const pub of listUserDisplays(db, userId)) {
    const displayId = pub.displayId;
    const entry: RecoveryDisplayRow = {
      id: displayId,
      label: pub.label,
      baseUrl: pub.baseUrl,
      role: pub.adoptedRole,
      identifier: pub.clientIdentifier,
    };
    if (pub.hasApiKey) {
      const row = findUserDisplayByDisplayId(db, userId, displayId);
      if (row) {
        const apiKey = getDecryptedApiKey(config.sessionSecret, row);
        entry.apiKey = apiKey;
        sessions[displayId] = {
          apiKey,
          identifier: pub.clientIdentifier,
          role: pub.adoptedRole,
          permissions: pub.permissions,
          expiresAtMs,
        };
      }
    }
    displays.push(entry);
  }

  return { displays, sessions };
}
