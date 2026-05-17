import path from 'node:path';
import { defaultTlsDir, envFlag, resolveTls, type ResolvedTls } from '@waddle/node-tls';

export type AppConfig = {
  authEnabled: boolean;
  bindHost: string;
  port: number;
  dataDir: string;
  dbPath: string;
  sessionSecret: string;
  clientIdentifier: string | null;
  secureCookies: boolean;
  tls: ResolvedTls;
};

export function loadConfig(): AppConfig {
  const authEnabled = envFlag('WADDLE_CONTROLLER_AUTH_ENABLED', process.env, false);
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
  const tls = resolveTls({
    env: process.env,
    tlsEnv: 'WADDLE_CONTROLLER_TLS',
    certEnv: 'WADDLE_CONTROLLER_TLS_CERT',
    keyEnv: 'WADDLE_CONTROLLER_TLS_KEY',
    dirEnv: 'WADDLE_CONTROLLER_TLS_DIR',
    defaultCertDir: defaultTlsDir(dataDir),
    commonName: 'waddle-controller',
  });
  const secureCookiesExplicit = process.env.WADDLE_CONTROLLER_SECURE_COOKIES?.trim();
  const secureCookies =
    secureCookiesExplicit != null && secureCookiesExplicit !== ''
      ? envFlag('WADDLE_CONTROLLER_SECURE_COOKIES', process.env, false)
      : tls.enabled;

  const clientIdentifier = process.env.WADDLE_CONTROLLER_CLIENT_IDENTIFIER?.trim() || null;

  return {
    authEnabled,
    bindHost: process.env.WADDLE_CONTROLLER_BIND?.trim() || '127.0.0.1',
    port: Number(process.env.PORT || process.env.WADDLE_CONTROLLER_PORT || 5199),
    dataDir,
    dbPath: path.join(dataDir, 'controller.db'),
    sessionSecret: sessionSecret || 'dev-insecure-secret',
    clientIdentifier,
    secureCookies,
    tls,
  };
}
