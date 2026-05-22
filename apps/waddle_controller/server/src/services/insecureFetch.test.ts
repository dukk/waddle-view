import { createServer } from 'node:http';
import { describe, expect, it, vi } from 'vitest';
import { DisplayUpstreamError, insecureNodeFetch } from './insecureFetch.js';

describe('insecureNodeFetch', () => {
  it('fetches plaintext HTTP responses', async () => {
    const server = createServer((_req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('hello-display');
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
    const addr = server.address();
    if (!addr || typeof addr === 'string') throw new Error('no address');
    const url = `http://127.0.0.1:${addr.port}/v1/ping`;

    const res = await insecureNodeFetch(url, {
      method: 'GET',
      headers: new Headers(),
    });
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('hello-display');
    await new Promise<void>((resolve, reject) =>
      server.close((err) => (err ? reject(err) : resolve())),
    );
  });

  it('rejects when the display port is unreachable', async () => {
    await expect(
      insecureNodeFetch('http://127.0.0.1:1/v1/ping', {
        method: 'GET',
        headers: new Headers(),
      }),
    ).rejects.toMatchObject({
      name: 'DisplayUpstreamError',
      code: 'display_unreachable',
    } satisfies Partial<DisplayUpstreamError>);
  });

  it('maps socket timeout to display_timeout', async () => {
    const server = createServer(() => {
      // Never respond — triggers BFF socket inactivity timeout.
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
    const addr = server.address();
    if (!addr || typeof addr === 'string') throw new Error('no address');
    const url = `http://127.0.0.1:${addr.port}/v1/slow`;

    vi.useFakeTimers();
    try {
      const pending = insecureNodeFetch(url, {
        method: 'GET',
        headers: new Headers(),
        timeoutMs: 50,
      });
      const rejection = expect(pending).rejects.toMatchObject({
        name: 'DisplayUpstreamError',
        code: 'display_timeout',
      } satisfies Partial<DisplayUpstreamError>);
      await vi.advanceTimersByTimeAsync(60);
      await rejection;
    } finally {
      vi.useRealTimers();
      await new Promise<void>((resolve, reject) =>
        server.close((err) => (err ? reject(err) : resolve())),
      );
    }
  });
});
