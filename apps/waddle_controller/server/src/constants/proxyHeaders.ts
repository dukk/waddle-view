export const DISPLAY_URL_HEADER = 'X-Waddle-Display-Url';
export const DISPLAY_ID_HEADER = 'X-Waddle-Display-Id';

const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailers',
  'transfer-encoding',
  'upgrade',
]);

const STRIP_TO_UPSTREAM = new Set([
  ...HOP_BY_HOP,
  'host',
  DISPLAY_URL_HEADER.toLowerCase(),
  DISPLAY_ID_HEADER.toLowerCase(),
]);

export function isAdoptionProxyPath(pathname: string): boolean {
  return pathname.startsWith('/v1/adoption/');
}

export function shouldStripUpstreamHeader(name: string): boolean {
  const lower = name.toLowerCase();
  if (STRIP_TO_UPSTREAM.has(lower)) return true;
  if (lower.startsWith('x-waddle-')) return true;
  return false;
}

export function normalizeDisplayBaseUrl(url: string): string {
  return url.trim().replace(/\/+$/, '');
}

export function validateProxyTargetScheme(url: URL): boolean {
  return url.protocol === 'http:' || url.protocol === 'https:';
}
