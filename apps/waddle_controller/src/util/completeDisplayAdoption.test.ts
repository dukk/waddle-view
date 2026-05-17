import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { completeDisplayAdoption } from '@/util/completeDisplayAdoption';
import { loadDisplays } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';

describe('completeDisplayAdoption', () => {
  beforeEach(() => {
    localStorage.clear();
    localStorage.clear();
    sessionStorage.clear();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('confirms adoption then persists display and session', async () => {
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

    const { display, session } = await completeDisplayAdoption({
      baseUrl: 'https://kiosk.test',
      label: 'Lab',
      identifier: 'ctrl-1',
      challengeCode: 'ABCD1234',
    });

    expect(display.label).toBe('Lab');
    expect(session.apiKey).toBe('wk_test');
    expect(loadDisplays()).toHaveLength(1);
    expect(loadSession(display.id)?.apiKey).toBe('wk_test');
  });

  it('second adoption on same base URL creates a separate display row', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            api_key: 'wk_admin',
            identifier: 'wc-host',
            role: 'admin',
            permissions: ['users.manage'],
          }),
          { status: 200 },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            api_key: 'wk_operator',
            identifier: 'wc-host-operator',
            role: 'operator',
            permissions: ['telemetry.read'],
          }),
          { status: 200 },
        ),
      );
    vi.stubGlobal('fetch', fetchMock);

    const first = await completeDisplayAdoption({
      baseUrl: 'https://kiosk.test',
      identifier: 'wc-host',
      challengeCode: 'AAAAAAAA',
    });
    const second = await completeDisplayAdoption({
      baseUrl: 'https://kiosk.test',
      identifier: 'wc-host-operator',
      challengeCode: 'BBBBBBBB',
    });

    const rows = loadDisplays();
    expect(rows).toHaveLength(2);
    expect(loadSession(first.display.id)?.role).toBe('admin');
    expect(loadSession(second.display.id)?.role).toBe('operator');
    expect(loadSession(first.display.id)?.apiKey).toBe('wk_admin');
    expect(loadSession(second.display.id)?.apiKey).toBe('wk_operator');
  });
});
