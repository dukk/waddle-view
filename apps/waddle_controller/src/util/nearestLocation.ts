import type { WeatherLocationRow } from '@/api/interests';

const EARTH_RADIUS_KM = 6371;

/** Great-circle distance in kilometers between two WGS84 points. */
export function haversineDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(a));
}

/** Nearest catalog location within [maxDistanceKm], or null when none qualify. */
export function findNearestWeatherLocation(
  locations: WeatherLocationRow[],
  latitude: number,
  longitude: number,
  maxDistanceKm = 150,
): WeatherLocationRow | null {
  let best: WeatherLocationRow | null = null;
  let bestKm = Infinity;
  for (const row of locations) {
    const km = haversineDistanceKm(latitude, longitude, row.latitude, row.longitude);
    if (km < bestKm) {
      bestKm = km;
      best = row;
    }
  }
  if (best == null || bestKm > maxDistanceKm) {
    return null;
  }
  return best;
}
