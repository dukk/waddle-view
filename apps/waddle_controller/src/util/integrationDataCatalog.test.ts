import { describe, expect, it } from 'vitest';
import type { IntegrationRow } from '@/api/integrations';
import {
  calendarCatalogSourceNeedle,
  catalogDataKindForIntegrationType,
  catalogFilterParamsForIntegration,
  dataCatalogPath,
  parseDataCatalogSearchParams,
} from './integrationDataCatalog';

function row(overrides: Partial<IntegrationRow> = {}): IntegrationRow {
  return {
    id: 'int-1',
    integration_type: 'photo_pexels',
    enabled: true,
    poll_seconds: 300,
    config_json: {},
    ...overrides,
  };
}

describe('integrationDataCatalog', () => {
  it('catalogDataKindForIntegrationType maps provider prefixes', () => {
    expect(catalogDataKindForIntegrationType('calendar_google')).toBe('calendar_events');
    expect(catalogDataKindForIntegrationType('joke_openai')).toBe('jokes');
    expect(catalogDataKindForIntegrationType('trivia_opentdb')).toBe('trivia');
    expect(catalogDataKindForIntegrationType('news_rss')).toBe('news');
    expect(catalogDataKindForIntegrationType('photo_pexels')).toBe('photos');
    expect(catalogDataKindForIntegrationType('video_pexels')).toBe('videos');
    expect(catalogDataKindForIntegrationType('quote_quoterism')).toBe('quoterism_quotes');
    expect(catalogDataKindForIntegrationType('stock_finnhub')).toBe('stocks');
    expect(catalogDataKindForIntegrationType('tasks_trello')).toBe('tasks');
    expect(catalogDataKindForIntegrationType('weather_openmeteo')).toBe('weather');
    expect(catalogDataKindForIntegrationType('weather_alerts_nws')).toBe('weather_alerts');
  });

  it('catalogDataKindForIntegrationType returns null for non-catalog integrations', () => {
    expect(catalogDataKindForIntegrationType('general_openai')).toBeNull();
    expect(catalogDataKindForIntegrationType('home_assistant')).toBeNull();
    expect(catalogDataKindForIntegrationType('stub')).toBeNull();
    expect(catalogDataKindForIntegrationType('air_quality_openmeteo')).toBeNull();
  });

  it('calendarCatalogSourceNeedle maps calendar integration types', () => {
    expect(calendarCatalogSourceNeedle('calendar_google')).toBe('google_calendar');
    expect(calendarCatalogSourceNeedle('calendar_outlook')).toBe('outlook_calendar');
    expect(calendarCatalogSourceNeedle('calendar_ical')).toBe('ical_feed');
    expect(calendarCatalogSourceNeedle('calendar_mealviewer')).toBe('mealviewer');
    expect(calendarCatalogSourceNeedle('photo_pexels')).toBeNull();
  });

  it('dataCatalogPath builds deep link query string', () => {
    expect(dataCatalogPath(row({ integration_type: 'photo_pexels', id: 'int-42' }))).toBe(
      '/data?kind=photos&integration_type=photo_pexels&integration_id=int-42',
    );
    expect(dataCatalogPath(row({ integration_type: 'general_openai' }))).toBeNull();
  });

  it('catalogFilterParamsForIntegration adds kind-specific query params', () => {
    const integration = row({ integration_type: 'photo_pexels', id: 'int-1' });
    expect(catalogFilterParamsForIntegration('photos', integration).toString()).toBe(
      'data_provider=photo_pexels',
    );

    const calendar = row({ integration_type: 'calendar_google', id: 'int-cal' });
    expect(catalogFilterParamsForIntegration('calendar_events', calendar).toString()).toBe(
      'source=google_calendar',
    );

    const trivia = row({ integration_type: 'trivia_openai', id: 'int-triv' });
    expect(catalogFilterParamsForIntegration('trivia', trivia).toString()).toBe(
      'integration_type=int-triv',
    );

    const tasks = row({ integration_type: 'tasks_trello', id: 'int-task' });
    expect(catalogFilterParamsForIntegration('tasks', tasks).toString()).toBe(
      'integration_id=int-task',
    );

    expect(catalogFilterParamsForIntegration('jokes', integration).toString()).toBe('');
  });

  it('parseDataCatalogSearchParams reads integration filter from URL', () => {
    const params = new URLSearchParams(
      'kind=photos&integration_type=photo_pexels&integration_id=int-1',
    );
    expect(parseDataCatalogSearchParams(params)).toEqual({
      kind: 'photos',
      integrationType: 'photo_pexels',
      integrationId: 'int-1',
    });
  });
});
