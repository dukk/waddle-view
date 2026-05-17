import { mkdtempSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it, afterEach } from 'vitest';
import { resolveTls } from '@waddle/node-tls';

describe('@waddle/node-tls resolveTls', () => {
  const dirs: string[] = [];

  afterEach(() => {
    for (const d of dirs) {
      rmSync(d, { recursive: true, force: true });
    }
    dirs.length = 0;
  });

  it('defaults TLS on and generates certs', () => {
    const dir = mkdtempSync(path.join(os.tmpdir(), 'waddle-tls-'));
    dirs.push(dir);
    const tls = resolveTls({
      env: {},
      tlsEnv: 'WADDLE_HTTP_TLS',
      certEnv: 'WADDLE_HTTP_TLS_CERT',
      keyEnv: 'WADDLE_HTTP_TLS_KEY',
      dirEnv: 'WADDLE_HTTP_TLS_DIR',
      defaultCertDir: dir,
      commonName: 'localhost',
    });
    expect(tls.enabled).toBe(true);
    expect(tls.pem?.key.length).toBeGreaterThan(0);
    expect(tls.pem?.cert.length).toBeGreaterThan(0);
  });

  it('honors WADDLE_HTTP_TLS=0', () => {
    const tls = resolveTls({
      env: { WADDLE_HTTP_TLS: '0' },
      tlsEnv: 'WADDLE_HTTP_TLS',
      certEnv: 'WADDLE_HTTP_TLS_CERT',
      keyEnv: 'WADDLE_HTTP_TLS_KEY',
      dirEnv: 'WADDLE_HTTP_TLS_DIR',
      defaultCertDir: '/tmp/unused',
      commonName: 'localhost',
    });
    expect(tls.enabled).toBe(false);
  });
});
