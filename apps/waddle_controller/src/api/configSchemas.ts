import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import {
  loadConfigSchemas,
  saveConfigSchemas,
  type ConfigSchemasBundle,
} from '@/storage/configSchemaCache';

let loggedLazyFetch = false;

function logLazyFetchOnce(displayId: string): void {
  if (loggedLazyFetch) {
    return;
  }
  loggedLazyFetch = true;
  console.info(
    '[waddle-controller] config schemas missing in cache; fetching once for display',
    displayId,
  );
}

export async function fetchConfigSchemasFromDisplay(
  display: SavedDisplay,
): Promise<ConfigSchemasBundle> {
  return apiJson<ConfigSchemasBundle>(display, '/v1/meta/config-schemas');
}

export async function fetchAndCacheConfigSchemas(
  display: SavedDisplay,
): Promise<ConfigSchemasBundle> {
  const bundle = await fetchConfigSchemasFromDisplay(display);
  saveConfigSchemas(display.id, bundle);
  return bundle;
}

/** Returns cached schemas, fetching once when the cache was cleared or never populated. */
export async function ensureConfigSchemasCached(
  display: SavedDisplay,
): Promise<ConfigSchemasBundle> {
  const cached = loadConfigSchemas(display.id);
  if (cached) {
    return cached;
  }
  logLazyFetchOnce(display.id);
  return fetchAndCacheConfigSchemas(display);
}
