import { describe, expect, it } from 'vitest';
import { DISPLAY_ID_HEADER, DISPLAY_URL_HEADER } from '@/constants/proxyHeaders';
import { displayProxyHeaders, proxyUrlForPath } from './displayProxy';
import type { SavedDisplay } from '@/storage/displays';

const display: SavedDisplay = {
  id: 'd_test',
  label: 'Test',
  baseUrl: 'https://display.example:8787',
};

describe('displayProxy', () => {
  it('builds proxy URL from display path', () => {
    expect(proxyUrlForPath('/v1/screens')).toBe('/bff/v1/proxy/v1/screens');
    expect(proxyUrlForPath('v1/adoption/request')).toBe('/bff/v1/proxy/v1/adoption/request');
  });

  it('sets display url and id headers', () => {
    const headers = displayProxyHeaders({ display });
    expect(headers.get(DISPLAY_URL_HEADER)).toBe('https://display.example:8787');
    expect(headers.get(DISPLAY_ID_HEADER)).toBe('d_test');
  });

  it('requires url when requireUrl is set', () => {
    expect(() => displayProxyHeaders({ requireUrl: true })).toThrow(/base URL/i);
  });
});
