import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { AppConfig } from './config.js';
import type { AppDatabase } from './db/database.js';
import { createAppContext, type AppVariables } from './middleware/context.js';
import { bootstrapGuard } from './middleware/guards.js';
import { statusRoutes } from './routes/status.js';
import { authRoutes } from './routes/auth.js';
import { bootstrapRoutes } from './routes/bootstrap.js';
import { settingsRoutes } from './routes/settings.js';
import { usersRoutes } from './routes/users.js';

export function createApp(config: AppConfig, db: AppDatabase) {
  const app = new Hono<{ Variables: AppVariables }>();

  app.use(
    '*',
    cors({
      origin: (origin) => origin ?? '*',
      credentials: true,
      allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowHeaders: ['Content-Type'],
    }),
  );

  app.use('*', createAppContext(config, db));
  app.use('/bff/v1/*', bootstrapGuard);

  const v1 = new Hono<{ Variables: AppVariables }>();
  v1.route('/', statusRoutes());
  v1.route('/', authRoutes());
  v1.route('/', bootstrapRoutes());
  v1.route('/', settingsRoutes());
  v1.route('/', usersRoutes());

  app.route('/bff/v1', v1);

  app.get('/bff/health', (c) => c.json({ ok: true }));

  return app;
}
