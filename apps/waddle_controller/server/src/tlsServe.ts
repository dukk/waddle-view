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

export function serveWithOptionalTls(options: {
  fetch: Parameters<typeof serve>[0]['fetch'];
  hostname: string;
  port: number;
  tls: ResolvedTls;
  config?: AppConfig;
  db?: AppDatabase;
}): void {
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
          const user = sessionUserFromUpgrade(options.config!, options.db!, request);
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

  if (options.tls.enabled && options.tls.pem) {
    const server = createHttpsServer(options.tls.pem, listener);
    attachUpgrade(server);
    server.listen(options.port, options.hostname);
    return;
  }

  const server = createHttpServer(listener);
  attachUpgrade(server);
  server.listen(options.port, options.hostname);
}

function sessionUserFromUpgrade(
  config: AppConfig,
  db: AppDatabase,
  request: IncomingMessage,
): PublicUser | null {
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
