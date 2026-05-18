import { describe, expect, it } from 'vitest';
import { integrationDisplayName } from './integrationDisplayName';

describe('integrationDisplayName', () => {
  it('maps known integration types', () => {
    expect(integrationDisplayName('news_rss')).toBe('RSS News');
    expect(integrationDisplayName('calendar_google')).toBe('Google Calendar');
    expect(integrationDisplayName('calendar_ical')).toBe('iCal / ICS Calendar');
  });

  it('returns Integration for blank input', () => {
    expect(integrationDisplayName('')).toBe('Integration');
    expect(integrationDisplayName('   ')).toBe('Integration');
  });

  it('title-cases unknown types with reversed segments', () => {
    expect(integrationDisplayName('foo_bar')).toBe('Bar Foo');
    expect(integrationDisplayName('custom_openai_widget')).toBe('Widget OpenAI Custom');
  });

  it('applies acronym tokens for unknown types', () => {
    expect(integrationDisplayName('weather_alerts_nws')).toBe('NWS Weather Alerts');
  });
});
