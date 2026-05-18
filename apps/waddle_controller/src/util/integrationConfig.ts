import { parseJsonObject } from '@/util/json';

/** Reads optional `baseUrl` from integration `config_json`. */
export function integrationConfigBaseUrl(configJson: unknown): string | null {
  const o = parseJsonObject(configJson);
  const raw = o.baseUrl;
  if (typeof raw === 'string') {
    const trimmed = raw.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  return null;
}
