import { createMiddleware } from 'hono/factory';
import type { AppConfig } from '../config.js';
import type { AppDatabase } from '../db/database.js';
import type { PublicUser } from '../types.js';
import { resolveSessionUser, SESSION_COOKIE } from '../services/sessions.js';
import { getCookie } from 'hono/cookie';

export type AppVariables = {
  config: AppConfig;
  db: AppDatabase;
  user: PublicUser | null;
  sessionId: string | null;
};

export function createAppContext(config: AppConfig, db: AppDatabase) {
  return createMiddleware<{ Variables: AppVariables }>(async (c, next) => {
    c.set('config', config);
    c.set('db', db);
    const sessionId = getCookie(c, SESSION_COOKIE) ?? null;
    c.set('sessionId', sessionId);
    c.set('user', resolveSessionUser(db, sessionId ?? undefined));
    await next();
  });
}
