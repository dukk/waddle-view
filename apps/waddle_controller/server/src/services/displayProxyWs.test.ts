import { describe, it, expect } from 'vitest';
import type { IncomingMessage } from 'node:http';
import {
  displayWebSocketUrl,
  headersFromWebSocketUpgrade,
  upstreamPathFromProxyWsRequest,
} from './displayProxyWs.js';
import { DISPLAY_ID_HEADER } from '../constants/proxyHeaders.js';

describe('displayProxyWs', () => {
  it('maps proxy-ws pathname to display path', () => {
    expect(
      upstreamPathFromProxyWsRequest('/bff/v1/proxy-ws/v1/display/live-preview/ws'),
    ).toBe('/v1/display/live-preview/ws');
  });

  it('builds wss upstream URL from https display base', () => {
    expect(
      displayWebSocketUrl(
        'https://127.0.0.1:8787',
        '/v1/display/live-preview/ws',
        'ticket=abc',
      ),
    ).toBe('wss://127.0.0.1:8787/v1/display/live-preview/ws?ticket=abc');
  });

  it('reads display id and authorization from query', () => {
    const req = {
      url: '/bff/v1/proxy-ws/v1/display/live-preview/ws?display_id=d1&authorization=Bearer%20tok',
      headers: {},
    } as IncomingMessage;
    const headers = headersFromWebSocketUpgrade(req);
    expect(headers.get(DISPLAY_ID_HEADER)).toBe('d1');
    expect(headers.get('Authorization')).toBe('Bearer tok');
  });
});
