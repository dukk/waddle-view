import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import selfsigned from 'selfsigned';

export type SelfSignedPaths = {
  certPath: string;
  keyPath: string;
};

/** Creates or reuses a self-signed cert pair under [dir]. */
export function ensureSelfSignedCert(dir: string, commonName: string): SelfSignedPaths {
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const keyPath = path.join(dir, 'key.pem');
  const certPath = path.join(dir, 'cert.pem');
  if (!existsSync(keyPath) || !existsSync(certPath)) {
    const generated = selfsigned.generate(
      [{ name: 'commonName', value: commonName }],
      { days: 825, keySize: 2048, algorithm: 'sha256' },
    );
    writeFileSync(keyPath, generated.private, { mode: 0o600 });
    writeFileSync(certPath, generated.cert, { mode: 0o644 });
  }
  return { certPath, keyPath };
}

export function readTlsPemFiles(paths: SelfSignedPaths): { key: Buffer; cert: Buffer } {
  return {
    key: readFileSync(paths.keyPath),
    cert: readFileSync(paths.certPath),
  };
}
