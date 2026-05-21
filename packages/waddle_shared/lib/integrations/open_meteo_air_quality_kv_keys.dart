/// Integration KV keys for [air_quality_openmeteo] collector results.
///
/// Bind KV widgets with `integrationId` + [openMeteoAirQualityLocationCurrentKey].
const String kOpenMeteoAirQualityLocationKeyPrefix = 'air_quality.location.';

/// Per-location current readings JSON (`value_type`: `json`).
String openMeteoAirQualityLocationCurrentKey(String locationId) =>
    '$kOpenMeteoAirQualityLocationKeyPrefix$locationId.current';

/// Per-location hourly forecast JSON (`value_type`: `json`).
String openMeteoAirQualityLocationHourlyKey(String locationId) =>
    '$kOpenMeteoAirQualityLocationKeyPrefix$locationId.hourly';

/// Per-location last successful collect epoch ms (`value_type`: `int_ms`).
String openMeteoAirQualityLocationCollectedAtKey(String locationId) =>
    '$kOpenMeteoAirQualityLocationKeyPrefix$locationId.collected_at_ms';
