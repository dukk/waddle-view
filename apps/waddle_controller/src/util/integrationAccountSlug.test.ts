import { describe, expect, it } from 'vitest';
import { integrationAccountIdFromName } from './integrationAccountSlug';

describe('integrationAccountIdFromName', () => {
  it('slugifies display names and avoids collisions', () => {
    expect(integrationAccountIdFromName('OpenWeather Home', [])).toBe('openweather_home');
    expect(integrationAccountIdFromName('OpenWeather Home', ['openweather_home'])).toBe(
      'openweather_home_2',
    );
  });
});
