import { describe, expect, it } from 'vitest';
import { formatListenAddressInUseError, serveWithOptionalTls } from './tlsServe.js';

describe('serveWithOptionalTls', () => {
  it('exports a function', () => {
    expect(typeof serveWithOptionalTls).toBe('function');
  });
});

describe('formatListenAddressInUseError', () => {
  it('mentions port, host, and remediation', () => {
    const msg = formatListenAddressInUseError('127.0.0.1', 5199);
    expect(msg).toContain('5199');
    expect(msg).toContain('127.0.0.1');
    expect(msg).toContain('EADDRINUSE');
    expect(msg).toContain('npm run dev');
    expect(msg).toContain('WADDLE_CONTROLLER_PORT');
  });
});
