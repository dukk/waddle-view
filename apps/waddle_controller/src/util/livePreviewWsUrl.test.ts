import { describe, expect, it } from 'vitest';
import { buildLivePreviewWebSocketUrl } from '@/util/livePreviewWsUrl';
import type { SavedDisplay } from '@/storage/displays';

describe('buildLivePreviewWebSocketUrl', () => {
  it('includes ticket and display path', () => {
    const display: SavedDisplay = {
      id: 'd1',
      label: 'TV',
      baseUrl: 'https://display.test:8787',
    };
    const url = buildLivePreviewWebSocketUrl(display, 'abc123');
    expect(url).toContain('/bff/v1/proxy-ws/v1/display/live-preview/ws');
    expect(url).toContain('ticket=abc123');
    expect(url).toContain('display_id=d1');
    expect(url).toContain('display_url=');
  });
});
