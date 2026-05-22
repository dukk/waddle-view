import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import { loadAboutManifest } from '../services/aboutManifest.js';
import type { AboutResponse } from '../types.js';

export function aboutRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.get('/about', (c) => {
    const manifest = loadAboutManifest();
    const body: AboutResponse = {
      app: manifest.app,
      version: manifest.version,
      build: manifest.build,
      productLicense: manifest.productLicense,
      dependencies: manifest.dependencies,
      thirdPartyNotices: manifest.thirdPartyNotices,
    };
    return c.json(body);
  });

  return app;
}
