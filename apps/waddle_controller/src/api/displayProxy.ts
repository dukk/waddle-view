import { isDisplayProxyAuthEnabled } from '@/api/displayAuthMode';
import {
  DISPLAY_ID_HEADER,
  DISPLAY_URL_HEADER,
  PROXY_PREFIX,
} from '@/constants/proxyHeaders';
import type { SavedDisplay } from '@/storage/displays';
import { normalizeBaseUrl } from '@/storage/displays';

export type DisplayProxyHeaderOptions = {
  display?: SavedDisplay | null;
  baseUrl?: string;
  displayId?: string;
  /** When true, omitting display URL is an error on the client before fetch. */
  requireUrl?: boolean;
  authorization?: string;
  /** When true and display is set, URL header may be omitted (BFF resolves from DB). */
  omitUrlWhenAuth?: boolean;
};

export function proxyUrlForPath(displayPath: string): string {
  const path = displayPath.startsWith('/') ? displayPath : `/${displayPath}`;
  return `${PROXY_PREFIX}${path}`;
}

export function displayProxyHeaders(options: DisplayProxyHeaderOptions = {}): Headers {
  const headers = new Headers();
  const baseUrl = options.baseUrl ?? options.display?.baseUrl;
  if (baseUrl) {
    headers.set(DISPLAY_URL_HEADER, normalizeBaseUrl(baseUrl));
  } else if (options.requireUrl) {
    throw new Error('Display base URL is required for this request');
  }
  const displayId = options.displayId ?? options.display?.id;
  if (displayId) {
    headers.set(DISPLAY_ID_HEADER, displayId);
  }
  if (options.authorization) {
    headers.set('Authorization', options.authorization);
  }
  const omitUrl = options.omitUrlWhenAuth ?? isDisplayProxyAuthEnabled();
  if (omitUrl && displayId && headers.has(DISPLAY_URL_HEADER)) {
    headers.delete(DISPLAY_URL_HEADER);
  }
  return headers;
}

export async function displayProxyFetch(
  displayPath: string,
  init: RequestInit = {},
  headerOptions: DisplayProxyHeaderOptions = {},
): Promise<Response> {
  const proxyHeaders = displayProxyHeaders(headerOptions);
  const merged = new Headers(init.headers);
  proxyHeaders.forEach((value, key) => merged.set(key, value));
  if (init.body && !merged.has('Content-Type')) {
    merged.set('Content-Type', 'application/json');
  }
  return fetch(proxyUrlForPath(displayPath), {
    ...init,
    headers: merged,
    credentials: 'include',
    referrerPolicy: 'origin',
  });
}
