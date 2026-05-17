import { describe, expect, it } from 'vitest';
import {
  integrationDataFamily,
  integrationIconImageUrl,
  integrationIconSource,
  integrationMuiIconSource,
} from './integrationIcon';

describe('integrationDataFamily', () => {
  it('returns prefix before underscore', () => {
    expect(integrationDataFamily('calendar_google')).toBe('calendar');
    expect(integrationDataFamily('stub')).toBe('stub');
  });
});

describe('integrationIconSource', () => {
  it('maps known providers to Simple Icons', () => {
    expect(integrationIconSource('calendar_google')).toEqual({
      kind: 'simpleicons',
      slug: 'googlecalendar',
      color: '4285F4',
    });
    expect(integrationIconSource('media_pexels')).toMatchObject({
      kind: 'simpleicons',
      slug: 'pexels',
    });
    expect(integrationIconSource('news_rss')).toMatchObject({ kind: 'simpleicons', slug: 'rss' });
  });

  it('uses curated favicon hosts for services without Simple Icons entries', () => {
    expect(integrationIconSource('weather_nws_alerts')).toEqual({
      kind: 'favicon',
      hostname: 'weather.gov',
    });
    expect(integrationIconSource('trivia_opentdb')).toEqual({
      kind: 'favicon',
      hostname: 'opentdb.com',
    });
  });

  it('derives favicon from base_url when type is unknown', () => {
    expect(integrationIconSource('custom_provider', 'https://api.example.com/v1')).toEqual({
      kind: 'favicon',
      hostname: 'api.example.com',
    });
  });

  it('falls back to MUI family icons', () => {
    expect(integrationIconSource('stub').kind).toBe('mui');
    expect(integrationIconSource('unknown_widget').kind).toBe('mui');
  });
});

describe('integrationMuiIconSource', () => {
  it('uses RSS icon for news_rss when forced to MUI', () => {
    expect(integrationMuiIconSource('news_rss').kind).toBe('mui');
  });
});

describe('integrationIconImageUrl', () => {
  it('builds Simple Icons CDN URLs', () => {
    expect(
      integrationIconImageUrl({
        kind: 'simpleicons',
        slug: 'openai',
      }),
    ).toBe('https://cdn.simpleicons.org/openai');
    expect(
      integrationIconImageUrl({
        kind: 'simpleicons',
        slug: 'bing',
        color: '258FFA',
      }),
    ).toBe('https://cdn.simpleicons.org/bing/258FFA');
  });

  it('builds Google favicon URLs', () => {
    expect(integrationIconImageUrl({ kind: 'favicon', hostname: 'weather.gov' })).toBe(
      'https://www.google.com/s2/favicons?domain=weather.gov&sz=64',
    );
  });

  it('returns null for MUI-only sources', () => {
    expect(integrationIconSource('stub').kind).toBe('mui');
    expect(integrationIconImageUrl(integrationIconSource('stub'))).toBeNull();
  });
});
