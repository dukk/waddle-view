import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type GoogleCalendarRow = {
  id: string;
  name: string;
};

export async function fetchGoogleCalendars(
  display: SavedDisplay,
  accountId: string,
): Promise<GoogleCalendarRow[]> {
  const body = await apiJson<{ items: GoogleCalendarRow[] }>(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}/google/calendars`,
  );
  return body.items ?? [];
}
