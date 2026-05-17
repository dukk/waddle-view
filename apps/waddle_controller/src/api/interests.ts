import { apiFetch, apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type WeatherLocationRow = {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  enabled: boolean;
  include_active_weather_alerts: boolean;
};

export type RssFeedRow = {
  id: string;
  url: string;
  title: string | null;
  category: string;
  poll_seconds: number;
  max_articles: number;
  enabled: boolean;
  last_fetched_at: number | null;
  consecutive_failures: number;
  next_retry_at: number | null;
};

export type StockSymbolRow = {
  id: string;
  symbol: string;
  display_name: string;
  enabled: boolean;
};

export type CategoryInterestRow = {
  id: string;
  label: string;
  is_seasonal: boolean;
  start_month: number | null;
  start_day: number | null;
  end_month: number | null;
  end_day: number | null;
  category_prompt: string | null;
  min_jokes?: number;
  max_jokes?: number;
  min_questions?: number;
  max_questions?: number;
};

export async function listWeatherLocations(
  display: SavedDisplay,
): Promise<WeatherLocationRow[]> {
  const body = await apiJson<{ items: WeatherLocationRow[] }>(
    display,
    '/v1/interests/weather-locations',
  );
  return body.items;
}

export async function createWeatherLocation(
  display: SavedDisplay,
  row: Omit<WeatherLocationRow, 'enabled' | 'include_active_weather_alerts'> & {
    enabled?: boolean;
    include_active_weather_alerts?: boolean;
  },
): Promise<void> {
  await apiFetch(display, '/v1/interests/weather-locations', {
    method: 'POST',
    body: JSON.stringify(row),
  });
}

export async function patchWeatherLocation(
  display: SavedDisplay,
  id: string,
  patch: Partial<WeatherLocationRow>,
): Promise<void> {
  await apiFetch(display, `/v1/interests/weather-locations/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
}

export async function deleteWeatherLocation(display: SavedDisplay, id: string): Promise<void> {
  await apiFetch(display, `/v1/interests/weather-locations/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}

export async function listRssFeeds(display: SavedDisplay): Promise<RssFeedRow[]> {
  const body = await apiJson<{ items: RssFeedRow[] }>(display, '/v1/interests/rss-feeds');
  return body.items;
}

export async function createRssFeed(
  display: SavedDisplay,
  row: Pick<RssFeedRow, 'id' | 'url'> &
    Partial<Pick<RssFeedRow, 'category' | 'poll_seconds' | 'max_articles' | 'enabled' | 'title'>>,
): Promise<void> {
  await apiFetch(display, '/v1/interests/rss-feeds', {
    method: 'POST',
    body: JSON.stringify(row),
  });
}

export async function patchRssFeed(
  display: SavedDisplay,
  id: string,
  patch: Partial<RssFeedRow>,
): Promise<void> {
  await apiFetch(display, `/v1/interests/rss-feeds/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
}

export async function deleteRssFeed(display: SavedDisplay, id: string): Promise<void> {
  await apiFetch(display, `/v1/interests/rss-feeds/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}

export async function listStockSymbols(display: SavedDisplay): Promise<StockSymbolRow[]> {
  const body = await apiJson<{ items: StockSymbolRow[] }>(
    display,
    '/v1/interests/stock-symbols',
  );
  return body.items;
}

export async function createStockSymbol(
  display: SavedDisplay,
  row: Pick<StockSymbolRow, 'id' | 'symbol'> & Partial<Pick<StockSymbolRow, 'display_name' | 'enabled'>>,
): Promise<void> {
  await apiFetch(display, '/v1/interests/stock-symbols', {
    method: 'POST',
    body: JSON.stringify(row),
  });
}

export async function patchStockSymbol(
  display: SavedDisplay,
  id: string,
  patch: Partial<StockSymbolRow>,
): Promise<void> {
  await apiFetch(display, `/v1/interests/stock-symbols/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
}

export async function deleteStockSymbol(display: SavedDisplay, id: string): Promise<void> {
  await apiFetch(display, `/v1/interests/stock-symbols/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}

export async function listJokeCategories(display: SavedDisplay): Promise<CategoryInterestRow[]> {
  const body = await apiJson<{ items: CategoryInterestRow[] }>(
    display,
    '/v1/interests/joke-categories',
  );
  return body.items;
}

export async function createJokeCategory(
  display: SavedDisplay,
  row: Pick<CategoryInterestRow, 'id' | 'label'> & Partial<CategoryInterestRow>,
): Promise<void> {
  await apiFetch(display, '/v1/interests/joke-categories', {
    method: 'POST',
    body: JSON.stringify(row),
  });
}

export async function patchJokeCategory(
  display: SavedDisplay,
  id: string,
  patch: Partial<CategoryInterestRow>,
): Promise<void> {
  await apiFetch(display, `/v1/interests/joke-categories/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
}

export async function deleteJokeCategory(display: SavedDisplay, id: string): Promise<void> {
  await apiFetch(display, `/v1/interests/joke-categories/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}

export async function listTriviaCategories(display: SavedDisplay): Promise<CategoryInterestRow[]> {
  const body = await apiJson<{ items: CategoryInterestRow[] }>(
    display,
    '/v1/interests/trivia-categories',
  );
  return body.items;
}

export async function createTriviaCategory(
  display: SavedDisplay,
  row: Pick<CategoryInterestRow, 'id' | 'label'> & Partial<CategoryInterestRow>,
): Promise<void> {
  await apiFetch(display, '/v1/interests/trivia-categories', {
    method: 'POST',
    body: JSON.stringify(row),
  });
}

export async function patchTriviaCategory(
  display: SavedDisplay,
  id: string,
  patch: Partial<CategoryInterestRow>,
): Promise<void> {
  await apiFetch(display, `/v1/interests/trivia-categories/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
}

export async function deleteTriviaCategory(display: SavedDisplay, id: string): Promise<void> {
  await apiFetch(display, `/v1/interests/trivia-categories/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  });
}
