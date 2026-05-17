import path from 'node:path';

export type AppConfig = {
  authEnabled: boolean;
  bindHost: string;
  port: number;
  dataDir: string;
  dbPath: string;
  sessionSecret: string;
  secureCookies: boolean;
};

function envFlag(name: string, defaultValue = false): boolean {
  const v = process.env[name]?.trim();
  if (!v) return defaultValue;
  return v === '1' || v.toLowerCase() === 'true' || v.toLowerCase() === 'yes';
}

export function loadConfig(): AppConfig {
  const authEnabled = envFlag('WADDLE_CONTROLLER_AUTH_ENABLED');
  const dataDir = process.env.WADDLE_CONTROLLER_DATA_DIR?.trim() || './data';
  let sessionSecret = process.env.WADDLE_CONTROLLER_SESSION_SECRET?.trim() ?? '';
  if (authEnabled && !sessionSecret) {
    const isProd = process.env.NODE_ENV === 'production';
    if (isProd) {
      throw new Error(
        'WADDLE_CONTROLLER_SESSION_SECRET is required when WADDLE_CONTROLLER_AUTH_ENABLED=1',
      );
    }
    sessionSecret = 'dev-only-insecure-session-secret';
    console.error(
      'WARN: WADDLE_CONTROLLER_AUTH_ENABLED=1 but WADDLE_CONTROLLER_SESSION_SECRET is unset; ' +
        'using a dev-only default. Set WADDLE_CONTROLLER_SESSION_SECRET before production.',
    );
  }
  return {
    authEnabled,
    bindHost: process.env.WADDLE_CONTROLLER_BIND?.trim() || '127.0.0.1',
    port: Number(process.env.PORT || process.env.WADDLE_CONTROLLER_PORT || 5199),
    dataDir,
    dbPath: path.join(dataDir, 'controller.db'),
    sessionSecret: sessionSecret || 'dev-insecure-secret',
    secureCookies: envFlag('WADDLE_CONTROLLER_SECURE_COOKIES'),
  };
}
