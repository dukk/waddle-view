import { apiJson } from '@/api/client';
import type { DisplayCustomTheme } from '@/constants/displayThemes';
import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';
import type { SavedDisplay } from '@/storage/displays';

type ThemesListResponse = { items: DisplayCustomTheme[] };

export async function fetchDisplayThemes(display: SavedDisplay): Promise<DisplayCustomTheme[]> {
  const body = await apiJson<ThemesListResponse>(display, '/v1/display/themes');
  return body.items ?? [];
}

export async function createDisplayTheme(
  display: SavedDisplay,
  body: { label: string; preview: DisplayThemePreviewGroups },
): Promise<DisplayCustomTheme> {
  return apiJson<DisplayCustomTheme>(display, '/v1/display/themes', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

export async function updateDisplayTheme(
  display: SavedDisplay,
  id: string,
  body: { label?: string; preview?: DisplayThemePreviewGroups },
): Promise<DisplayCustomTheme> {
  return apiJson<DisplayCustomTheme>(display, `/v1/display/themes/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  });
}

export async function deleteDisplayTheme(
  display: SavedDisplay,
  id: string,
): Promise<void> {
  await apiJson(display, `/v1/display/themes/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}
