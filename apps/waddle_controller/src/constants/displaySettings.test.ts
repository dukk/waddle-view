import { describe, expect, it } from 'vitest';
import {
  DEFAULT_DISPLAY_TICKER_ITEM_SEPARATOR,
  DEFAULT_DISPLAY_TICKER_PROGRAM_SEPARATOR,
  DEFAULT_DISPLAY_WEATHER_TEMPERATURE_UNIT,
  normalizeDisplayTickerSeparator,
  normalizeDisplayWeatherTemperatureUnit,
} from './displaySettings';

describe('normalizeDisplayWeatherTemperatureUnit', () => {
  it('defaults to Fahrenheit when unset', () => {
    expect(DEFAULT_DISPLAY_WEATHER_TEMPERATURE_UNIT).toBe('f');
    expect(normalizeDisplayWeatherTemperatureUnit(null)).toBe('f');
    expect(normalizeDisplayWeatherTemperatureUnit(undefined)).toBe('f');
    expect(normalizeDisplayWeatherTemperatureUnit('')).toBe('f');
  });

  it('accepts explicit c and f', () => {
    expect(normalizeDisplayWeatherTemperatureUnit('c')).toBe('c');
    expect(normalizeDisplayWeatherTemperatureUnit('celsius')).toBe('c');
    expect(normalizeDisplayWeatherTemperatureUnit('f')).toBe('f');
    expect(normalizeDisplayWeatherTemperatureUnit('fahrenheit')).toBe('f');
    expect(normalizeDisplayWeatherTemperatureUnit('imperial')).toBe('f');
  });
});

describe('normalizeDisplayTickerSeparator', () => {
  it('defaults item and program separators', () => {
    expect(DEFAULT_DISPLAY_TICKER_ITEM_SEPARATOR).toBe('dot');
    expect(DEFAULT_DISPLAY_TICKER_PROGRAM_SEPARATOR).toBe('diamond');
    expect(
      normalizeDisplayTickerSeparator(null, DEFAULT_DISPLAY_TICKER_ITEM_SEPARATOR),
    ).toBe('dot');
    expect(
      normalizeDisplayTickerSeparator('', DEFAULT_DISPLAY_TICKER_PROGRAM_SEPARATOR),
    ).toBe('diamond');
  });

  it('accepts dot and diamond', () => {
    expect(
      normalizeDisplayTickerSeparator('diamond', DEFAULT_DISPLAY_TICKER_ITEM_SEPARATOR),
    ).toBe('diamond');
    expect(
      normalizeDisplayTickerSeparator('dot', DEFAULT_DISPLAY_TICKER_PROGRAM_SEPARATOR),
    ).toBe('dot');
  });
});
