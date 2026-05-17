import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/weather_openweathermap/weather_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _WeatherClient extends http.BaseClient {
  _WeatherClient(this.onRequest);

  final http.Response Function(Uri uri) onRequest;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends += 1;
    final response = onRequest(request.url);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class _ThrowingWeatherClient extends http.BaseClient {
  _ThrowingWeatherClient(this.error);

  final Object error;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends += 1;
    throw error;
  }
}

/// OpenWeather Current Weather API 2.5 response shape (`/data/2.5/weather`).
String _payload({required double temp, required String desc}) {
  return jsonEncode({
    'dt': 1714960000,
    'main': {'temp': temp},
    'weather': [
      {'description': desc, 'icon': '10d'},
    ],
  });
}

/// OpenWeather Forecast API 2.5 response shape (`/data/2.5/forecast`).
String _forecastPayload({required double baseTemp}) {
  return jsonEncode({
    'list': [
      {
        'dt': 1714963600,
        'main': {'temp': baseTemp + 1},
        'weather': [
          {'description': 'hour1', 'icon': '01d'},
        ],
      },
      {
        'dt': 1714967200,
        'main': {'temp': baseTemp + 2},
        'weather': [
          {'description': 'hour2', 'icon': '02d'},
        ],
      },
      {
        'dt': 1714970800,
        'main': {'temp': baseTemp + 3},
        'weather': [
          {'description': 'hour3', 'icon': '03d'},
        ],
      },
    ],
  });
}

Future<DataWriteContextImpl> _ctx(
  AppDatabase db,
  InMemorySecretStore secrets, {
  String? apiKey,
}) async {
  if (apiKey != null) {
    await secrets.write(
      providerAccessTokenSecretKey('weather_openweathermap'),
      apiKey,
    );
  }
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

void main() {
  test('collect skips when weather token missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherOpenWeatherMapIntegrationId,
            integrationType: 'weather_openweathermap',
            pollSeconds: const Value(60),
          ),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets);
    final client = _WeatherClient((_) => http.Response(_payload(temp: 70, desc: 'clear'), 200));
    final provider = WeatherDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 0);
    final rows = await db.select(db.weatherCurrent).get();
    expect(rows, isEmpty);
    await db.close();
  });

  test('collect writes weather payload to weather tables', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherOpenWeatherMapIntegrationId,
            integrationType: 'weather_openweathermap',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.openweathermap.org'),
            configJson: const Value(
              '{"defaultLocation":{"name":"NYC","lat":40.7128,"lon":-74.0060},"hourlyCount":2}',
            ),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
          ),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'owm-key');

    final client = _WeatherClient((uri) {
      if (uri.path.endsWith('/data/2.5/forecast')) {
        return http.Response(
          _forecastPayload(baseTemp: 71.5),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        _payload(temp: 71.5, desc: 'light rain'),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final provider = WeatherDataProvider(
      httpClient: client,
      nowMs: () => 2000,
    );
    await provider.collect(ctx);

    expect(client.sends, 3);
    final nyc = await (db.select(db.weatherCurrent)
          ..where((t) => t.locationId.equals('nyc')))
        .getSingleOrNull();
    expect(nyc, isNotNull);
    expect(nyc!.currentTemp, closeTo(71.5, 0.001));
    expect(nyc.currentDescription, 'light rain');
    expect(nyc.observedAtMs, DateTime.fromMillisecondsSinceEpoch(2000));
    final hourly = jsonDecode(nyc.hourlyJson ?? '[]') as List<dynamic>;
    expect(hourly, hasLength(2));
    expect((hourly.first as Map<String, dynamic>)['description'], 'hour1');
    await db.close();
  });

  test('collect fetches all enabled configured weather locations', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherOpenWeatherMapIntegrationId,
            integrationType: 'weather_openweathermap',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.openweathermap.org'),
            configJson: const Value(
              '{"defaultLocation":{"name":"NYC","lat":40.7128,"lon":-74.0060},"hourlyCount":2}',
            ),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'denver',
            name: 'Denver',
            latitude: 39.7392,
            longitude: -104.9903,
          ),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'owm-key');

    final seen = <String>[];
    final client = _WeatherClient((uri) {
      seen.add(uri.toString());
      if (uri.path.endsWith('/data/2.5/forecast')) {
        final lat = uri.queryParameters['lat'];
        if (lat == '39.7392') {
          return http.Response(_forecastPayload(baseTemp: 50), 200);
        }
        return http.Response(_forecastPayload(baseTemp: 70), 200);
      }
      final lat = uri.queryParameters['lat'];
      if (lat == '39.7392') {
        return http.Response(_payload(temp: 50, desc: 'snow'), 200);
      }
      return http.Response(_payload(temp: 70, desc: 'sunny'), 200);
    });
    final provider = WeatherDataProvider(httpClient: client, nowMs: () => 3000);

    await provider.collect(ctx);

    expect(client.sends, 6);
    final nyc = await (db.select(db.weatherCurrent)
          ..where((t) => t.locationId.equals('nyc')))
        .getSingleOrNull();
    final denver = await (db.select(db.weatherCurrent)
          ..where((t) => t.locationId.equals('denver')))
        .getSingleOrNull();
    expect(nyc, isNotNull);
    expect(denver, isNotNull);
    expect(seen.any((u) => u.contains('lat=39.7392')), isTrue);
    await db.close();
  });

  test('collect stores weather icon in blob metadata', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherOpenWeatherMapIntegrationId,
            integrationType: 'weather_openweathermap',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.openweathermap.org'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
          ),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'owm-key');
    final client = _WeatherClient((uri) {
      if (uri.path.contains('/img/wn/')) {
        return http.Response.bytes(
          const <int>[0x89, 0x50, 0x4e, 0x47],
          200,
          headers: {'content-type': 'image/png'},
        );
      }
      if (uri.path.endsWith('/data/2.5/forecast')) {
        return http.Response(_forecastPayload(baseTemp: 71.5), 200);
      }
      return http.Response(_payload(temp: 71.5, desc: 'light rain'), 200);
    });
    final provider = WeatherDataProvider(httpClient: client, nowMs: () => 2000);
    await provider.collect(ctx);

    final weather = await db.select(db.weatherCurrent).getSingle();
    expect(weather.currentIconBlobKey, isNotNull);
    final blob = await db.select(db.blobMetadata).getSingle();
    expect(blob.blobKey, startsWith('weather/icons/10d'));
    await db.close();
  });

  test('collect swallows client socket failures and continues safely', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherOpenWeatherMapIntegrationId,
            integrationType: 'weather_openweathermap',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.openweathermap.org'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
          ),
        );
    final secrets = InMemorySecretStore();
    final ctx = await _ctx(db, secrets, apiKey: 'owm-key');
    final client = _ThrowingWeatherClient(
      http.ClientException(
        'socket failed',
        Uri.parse('https://api.openweathermap.org/data/2.5/weather'),
      ),
    );
    final provider = WeatherDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    final rows = await db.select(db.weatherCurrent).get();
    expect(rows, isEmpty);
    await db.close();
  });
}
