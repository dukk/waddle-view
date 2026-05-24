import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/weather_openmeteo/open_meteo_weather_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

class _ForecastClient extends http.BaseClient {
  _ForecastClient(this.body);

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
  Future<BlobRef> putBytes(
    List<int> bytes, {
    required String logicalKey,
  }) async => BlobRef(logicalKey);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

String _openMeteoForecastBody() {
  return jsonEncode({
    'current': {
      'time': '2024-06-01T12:00',
      'temperature_2m': 72.5,
      'weather_code': 0,
    },
    'hourly': {
      'time': ['2024-06-01T13:00', '2024-06-01T14:00'],
      'temperature_2m': [73.0, 74.0],
      'weather_code': [1, 61],
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
  test('collect skips when integration disabled', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    final client = _ForecastClient(_openMeteoForecastBody());
    final provider = OpenMeteoWeatherDataProvider(httpClient: client);
    final ctx = await _ctx(db);
    await provider.collect(ctx);
    expect(client.sends, 0);
    await db.close();
  });

  test('collect writes weather_current for default location', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    await db
        .into(db.integrations)
        .insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherOpenMeteoIntegrationId,
            integrationType: kWeatherOpenMeteoProviderId,
            pollSeconds: const Value(60),
            enabled: const Value(true),
            configJson: const Value(
              '{"units":"imperial","hourlyCount":2,'
              '"defaultLocation":{"name":"Default","lat":40.71,"lon":-74.01}}',
            ),
          ),
        );
    final client = _ForecastClient(_openMeteoForecastBody());
    final provider = OpenMeteoWeatherDataProvider(
      httpClient: client,
      nowMs: () => 1_700_000_000_000,
    );
    await provider.collect(await _ctx(db));
    expect(client.sends, 1);

    final row = await (db.select(
      db.weatherCurrent,
    )..where((t) => t.locationId.equals('default'))).getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.currentTemp, closeTo(22.5, 0.01));
    expect(row.currentDescription, 'Clear sky');
    final hourly = jsonDecode(row.hourlyJson ?? '[]') as List<dynamic>;
    expect(hourly.length, 2);
    expect((hourly.first as Map)['description'], 'Mainly clear');
    expect((hourly.first as Map)['temp'], closeTo(22.778, 0.01));
    expect((hourly[1] as Map)['temp'], closeTo(23.333, 0.01));
    await db.close();
  });

  test('collect stores metric API temperatures as Celsius unchanged', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    await db
        .into(db.integrations)
        .insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherOpenMeteoIntegrationId,
            integrationType: kWeatherOpenMeteoProviderId,
            pollSeconds: const Value(60),
            enabled: const Value(true),
            configJson: const Value(
              '{"units":"metric","hourlyCount":1,'
              '"defaultLocation":{"name":"Default","lat":40.71,"lon":-74.01}}',
            ),
          ),
        );
    final client = _ForecastClient(_openMeteoForecastBody());
    final provider = OpenMeteoWeatherDataProvider(httpClient: client);
    await provider.collect(await _ctx(db));

    final row = await (db.select(
      db.weatherCurrent,
    )..where((t) => t.locationId.equals('default'))).getSingleOrNull();
    expect(row!.currentTemp, closeTo(72.5, 0.01));
    await db.close();
  });
}
