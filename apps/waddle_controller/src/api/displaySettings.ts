import { apiJson } from '@/api/client';
import type { DisplaySettings } from '@/constants/displaySettings';
import type { SavedDisplay } from '@/storage/displays';

export async function fetchDisplaySettings(display: SavedDisplay): Promise<DisplaySettings> {
  return apiJson<DisplaySettings>(display, '/v1/display/settings');
}

export async function putDisplaySettings(
  display: SavedDisplay,
  body: Partial<DisplaySettings>,
): Promise<void> {
  await apiJson(display, '/v1/display/settings', {
    method: 'PUT',
    body: JSON.stringify(body),
  });
}
