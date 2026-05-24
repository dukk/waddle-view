import path from 'node:path';
import { defaultTlsDir, envFlag, resolveTls, type ResolvedTls } from '@waddle/node-tls';
import { DEFAULT_PROXY_UPSTREAM_TIMEOUT_MS } from './services/insecureFetch.js';

export type AppConfig = {
  authEnabled: boolean;
  bindHost: string;
  port: number;
  dataDir: string;
  dbPath: string;
  databaseUrl: string | null;
  sessionSecret: string;
  clientIdentifier: string | null;
  secureCookies: boolean;
  tls: ResolvedTls;
  /** Max wait for a proxied display HTTP response (socket inactivity). */
  proxyUpstreamTimeoutMs: number;
};

function parseProxyUpstreamTimeoutMs(env: NodeJS.ProcessEnv): number {
  const raw = env.WADDLE_CONTROLLER_PROXY_UPSTREAM_TIMEOUT_MS?.trim();
  if (!raw) return DEFAULT_PROXY_UPSTREAM_TIMEOUT_MS;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 1_000) {
    throw new Error(
      'WADDLE_CONTROLLER_PROXY_UPSTREAM_TIMEOUT_MS must be a number >= 1000',
    );
  }
  return Math.floor(n);
}

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
    dbPath: path.join(dataDir, 'waddle_controller.db'),
    databaseUrl: process.env.WADDLE_CONTROLLER_DATABASE_URL?.trim() || null,
    sessionSecret: sessionSecret || 'dev-insecure-secret',
    clientIdentifier,
    secureCookies,
    tls,
    proxyUpstreamTimeoutMs: parseProxyUpstreamTimeoutMs(process.env),
  };
}
