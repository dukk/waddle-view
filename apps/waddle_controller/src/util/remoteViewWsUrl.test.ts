import { describe, it, expect, vi, beforeEach } from 'vitest';
import { buildRemoteViewWebSocketUrl } from '@/util/remoteViewWsUrl';
import type { SavedDisplay } from '@/storage/displays';

vi.mock('@/api/client', () => ({
  sessionForDisplay: vi.fn(() => ({ apiKey: 'wd_test_key', role: 'admin', identifier: 'x' })),
}));

const display: SavedDisplay = {
  id: 'd_test',
  label: 'Test',
  baseUrl: 'https://display.local:8787',
};

describe('buildRemoteViewWebSocketUrl', () => {
  beforeEach(() => {
    vi.stubGlobal('location', {
      protocol: 'https:',
      host: 'controller.local:5173',
    });
  });

  it('builds wss proxy URL with ticket and display id', () => {
    const url = buildRemoteViewWebSocketUrl(display, 'ticket123');
    expect(url).toContain('wss://controller.local:5173/bff/v1/proxy-ws/v1/display/remote-view/ws');
    expect(url).toContain('ticket=ticket123');
    expect(url).toContain('display_id=d_test');
    expect(url).toContain('authorization=Bearer');
  });
});
