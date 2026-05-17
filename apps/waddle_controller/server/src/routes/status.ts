import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import { isUserManagementEnabled } from '../services/settings.js';
import { needsBootstrap } from '../services/bootstrap.js';
import type { StatusResponse } from '../types.js';

export function statusRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.get('/status', (c) => {
    const config = c.get('config');
    const user = c.get('user');
    const body: StatusResponse = {
      authEnabled: config.authEnabled,
      userManagementEnabled: isUserManagementEnabled(c.get('db')),
      needsBootstrap: needsBootstrap(c.get('db'), config.authEnabled),
    };
    if (user) {
      body.user = { id: user.id, username: user.username, role: user.role };
    }
    return c.json(body);
  });

  return app;
}
