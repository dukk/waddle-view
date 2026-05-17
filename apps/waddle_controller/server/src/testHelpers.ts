import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import type { AppConfig } from './config.js';
import { openTestDatabase } from './db/database.js';
import { createApp } from './app.js';
import { resetRateLimits } from './lib/rateLimit.js';

export function testConfig(dir: string, overrides: Partial<AppConfig> = {}): AppConfig {
  const dataDir = path.join(dir, 'data');
  return {
    authEnabled: true,
    bindHost: '127.0.0.1',
    port: 5199,
    dataDir,
    dbPath: path.join(dataDir, 'waddle_controller.db'),
    sessionSecret: 'test-secret',
    clientIdentifier: null,
    secureCookies: false,
    tls: { enabled: false, paths: null, pem: null },
    ...overrides,
  };
}

export function createTestApp(overrides: Partial<AppConfig> = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'waddle-controller-'));
  const config = testConfig(dir, overrides);
  const db = openTestDatabase(dir);
  resetRateLimits();
  const app = createApp(config, db);
  return {
    app,
    db,
    config,
    dir,
    cleanup: () => {
      db.close();
      fs.rmSync(dir, { recursive: true, force: true });
    },
  };
}

export function sessionCookieHeader(setCookie: string | undefined): string | undefined {
  if (!setCookie) return undefined;
  const match = /waddle_controller_session=([^;]+)/.exec(setCookie);
  return match ? `waddle_controller_session=${match[1]}` : undefined;
}
