import { describe, it, expect } from 'vitest';
import { hashPassword, validatePassword, verifyPassword } from './services/password.js';

describe('password service', () => {
  it('rejects short passwords', () => {
    expect(validatePassword('short')).toMatch(/at least/);
  });

  it('hashes and verifies', async () => {
    const hash = await hashPassword('passwordpassword');
    expect(await verifyPassword('passwordpassword', hash)).toBe(true);
    expect(await verifyPassword('wrongpassword1', hash)).toBe(false);
  });
});
