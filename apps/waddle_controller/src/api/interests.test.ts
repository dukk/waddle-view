import { describe, expect, it, vi, beforeEach } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import {
  createJokeCategory,
  createRssFeed,
  createStockSymbol,
  createTriviaCategory,
  createWeatherLocation,
  deleteJokeCategory,
  deleteRssFeed,
  deleteStockSymbol,
  deleteTriviaCategory,
  deleteWeatherLocation,
  listJokeCategories,
  listRssFeeds,
  listStockSymbols,
  listTriviaCategories,
  listWeatherLocations,
  patchJokeCategory,
  patchRssFeed,
  patchStockSymbol,
  patchTriviaCategory,
  patchWeatherLocation,
} from './interests';

const display = { id: 'd1', name: 'Test', baseUrl: 'http://127.0.0.1:1' } as SavedDisplay;

vi.mock('./client', () => ({
  apiJson: vi.fn(),
  apiFetch: vi.fn(),
}));

import { apiFetch, apiJson } from './client';

describe('interests api', () => {
  beforeEach(() => {
    vi.mocked(apiJson).mockReset();
    vi.mocked(apiFetch).mockReset();
  });

  it('listWeatherLocations calls GET /v1/interests/weather-locations', async () => {
    vi.mocked(apiJson).mockResolvedValue({ items: [] });
    await listWeatherLocations(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/interests/weather-locations');
  });

  it('listRssFeeds calls GET /v1/interests/rss-feeds', async () => {
    vi.mocked(apiJson).mockResolvedValue({ items: [] });
    await listRssFeeds(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/interests/rss-feeds');
  });

  it('listStockSymbols calls GET /v1/interests/stock-symbols', async () => {
    vi.mocked(apiJson).mockResolvedValue({ items: [] });
    await listStockSymbols(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/interests/stock-symbols');
  });

  it('listJokeCategories calls GET /v1/interests/joke-categories', async () => {
    vi.mocked(apiJson).mockResolvedValue({ items: [] });
    await listJokeCategories(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/interests/joke-categories');
  });

  it('listTriviaCategories calls GET /v1/interests/trivia-categories', async () => {
    vi.mocked(apiJson).mockResolvedValue({ items: [] });
    await listTriviaCategories(display);
    expect(apiJson).toHaveBeenCalledWith(display, '/v1/interests/trivia-categories');
  });

  it('createWeatherLocation POSTs body', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await createWeatherLocation(display, {
      id: 'sea',
      name: 'Seattle',
      latitude: 47.6,
      longitude: -122.3,
    });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/weather-locations',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('patchWeatherLocation PATCHes id path', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await patchWeatherLocation(display, 'sea', { name: 'Seattle, WA' });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/weather-locations/sea',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('deleteWeatherLocation DELETEs id path', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await deleteWeatherLocation(display, 'sea');
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/weather-locations/sea',
      expect.objectContaining({ method: 'DELETE' }),
    );
  });

  it('createRssFeed POSTs rss body', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await createRssFeed(display, { id: 'f1', url: 'https://example.com/rss' });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/rss-feeds',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('patchRssFeed PATCHes feed id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await patchRssFeed(display, 'f1', { enabled: false });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/rss-feeds/f1',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('deleteRssFeed DELETEs feed id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await deleteRssFeed(display, 'f1');
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/rss-feeds/f1',
      expect.objectContaining({ method: 'DELETE' }),
    );
  });

  it('createStockSymbol POSTs symbol body', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await createStockSymbol(display, { id: 'aapl', symbol: 'AAPL' });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/stock-symbols',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('patchStockSymbol PATCHes symbol id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await patchStockSymbol(display, 'aapl', { enabled: true });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/stock-symbols/aapl',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('deleteStockSymbol DELETEs symbol id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await deleteStockSymbol(display, 'aapl');
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/stock-symbols/aapl',
      expect.objectContaining({ method: 'DELETE' }),
    );
  });

  it('createJokeCategory POSTs category body', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await createJokeCategory(display, { id: 'dad', label: 'Dad' });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/joke-categories',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('patchJokeCategory PATCHes category id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await patchJokeCategory(display, 'dad', { label: 'Dad jokes' });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/joke-categories/dad',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('deleteJokeCategory DELETEs category id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await deleteJokeCategory(display, 'dad');
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/joke-categories/dad',
      expect.objectContaining({ method: 'DELETE' }),
    );
  });

  it('createTriviaCategory POSTs category body', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await createTriviaCategory(display, { id: 'sci', label: 'Science' });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/trivia-categories',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('patchTriviaCategory PATCHes category id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await patchTriviaCategory(display, 'sci', { max_questions: 50 });
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/trivia-categories/sci',
      expect.objectContaining({ method: 'PATCH' }),
    );
  });

  it('deleteTriviaCategory DELETEs category id', async () => {
    vi.mocked(apiFetch).mockResolvedValue(new Response('{}', { status: 200 }));
    await deleteTriviaCategory(display, 'sci');
    expect(apiFetch).toHaveBeenCalledWith(
      display,
      '/v1/interests/trivia-categories/sci',
      expect.objectContaining({ method: 'DELETE' }),
    );
  });
});
