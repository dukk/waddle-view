import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/weather_location_category.dart';

/// Default catalog locations (idempotent; refreshes name/coords/category on conflict).
Future<void> ensureDefaultInterestsLocations(AppDatabase db) async {
  for (final row in _defaultWeatherLocations) {
    final existing = await (db.select(db.interestsLocations)
          ..where((t) => t.id.equals(row.id)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.interestsLocations)..where((t) => t.id.equals(row.id))).write(
        InterestsLocationsCompanion(
          name: Value(row.name),
          latitude: Value(row.latitude),
          longitude: Value(row.longitude),
          category: Value(row.category),
        ),
      );
      continue;
    }
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: row.id,
            name: row.name,
            latitude: row.latitude,
            longitude: row.longitude,
            category: Value(row.category),
            includeWeather: Value(row.includeWeather),
            includeWeatherAlerts: Value(row.includeWeatherAlerts),
            includeLocalNews: Value(row.includeLocalNews),
          ),
        );
  }
}

typedef _WeatherSeed = ({
  String id,
  String name,
  double latitude,
  double longitude,
  String category,
  bool includeWeather,
  bool includeWeatherAlerts,
  bool includeLocalNews,
});

const _na = kWeatherLocationRegionNorthAmerica;
const _eu = kWeatherLocationRegionEurope;
const _as = kWeatherLocationRegionAsia;
const _sa = kWeatherLocationRegionSouthAmerica;
const _af = kWeatherLocationRegionAfrica;
const _oc = kWeatherLocationRegionOceania;

