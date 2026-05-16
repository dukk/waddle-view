import 'package:waddle_shared/net/http_debug_uri.dart';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;

import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'weather_locations_for_collect.dart';
import 'weather_provider_extra_config.dart';

const String kWeatherProviderId = 'weather_openweathermap';
const String kDefaultOpenWeatherBaseUrl = 'https://api.openweathermap.org';

class WeatherDataProvider implements IDataProvider {
  WeatherDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kWeatherProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(ctx.db.integrations)
              ..where((t) => t.id.equals(kWeatherProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      ctx.diagnostics.provider('weather: skip (disabled)');
      return;
    }
    final config = await ctx.resolveConfig(kWeatherProviderId);
    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      ctx.diagnostics.provider('weather: skip (no API token)');
      return;
    }
    final extra = WeatherProviderExtraConfig.parse(config.configJson);
    final baseUrl = (config.baseUrl != null && config.baseUrl!.trim().isNotEmpty)
        ? config.baseUrl!.trim()
        : kDefaultOpenWeatherBaseUrl;
    final locations = await resolveWeatherLocationsForCollect(
      ctx.db,
      extra.defaultLocation,
    );
    final now = _nowMs();
    ctx.diagnostics.provider(
      'weather: collect locations=${locations.length} base=${safeHttpUriForLog(Uri.parse(baseUrl))}',
    );

