import 'dart:convert';

import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/integrations/open_meteo_air_quality_kv_keys.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Writes [air_quality_openmeteo] per-location payloads to integration KV.
class OpenMeteoAirQualityKvStore {
  OpenMeteoAirQualityKvStore(this._kv);

  final IntegrationKvRepository _kv;

  factory OpenMeteoAirQualityKvStore.fromDb(AppDatabase db) =>
      OpenMeteoAirQualityKvStore(IntegrationKvRepository(db));

  Future<void> writeLocationSnapshot({
    required String integrationId,
    required String locationId,
    required Map<String, Object?> current,
    required List<Map<String, Object?>> hourly,
    required int collectedAtMs,
  }) async {
    await _kv.upsertIntegration(
      integrationId: integrationId,
      key: openMeteoAirQualityLocationCurrentKey(locationId),
      value: jsonEncode(current),
      valueType: kIntegrationKvTypeJson,
    );
    await _kv.upsertIntegration(
      integrationId: integrationId,
      key: openMeteoAirQualityLocationHourlyKey(locationId),
      value: jsonEncode(hourly),
      valueType: kIntegrationKvTypeJson,
    );
    await _kv.upsertIntegration(
      integrationId: integrationId,
      key: openMeteoAirQualityLocationCollectedAtKey(locationId),
      value: '$collectedAtMs',
      valueType: kIntegrationKvTypeIntMs,
    );
  }

  Future<void> touchLastCollectMs({
    required String integrationId,
    required int collectedAtMs,
  }) async {
    await _kv.upsertIntegration(
      integrationId: integrationId,
      key: kIntegrationLastCollectKey,
      value: '$collectedAtMs',
      valueType: kIntegrationKvTypeIntMs,
    );
  }
}
