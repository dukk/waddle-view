import { describe, expect, it } from 'vitest';
import {
  DEFAULT_DISPLAY_WEATHER_TEMPERATURE_UNIT,
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
