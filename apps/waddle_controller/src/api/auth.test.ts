import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchMe, loginDisplay, logoutDisplay, registerViewerDisplay } from './auth';

describe('auth api', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('loginDisplay normalizes base URL and maps session fields', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            session_token: 'tok',
            expires_at_ms: 99,
            user: {
              id: 'u1',
              username: 'op',
              display_name: 'Op',
              role: 'operator',
              is_bootstrap: false,
              disabled: false,
            },
            permissions: ['telemetry.read'],
            warnings: ['w1'],
          }),
          { status: 200 },
        ),
      ),
    );

    const result = await loginDisplay('https://kiosk.test/', 'op', 'pw');
    expect(result.baseUrl).toBe('https://kiosk.test');
    expect(result.token).toBe('tok');
    expect(result.warnings).toEqual(['w1']);
    expect(fetch).toHaveBeenCalledWith(
      'https://kiosk.test/v1/auth/login',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('loginDisplay throws on failure', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(new Response('bad creds', { status: 401 })),
    );
    await expect(loginDisplay('https://kiosk.test', 'x', 'y')).rejects.toThrow('bad creds');
  });

  it('registerViewerDisplay posts registration secret', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            session_token: 'vtok',
            expires_at_ms: 1,
            user: {
              id: 'v1',
              username: 'viewer1',
              display_name: 'Viewer',
              role: 'viewer',
              is_bootstrap: false,
              disabled: false,
            },
            permissions: ['telemetry.read'],
          }),
          { status: 200 },
        ),
      ),
    );

    const result = await registerViewerDisplay('https://kiosk.test', {
      username: 'viewer1',
      password: 'pw',
      registrationSecret: 'sekrit',
    });
    expect(result.token).toBe('vtok');
    const body = JSON.parse((fetch as ReturnType<typeof vi.fn>).mock.calls[0]![1]!.body as string);
    expect(body.registration_secret).toBe('sekrit');
  });

  it('fetchMe maps user payload', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            user: {
              id: 'u1',
              username: 'op',
              display_name: 'Op',
              role: 'operator',
              is_bootstrap: false,
              disabled: false,
            },
            permissions: ['telemetry.read'],
            warnings: [],
          }),
          { status: 200 },
        ),
      ),
    );

    const me = await fetchMe('https://kiosk.test', 'tok');
    expect(me.user.username).toBe('op');
    expect(me.permissions).toEqual(['telemetry.read']);
    expect(me.expiresAtMs).toBeGreaterThan(Date.now());
  });

  it('logoutDisplay swallows network errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('offline')));
    await expect(logoutDisplay('https://kiosk.test', 'tok')).resolves.toBeUndefined();
  });
});
