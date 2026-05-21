import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/air_quality_openmeteo/open_meteo_air_quality_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/integrations/open_meteo_air_quality_kv_keys.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

class _AirQualityClient extends http.BaseClient {
  _AirQualityClient(this.body);

  final String body;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends += 1;
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _NoOpBlobs implements BlobStore {
  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  Future<List<int>> readBytes(BlobRef ref) async => const [];

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async =>
      BlobRef(logicalKey);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

String _airQualityBody() {
  return jsonEncode({
    'current': {
      'pm10': 12.1,
      'pm2_5': 8.4,
      'us_aqi': 42,
      'european_aqi': 25,
    },
    'current_units': {
      'pm10': 'μg/m³',
      'us_aqi': 'U.S. AQI',
    },
    'hourly': {
      'time': ['2024-06-01T13:00', '2024-06-01T14:00'],
      'pm10': [11.0, 10.5],
      'pm2_5': [7.0, 6.5],
      'us_aqi': [40, 38],
      'european_aqi': [24, 22],
    },
    'hourly_units': {
      'pm10': 'μg/m³',
      'us_aqi': 'U.S. AQI',
    },
  });
}

Future<DataWriteContextImpl> _ctx(AppDatabase db) async {
  final secrets = InMemorySecretStore();
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: _NoOpBlobs(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

void main() {
  test('collect writes KV keys per location', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    const integrationId = kDefaultAirQualityOpenMeteoIntegrationId;
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: integrationId,
            integrationType: kAirQualityOpenMeteoProviderId,
            pollSeconds: const Value(0),
            enabled: const Value(true),
            configJson: const Value(
              '{"hourlyCount":2,'
              '"defaultLocation":{"name":"Default","lat":40.71,"lon":-74.01}}',
            ),
          ),
        );
    final client = _AirQualityClient(_airQualityBody());
    final provider = OpenMeteoAirQualityDataProvider(
      httpClient: client,
      nowMs: () => 1_700_000_000_000,
    );
    await provider.collect(await _ctx(db));
    expect(client.sends, 1);

    final kv = IntegrationKvRepository(db);
    const locId = 'default';
    final currentRaw = await kv.getIntegrationValue(
      integrationId,
      openMeteoAirQualityLocationCurrentKey(locId),
    );
    expect(currentRaw, isNotNull);
    final current = jsonDecode(currentRaw!) as Map<String, dynamic>;
    expect(current['location_id'], locId);
    expect(current['us_aqi'], 42);
    expect(current['pm2_5'], 8.4);

    final hourlyRaw = await kv.getIntegrationValue(
      integrationId,
      openMeteoAirQualityLocationHourlyKey(locId),
    );
    final hourly = jsonDecode(hourlyRaw!) as List<dynamic>;
    expect(hourly.length, 2);

    final collectedRaw = await kv.getIntegrationValue(
      integrationId,
      openMeteoAirQualityLocationCollectedAtKey(locId),
    );
    expect(collectedRaw, '1700000000000');

    final rows = await (db.select(db.integrationsKeyValue)
          ..where((t) => t.integrationId.equals(integrationId)))
        .get();
    final currentRow = rows.firstWhere(
      (r) => r.key == openMeteoAirQualityLocationCurrentKey(locId),
    );
    expect(currentRow.valueType, kIntegrationKvTypeJson);
    await db.close();
  });

  test('collect respects poll_seconds gate', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    const integrationId = kDefaultAirQualityOpenMeteoIntegrationId;
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: integrationId,
            integrationType: kAirQualityOpenMeteoProviderId,
            pollSeconds: const Value(900),
            enabled: const Value(true),
            configJson: const Value(
              '{"hourlyCount":2,'
              '"defaultLocation":{"name":"Default","lat":40.71,"lon":-74.01}}',
            ),
          ),
        );
    final kv = IntegrationKvRepository(db);
    await kv.upsertIntegration(
      integrationId: integrationId,
      key: kIntegrationLastCollectKey,
      value: '1700000000000',
      valueType: kIntegrationKvTypeIntMs,
    );
    final client = _AirQualityClient(_airQualityBody());
    final provider = OpenMeteoAirQualityDataProvider(
      httpClient: client,
      nowMs: () => 1_700_000_100_000,
    );
    await provider.collect(await _ctx(db));
    expect(client.sends, 0);
    await db.close();
  });
}
