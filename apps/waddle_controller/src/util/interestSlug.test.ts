import { describe, expect, it } from 'vitest';
import {
  rssFeedInterestId,
  slugifyInterestSource,
  stockSymbolInterestId,
  uniqueInterestSlug,
  weatherLocationInterestId,
} from './interestSlug';

describe('slugifyInterestSource', () => {
  it('lowercases and replaces spaces with underscores', () => {
    expect(slugifyInterestSource('Seattle Home')).toBe('seattle_home');
  });

  it('strips diacritics and non-alphanumeric runs', () => {
    expect(slugifyInterestSource('São Paulo — HQ')).toBe('sao_paulo_hq');
  });

  it('prefixes when the slug would start with a digit', () => {
    expect(slugifyInterestSource('123 Main')).toBe('i_123_main');
  });

  it('returns empty for blank input', () => {
    expect(slugifyInterestSource('   ')).toBe('');
  });
});

describe('uniqueInterestSlug', () => {
  it('returns base when unused', () => {
    expect(uniqueInterestSlug('kitchen', ['living_room'])).toBe('kitchen');
  });

  it('appends numeric suffix on collision', () => {
    expect(uniqueInterestSlug('kitchen', ['kitchen', 'kitchen_2'])).toBe('kitchen_3');
  });
});

describe('weatherLocationInterestId', () => {
  it('builds slug from location name', () => {
    expect(weatherLocationInterestId('Back Yard', [])).toBe('back_yard');
  });
});

describe('rssFeedInterestId', () => {
  it('builds slug from feed name not url', () => {
    expect(rssFeedInterestId('BBC World News', [])).toBe('bbc_world_news');
  });
});

describe('stockSymbolInterestId', () => {
  it('lowercases ticker symbol', () => {
    expect(stockSymbolInterestId('AAPL', [])).toBe('aapl');
  });
});
