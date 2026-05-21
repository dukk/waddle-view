import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../weather_openweathermap/weather_locations_for_collect.dart';
import '../weather_openweathermap/weather_provider_extra_config.dart';
import 'open_meteo_http.dart';
import 'wmo_weather_code.dart';

const String kWeatherOpenMeteoProviderId = 'weather_openmeteo';
const String kDefaultOpenMeteoWeatherBaseUrl = 'https://api.open-meteo.com';

class OpenMeteoWeatherDataProvider implements IDataProvider {
  OpenMeteoWeatherDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kWeatherOpenMeteoProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final settings = await enabledIntegrationsForType(ctx.db, id);
    if (settings.isEmpty) {
      ctx.diagnostics.provider('open_meteo_weather: skip (disabled)');
      return;
    }
    final setting = settings.first;
    final config = await ctx.resolveConfig(setting.id);
    final extra = WeatherProviderExtraConfig.parse(config.configJson);
    final baseUrl = normalizeOpenMeteoBaseUrl(
      config.baseUrl,
      kDefaultOpenMeteoWeatherBaseUrl,
    );
    final locations = await resolveWeatherLocationsForCollect(
      ctx.db,
      extra.defaultLocation,
    );
    final tempUnit = _temperatureUnit(extra.units);
    ctx.diagnostics.provider(
      'open_meteo_weather: collect locations=${locations.length} '
      'base=${normalizeOpenMeteoBaseUrl(baseUrl, kDefaultOpenMeteoWeatherBaseUrl)}',
    );

    for (final location in locations) {
      try {
        await ensureSyntheticDefaultInterestsLocation(ctx.db, location);
        final uri = Uri.parse('$baseUrl/v1/forecast').replace(
          queryParameters: {
            'latitude': location.lat.toStringAsFixed(4),
            'longitude': location.lon.toStringAsFixed(4),
            'current': 'temperature_2m,weather_code',
            'hourly': 'temperature_2m,weather_code',
            'forecast_hours': '${extra.hourlyCount}',
            'temperature_unit': tempUnit,
            'timezone': 'auto',
          },
        );
        final res = await openMeteoSafeGet(
          _http,
          uri,
          diagnostics: ctx.diagnostics,
          logLabel: 'open_meteo_weather',
          locationId: location.id,
        );
        if (res == null || res.statusCode != 200) {
          if (res != null) {
            ctx.diagnostics.provider(
              'open_meteo_weather: status=${res.statusCode} id=${location.id}',
            );
          }
          continue;
        }
        final normalized = _normalizeForecastPayload(
          res.body,
          hourlyCount: extra.hourlyCount,
        );
        if (normalized == null) {
          continue;
        }
        final now = _nowMs();
        await ctx.db.into(ctx.db.weatherCurrent).insertOnConflictUpdate(
              WeatherCurrentCompanion.insert(
                locationId: location.id,
                observedAtMs: DateTime.fromMillisecondsSinceEpoch(
                  normalized.observedAtMs ?? now,
                ),
                currentTemp: Value(normalized.currentTemp),
                currentDescription: Value(normalized.currentDescription),
                currentIconBlobKey: const Value.absent(),
                hourlyJson: Value(jsonEncode(normalized.hourly)),
              ),
            );
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail(
          'open_meteo_weather: collect id=${location.id}',
          e,
          st,
        );
      }
    }
  }

  static String _temperatureUnit(String units) {
    final u = units.trim().toLowerCase();
    if (u == 'imperial' || u == 'fahrenheit' || u == 'f') {
      return 'fahrenheit';
    }
    return 'celsius';
  }
}

class _NormalizedWeather {
  const _NormalizedWeather({
    required this.currentTemp,
    required this.currentDescription,
    required this.hourly,
    this.observedAtMs,
  });

  final double? currentTemp;
  final String currentDescription;
  final List<Map<String, dynamic>> hourly;
  final int? observedAtMs;
}

_NormalizedWeather? _normalizeForecastPayload(
  String body, {
  required int hourlyCount,
}) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final current = decoded['current'];
    if (current is! Map<String, dynamic>) {
      return null;
    }
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    final currentTemp = (current['temperature_2m'] as num?)?.toDouble();
    final observedAtMs = _parseIsoTimeToEpochMs(current['time'] as String?);

    final hourlyOut = <Map<String, dynamic>>[];
    final hourly = decoded['hourly'];
    if (hourly is Map<String, dynamic>) {
      final times = hourly['time'];
      final temps = hourly['temperature_2m'];
      final codes = hourly['weather_code'];
      if (times is List && temps is List && codes is List) {
        final limit = hourlyCount > 0 ? hourlyCount : times.length;
        for (var i = 0; i < times.length && hourlyOut.length < limit; i++) {
          final timeRaw = times[i];
          final tempRaw = i < temps.length ? temps[i] : null;
          final codeRaw = i < codes.length ? codes[i] : null;
          if (timeRaw is! String) {
            continue;
          }
          final dt = _parseIsoTimeToEpochMs(timeRaw);
          if (dt == null) {
            continue;
          }
          final wmo = (codeRaw as num?)?.toInt() ?? 0;
          hourlyOut.add({
            'dt': dt ~/ 1000,
            'temp': (tempRaw as num?)?.toDouble(),
            'description': wmoWeatherDescription(wmo),
            'icon': wmoWeatherOpenWeatherIcon(wmo),
          });
        }
      }
    }

    return _NormalizedWeather(
      currentTemp: currentTemp,
      currentDescription: wmoWeatherDescription(code),
      hourly: hourlyOut,
      observedAtMs: observedAtMs,
    );
  } on Object {
    return null;
  }
}

int? _parseIsoTimeToEpochMs(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    return DateTime.parse(raw.trim()).millisecondsSinceEpoch;
  } on Object {
    return null;
  }
}
