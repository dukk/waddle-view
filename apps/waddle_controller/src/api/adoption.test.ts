import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  adoptionJsonHeaders,
  confirmAdoption,
  expectedControllerOrigin,
  grantAdoption,
  requestAdoption,
  sessionFromAdoption,
} from './adoption';

describe('adoptionJsonHeaders', () => {
  it('sets Content-Type only; browser sends Origin and Referer', () => {
    expect(adoptionJsonHeaders()).toEqual({ 'Content-Type': 'application/json' });
    if (typeof window !== 'undefined' && window.location?.origin) {
      expect(expectedControllerOrigin()).toBe(window.location.origin);
    }
  });
});

describe('adoption API', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('requestAdoption posts identifier and role', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          expires_at_ms: 1,
          identifier: 'ctrl-1',
          role: 'operator',
        }),
        { status: 200 },
      ),
    );
    vi.stubGlobal('fetch', fetchMock);

    const result = await requestAdoption('https://kiosk.test/', {
      identifier: 'ctrl-1',
      role: 'operator',
    });

    expect(result.identifier).toBe('ctrl-1');
    expect(result).not.toHaveProperty('challenge_code');
    expect(fetchMock).toHaveBeenCalledWith(
      'https://kiosk.test/v1/adoption/request',
      expect.objectContaining({
        method: 'POST',
        referrerPolicy: 'origin',
      }),
    );
    const init = fetchMock.mock.calls[0]![1] as RequestInit;
    expect(init.headers).toMatchObject(
      expect.objectContaining({ 'Content-Type': 'application/json' }),
    );
    expect(JSON.parse(String(init.body))).toEqual({
      identifier: 'ctrl-1',
      role: 'operator',
    });
  });

  it('confirmAdoption posts challenge code', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            api_key: 'wk_test',
            identifier: 'ctrl-1',
            role: 'operator',
            permissions: ['telemetry.read'],
          }),
          { status: 200 },
        ),
      ),
    );

    const result = await confirmAdoption('https://kiosk.test', {
      identifier: 'ctrl-1',
      challenge_code: 'ABCD1234',
    });

    expect(result.api_key).toBe('wk_test');
    expect(result.permissions).toContain('telemetry.read');
  });

  it('grantAdoption sends admin bearer', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          api_key: 'wk_admin_grant',
          identifier: 'other',
          role: 'viewer',
          permissions: ['telemetry.read'],
        }),
        { status: 200 },
      ),
    );
    vi.stubGlobal('fetch', fetchMock);

    await grantAdoption('https://kiosk.test', 'admin-key', {
      identifier: 'other',
      role: 'viewer',
    });

    const init = fetchMock.mock.calls[0]![1] as RequestInit;
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer admin-key');
  });

  it('throws on HTTP errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('denied', { status: 403 })));
    await expect(
      requestAdoption('https://kiosk.test', { identifier: 'x', role: 'viewer' }),
    ).rejects.toThrow('denied');
  });

  it('sessionFromAdoption builds DisplaySession', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-16T12:00:00Z'));
    const session = sessionFromAdoption('https://kiosk.test/', {
      api_key: 'wk_x',
      identifier: 'ctrl-1',
      role: 'operator',
      permissions: ['telemetry.read'],
    });
    expect(session.apiKey).toBe('wk_x');
    expect(session.identifier).toBe('ctrl-1');
    expect(session.role).toBe('operator');
    expect(session.expiresAtMs).toBeGreaterThan(Date.now());
    vi.useRealTimers();
  });
});
