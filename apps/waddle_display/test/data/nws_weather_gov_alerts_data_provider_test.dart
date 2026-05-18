import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/weather_alerts_nws/nws_weather_gov_alerts_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _NwsClient extends http.BaseClient {
  _NwsClient(this.onRequest);

  final http.Response Function(Uri uri, Map<String, String> headers) onRequest;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends += 1;
    final h = <String, String>{};
    request.headers.forEach((k, v) {
      h[k] = v;
    });
    final response = onRequest(request.url, h);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

String _geoJson({
  required String alertId,
  required String event,
  String headline = 'Headline text',
  String? description,
}) {
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': {
          'id': alertId,
          'event': event,
          'headline': headline,
          'severity': 'Severe',
          'effective': '2026-05-01T12:00:00+00:00',
          'expires': '2026-05-02T12:00:00+00:00',
          'description': description ?? 'Line one.\n\nLine two.',
        },
      },
    ],
  });
}

Future<DataWriteContextImpl> _ctx(AppDatabase db, InMemorySecretStore secrets) async {
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

void main() {
  test('collect skips when provider disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            enabled: const Value(false),
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value('{}'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _NwsClient(
      (uri, headers) {
        throw StateError('unexpected HTTP $uri');
      },
    );
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 0);
    await db.close();
  });

  test('collect skips when provider row missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _NwsClient(
      (uri, headers) {
        throw StateError('unexpected HTTP $uri');
      },
    );
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 0);
    await db.close();
  });

  test('collect writes NWS alerts for each enabled location', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value(
              '{"userAgent":"(test, test@example.com)","defaultLocation":{"name":"X","lat":0,"lon":0}}',
            ),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _NwsClient((uri, headers) {
      expect(headers['Accept'], 'application/geo+json');
      expect(headers['User-Agent'], '(test, test@example.com)');
      expect(uri.queryParameters['point'], '40.7128,-74.0060');
      return http.Response(
        _geoJson(alertId: 'urn:oid:1.2.3', event: 'Winter Storm Warning'),
        200,
        headers: {'content-type': 'application/geo+json'},
      );
    });
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    final rows = await db.select(db.weatherAlerts).get();
    expect(rows, hasLength(1));
    expect(rows.single.locationId, 'nyc');
    expect(rows.single.nwsAlertId, 'urn:oid:1.2.3');
    expect(rows.single.event, 'Winter Storm Warning');
    expect(rows.single.headline, 'Headline text');
    expect(rows.single.severity, 'Severe');
    expect(rows.single.descriptionExcerpt, isNotNull);
    expect(rows.single.descriptionExcerpt, contains('Line one'));
    await db.close();
  });

  test('collect replaces prior alerts for location', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value('{}'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    var call = 0;
    final client = _NwsClient((uri, headers) {
      expect(uri.path, contains('/alerts/active'));
      expect(headers['Accept'], isNotNull);
      call += 1;
      if (call == 1) {
        return http.Response(
          _geoJson(alertId: 'urn:a', event: 'First'),
          200,
        );
      }
      return http.Response(
        _geoJson(alertId: 'urn:b', event: 'Second'),
        200,
      );
    });
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);
    expect(await db.select(db.weatherAlerts).get(), hasLength(1));
    expect((await db.select(db.weatherAlerts).get()).single.event, 'First');

    await provider.collect(ctx);
    final rows = await db.select(db.weatherAlerts).get();
    expect(rows, hasLength(1));
    expect(rows.single.nwsAlertId, 'urn:b');
    expect(rows.single.event, 'Second');
    await db.close();
  });

  test('collect clears stored alerts when API returns empty features', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value('{}'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    await db.into(db.weatherAlerts).insert(
          WeatherAlertsCompanion.insert(
            locationId: 'nyc',
            nwsAlertId: 'urn:old',
            event: 'Old',
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _NwsClient(
      (uri, headers) => http.Response(
        jsonEncode({'type': 'FeatureCollection', 'features': []}),
        200,
      ),
    );
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(await db.select(db.weatherAlerts).get(), isEmpty);
    await db.close();
  });

  test('collect does not clear alerts on HTTP error', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value('{}'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    await db.into(db.weatherAlerts).insert(
          WeatherAlertsCompanion.insert(
            locationId: 'nyc',
            nwsAlertId: 'urn:stale',
            event: 'Old',
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _NwsClient(
      (uri, headers) {
        expect(uri.host, isNotEmpty);
        expect(headers['User-Agent'], isNotNull);
        return http.Response('error', 503);
      },
    );
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    final rows = await db.select(db.weatherAlerts).get();
    expect(rows, hasLength(1));
    expect(rows.single.event, 'Old');
    await db.close();
  });

  test('collect catches per-location errors without rethrowing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value('{}'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _NwsClient(
      (uri, headers) => throw StateError('network down'),
    );
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    await db.close();
  });

  test('collect stores truncated description excerpt for long text', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value('{}'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    final longDesc = List.filled(500, 'x').join();
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _NwsClient(
      (uri, headers) => http.Response(
        _geoJson(
          alertId: 'urn:long',
          event: 'Wall of text',
          description: longDesc,
        ),
        200,
      ),
    );
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    final row = (await db.select(db.weatherAlerts).get()).single;
    expect(row.descriptionExcerpt, isNotNull);
    expect(row.descriptionExcerpt!.length, lessThanOrEqualTo(401));
    expect(row.descriptionExcerpt!.endsWith('\u2026'), isTrue);
    await db.close();
  });

  test('collect skips HTTP and clears alerts when include_weather_alerts is false',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value('{}'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(false),
          ),
        );
    await db.into(db.weatherAlerts).insert(
          WeatherAlertsCompanion.insert(
            locationId: 'nyc',
            nwsAlertId: 'urn:old',
            event: 'Old',
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _NwsClient(
      (uri, headers) {
        throw StateError('unexpected HTTP $uri');
      },
    );
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 0);
    expect(await db.select(db.weatherAlerts).get(), isEmpty);
    await db.close();
  });

  test('collect requests only locations with include_weather_alerts true',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultWeatherAlertsNwsIntegrationId,
            integrationType: 'weather_alerts_nws',
            pollSeconds: const Value(60),
            baseUrl: const Value('https://api.weather.gov'),
            configJson: const Value('{}'),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'nyc',
            name: 'NYC',
            latitude: 40.7128,
            longitude: -74.0060,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(false),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'bos',
            name: 'Boston',
            latitude: 42.3601,
            longitude: -71.0589,
            includeWeather: const Value(true),
            includeWeatherAlerts: const Value(true),
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final requested = <String>[];
    final client = _NwsClient((uri, headers) {
      requested.add(uri.queryParameters['point']!);
      return http.Response(
        jsonEncode({'type': 'FeatureCollection', 'features': []}),
        200,
      );
    });
    final provider = NwsWeatherGovAlertsDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 1);
    expect(requested, ['42.3601,-71.0589']);
    await db.close();
  });
}
