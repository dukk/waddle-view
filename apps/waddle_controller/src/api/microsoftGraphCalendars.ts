import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type MicrosoftGraphCalendarRow = {
  id: string;
  name: string;
};

export async function fetchMicrosoftGraphCalendars(
  display: SavedDisplay,
  accountId: string,
): Promise<MicrosoftGraphCalendarRow[]> {
  const body = await apiJson<{ items: MicrosoftGraphCalendarRow[] }>(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}/microsoft-graph/calendars`,
  );
  return body.items ?? [];
}
