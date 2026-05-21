import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../weather_openmeteo/open_meteo_http.dart';
import '../weather_openweathermap/weather_locations_for_collect.dart';
import '../weather_openweathermap/weather_provider_extra_config.dart';
import 'open_meteo_air_quality_kv_store.dart';

const String kAirQualityOpenMeteoProviderId = 'air_quality_openmeteo';
const String kDefaultOpenMeteoAirQualityBaseUrl =
    'https://air-quality-api.open-meteo.com';

const String _kCurrentVariables =
    'pm10,pm2_5,us_aqi,european_aqi,ozone,nitrogen_dioxide,'
    'sulphur_dioxide,carbon_monoxide';
const String _kHourlyVariables = 'pm10,pm2_5,us_aqi,european_aqi';

class OpenMeteoAirQualityDataProvider implements IDataProvider {
  OpenMeteoAirQualityDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kAirQualityOpenMeteoProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final rows = await enabledIntegrationsForType(ctx.db, id);
    for (final setting in rows) {
      await _collectIntegration(ctx, setting);
    }
  }

  Future<void> _collectIntegration(
    DataWriteContext ctx,
    Integration setting,
  ) async {
    final integrationId = setting.id;
    final nowMs = _nowMs();
    final kvRepo = IntegrationKvRepository(ctx.db);

    if (setting.pollSeconds > 0) {
      final lastValue = await kvRepo.getIntegrationValue(
        integrationId,
        kIntegrationLastCollectKey,
      );
      final last = int.tryParse(lastValue ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        ctx.diagnostics.provider(
          'open_meteo_air_quality: skip poll ($integrationId '
          '${setting.pollSeconds}s gate, lastMs=$last)',
        );
        return;
      }
    }

    final config = await ctx.resolveConfig(integrationId);
    final extra = WeatherProviderExtraConfig.parse(config.configJson);
    final baseUrl = normalizeOpenMeteoBaseUrl(
      config.baseUrl,
      kDefaultOpenMeteoAirQualityBaseUrl,
    );
    final locations = await resolveWeatherLocationsForCollect(
      ctx.db,
      extra.defaultLocation,
    );
    ctx.diagnostics.provider(
      'open_meteo_air_quality: collect id=$integrationId '
      'locations=${locations.length}',
    );

    final store = OpenMeteoAirQualityKvStore(kvRepo);
    var anyOk = false;

    for (final location in locations) {
      try {
        await ensureSyntheticDefaultInterestsLocation(ctx.db, location);
        final uri = Uri.parse('$baseUrl/v1/air-quality').replace(
          queryParameters: {
            'latitude': location.lat.toStringAsFixed(4),
            'longitude': location.lon.toStringAsFixed(4),
            'current': _kCurrentVariables,
            'hourly': _kHourlyVariables,
            'forecast_hours': '${extra.hourlyCount}',
            'timezone': 'auto',
          },
        );
        final res = await openMeteoSafeGet(
          _http,
          uri,
          diagnostics: ctx.diagnostics,
          logLabel: 'open_meteo_air_quality',
          locationId: location.id,
        );
        if (res == null || res.statusCode != 200) {
          if (res != null) {
            ctx.diagnostics.provider(
              'open_meteo_air_quality: status=${res.statusCode} '
              'id=${location.id}',
            );
          }
          continue;
        }
        final snapshot = _normalizeAirQualityPayload(
          res.body,
          locationId: location.id,
          locationName: location.name,
          latitude: location.lat,
          longitude: location.lon,
          hourlyCount: extra.hourlyCount,
        );
        if (snapshot == null) {
          continue;
        }
        await store.writeLocationSnapshot(
          integrationId: integrationId,
          locationId: location.id,
          current: snapshot.current,
          hourly: snapshot.hourly,
          collectedAtMs: nowMs,
        );
        anyOk = true;
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail(
          'open_meteo_air_quality: collect id=${location.id}',
          e,
          st,
        );
      }
    }

    if (anyOk) {
      await store.touchLastCollectMs(
        integrationId: integrationId,
        collectedAtMs: nowMs,
      );
      ctx.diagnostics.provider(
        'open_meteo_air_quality: finished id=$integrationId',
      );
    }
  }
}

class _AirQualitySnapshot {
  const _AirQualitySnapshot({
    required this.current,
    required this.hourly,
  });

  final Map<String, Object?> current;
  final List<Map<String, Object?>> hourly;
}

_AirQualitySnapshot? _normalizeAirQualityPayload(
  String body, {
  required String locationId,
  required String locationName,
  required double latitude,
  required double longitude,
  required int hourlyCount,
}) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final currentRaw = decoded['current'];
    final currentUnits = decoded['current_units'];
    final readings = <String, Object?>{};
    if (currentRaw is Map<String, dynamic>) {
      for (final key in [
        'pm10',
        'pm2_5',
        'us_aqi',
        'european_aqi',
        'ozone',
        'nitrogen_dioxide',
        'sulphur_dioxide',
        'carbon_monoxide',
      ]) {
        final v = currentRaw[key];
        if (v != null) {
          readings[key] = v;
        }
      }
    }
    final unitsOut = <String, String>{};
    if (currentUnits is Map<String, dynamic>) {
      for (final entry in currentUnits.entries) {
        final u = entry.value;
        if (u is String && u.isNotEmpty) {
          unitsOut[entry.key] = u;
        }
      }
    }

    final current = <String, Object?>{
      'location_id': locationId,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      ...readings,
      if (unitsOut.isNotEmpty) 'units': unitsOut,
    };

    final hourlyOut = <Map<String, Object?>>[];
    final hourly = decoded['hourly'];
    final hourlyUnits = decoded['hourly_units'];
    if (hourly is Map<String, dynamic>) {
      final times = hourly['time'];
      if (times is List) {
        final limit = hourlyCount > 0 ? hourlyCount : times.length;
        for (var i = 0; i < times.length && hourlyOut.length < limit; i++) {
          final timeRaw = times[i];
          if (timeRaw is! String) {
            continue;
          }
          final hour = <String, Object?>{'time': timeRaw};
          for (final key in ['pm10', 'pm2_5', 'us_aqi', 'european_aqi']) {
            final series = hourly[key];
            if (series is List && i < series.length) {
              final v = series[i];
              if (v != null) {
                hour[key] = v;
              }
            }
          }
          if (hourlyUnits is Map<String, dynamic>) {
            final u = <String, String>{};
            for (final key in ['pm10', 'pm2_5', 'us_aqi', 'european_aqi']) {
              final unit = hourlyUnits[key];
              if (unit is String && unit.isNotEmpty) {
                u[key] = unit;
              }
            }
            if (u.isNotEmpty) {
              hour['units'] = u;
            }
          }
          hourlyOut.add(hour);
        }
      }
    }

    return _AirQualitySnapshot(current: current, hourly: hourlyOut);
  } on Object {
    return null;
  }
}
