import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import { requireAuth, requireAuthEnabled } from '../middleware/guards.js';
import type { PublicUser } from '../types.js';
import {
  deleteUserDisplay,
  listUserDisplays,
  setActiveUserDisplay,
  upsertUserDisplay,
} from '../services/userDisplays.js';

function sessionUser(c: { get: (key: 'user') => PublicUser | null }): PublicUser | Response {
  const user = c.get('user');
  if (!user) {
    return Response.json({ error: 'Unauthorized', code: 'unauthorized' }, { status: 401 });
  }
  return user;
}

export function userDisplaysRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();
  const authed = new Hono<{ Variables: AppVariables }>();
  authed.use('*', requireAuthEnabled, requireAuth);

  authed.get('/', (c) => {
    const user = sessionUser(c);
    if (user instanceof Response) return user;
    return c.json({ displays: listUserDisplays(c.get('db'), user.id) });
  });

  authed.put('/', async (c) => {
    const user = sessionUser(c);
    if (user instanceof Response) return user;
    const body = (await c.req.json<{
      displayId?: string;
      label?: string;
      baseUrl?: string;
      clientIdentifier?: string;
      adoptedRole?: string;
      apiKey?: string;
      permissions?: string[];
    }>().catch(() => ({}))) as {
      displayId?: string;
      label?: string;
      baseUrl?: string;
      clientIdentifier?: string;
      adoptedRole?: string;
      apiKey?: string;
      permissions?: string[];
    };
    const displayId = body.displayId?.trim() ?? '';
    const baseUrl = body.baseUrl?.trim() ?? '';
    const clientIdentifier = body.clientIdentifier?.trim() ?? '';
    const adoptedRole = body.adoptedRole?.trim() ?? '';
    const apiKey = body.apiKey?.trim() ?? '';
    if (!displayId || !baseUrl || !clientIdentifier || !adoptedRole || !apiKey) {
      return c.json({ error: 'Missing required fields', code: 'invalid_request' }, 400);
    }
    try {
      void new URL(baseUrl);
    } catch {
      return c.json({ error: 'Invalid base URL', code: 'invalid_request' }, 400);
    }
    const display = upsertUserDisplay(c.get('db'), c.get('config').sessionSecret, user.id, {
      displayId,
      label: body.label?.trim() ?? baseUrl,
      baseUrl,
      clientIdentifier,
      adoptedRole,
      apiKey,
      permissions: Array.isArray(body.permissions) ? body.permissions : [],
    });
    return c.json({ display });
  });

  authed.patch('/active', async (c) => {
    const user = sessionUser(c);
    if (user instanceof Response) return user;
    const body = (await c.req.json<{ displayId?: string }>().catch(() => ({}))) as {
      displayId?: string;
    };
    const displayId = body.displayId?.trim() ?? '';
    if (!displayId) {
      return c.json({ error: 'displayId required', code: 'invalid_request' }, 400);
    }
    const display = setActiveUserDisplay(c.get('db'), user.id, displayId);
    if (!display) {
      return c.json({ error: 'Display not found', code: 'not_found' }, 404);
    }
    return c.json({ display });
  });

  authed.delete('/:displayId', (c) => {
    const user = sessionUser(c);
    if (user instanceof Response) return user;
    const displayId = c.req.param('displayId');
    const ok = deleteUserDisplay(c.get('db'), user.id, displayId);
    if (!ok) {
      return c.json({ error: 'Display not found', code: 'not_found' }, 404);
    }
    return c.json({ ok: true });
  });

  app.route('/user-displays', authed);
  return app;
}
