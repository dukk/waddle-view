import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { loadConfig } from './config.js';

describe('loadConfig', () => {
  const env = { ...process.env };

  beforeEach(() => {
    process.env = { ...env };
  });

  afterEach(() => {
    process.env = env;
  });

  it('defaults auth to disabled', () => {
    delete process.env.WADDLE_CONTROLLER_AUTH_ENABLED;
    const cfg = loadConfig();
    expect(cfg.authEnabled).toBe(false);
  });

  it('requires session secret when auth enabled in production', () => {
    process.env.NODE_ENV = 'production';
    process.env.WADDLE_CONTROLLER_AUTH_ENABLED = '1';
    delete process.env.WADDLE_CONTROLLER_SESSION_SECRET;
    expect(() => loadConfig()).toThrow(/SESSION_SECRET/);
  });

  it('uses dev fallback secret when auth enabled without secret in dev', () => {
    delete process.env.NODE_ENV;
    process.env.WADDLE_CONTROLLER_AUTH_ENABLED = '1';
    delete process.env.WADDLE_CONTROLLER_SESSION_SECRET;
    const cfg = loadConfig();
    expect(cfg.sessionSecret).toContain('dev-only');
  });
});
