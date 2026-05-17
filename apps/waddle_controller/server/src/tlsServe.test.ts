import { describe, expect, it } from 'vitest';
import { serveWithOptionalTls } from './tlsServe.js';

describe('serveWithOptionalTls', () => {
  it('exports a function', () => {
    expect(typeof serveWithOptionalTls).toBe('function');
  });
});
