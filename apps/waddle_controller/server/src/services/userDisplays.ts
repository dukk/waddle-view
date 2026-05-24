import { randomUUID } from 'node:crypto';
import type { DbClient } from '../db/client.js';
import { orderByLabel, sqlActiveFlag, sqlInactiveFlag } from '../db/sqlDialect.js';
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
  is_active: number | boolean;
  created_at: string;
  updated_at: string;
};

function isActiveFlag(value: number | boolean): boolean {
  return value === true || value === 1;
}

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
    isActive: isActiveFlag(row.is_active),
    hasApiKey: Boolean(row.api_key_ciphertext),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listUserDisplays(db: DbClient, userId: string): Promise<UserDisplayPublic[]> {
  const rows = await db.query<UserDisplayRow>(
    `SELECT * FROM user_displays WHERE user_id = ? ORDER BY ${orderByLabel(db.dialect)}`,
    [userId],
  );
  return rows.map(toPublic);
}

export async function findUserDisplayByDisplayId(
  db: DbClient,
  userId: string,
  displayId: string,
): Promise<UserDisplayRow | null> {
  return (
    (await db.queryOne<UserDisplayRow>(
      'SELECT * FROM user_displays WHERE user_id = ? AND display_id = ?',
      [userId, displayId],
    )) ?? null
  );
}

export async function findActiveUserDisplay(
  db: DbClient,
  userId: string,
): Promise<UserDisplayRow | null> {
  return (
    (await db.queryOne<UserDisplayRow>(
      'SELECT * FROM user_displays WHERE user_id = ? AND is_active = ? LIMIT 1',
      [userId, sqlActiveFlag(db.dialect)],
    )) ?? null
  );
}

export function getDecryptedApiKey(sessionSecret: string, row: UserDisplayRow): string {
  return decryptDisplayApiKey(sessionSecret, row.api_key_ciphertext, row.api_key_iv);
}

export async function upsertUserDisplay(
  db: DbClient,
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
): Promise<UserDisplayPublic> {
  const now = new Date().toISOString();
  const baseUrl = normalizeDisplayBaseUrl(input.baseUrl);
  const enc = encryptDisplayApiKey(sessionSecret, input.apiKey);
  const permissionsJson = JSON.stringify(input.permissions);
  const existing = await findUserDisplayByDisplayId(db, userId, input.displayId);
  if (existing) {
    await db.run(
      `UPDATE user_displays SET label = ?, base_url = ?, client_identifier = ?, adopted_role = ?,
       api_key_ciphertext = ?, api_key_iv = ?, permissions_json = ?, updated_at = ?
       WHERE id = ?`,
      [
        input.label.trim() || baseUrl,
        baseUrl,
        input.clientIdentifier.trim(),
        input.adoptedRole,
        enc.ciphertext,
        enc.iv,
        permissionsJson,
        now,
        existing.id,
      ],
    );
    const row = await findUserDisplayByDisplayId(db, userId, input.displayId);
    if (!row) throw new Error('Display not found after update');
    return toPublic(row);
  }
  const id = randomUUID();
  await db.run(
    `INSERT INTO user_displays (
      id, user_id, display_id, label, base_url, client_identifier, adopted_role,
      api_key_ciphertext, api_key_iv, permissions_json, is_active, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`,
    [
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
    ],
  );
  const row = await findUserDisplayByDisplayId(db, userId, input.displayId);
  if (!row) throw new Error('Display not found after insert');
  return toPublic(row);
}

export async function setActiveUserDisplay(
  db: DbClient,
  userId: string,
  displayId: string,
): Promise<UserDisplayPublic | null> {
  const row = await findUserDisplayByDisplayId(db, userId, displayId);
  if (!row) return null;
  const now = new Date().toISOString();
  await db.transaction(async (tx) => {
    await tx.run('UPDATE user_displays SET is_active = ?, updated_at = ? WHERE user_id = ?', [
      sqlInactiveFlag(db.dialect),
      now,
      userId,
    ]);
    await tx.run(
      'UPDATE user_displays SET is_active = ?, updated_at = ? WHERE user_id = ? AND display_id = ?',
      [sqlActiveFlag(db.dialect), now, userId, displayId],
    );
  });
  const updated = await findUserDisplayByDisplayId(db, userId, displayId);
  if (!updated) return null;
  return toPublic(updated);
}

export async function deleteUserDisplay(
  db: DbClient,
  userId: string,
  displayId: string,
): Promise<boolean> {
  const result = await db.run(
    'DELETE FROM user_displays WHERE user_id = ? AND display_id = ?',
    [userId, displayId],
  );
  return result.changes > 0;
}

export function userDisplayBaseUrlMatches(row: UserDisplayRow, requestedUrl: string): boolean {
  return normalizeDisplayBaseUrl(row.base_url) === normalizeDisplayBaseUrl(requestedUrl);
}

export async function findUserDisplayByBaseUrl(
  db: DbClient,
  userId: string,
  baseUrl: string,
): Promise<UserDisplayRow | null> {
  const normalized = normalizeDisplayBaseUrl(baseUrl);
  const rows = await db.query<UserDisplayRow>(
    'SELECT * FROM user_displays WHERE user_id = ?',
    [userId],
  );
  return rows.find((r) => normalizeDisplayBaseUrl(r.base_url) === normalized) ?? null;
}
