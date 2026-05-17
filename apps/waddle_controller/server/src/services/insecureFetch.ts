import http from 'node:http';
import https from 'node:https';
import { Readable } from 'node:stream';

const UPSTREAM_TIMEOUT_MS = 60_000;

export class DisplayUpstreamError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly upstreamUrl: string,
    options?: { cause?: unknown },
  ) {
    super(message, options);
    this.name = 'DisplayUpstreamError';
  }
}

function normalizeUpstreamError(url: string, err: unknown): DisplayUpstreamError {
  const errno =
    err && typeof err === 'object' && 'code' in err
      ? String((err as NodeJS.ErrnoException).code)
      : '';
  const unreachable =
    errno === 'ECONNREFUSED' ||
    errno === 'ECONNRESET' ||
    errno === 'ENOTFOUND' ||
    errno === 'EHOSTUNREACH' ||
    errno === 'ETIMEDOUT' ||
    errno === 'ERR_SOCKET_CONNECTION_TIMEOUT';
  if (unreachable) {
    return new DisplayUpstreamError(
      `Could not reach the display at ${url}. Check that waddle_display is running and the base URL is correct.`,
      errno === 'ETIMEDOUT' ? 'display_timeout' : 'display_unreachable',
      url,
      { cause: err },
    );
  }
  const message = err instanceof Error ? err.message : String(err);
  return new DisplayUpstreamError(
    `Display request failed for ${url}: ${message}`,
    'display_upstream_error',
    url,
    { cause: err },
  );
}

export async function insecureNodeFetch(
  url: string,
  init: { method: string; headers: Headers; body?: ArrayBuffer },
): Promise<Response> {
  const parsed = new URL(url);
  const isHttps = parsed.protocol === 'https:';
  const lib = isHttps ? https.request : http.request;
  const headerRecord: Record<string, string> = {};
  init.headers.forEach((value, key) => {
    headerRecord[key] = value;
  });

  return new Promise((resolve, reject) => {
    const fail = (err: unknown) => {
      reject(normalizeUpstreamError(url, err));
    };

    const req = lib(
      {
        hostname: parsed.hostname,
        port: parsed.port || (isHttps ? 443 : 80),
        path: `${parsed.pathname}${parsed.search}`,
        method: init.method,
        headers: headerRecord,
        rejectUnauthorized: false,
      },
      (res) => {
        res.on('error', fail);
        const headers = new Headers();
        for (const [key, value] of Object.entries(res.headers)) {
          if (value == null) continue;
          if (Array.isArray(value)) {
            for (const v of value) headers.append(key, v);
          } else {
            headers.set(key, value);
          }
        }
        const webStream = Readable.toWeb(res) as ReadableStream<Uint8Array>;
        resolve(
          new Response(webStream, {
            status: res.statusCode ?? 502,
            statusText: res.statusMessage,
            headers,
          }),
        );
      },
    );
    req.on('error', fail);
    req.setTimeout(UPSTREAM_TIMEOUT_MS, () => {
      req.destroy();
      fail(new Error('ETIMEDOUT'));
    });
    if (init.body && init.body.byteLength > 0) {
      req.write(Buffer.from(init.body));
    }
    req.end();
  });
}
