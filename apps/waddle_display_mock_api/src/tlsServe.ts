import { createServer as createHttpsServer } from 'node:https';
import { serve } from '@hono/node-server';
import type { ResolvedTls } from '@waddle/node-tls';

export function serveWithOptionalTls(options: {
  fetch: Parameters<typeof serve>[0]['fetch'];
  hostname: string;
  port: number;
  tls: ResolvedTls;
}): void {
  if (options.tls.enabled && options.tls.pem) {
    serve({
      fetch: options.fetch,
      hostname: options.hostname,
      port: options.port,
      createServer: createHttpsServer,
      serverOptions: options.tls.pem,
    });
    return;
  }
  serve({
    fetch: options.fetch,
    hostname: options.hostname,
    port: options.port,
  });
}
