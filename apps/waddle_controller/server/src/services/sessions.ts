import { randomUUID } from 'node:crypto';
import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
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

export function createSession(db: AppDatabase, userId: string): string {
  const id = randomUUID();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_MS).toISOString();
  db.prepare(
    `INSERT INTO sessions (id, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)`,
  ).run(id, userId, expiresAt, now.toISOString());
  return id;
}

export function deleteSession(db: AppDatabase, sessionId: string): void {
  db.prepare('DELETE FROM sessions WHERE id = ?').run(sessionId);
}

export function resolveSessionUser(db: AppDatabase, sessionId: string | undefined): PublicUser | null {
  if (!sessionId) return null;
  const row = db.prepare('SELECT * FROM sessions WHERE id = ?').get(sessionId) as SessionRow | undefined;
  if (!row) return null;
  if (new Date(row.expires_at).getTime() <= Date.now()) {
    deleteSession(db, sessionId);
    return null;
  }
  const user = findUserById(db, row.user_id);
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
