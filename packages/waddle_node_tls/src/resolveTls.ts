import path from 'node:path';
import { envFlag } from './envFlag.js';
import { ensureSelfSignedCert, readTlsPemFiles, type SelfSignedPaths } from './selfSigned.js';

export type ResolvedTls = {
  enabled: boolean;
  paths: SelfSignedPaths | null;
  pem: { key: Buffer; cert: Buffer } | null;
};

export type ResolveTlsOptions = {
  env: NodeJS.ProcessEnv;
  /** Env var toggling TLS (default on when unset). */
  tlsEnv: string;
  certEnv: string;
  keyEnv: string;
  dirEnv: string;
  defaultCertDir: string;
  commonName: string;
  /** Default true — pass false to default TLS off. */
  defaultEnabled?: boolean;
};

export function resolveTls(options: ResolveTlsOptions): ResolvedTls {
  const enabled = envFlag(options.tlsEnv, options.env, options.defaultEnabled ?? true);
  if (!enabled) {
    return { enabled: false, paths: null, pem: null };
  }

  const certOverride = options.env[options.certEnv]?.trim();
  const keyOverride = options.env[options.keyEnv]?.trim();
  const dir =
    options.env[options.dirEnv]?.trim() ||
    options.defaultCertDir;

  let paths: SelfSignedPaths;
  if (certOverride && keyOverride) {
    paths = { certPath: certOverride, keyPath: keyOverride };
  } else {
    paths = ensureSelfSignedCert(dir, options.commonName);
  }

  return {
    enabled: true,
    paths,
    pem: readTlsPemFiles(paths),
  };
}

export function defaultTlsDir(dataDir: string): string {
  return path.join(dataDir, 'tls');
}
