import { apiFetch, apiJson, ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { pickActiveDisplayAlert, type DisplayAlertRow } from '@/util/activeDisplayAlert';

function formatApiError(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

export async function postDisplayNavigation(
  active: SavedDisplay,
  surface: 'screen' | 'ticker',
  direction: 'back' | 'forward',
): Promise<string | null> {
  try {
    await apiFetch(active, '/v1/display/navigation', {
      method: 'POST',
      body: JSON.stringify({ surface, direction }),
    });
    return null;
  } catch (e) {
    return formatApiError(e);
  }
}

/** Dismisses the top active display alert (same as Enter on the display). */
export async function dismissActiveDisplayAlert(active: SavedDisplay): Promise<string | null> {
  let items: DisplayAlertRow[];
  try {
    const res = await apiJson<{ items: DisplayAlertRow[] }>(active, '/v1/alerts');
    items = res.items ?? [];
  } catch (e) {
    return formatApiError(e);
  }
  const alert = pickActiveDisplayAlert(items);
  if (!alert) return 'No active alert to dismiss';
  try {
    await apiFetch(active, `/v1/alerts/${alert.id}`, { method: 'DELETE' });
    return null;
  } catch (e) {
    return formatApiError(e);
  }
}
