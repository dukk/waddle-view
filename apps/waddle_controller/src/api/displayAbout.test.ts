import { describe, it, expect, vi, afterEach } from 'vitest';
import { fetchDisplayAbout } from '@/api/displayAbout';

describe('fetchDisplayAbout', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  const display = {
    id: 'd1',
    label: 'Test',
    baseUrl: 'https://127.0.0.1:8787',
  };

  it('returns ok payload when proxy responds with about JSON', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            app: 'waddle_display',
            version: '1.0.0',
            build: '1',
            product_license: {
              id: 'ONC',
              name: 'ONC',
              url: 'https://example.com/LICENSE',
              summary: 'summary',
            },
            dependencies: [{ name: 'meta', version: '1.0.0', license: '' }],
            third_party_licenses: 'notices',
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
      ),
    );

    const result = await fetchDisplayAbout(display);
    expect(result.state).toBe('ok');
    if (result.state === 'ok') {
      expect(result.about.version).toBe('1.0.0');
      expect(result.about.dependencies).toHaveLength(1);
    }
  });

  it('returns unsupported when display responds 404', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('', { status: 404 })));

    const result = await fetchDisplayAbout(display);
    expect(result.state).toBe('unsupported');
  });
});
