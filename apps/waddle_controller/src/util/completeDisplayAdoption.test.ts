import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { completeDisplayAdoption } from '@/util/completeDisplayAdoption';
import { loadDisplays } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';

describe('completeDisplayAdoption', () => {
  beforeEach(() => {
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
});
