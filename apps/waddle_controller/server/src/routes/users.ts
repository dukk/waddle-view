import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import type { ControllerRole } from '../types.js';
import { createUser, deleteUser, listUsers, updateUser } from '../services/users.js';
import { requireAdmin, requireAuth, requireUserManagement } from '../middleware/guards.js';

export function usersRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.use('*', requireAuth, requireAdmin, requireUserManagement);

  app.get('/users', (c) => c.json({ users: listUsers(c.get('db')) }));

  app.post('/users', async (c) => {
    const body = (await c.req.json<{
      username?: string;
      password?: string;
      role?: ControllerRole;
    }>().catch(() => ({} as { username?: string; password?: string; role?: ControllerRole }))) as {
      username?: string;
      password?: string;
      role?: ControllerRole;
    };
    const username = body.username?.trim() ?? '';
    const password = body.password ?? '';
    const role = body.role ?? 'operator';
    if (!username || !password) {
      return c.json({ error: 'Username and password required', code: 'invalid_request' }, 400);
    }
    if (role !== 'admin' && role !== 'operator') {
      return c.json({ error: 'Invalid role', code: 'invalid_request' }, 400);
    }
    try {
      const user = await createUser(c.get('db'), { username, password, role });
      return c.json({ user }, 201);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Create failed';
      return c.json({ error: msg, code: 'create_failed' }, 400);
    }
  });

  app.patch('/users/:id', async (c) => {
    const id = c.req.param('id');
    const body = (await c.req.json<{
      role?: ControllerRole;
      disabled?: boolean;
      password?: string;
    }>().catch(() => ({} as { role?: ControllerRole; disabled?: boolean; password?: string }))) as {
      role?: ControllerRole;
      disabled?: boolean;
      password?: string;
    };
    if (body.role !== undefined && body.role !== 'admin' && body.role !== 'operator') {
      return c.json({ error: 'Invalid role', code: 'invalid_request' }, 400);
    }
    try {
      const user = await updateUser(c.get('db'), id, body);
      return c.json({ user });
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Update failed';
      const status = msg === 'User not found' ? 404 : 400;
      return c.json({ error: msg, code: 'update_failed' }, status);
    }
  });

  app.delete('/users/:id', (c) => {
    try {
      deleteUser(c.get('db'), c.req.param('id'));
      return c.json({ ok: true });
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Delete failed';
      const status = msg === 'User not found' ? 404 : 400;
      return c.json({ error: msg, code: 'delete_failed' }, status);
    }
  });

  return app;
}
