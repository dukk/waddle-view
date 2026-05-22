import { displayProxyFetch } from '@/api/displayProxy';
import type { SavedDisplay } from '@/storage/displays';
import { readProxyErrorMessage } from '@/util/proxyErrorBody';

export type DisplayProductLicense = {
  id: string;
  name: string;
  url: string;
  summary: string;
};

export type DisplayDependencyRow = {
  name: string;
  version: string;
  license?: string;
};

export type DisplayAboutPayload = {
  app: string;
  version: string;
  build: string;
  product_license: DisplayProductLicense;
  dependencies: DisplayDependencyRow[];
  third_party_licenses: string;
};

export type DisplayAboutResult =
  | { state: 'ok'; about: DisplayAboutPayload }
  | { state: 'unsupported'; message: string }
  | { state: 'offline'; message: string };

function isDisplayAboutPayload(value: unknown): value is DisplayAboutPayload {
  if (value == null || typeof value !== 'object') return false;
  const v = value as DisplayAboutPayload;
  return (
    typeof v.app === 'string' &&
    typeof v.version === 'string' &&
    typeof v.build === 'string' &&
    v.product_license != null &&
    Array.isArray(v.dependencies)
  );
}

export async function fetchDisplayAbout(display: SavedDisplay): Promise<DisplayAboutResult> {
  try {
    const res = await displayProxyFetch('/v1/about', { method: 'GET' }, { display });
    if (res.status === 404) {
      return {
        state: 'unsupported',
        message:
          'This display does not expose /v1/about yet. Upgrade the display for full dependency and license details.',
      };
    }
    if (!res.ok) {
      const message = await readProxyErrorMessage(res, `About request failed (${res.status})`);
      return { state: 'offline', message };
    }
    const body: unknown = await res.json();
    if (!isDisplayAboutPayload(body)) {
      return { state: 'offline', message: 'Display returned an unexpected about response' };
    }
    return { state: 'ok', about: body };
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return { state: 'offline', message };
  }
}