const _defaultWeatherLocations = <_WeatherSeed>[
  // North America
  (id: 'salt_lake_city_ut', name: 'Salt Lake City, UT', latitude: 40.7608, longitude: -111.8910, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'atlanta_ga', name: 'Atlanta, GA', latitude: 33.7490, longitude: -84.3880, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'sandiego_ca', name: 'San Diego, CA', latitude: 32.7157, longitude: -117.1611, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'miami_fl', name: 'Miami, FL', latitude: 25.7617, longitude: -80.1918, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'denver_co', name: 'Denver, CO', latitude: 39.7392, longitude: -104.9903, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'las_vegas_nv', name: 'Las Vegas, NV', latitude: 36.1699, longitude: -115.1398, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'phoenix_az', name: 'Phoenix, AZ', latitude: 33.4483, longitude: -112.0740, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'seattle_wa', name: 'Seattle, WA', latitude: 47.6062, longitude: -122.3321, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'washington_dc', name: 'Washington, DC', latitude: 38.8951, longitude: -77.0369, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'boston_ma', name: 'Boston, MA', latitude: 42.3601, longitude: -71.0589, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'chicago_il', name: 'Chicago, IL', latitude: 41.8781, longitude: -87.6298, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'houston_tx', name: 'Houston, TX', latitude: 29.7604, longitude: -95.3698, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'austin_tx', name: 'Austin, TX', latitude: 30.2672, longitude: -97.7431, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'san_francisco_ca', name: 'San Francisco, CA', latitude: 37.7749, longitude: -122.4194, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'new_york_ny', name: 'New York, NY', latitude: 40.7128, longitude: -74.0060, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'toronto_ca', name: 'Toronto, Canada', latitude: 43.6532, longitude: -79.3832, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'vancouver_bc', name: 'Vancouver, Canada', latitude: 49.2827, longitude: -123.1207, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'montreal_qc', name: 'Montreal, Canada', latitude: 45.5019, longitude: -73.5674, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'mexico_city_mx', name: 'Mexico City, Mexico', latitude: 19.4326, longitude: -99.1332, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  // Europe
  (id: 'london_gb', name: 'London, United Kingdom', latitude: 51.5074, longitude: -0.1278, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'paris_fr', name: 'Paris, France', latitude: 48.8566, longitude: 2.3522, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'berlin_de', name: 'Berlin, Germany', latitude: 52.5200, longitude: 13.4050, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'madrid_es', name: 'Madrid, Spain', latitude: 40.4168, longitude: -3.7038, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'rome_it', name: 'Rome, Italy', latitude: 41.9028, longitude: 12.4964, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'amsterdam_nl', name: 'Amsterdam, Netherlands', latitude: 52.3676, longitude: 4.9041, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'dublin_ie', name: 'Dublin, Ireland', latitude: 53.3498, longitude: -6.2603, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'stockholm_se', name: 'Stockholm, Sweden', latitude: 59.3293, longitude: 18.0686, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'zurich_ch', name: 'Zurich, Switzerland', latitude: 47.3769, longitude: 8.5417, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'athens_gr', name: 'Athens, Greece', latitude: 37.9838, longitude: 23.7275, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'warsaw_pl', name: 'Warsaw, Poland', latitude: 52.2297, longitude: 21.0122, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'lisbon_pt', name: 'Lisbon, Portugal', latitude: 38.7223, longitude: -9.1393, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'istanbul_tr', name: 'Istanbul, Turkey', latitude: 41.0082, longitude: 28.9784, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'vienna_at', name: 'Vienna, Austria', latitude: 48.2082, longitude: 16.3738, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'oslo_no', name: 'Oslo, Norway', latitude: 59.9139, longitude: 10.7522, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'copenhagen_dk', name: 'Copenhagen, Denmark', latitude: 55.6761, longitude: 12.5683, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'prague_cz', name: 'Prague, Czech Republic', latitude: 50.0755, longitude: 14.4378, category: _eu, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  // Asia
  (id: 'tokyo_jp', name: 'Tokyo, Japan', latitude: 35.6762, longitude: 139.6503, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'mumbai_in', name: 'Mumbai, India', latitude: 19.0760, longitude: 72.8777, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'beijing_cn', name: 'Beijing, China', latitude: 39.9042, longitude: 116.4074, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'dubai_ae', name: 'Dubai, United Arab Emirates', latitude: 25.2048, longitude: 55.2708, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'singapore_sg', name: 'Singapore', latitude: 1.3521, longitude: 103.8198, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'seoul_kr', name: 'Seoul, South Korea', latitude: 37.5665, longitude: 126.9780, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'hong_kong_hk', name: 'Hong Kong', latitude: 22.3193, longitude: 114.1694, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'bangkok_th', name: 'Bangkok, Thailand', latitude: 13.7563, longitude: 100.5018, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'jakarta_id', name: 'Jakarta, Indonesia', latitude: -6.2088, longitude: 106.8456, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'manila_ph', name: 'Manila, Philippines', latitude: 14.5995, longitude: 120.9842, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'taipei_tw', name: 'Taipei, Taiwan', latitude: 25.0330, longitude: 121.5654, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'delhi_in', name: 'Delhi, India', latitude: 28.7041, longitude: 77.1025, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'riyadh_sa', name: 'Riyadh, Saudi Arabia', latitude: 24.7136, longitude: 46.6753, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'kuala_lumpur_my', name: 'Kuala Lumpur, Malaysia', latitude: 3.1390, longitude: 101.6869, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'ho_chi_minh_city_vn', name: 'Ho Chi Minh City, Vietnam', latitude: 10.8231, longitude: 106.6297, category: _as, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  // South America
  (id: 'sao_paulo_br', name: 'São Paulo, Brazil', latitude: -23.5505, longitude: -46.6333, category: _sa, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'buenos_aires_ar', name: 'Buenos Aires, Argentina', latitude: -34.6037, longitude: -58.3816, category: _sa, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'lima_pe', name: 'Lima, Peru', latitude: -12.0464, longitude: -77.0428, category: _sa, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'santiago_cl', name: 'Santiago, Chile', latitude: -33.4489, longitude: -70.6693, category: _sa, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'bogota_co', name: 'Bogotá, Colombia', latitude: 4.7110, longitude: -74.0721, category: _sa, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'rio_de_janeiro_br', name: 'Rio de Janeiro, Brazil', latitude: -22.9068, longitude: -43.1729, category: _sa, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'caracas_ve', name: 'Caracas, Venezuela', latitude: 10.4806, longitude: -66.9036, category: _sa, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  // Africa
  (id: 'cairo_eg', name: 'Cairo, Egypt', latitude: 30.0444, longitude: 31.2357, category: _af, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'johannesburg_za', name: 'Johannesburg, South Africa', latitude: -26.2041, longitude: 28.0473, category: _af, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'lagos_ng', name: 'Lagos, Nigeria', latitude: 6.5244, longitude: 3.3792, category: _af, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'nairobi_ke', name: 'Nairobi, Kenya', latitude: -1.2921, longitude: 36.8219, category: _af, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'casablanca_ma', name: 'Casablanca, Morocco', latitude: 33.5731, longitude: -7.5898, category: _af, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'cape_town_za', name: 'Cape Town, South Africa', latitude: -33.9249, longitude: 18.4241, category: _af, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'addis_ababa_et', name: 'Addis Ababa, Ethiopia', latitude: 9.0320, longitude: 38.7469, category: _af, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  // Oceania (Australia, New Zealand, and Pacific islands)
  (id: 'sydney_au', name: 'Sydney, Australia', latitude: -33.8688, longitude: 151.2093, category: _oc, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'melbourne_au', name: 'Melbourne, Australia', latitude: -37.8136, longitude: 144.9631, category: _oc, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'auckland_nz', name: 'Auckland, New Zealand', latitude: -36.8485, longitude: 174.7633, category: _oc, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'wellington_nz', name: 'Wellington, New Zealand', latitude: -41.2865, longitude: 174.7762, category: _oc, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'suva_fj', name: 'Suva, Fiji', latitude: -18.1416, longitude: 178.4419, category: _oc, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'port_moresby_pg', name: 'Port Moresby, Papua New Guinea', latitude: -9.4438, longitude: 147.1803, category: _oc, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'honolulu_hi', name: 'Honolulu, HI', latitude: 21.3069, longitude: -157.8583, category: _na, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
];
