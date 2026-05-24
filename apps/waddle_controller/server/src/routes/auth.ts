import { Hono } from 'hono';
import { deleteCookie, setCookie } from 'hono/cookie';
import type { AppVariables } from '../middleware/context.js';
import { findUserByUsername, recordUserLogin } from '../services/users.js';
import { verifyPassword } from '../services/password.js';
import {
  createSession,
  deleteSession,
  SESSION_COOKIE,
  sessionCookieOptions,
} from '../services/sessions.js';
import { checkRateLimit } from '../lib/rateLimit.js';
import { requireAuth } from '../middleware/guards.js';
import { isEffectiveUserMode } from '../services/userMode.js';
import { changeUserPassword } from '../services/users.js';

function userPayload(user: {
  id: string;
  username: string;
  role: string;
  mustChangePassword: boolean;
}) {
  return {
    id: user.id,
    username: user.username,
    role: user.role,
    mustChangePassword: user.mustChangePassword,
  };
}

export function authRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.post('/auth/login', async (c) => {
    const config = c.get('config');
    const db = c.get('db');
    if (!(await isEffectiveUserMode(config, db))) {
      return c.json({ error: 'User mode is disabled', code: 'user_mode_disabled' }, 403);
    }
    const ip = c.req.header('x-forwarded-for')?.split(',')[0]?.trim() || 'local';
    if (!checkRateLimit(`login:${ip}`)) {
      return c.json({ error: 'Too many attempts', code: 'rate_limited' }, 429);
    }
    const body = (await c.req.json<{ username?: string; password?: string }>().catch(
      () => ({} as { username?: string; password?: string }),
    )) as { username?: string; password?: string };
    const username = body.username?.trim() ?? '';
    const password = body.password ?? '';
    if (!username || !password) {
      return c.json({ error: 'Username and password required', code: 'invalid_request' }, 400);
    }
    const record = await findUserByUsername(db, username);
    if (!record || record.disabled) {
      return c.json({ error: 'Invalid credentials', code: 'invalid_credentials' }, 401);
    }
    const ok = await verifyPassword(password, record.passwordHash);
    if (!ok) {
      return c.json({ error: 'Invalid credentials', code: 'invalid_credentials' }, 401);
    }
    await recordUserLogin(db, record.id);
    const sessionId = await createSession(db, record.id);
    setCookie(c, SESSION_COOKIE, sessionId, sessionCookieOptions(config));
    return c.json({ user: userPayload(record) });
  });

  app.post('/auth/logout', requireAuth, async (c) => {
    const sessionId = c.get('sessionId');
    if (sessionId) await deleteSession(c.get('db'), sessionId);
    deleteCookie(c, SESSION_COOKIE, { path: '/' });
    return c.json({ ok: true });
  });

  app.get('/auth/me', requireAuth, async (c) => {
    if (!(await isEffectiveUserMode(c.get('config'), c.get('db')))) {
      return c.json({ user: null });
    }
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized', code: 'unauthorized' }, 401);
    return c.json({ user: userPayload(user) });
  });

  app.post('/auth/change-password', requireAuth, async (c) => {
    const user = c.get('user');
    if (!user) {
      return c.json({ error: 'Unauthorized', code: 'unauthorized' }, 401);
    }
    const body = (await c.req.json<{ currentPassword?: string; newPassword?: string }>().catch(
      () => ({} as { currentPassword?: string; newPassword?: string }),
    )) as { currentPassword?: string; newPassword?: string };
    const currentPassword = body.currentPassword ?? '';
    const newPassword = body.newPassword ?? '';
    if (!currentPassword || !newPassword) {
      return c.json(
        { error: 'currentPassword and newPassword required', code: 'invalid_request' },
        400,
      );
    }
    try {
      const updated = await changeUserPassword(c.get('db'), user.id, currentPassword, newPassword);
      return c.json({ user: userPayload(updated) });
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Change password failed';
      const status = msg === 'User not found' ? 404 : 400;
      return c.json({ error: msg, code: 'change_password_failed' }, status);
    }
  });

  return app;
}
