import { randomUUID } from 'node:crypto';
import type { AppDatabase } from '../db/database.js';
import { normalizeDisplayBaseUrl } from '../constants/proxyHeaders.js';
import { decryptDisplayApiKey, encryptDisplayApiKey } from './displaySecrets.js';

export type UserDisplayPublic = {
  id: string;
  displayId: string;
  label: string;
  baseUrl: string;
  clientIdentifier: string;
  adoptedRole: string;
  permissions: string[];
  isActive: boolean;
  hasApiKey: boolean;
  createdAt: string;
  updatedAt: string;
};

export type UserDisplayRow = {
  id: string;
  user_id: string;
  display_id: string;
  label: string;
  base_url: string;
  client_identifier: string;
  adopted_role: string;
  api_key_ciphertext: string;
  api_key_iv: string;
  permissions_json: string;
  is_active: number;
  created_at: string;
  updated_at: string;
};

function parsePermissions(json: string): string[] {
  try {
    const parsed = JSON.parse(json) as unknown;
    return Array.isArray(parsed) ? parsed.filter((p): p is string => typeof p === 'string') : [];
  } catch {
    return [];
  }
}

function toPublic(row: UserDisplayRow): UserDisplayPublic {
  return {
    id: row.id,
    displayId: row.display_id,
    label: row.label,
    baseUrl: row.base_url,
    clientIdentifier: row.client_identifier,
    adoptedRole: row.adopted_role,
    permissions: parsePermissions(row.permissions_json),
    isActive: row.is_active !== 0,
    hasApiKey: Boolean(row.api_key_ciphertext),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function listUserDisplays(db: AppDatabase, userId: string): UserDisplayPublic[] {
  const rows = db
    .prepare('SELECT * FROM user_displays WHERE user_id = ? ORDER BY label COLLATE NOCASE')
    .all(userId) as UserDisplayRow[];
  return rows.map(toPublic);
}

export function findUserDisplayByDisplayId(
  db: AppDatabase,
  userId: string,
  displayId: string,
): UserDisplayRow | null {
  return (
    (db
      .prepare('SELECT * FROM user_displays WHERE user_id = ? AND display_id = ?')
      .get(userId, displayId) as UserDisplayRow | undefined) ?? null
  );
}

export function findActiveUserDisplay(
  db: AppDatabase,
  userId: string,
): UserDisplayRow | null {
  return (
    (db
      .prepare('SELECT * FROM user_displays WHERE user_id = ? AND is_active = 1 LIMIT 1')
      .get(userId) as UserDisplayRow | undefined) ?? null
  );
}

export function getDecryptedApiKey(
  sessionSecret: string,
  row: UserDisplayRow,
): string {
  return decryptDisplayApiKey(sessionSecret, row.api_key_ciphertext, row.api_key_iv);
}

export function upsertUserDisplay(
  db: AppDatabase,
  sessionSecret: string,
  userId: string,
  input: {
    displayId: string;
    label: string;
    baseUrl: string;
    clientIdentifier: string;
    adoptedRole: string;
    apiKey: string;
    permissions: string[];
  },
): UserDisplayPublic {
  const now = new Date().toISOString();
  const baseUrl = normalizeDisplayBaseUrl(input.baseUrl);
  const enc = encryptDisplayApiKey(sessionSecret, input.apiKey);
  const permissionsJson = JSON.stringify(input.permissions);
  const existing = findUserDisplayByDisplayId(db, userId, input.displayId);
  if (existing) {
    db.prepare(
      `UPDATE user_displays SET label = ?, base_url = ?, client_identifier = ?, adopted_role = ?,
       api_key_ciphertext = ?, api_key_iv = ?, permissions_json = ?, updated_at = ?
       WHERE id = ?`,
    ).run(
      input.label.trim() || baseUrl,
      baseUrl,
      input.clientIdentifier.trim(),
      input.adoptedRole,
      enc.ciphertext,
      enc.iv,
      permissionsJson,
      now,
      existing.id,
    );
    return toPublic(findUserDisplayByDisplayId(db, userId, input.displayId)!);
  }
  const id = randomUUID();
  db.prepare(
    `INSERT INTO user_displays (
      id, user_id, display_id, label, base_url, client_identifier, adopted_role,
      api_key_ciphertext, api_key_iv, permissions_json, is_active, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`,
  ).run(
    id,
    userId,
    input.displayId,
    input.label.trim() || baseUrl,
    baseUrl,
    input.clientIdentifier.trim(),
    input.adoptedRole,
    enc.ciphertext,
    enc.iv,
    permissionsJson,
    now,
    now,
  );
  return toPublic(findUserDisplayByDisplayId(db, userId, input.displayId)!);
}

export function setActiveUserDisplay(
  db: AppDatabase,
  userId: string,
  displayId: string,
): UserDisplayPublic | null {
  const row = findUserDisplayByDisplayId(db, userId, displayId);
  if (!row) return null;
  const now = new Date().toISOString();
  const tx = db.transaction(() => {
    db.prepare('UPDATE user_displays SET is_active = 0, updated_at = ? WHERE user_id = ?').run(
      now,
      userId,
    );
    db.prepare(
      'UPDATE user_displays SET is_active = 1, updated_at = ? WHERE user_id = ? AND display_id = ?',
    ).run(now, userId, displayId);
  });
  tx();
  return toPublic(findUserDisplayByDisplayId(db, userId, displayId)!);
}

export function deleteUserDisplay(
  db: AppDatabase,
  userId: string,
  displayId: string,
): boolean {
  const result = db
    .prepare('DELETE FROM user_displays WHERE user_id = ? AND display_id = ?')
    .run(userId, displayId);
  return result.changes > 0;
}

export function userDisplayBaseUrlMatches(
  row: UserDisplayRow,
  requestedUrl: string,
): boolean {
  return normalizeDisplayBaseUrl(row.base_url) === normalizeDisplayBaseUrl(requestedUrl);
}

export function findUserDisplayByBaseUrl(
  db: AppDatabase,
  userId: string,
  baseUrl: string,
): UserDisplayRow | null {
  const normalized = normalizeDisplayBaseUrl(baseUrl);
  const rows = db
    .prepare('SELECT * FROM user_displays WHERE user_id = ?')
    .all(userId) as UserDisplayRow[];
  return rows.find((r) => normalizeDisplayBaseUrl(r.base_url) === normalized) ?? null;
}