    for (final location in locations) {
      try {
        final weatherUri = Uri.parse('$baseUrl/data/2.5/weather').replace(
          queryParameters: {
            'lat': location.lat.toStringAsFixed(4),
            'lon': location.lon.toStringAsFixed(4),
            'units': extra.units,
            'lang': extra.language,
            'appid': token,
          },
        );
        ctx.diagnostics.provider(
          'weather: GET current id=${location.id} lat=${location.lat} lon=${location.lon} '
          '${safeHttpUriForLog(weatherUri)}',
        );
        final weatherRes = await _safeGet(
          weatherUri,
          diagnostics: ctx.diagnostics,
          phase: 'current',
          locationId: location.id,
        );
        if (weatherRes == null) {
          continue;
        }
        if (weatherRes.statusCode != 200) {
          ctx.diagnostics.provider(
            'weather: current status=${weatherRes.statusCode} id=${location.id}',
          );
          continue;
        }
        final current = _normalizeCurrentWeatherPayload(weatherRes.body);
        if (current == null) {
          continue;
        }
        final forecastUri = Uri.parse('$baseUrl/data/2.5/forecast').replace(
          queryParameters: {
            'lat': location.lat.toStringAsFixed(4),
            'lon': location.lon.toStringAsFixed(4),
            'units': extra.units,
            'lang': extra.language,
            'appid': token,
          },
        );
        ctx.diagnostics.provider(
          'weather: GET forecast id=${location.id} '
          '${safeHttpUriForLog(forecastUri)}',
        );
        final forecastRes = await _safeGet(
          forecastUri,
          diagnostics: ctx.diagnostics,
          phase: 'forecast',
          locationId: location.id,
        );
        if (forecastRes == null) {
          continue;
        }
        final hourly = forecastRes.statusCode == 200
            ? _normalizeForecastPayload(forecastRes.body, extra.hourlyCount)
            : null;
        if (forecastRes.statusCode != 200) {
          ctx.diagnostics.provider(
            'weather: forecast status=${forecastRes.statusCode} id=${location.id}',
          );
        } else {
          ctx.diagnostics.provider(
            'weather: forecast ok id=${location.id} hourlyPoints=${hourly?.length ?? 0}',
          );
        }
        final currentIconCode = (current['icon'] as String?) ?? '';
        final currentIconBlobKey = await _storeIconIfPresent(
          ctx,
          baseUrl: baseUrl,
          iconCode: currentIconCode,
        );
        await ctx.db.into(ctx.db.weatherCurrent).insertOnConflictUpdate(
              WeatherCurrentCompanion.insert(
                locationId: location.id,
                observedAtMs: DateTime.fromMillisecondsSinceEpoch(now),
                currentTemp: Value((current['temp'] as num?)?.toDouble()),
                currentDescription: Value((current['description'] as String?)?.trim()),
                currentIconBlobKey: Value(currentIconBlobKey),
                hourlyJson: Value(jsonEncode(hourly ?? const <Map<String, dynamic>>[])),
              ),
            );
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail('weather: collect id=${location.id}', e, st);
      }
    }
  }

  Future<String?> _storeIconIfPresent(
    DataWriteContext ctx, {
    required String baseUrl,
    required String iconCode,
  }) async {
    final code = iconCode.trim();
    if (code.isEmpty) {
      return null;
    }
    final iconUrl = Uri.parse('$baseUrl/img/wn/$code@2x.png');
    ctx.diagnostics.provider(
      'weather: GET icon code=$code ${safeHttpUriForLog(iconUrl)}',
    );
    final res = await _safeGet(
      iconUrl,
      diagnostics: ctx.diagnostics,
      phase: 'icon',
      locationId: code,
    );
    if (res == null) {
      return null;
    }
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      ctx.diagnostics.provider(
        'weather: icon code=$code status=${res.statusCode} bytes=${res.bodyBytes.length}',
      );
      return null;
    }
    final logicalKey = 'weather/icons/$code@2x.png';
    final ref = await ctx.blobs.putBytes(
      res.bodyBytes,
      logicalKey: logicalKey,
    );
    ctx.diagnostics.provider(
      'weather: stored icon code=$code bytes=${res.bodyBytes.length} blobKey=$logicalKey',
    );
    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
          BlobMetadataCompanion.insert(
            blobKey: logicalKey,
            sha256: ref.storageKey.split('/').last,
            relativePath: ref.storageKey,
            bytes: res.bodyBytes.length,
            mimeType: Value(res.headers['content-type']?.split(';').first.trim()),
            capturedAt: DateTime.fromMillisecondsSinceEpoch(_nowMs()),
          ),
        );
    return logicalKey;
  }

  /// Normalizes [OpenWeather Current Weather 2.5](https://openweathermap.org/current)
  /// JSON.
  Map<String, dynamic>? _normalizeCurrentWeatherPayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final main = decoded['main'];
      if (main is! Map<String, dynamic>) {
        return null;
      }
      return {
        'dt': (decoded['dt'] as num?)?.toInt(),
        'temp': (main['temp'] as num?)?.toDouble(),
        'description': _weatherDescription(decoded),
        'icon': _weatherIcon(decoded),
      };
    } on Object {
      return null;
    }
  }

  /// Normalizes [OpenWeather Forecast 2.5](https://openweathermap.org/forecast5)
  /// JSON into a compact list used by [WeatherSlideWidget].
  List<Map<String, dynamic>>? _normalizeForecastPayload(String body, int hourlyCount) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final listRaw = decoded['list'];
      if (listRaw is! List) {
        return null;
      }
      final hourlyOut = <Map<String, dynamic>>[];
      for (final item in listRaw.take(hourlyCount)) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final main = item['main'];
        hourlyOut.add({
          'dt': (item['dt'] as num?)?.toInt(),
          'temp': (main is Map<String, dynamic>) ? (main['temp'] as num?)?.toDouble() : null,
          'description': _weatherDescription(item),
          'icon': _weatherIcon(item),
        });
      }
      return hourlyOut;
    } on Object {
      return null;
    }
  }

  String _weatherDescription(Map<String, dynamic> source) {
    final list = source['weather'];
    if (list is List && list.isNotEmpty && list.first is Map<String, dynamic>) {
      final first = list.first as Map<String, dynamic>;
      final value = first['description'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _weatherIcon(Map<String, dynamic> source) {
    final list = source['weather'];
    if (list is List && list.isNotEmpty && list.first is Map<String, dynamic>) {
      final first = list.first as Map<String, dynamic>;
      final value = first['icon'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  Future<http.Response?> _safeGet(
    Uri uri, {
    required CollectDiagnostics diagnostics,
    required String phase,
    required String locationId,
  }) async {
    try {
      final res = await _http.get(uri);
      diagnostics.provider(
        'weather: $phase ok location=$locationId status=${res.statusCode} '
        'bytes=${res.bodyBytes.length}',
      );
      return res;
    } on http.ClientException catch (e, st) {
      diagnostics.providerFail(
        'weather: $phase request failed location=$locationId',
        e,
        st,
      );
      return null;
    } on SocketException catch (e, st) {
      diagnostics.providerFail(
        'weather: $phase socket failed location=$locationId',
        e,
        st,
      );
      return null;
    } on Object catch (e, st) {
      diagnostics.providerFail(
        'weather: $phase unexpected request error location=$locationId',
        e,
        st,
      );
      return null;
    }
  }
}
