import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/database.dart';

/// Ids of the default world-city catalog (five megacities, one per country).
const Set<String> kDefaultWeatherLocationCatalogIds = {
  'tokyo_jp',
  'delhi_in',
  'shanghai_cn',
  'sao_paulo_br',
  'new_york_ny',
};

/// Former catalog ids removed in schema 39 (do not delete operator-created rows).
const Set<String> kRetiredDefaultWeatherLocationCatalogIds = {
  'salt_lake_city_ut',
  'atlanta_ga',
  'sandiego_ca',
  'miami_fl',
  'denver_co',
  'las_vegas_nv',
  'phoenix_az',
  'seattle_wa',
  'washington_dc',
  'boston_ma',
  'chicago_il',
  'houston_tx',
  'austin_tx',
  'san_francisco_ca',
  'toronto_ca',
  'vancouver_bc',
  'montreal_qc',
  'mexico_city_mx',
  'london_gb',
  'paris_fr',
  'berlin_de',
  'madrid_es',
  'rome_it',
  'amsterdam_nl',
  'dublin_ie',
  'stockholm_se',
  'zurich_ch',
  'athens_gr',
  'warsaw_pl',
  'lisbon_pt',
  'istanbul_tr',
  'vienna_at',
  'oslo_no',
  'copenhagen_dk',
  'prague_cz',
  'mumbai_in',
  'beijing_cn',
  'dubai_ae',
  'singapore_sg',
  'seoul_kr',
  'hong_kong_hk',
  'bangkok_th',
  'jakarta_id',
  'manila_ph',
  'taipei_tw',
  'riyadh_sa',
  'kuala_lumpur_my',
  'ho_chi_minh_city_vn',
  'buenos_aires_ar',
  'lima_pe',
  'santiago_cl',
  'bogota_co',
  'rio_de_janeiro_br',
  'caracas_ve',
  'cairo_eg',
  'johannesburg_za',
  'lagos_ng',
  'nairobi_ke',
  'casablanca_ma',
  'cape_town_za',
  'addis_ababa_et',
  'sydney_au',
  'melbourne_au',
  'auckland_nz',
  'wellington_nz',
  'suva_fj',
  'port_moresby_pg',
  'honolulu_hi',
};

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

const _general = 'general';

const _defaultWeatherLocations = <_WeatherSeed>[
  (id: 'tokyo_jp', name: 'Tokyo, Japan', latitude: 35.6762, longitude: 139.6503, category: _general, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'delhi_in', name: 'Delhi, India', latitude: 28.7041, longitude: 77.1025, category: _general, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'shanghai_cn', name: 'Shanghai, China', latitude: 31.2304, longitude: 121.4737, category: _general, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'sao_paulo_br', name: 'São Paulo, Brazil', latitude: -23.5505, longitude: -46.6333, category: _general, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
  (id: 'new_york_ny', name: 'New York, NY', latitude: 40.7128, longitude: -74.0060, category: _general, includeWeather: false, includeWeatherAlerts: false, includeLocalNews: false),
];
