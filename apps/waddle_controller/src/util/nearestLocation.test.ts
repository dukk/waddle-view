import { describe, expect, it } from 'vitest';
import type { WeatherLocationRow } from '@/api/interests';
import { findNearestWeatherLocation, haversineDistanceKm } from './nearestLocation';

const row = (id: string, lat: number, lon: number): WeatherLocationRow => ({
  id,
  name: id,
  latitude: lat,
  longitude: lon,
  category: 'general',
  include_weather: false,
  include_weather_alerts: false,
  include_local_news: false,
});

describe('nearestLocation', () => {
  it('haversineDistanceKm is zero for identical points', () => {
    expect(haversineDistanceKm(40.7, -74.0, 40.7, -74.0)).toBe(0);
  });

  it('findNearestWeatherLocation picks closest within max distance', () => {
    const locations = [
      row('far', 34.0, -118.0),
      row('near', 40.76, -111.89),
    ];
    const nearest = findNearestWeatherLocation(locations, 40.7608, -111.891, 50);
    expect(nearest?.id).toBe('near');
  });

  it('findNearestWeatherLocation returns null when all rows are too far', () => {
    const locations = [row('far', 51.5, -0.12)];
    expect(findNearestWeatherLocation(locations, 40.7, -74.0, 10)).toBeNull();
  });
});
