import { afterEach, describe, expect, it, vi } from 'vitest';
import { createBffUser, listBffUsers } from '@/api/bffUsers';

describe('bffUsers', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('listBffUsers fetches users', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ users: [] }),
      }),
    );
    const res = await listBffUsers();
    expect(res.users).toEqual([]);
  });

  it('createBffUser posts payload', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          user: {
            id: '1',
            username: 'op',
            role: 'operator',
            disabled: false,
            createdAt: '',
            updatedAt: '',
          },
        }),
      }),
    );
    const res = await createBffUser({
      username: 'op',
      password: 'passwordpassword',
      role: 'operator',
    });
    expect(res.user.username).toBe('op');
  });
});
