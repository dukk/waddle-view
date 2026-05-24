import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import type { ControllerRole } from '../types.js';
import { createUser, deleteUser, listUsers, updateUser } from '../services/users.js';
import { requireAdmin, requireAuth, requireUserManagement } from '../middleware/guards.js';

export function usersRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();
  const adminOnly = new Hono<{ Variables: AppVariables }>();
  adminOnly.use('*', requireAuth, requireAdmin, requireUserManagement);

  adminOnly.get('/', async (c) => c.json({ users: await listUsers(c.get('db')) }));

  adminOnly.post('/', async (c) => {
    const body = (await c.req.json<{
      username?: string;
      password?: string;
      role?: ControllerRole;
      mustChangePassword?: boolean;
    }>().catch(() => ({} as {
      username?: string;
      password?: string;
      role?: ControllerRole;
      mustChangePassword?: boolean;
    }))) as {
      username?: string;
      password?: string;
      role?: ControllerRole;
      mustChangePassword?: boolean;
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
      const user = await createUser(c.get('db'), {
        username,
        password,
        role,
        mustChangePassword: body.mustChangePassword,
      });
      return c.json({ user }, 201);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Create failed';
      return c.json({ error: msg, code: 'create_failed' }, 400);
    }
  });

  adminOnly.patch('/:id', async (c) => {
    const id = c.req.param('id');
    const body = (await c.req.json<{
      role?: ControllerRole;
      disabled?: boolean;
      password?: string;
      mustChangePassword?: boolean;
    }>().catch(() => ({} as {
      role?: ControllerRole;
      disabled?: boolean;
      password?: string;
      mustChangePassword?: boolean;
    }))) as {
      role?: ControllerRole;
      disabled?: boolean;
      password?: string;
      mustChangePassword?: boolean;
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

  adminOnly.delete('/:id', async (c) => {
    try {
      await deleteUser(c.get('db'), c.req.param('id'));
      return c.json({ ok: true });
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Delete failed';
      const status = msg === 'User not found' ? 404 : 400;
      return c.json({ error: msg, code: 'delete_failed' }, status);
    }
  });

  app.route('/users', adminOnly);
  return app;
}
