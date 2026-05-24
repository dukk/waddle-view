import { randomUUID } from 'node:crypto';
import type { DbClient } from '../db/client.js';
import { isUniqueConstraintError } from '../db/client.js';
import { orderByUsername, sqlBool, sqlInactiveFlag, usernameEquals } from '../db/sqlDialect.js';
import type { ControllerRole, PublicUser } from '../types.js';
import { hashPassword } from './password.js';

type UserRow = {
  id: string;
  username: string;
  password_hash: string;
  role: ControllerRole;
  disabled: number | boolean;
  must_change_password: number | boolean;
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
};

function isTruthyFlag(value: number | boolean): boolean {
  return value === true || value === 1;
}

function toPublicUser(row: UserRow): PublicUser {
  return {
    id: row.id,
    username: row.username,
    role: row.role,
    disabled: isTruthyFlag(row.disabled),
    mustChangePassword: isTruthyFlag(row.must_change_password),
    lastLoginAt: row.last_login_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function countUsers(db: DbClient): Promise<number> {
  const row = await db.queryOne<{ c: number }>('SELECT COUNT(*) AS c FROM users');
  return row?.c ?? 0;
}

export async function listUsers(db: DbClient): Promise<PublicUser[]> {
  const rows = await db.query<UserRow>(
    `SELECT * FROM users ORDER BY ${orderByUsername(db.dialect)}`,
  );
  return rows.map(toPublicUser);
}

export async function findUserById(db: DbClient, id: string): Promise<PublicUser | null> {
  const row = await db.queryOne<UserRow>('SELECT * FROM users WHERE id = ?', [id]);
  return row ? toPublicUser(row) : null;
}

export async function findUserByUsername(
  db: DbClient,
  username: string,
): Promise<(PublicUser & { passwordHash: string }) | null> {
  const row = await db.queryOne<UserRow>(`SELECT * FROM users WHERE ${usernameEquals(db.dialect)}`, [
    username.trim(),
  ]);
  if (!row) return null;
  return { ...toPublicUser(row), passwordHash: row.password_hash };
}

export async function countAdmins(db: DbClient): Promise<number> {
  const row = await db.queryOne<{ c: number }>(
    "SELECT COUNT(*) AS c FROM users WHERE role = 'admin' AND disabled = ?",
    [sqlInactiveFlag(db.dialect)],
  );
  return row?.c ?? 0;
}

export async function recordUserLogin(db: DbClient, userId: string): Promise<void> {
  const now = new Date().toISOString();
  await db.run('UPDATE users SET last_login_at = ?, updated_at = ? WHERE id = ?', [
    now,
    now,
    userId,
  ]);
}

export async function createUser(
  db: DbClient,
  input: {
    username: string;
    password: string;
    role: ControllerRole;
    mustChangePassword?: boolean;
  },
): Promise<PublicUser> {
  const now = new Date().toISOString();
  const id = randomUUID();
  const passwordHash = await hashPassword(input.password);
  const mustChange = sqlBool(db.dialect, Boolean(input.mustChangePassword));
  const disabled = sqlInactiveFlag(db.dialect);
  try {
    await db.run(
      `INSERT INTO users (id, username, password_hash, role, disabled, must_change_password, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, input.username.trim(), passwordHash, input.role, disabled, mustChange, now, now],
    );
  } catch (e: unknown) {
    if (isUniqueConstraintError(e, db.dialect)) {
      throw new Error('Username already exists');
    }
    throw e;
  }
  const user = await findUserById(db, id);
  if (!user) throw new Error('User not found');
  return user;
}

export async function updateUser(
  db: DbClient,
  id: string,
  patch: {
    role?: ControllerRole;
    disabled?: boolean;
    password?: string;
    mustChangePassword?: boolean;
  },
): Promise<PublicUser> {
  const existing = await db.queryOne<UserRow>('SELECT * FROM users WHERE id = ?', [id]);
  if (!existing) throw new Error('User not found');

  const role = patch.role ?? existing.role;
  const disabled =
    patch.disabled !== undefined
      ? sqlBool(db.dialect, patch.disabled)
      : isTruthyFlag(existing.disabled)
        ? sqlBool(db.dialect, true)
        : sqlBool(db.dialect, false);
  const mustChangePassword =
    patch.mustChangePassword !== undefined
      ? sqlBool(db.dialect, patch.mustChangePassword)
      : isTruthyFlag(existing.must_change_password)
        ? sqlBool(db.dialect, true)
        : sqlBool(db.dialect, false);
  const now = new Date().toISOString();
  let passwordHash = existing.password_hash;
  if (patch.password) {
    passwordHash = await hashPassword(patch.password);
  }

  if (
    existing.role === 'admin' &&
    role !== 'admin' &&
    (await countAdmins(db)) <= 1 &&
    !isTruthyFlag(existing.disabled)
  ) {
    throw new Error('Cannot remove the last active admin');
  }
  if (existing.role === 'admin' && disabled === sqlBool(db.dialect, true) && (await countAdmins(db)) <= 1) {
    throw new Error('Cannot disable the last active admin');
  }

  await db.run(
    `UPDATE users SET role = ?, disabled = ?, password_hash = ?, must_change_password = ?, updated_at = ? WHERE id = ?`,
    [role, disabled, passwordHash, mustChangePassword, now, id],
  );
  const user = await findUserById(db, id);
  if (!user) throw new Error('User not found');
  return user;
}

export async function changeUserPassword(
  db: DbClient,
  userId: string,
  currentPassword: string,
  newPassword: string,
): Promise<PublicUser> {
  const row = await db.queryOne<UserRow>('SELECT * FROM users WHERE id = ?', [userId]);
  if (!row) throw new Error('User not found');
  const { verifyPassword } = await import('./password.js');
  const ok = await verifyPassword(currentPassword, row.password_hash);
  if (!ok) throw new Error('Current password is incorrect');
  return updateUser(db, userId, { password: newPassword, mustChangePassword: false });
}

export async function deleteUser(db: DbClient, id: string): Promise<void> {
  const existing = await db.queryOne<UserRow>('SELECT * FROM users WHERE id = ?', [id]);
  if (!existing) throw new Error('User not found');
  if (existing.role === 'admin' && (await countAdmins(db)) <= 1) {
    throw new Error('Cannot delete the last active admin');
  }
  await db.run('DELETE FROM users WHERE id = ?', [id]);
}
