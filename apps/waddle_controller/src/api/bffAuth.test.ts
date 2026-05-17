import { afterEach, describe, expect, it, vi } from 'vitest';
import { bffLogin, fetchBffStatus } from '@/api/bffAuth';

describe('bffAuth', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('fetchBffStatus calls status endpoint', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          authEnabled: true,
          userManagementEnabled: false,
          needsBootstrap: false,
        }),
      }),
    );
    const status = await fetchBffStatus();
    expect(status.authEnabled).toBe(true);
  });

  it('bffLogin posts credentials', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ user: { id: '1', username: 'admin', role: 'admin' } }),
      }),
    );
    const res = await bffLogin('admin', 'passwordpassword');
    expect(res.user.username).toBe('admin');
    const [, init] = (fetch as ReturnType<typeof vi.fn>).mock.calls[0] as [string, RequestInit];
    expect(init.method).toBe('POST');
    expect(init.body).toContain('admin');
  });
});
