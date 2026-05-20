import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type MicrosoftGraphDriveFolderRow = {
  id: string;
  name: string;
  path: string;
  folder: boolean;
};

export async function fetchMicrosoftGraphDriveChildren(
  display: SavedDisplay,
  accountId: string,
  path = '',
): Promise<MicrosoftGraphDriveFolderRow[]> {
  const q = path.trim() ? `?path=${encodeURIComponent(path)}` : '';
  const body = await apiJson<{ items: MicrosoftGraphDriveFolderRow[] }>(
    display,
    `/v1/integration-accounts/${encodeURIComponent(accountId)}/microsoft-graph/drive/children${q}`,
  );
  return body.items ?? [];
}
