import { randomUUID } from 'node:crypto';
import type { AppDatabase } from '../db/database.js';
import type { ControllerRole, PublicUser } from '../types.js';
import { hashPassword } from './password.js';

type UserRow = {
  id: string;
  username: string;
  password_hash: string;
  role: ControllerRole;
  disabled: number;
  created_at: string;
  updated_at: string;
};

function toPublicUser(row: UserRow): PublicUser {
  return {
    id: row.id,
    username: row.username,
    role: row.role,
    disabled: row.disabled !== 0,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function countUsers(db: AppDatabase): number {
  const row = db.prepare('SELECT COUNT(*) AS c FROM users').get() as { c: number };
  return row.c;
}

export function listUsers(db: AppDatabase): PublicUser[] {
  const rows = db
    .prepare('SELECT * FROM users ORDER BY username COLLATE NOCASE')
    .all() as UserRow[];
  return rows.map(toPublicUser);
}

export function findUserById(db: AppDatabase, id: string): PublicUser | null {
  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(id) as UserRow | undefined;
  return row ? toPublicUser(row) : null;
}

export function findUserByUsername(db: AppDatabase, username: string): (PublicUser & { passwordHash: string }) | null {
  const row = db
    .prepare('SELECT * FROM users WHERE username = ? COLLATE NOCASE')
    .get(username.trim()) as UserRow | undefined;
  if (!row) return null;
  return { ...toPublicUser(row), passwordHash: row.password_hash };
}

export function countAdmins(db: AppDatabase): number {
  const row = db
    .prepare("SELECT COUNT(*) AS c FROM users WHERE role = 'admin' AND disabled = 0")
    .get() as { c: number };
  return row.c;
}

export async function createUser(
  db: AppDatabase,
  input: { username: string; password: string; role: ControllerRole },
): Promise<PublicUser> {
  const now = new Date().toISOString();
  const id = randomUUID();
  const passwordHash = await hashPassword(input.password);
  try {
    db.prepare(
      `INSERT INTO users (id, username, password_hash, role, disabled, created_at, updated_at)
       VALUES (?, ?, ?, ?, 0, ?, ?)`,
    ).run(id, input.username.trim(), passwordHash, input.role, now, now);
  } catch (e: unknown) {
    if (e && typeof e === 'object' && 'code' in e && (e as { code: string }).code === 'SQLITE_CONSTRAINT_UNIQUE') {
      throw new Error('Username already exists');
    }
    throw e;
  }
  return findUserById(db, id)!;
}

export async function updateUser(
  db: AppDatabase,
  id: string,
  patch: { role?: ControllerRole; disabled?: boolean; password?: string },
): Promise<PublicUser> {
  const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(id) as UserRow | undefined;
  if (!existing) throw new Error('User not found');

  const role = patch.role ?? existing.role;
  const disabled = patch.disabled !== undefined ? (patch.disabled ? 1 : 0) : existing.disabled;
  const now = new Date().toISOString();
  let passwordHash = existing.password_hash;
  if (patch.password) {
    passwordHash = await hashPassword(patch.password);
  }

  if (existing.role === 'admin' && role !== 'admin' && countAdmins(db) <= 1 && existing.disabled === 0) {
    throw new Error('Cannot remove the last active admin');
  }
  if (existing.role === 'admin' && disabled === 1 && countAdmins(db) <= 1) {
    throw new Error('Cannot disable the last active admin');
  }

  db.prepare(
    `UPDATE users SET role = ?, disabled = ?, password_hash = ?, updated_at = ? WHERE id = ?`,
  ).run(role, disabled, passwordHash, now, id);
  return findUserById(db, id)!;
}

export function deleteUser(db: AppDatabase, id: string): void {
  const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(id) as UserRow | undefined;
  if (!existing) throw new Error('User not found');
  if (existing.role === 'admin' && countAdmins(db) <= 1) {
    throw new Error('Cannot delete the last active admin');
  }
  db.prepare('DELETE FROM users WHERE id = ?').run(id);
}
