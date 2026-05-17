import { describe, expect, it } from 'vitest';
import { decryptDisplayApiKey, encryptDisplayApiKey } from './displaySecrets.js';

describe('displaySecrets', () => {
  it('round-trips api keys', () => {
    const secret = 'test-session-secret';
    const apiKey = 'waddle-display-api-key-abc123';
    const enc = encryptDisplayApiKey(secret, apiKey);
    expect(enc.ciphertext).not.toContain(apiKey);
    const plain = decryptDisplayApiKey(secret, enc.ciphertext, enc.iv);
    expect(plain).toBe(apiKey);
  });

  it('rejects tampered ciphertext', () => {
    const enc = encryptDisplayApiKey('secret', 'key');
    expect(() =>
      decryptDisplayApiKey('secret', enc.ciphertext.slice(0, -2) + 'xx', enc.iv),
    ).toThrow();
  });
});
