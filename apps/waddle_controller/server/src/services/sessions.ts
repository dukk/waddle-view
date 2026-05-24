import { randomUUID } from 'node:crypto';
import type { AppConfig } from '../config.js';
import type { DbClient } from '../db/client.js';
import type { PublicUser } from '../types.js';
import { findUserById } from './users.js';

export const SESSION_COOKIE = 'waddle_controller_session';
const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

type SessionRow = {
  id: string;
  user_id: string;
  expires_at: string;
  created_at: string;
};

export async function createSession(db: DbClient, userId: string): Promise<string> {
  const id = randomUUID();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_MS).toISOString();
  await db.run(`INSERT INTO sessions (id, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)`, [
    id,
    userId,
    expiresAt,
    now.toISOString(),
  ]);
  return id;
}

export async function deleteSession(db: DbClient, sessionId: string): Promise<void> {
  await db.run('DELETE FROM sessions WHERE id = ?', [sessionId]);
}

export async function resolveSessionUser(
  db: DbClient,
  sessionId: string | undefined,
): Promise<PublicUser | null> {
  if (!sessionId) return null;
  const row = await db.queryOne<SessionRow>('SELECT * FROM sessions WHERE id = ?', [sessionId]);
  if (!row) return null;
  if (new Date(row.expires_at).getTime() <= Date.now()) {
    await deleteSession(db, sessionId);
    return null;
  }
  const user = await findUserById(db, row.user_id);
  if (!user || user.disabled) return null;
  return user;
}

export function sessionCookieOptions(config: AppConfig): {
  httpOnly: boolean;
  secure: boolean;
  sameSite: 'Lax';
  path: string;
  maxAge: number;
} {
  return {
    httpOnly: true,
    secure: config.secureCookies,
    sameSite: 'Lax',
    path: '/',
    maxAge: Math.floor(SESSION_TTL_MS / 1000),
  };
}
