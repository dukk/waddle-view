import { createServer as createHttpServer } from 'node:http';
import type { IncomingMessage } from 'node:http';
import { createServer as createHttpsServer } from 'node:https';
import type { Server } from 'node:http';
import { serve, getRequestListener } from '@hono/node-server';
import { WebSocketServer, type WebSocket } from 'ws';
import type { ResolvedTls } from '@waddle/node-tls';
import type { AppConfig } from './config.js';
import type { AppDatabase } from './db/database.js';
import type { PublicUser } from './types.js';
import { pipeDisplayWebSocketProxy } from './services/displayProxyWs.js';
import { resolveSessionUser, SESSION_COOKIE } from './services/sessions.js';

const PROXY_WS_PREFIX = '/bff/v1/proxy-ws';

/** Actionable message when the BFF port is already bound (stale dev server or tsx restart race). */
export function formatListenAddressInUseError(hostname: string, port: number): string {
  return (
    `Port ${port} on ${hostname} is already in use (EADDRINUSE).\n` +
    'Stop any other waddle_controller BFF (Ctrl+C on `npm run dev`, or end the Node process ' +
    `listening on ${port}), then retry.\n` +
    `Or set PORT / WADDLE_CONTROLLER_PORT to a different port and match vite.config.ts proxy target.`
  );
}

export function serveWithOptionalTls(options: {
  fetch: Parameters<typeof serve>[0]['fetch'];
  hostname: string;
  port: number;
  tls: ResolvedTls;
  config?: AppConfig;
  db?: AppDatabase;
  onListening?: () => void;
}): Server {
  const listener = getRequestListener(options.fetch);
  const wss = new WebSocketServer({ noServer: true });

  const attachUpgrade = (server: Server) => {
    server.on('upgrade', (request, socket, head) => {
      const pathname = new URL(request.url ?? '/', 'http://localhost').pathname;
      if (!pathname.startsWith(PROXY_WS_PREFIX)) {
        socket.destroy();
        return;
      }
      if (!options.config || !options.db) {
        socket.destroy();
        return;
      }
      wss.handleUpgrade(request, socket, head, (clientWs: WebSocket) => {
        void (async () => {
          const user = await sessionUserFromUpgrade(options.config!, options.db!, request);
          await pipeDisplayWebSocketProxy(
            options.config!,
            options.db!,
            user,
            clientWs,
            request,
          );
        })();
      });
    });
  };

  const server =
    options.tls.enabled && options.tls.pem
      ? createHttpsServer(options.tls.pem, listener)
      : createHttpServer(listener);

  attachUpgrade(server);
  bindHttpServer(server, options.hostname, options.port, options.onListening);
  return server;
}

function bindHttpServer(
  server: Server,
  hostname: string,
  port: number,
  onListening?: () => void,
): void {
  server.on('error', (err: NodeJS.ErrnoException) => {
    if (err.code === 'EADDRINUSE') {
      console.error(formatListenAddressInUseError(hostname, port));
      process.exit(1);
    }
    throw err;
  });

  server.listen({ host: hostname, port, reuseAddress: true }, () => {
    onListening?.();
  });
}

async function sessionUserFromUpgrade(
  config: AppConfig,
  db: AppDatabase,
  request: IncomingMessage,
): Promise<PublicUser | null> {
  if (!config.authEnabled) {
    return null;
  }
  const cookie = request.headers.cookie;
  if (!cookie) return null;
  for (const part of cookie.split(';')) {
    const trimmed = part.trim();
    const eq = trimmed.indexOf('=');
    if (eq < 0) continue;
    const name = trimmed.slice(0, eq);
    if (name !== SESSION_COOKIE) continue;
    const sessionId = trimmed.slice(eq + 1);
    return resolveSessionUser(db, sessionId);
  }
  return null;
}
