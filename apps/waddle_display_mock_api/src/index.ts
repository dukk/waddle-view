import path from 'node:path';
import { resolveTls } from '@waddle/node-tls';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { mockAuth, readExpectedKey } from './lib/auth.js';
import { resolveScenario } from './lib/scenario.js';
import type { Scenario } from './lib/scenario.js';
import { v1Router } from './routes/v1.js';
import { serveWithOptionalTls } from './tlsServe.js';

const app = new Hono<{ Variables: { scenario: Scenario } }>();

app.use(
  '*',
  cors({
    origin: '*',
    allowMethods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'X-Api-Key', 'Authorization', 'X-Mock-Scenario'],
    maxAge: 86400,
  }),
);

app.use('*', async (c, next) => {
  c.set('scenario', resolveScenario(c));
  await next();
});

app.use('*', mockAuth);

app.route('/v1', v1Router());

app.get('/', (c) =>
  c.json({
    service: 'waddle_display_mock_api',
    usage: {
      baseUrl: 'Use the same paths as waddle_display /v1/*',
      apiKey: process.env.MOCK_SKIP_AUTH === '1' ? 'optional (MOCK_SKIP_AUTH=1)' : readExpectedKey(),
      scenarios:
        'Add ?scenario=empty|error|unauthorized or header X-Mock-Scenario (mirrors query). default returns sample payloads.',
    },
  }),
);

const port = Number(process.env.PORT || 3000);
const bindHost = process.env.WADDLE_DISPLAY_HTTP_BIND_IP?.trim() || '0.0.0.0';
const dataDir = process.env.WADDLE_MOCK_DATA_DIR?.trim() || path.join(process.cwd(), 'data');
const tls = resolveTls({
  env: process.env,
  tlsEnv: 'WADDLE_DISPLAY_HTTP_TLS',
  certEnv: 'WADDLE_DISPLAY_HTTP_TLS_CERT',
  keyEnv: 'WADDLE_DISPLAY_HTTP_TLS_KEY',
  dirEnv: 'WADDLE_DISPLAY_HTTP_TLS_DIR',
  defaultCertDir: path.join(dataDir, 'tls'),
  commonName: 'waddle-display-mock',
});
const scheme = tls.enabled ? 'https' : 'http';
console.error(
  `waddle_display_mock_api listening on ${scheme}://${bindHost}:${port} (tls=${tls.enabled}, expected X-Api-Key: ${readExpectedKey()})`,
);
serveWithOptionalTls({
  fetch: app.fetch,
  hostname: bindHost,
  port,
  tls,
});
