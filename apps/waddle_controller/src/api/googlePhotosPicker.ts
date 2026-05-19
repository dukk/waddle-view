import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type GooglePhotosPickerSession = {
  sessionId: string;
  pickerUri: string;
  mediaItemsSet: boolean;
  recommendedPollIntervalMs?: number;
  recommendedTimeoutMs?: number;
};

export type GooglePhotosPickedItem = {
  id: string;
  mimeType: string;
  filename: string;
  type: string;
};

export async function createGooglePhotosPickerSession(
  display: SavedDisplay,
  accountId: string,
  requestId?: string,
): Promise<GooglePhotosPickerSession> {
  const body = await apiJson<GooglePhotosPickerSession>(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}/google-photos/picker/sessions`,
    {
      method: 'POST',
      body: requestId ? JSON.stringify({ requestId }) : '{}',
    },
  );
  return body;
}

export async function getGooglePhotosPickerSession(
  display: SavedDisplay,
  accountId: string,
  sessionId: string,
): Promise<GooglePhotosPickerSession> {
  return apiJson<GooglePhotosPickerSession>(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}/google-photos/picker/sessions/${encodeURIComponent(sessionId)}`,
  );
}

export async function listGooglePhotosPickedMedia(
  display: SavedDisplay,
  accountId: string,
  sessionId: string,
): Promise<GooglePhotosPickedItem[]> {
  const all: GooglePhotosPickedItem[] = [];
  let pageToken: string | undefined;
  do {
    const q = pageToken ? `?pageToken=${encodeURIComponent(pageToken)}` : '';
    const body = await apiJson<{
      items: GooglePhotosPickedItem[];
      nextPageToken?: string;
    }>(
      display,
      `/v1/integration-accounts/${encodeURIComponent(accountId)}/google-photos/picker/sessions/${encodeURIComponent(sessionId)}/media-items${q}`,
    );
    all.push(...(body.items ?? []));
    pageToken = body.nextPageToken;
  } while (pageToken);
  return all;
}

export async function deleteGooglePhotosPickerSession(
  display: SavedDisplay,
  accountId: string,
  sessionId: string,
): Promise<void> {
  await apiJson(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}/google-photos/picker/sessions/${encodeURIComponent(sessionId)}`,
    { method: 'DELETE' },
  );
}

export function pickerUriForWeb(pickerUri: string): string {
  const trimmed = pickerUri.trim();
  if (trimmed.endsWith('/autoclose')) {
    return trimmed;
  }
  return `${trimmed.replace(/\/$/, '')}/autoclose`;
}

export async function pollGooglePhotosPickerUntilReady(
  display: SavedDisplay,
  accountId: string,
  sessionId: string,
  options?: { maxAttempts?: number },
): Promise<GooglePhotosPickerSession> {
  const maxAttempts = options?.maxAttempts ?? 120;
  let intervalMs = 2000;
  for (let i = 0; i < maxAttempts; i++) {
    const session = await getGooglePhotosPickerSession(display, accountId, sessionId);
    if (session.mediaItemsSet) {
      return session;
    }
    if (session.recommendedPollIntervalMs && session.recommendedPollIntervalMs > 0) {
      intervalMs = session.recommendedPollIntervalMs;
    }
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  throw new Error('Timed out waiting for Google Photos selection');
}
