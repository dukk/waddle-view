import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import {
  forwardDisplayProxy,
  upstreamPathFromProxyRequest,
} from '../services/displayProxy.js';

export function proxyRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.all('/proxy/*', async (c) => {
    const proxyPath = upstreamPathFromProxyRequest(new URL(c.req.url).pathname);
    return forwardDisplayProxy(
      c.get('config'),
      c.get('db'),
      c.get('user') ?? null,
      c.req.raw,
      proxyPath,
    );
  });

  return app;
}
