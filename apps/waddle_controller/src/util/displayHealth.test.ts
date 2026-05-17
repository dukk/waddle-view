import { describe, expect, it, vi } from 'vitest';

import type { SavedDisplay } from '@/storage/displays';
import {
  fetchDisplayHealth,
  formatDisplayHostSummary,
  type DisplayHealthPayload,
} from '@/util/displayHealth';

const display: SavedDisplay = {
  id: 'd1',
  label: 'Kitchen',
  baseUrl: 'http://192.168.1.10:8787',
};

describe('fetchDisplayHealth', () => {
  it('returns online when health responds with status ok', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            status: 'ok',
            app: 'waddle_display',
            version: '1.0.0',
            platform_os: 'linux',
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
      ),
    );
    const result = await fetchDisplayHealth(display);
    expect(result.state).toBe('online');
    if (result.state === 'online') {
      expect(result.health.version).toBe('1.0.0');
    }
  });

  it('returns offline on proxy failure', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ error: 'Could not reach display' }), {
          status: 502,
          headers: { 'Content-Type': 'application/json' },
        }),
      ),
    );
    const result = await fetchDisplayHealth(display);
    expect(result.state).toBe('offline');
    if (result.state === 'offline') {
      expect(result.message).toContain('Could not reach');
    }
  });
});

describe('formatDisplayHostSummary', () => {
  it('joins version, schema, os, host, and uptime', () => {
    const health: DisplayHealthPayload = {
      status: 'ok',
      app: 'waddle_display',
      version: '1.0.0',
      build: '1',
      schema_version: 48,
      platform_os: 'linux',
      platform_os_version: 'Ubuntu 24.04',
      hostname: 'pi-tv',
      cpu_count: 4,
      uptime_seconds: 3661,
    };
    const summary = formatDisplayHostSummary(health);
    expect(summary).toContain('waddle_display 1.0.0+1');
    expect(summary).toContain('schema 48');
    expect(summary).toContain('linux (Ubuntu 24.04)');
    expect(summary).toContain('pi-tv');
    expect(summary).toContain('4 CPUs');
    expect(summary).toContain('up 1h 1m');
  });
});
