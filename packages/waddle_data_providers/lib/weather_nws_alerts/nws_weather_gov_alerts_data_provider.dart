import 'package:waddle_shared/net/http_debug_uri.dart';
import 'dart:convert';

import 'package:drift/drift.dart' show Expression, Value;
import 'package:http/http.dart' as http;

import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import '../weather_openweathermap/weather_locations_for_collect.dart';
import '../weather_openweathermap/weather_provider_extra_config.dart';

const String kNwsWeatherAlertsProviderId = 'weather_nws_alerts';
const String kDefaultNwsWeatherGovBaseUrl = 'https://api.weather.gov';

/// NWS requires a User-Agent identifying the client; operators should set
/// `userAgent` in provider config with contact info per NWS API guidelines.
const String kDefaultNwsUserAgent =
    '(waddle-display; set userAgent in nws_weather_alerts provider config — '
    'see apps/waddle-display/README.md)';

class NwsWeatherGovAlertsDataProvider implements IDataProvider {
  NwsWeatherGovAlertsDataProvider({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  @override
  String get id => kNwsWeatherAlertsProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(ctx.db.integrations)
              ..where((t) => t.id.equals(kNwsWeatherAlertsProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      ctx.diagnostics.provider('nws_alerts: skip (disabled)');
      return;
    }
    final config = await ctx.resolveConfig(kNwsWeatherAlertsProviderId);
    final baseUrl = (config.baseUrl != null && config.baseUrl!.trim().isNotEmpty)
        ? config.baseUrl!.trim()
        : kDefaultNwsWeatherGovBaseUrl;
    final extra = WeatherProviderExtraConfig.parse(config.configJson);
    final userAgent = _parseUserAgent(config.configJson);
    final optedOut = await (ctx.db.select(ctx.db.interestsLocations)
          ..where(
            (t) => Expression.and([
              t.enabled.equals(true),
              t.includeActiveWeatherAlerts.equals(false),
            ]),
          ))
        .get();
    for (final row in optedOut) {
      await (ctx.db.delete(ctx.db.weatherAlerts)
            ..where((t) => t.locationId.equals(row.id)))
          .go();
    }

    final locations = await resolveWeatherLocationsForActiveAlertsCollect(
      ctx.db,
      extra.defaultLocation,
    );
    ctx.diagnostics.provider(
      'nws_alerts: collect locations=${locations.length} '
      'base=${safeHttpUriForLog(Uri.parse(baseUrl))}',
    );

    if (locations.isEmpty) {
      ctx.diagnostics.provider(
        'nws_alerts: no locations with include_active_weather_alerts; '
        'cleared stored alerts',
      );
      await ctx.db.delete(ctx.db.weatherAlerts).go();
      return;
    }

    for (final location in locations) {
      try {
        final uri = Uri.parse('$baseUrl/alerts/active').replace(
          queryParameters: {
            'point': '${location.lat.toStringAsFixed(4)},${location.lon.toStringAsFixed(4)}',
          },
        );
        ctx.diagnostics.provider(
          'nws_alerts: GET id=${location.id} ${safeHttpUriForLog(uri)}',
        );
        final res = await _http.get(
          uri,
          headers: {
            'Accept': 'application/geo+json',
            'User-Agent': userAgent,
          },
        );
        if (res.statusCode != 200) {
          ctx.diagnostics.provider(
            'nws_alerts: status=${res.statusCode} id=${location.id}',
          );
          continue;
        }
        final companions = _parseGeoJsonFeatures(res.body, location.id);
        await ctx.db.transaction(() async {
          await (ctx.db.delete(ctx.db.weatherAlerts)
                ..where((t) => t.locationId.equals(location.id)))
              .go();
          for (final c in companions) {
            await ctx.db.into(ctx.db.weatherAlerts).insert(c);
          }
        });
        ctx.diagnostics.provider(
          'nws_alerts: stored ${companions.length} alert(s) id=${location.id}',
        );
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail('nws_alerts: collect id=${location.id}', e, st);
      }
    }
  }
}

String _parseUserAgent(String? configJson) {
  if (configJson == null || configJson.trim().isEmpty) {
    return kDefaultNwsUserAgent;
  }
  try {
    final decoded = jsonDecode(configJson);
    if (decoded is! Map) {
      return kDefaultNwsUserAgent;
    }
    final m = Map<String, dynamic>.from(decoded);
    final ua = (m['userAgent'] as String?)?.trim();
    if (ua == null || ua.isEmpty) {
      return kDefaultNwsUserAgent;
    }
    return ua;
  } on Object {
    return kDefaultNwsUserAgent;
  }
}

List<WeatherAlertsCompanion> _parseGeoJsonFeatures(
  String body,
  String locationId,
) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return const [];
    }
    final root = Map<String, dynamic>.from(decoded);
    final features = root['features'];
    if (features is! List) {
      return const [];
    }
    final out = <WeatherAlertsCompanion>[];
    for (final f in features) {
      if (f is! Map) {
        continue;
      }
      final propsRaw = f['properties'];
      if (propsRaw is! Map) {
        continue;
      }
      final props = Map<String, dynamic>.from(propsRaw);
      final nwsId = (props['id'] as String?)?.trim();
      if (nwsId == null || nwsId.isEmpty) {
        continue;
      }
      final event = (props['event'] as String?)?.trim();
      final headline = (props['headline'] as String?)?.trim();
      final severity = (props['severity'] as String?)?.trim();
      final description = (props['description'] as String?)?.trim();
      final excerpt = _truncateDescription(description);
      final effectiveAt = _parseAlertDate(props['effective']);
      final expiresAt = _parseAlertDate(props['expires']);
      out.add(
        WeatherAlertsCompanion.insert(
          locationId: locationId,
          nwsAlertId: nwsId,
          event: (event == null || event.isEmpty) ? 'Weather alert' : event,
          headline: headline == null || headline.isEmpty
              ? const Value.absent()
              : Value(headline),
          severity: severity == null || severity.isEmpty
              ? const Value.absent()
              : Value(severity),
          effectiveAt: effectiveAt == null
              ? const Value.absent()
              : Value(effectiveAt),
          expiresAt: expiresAt == null
              ? const Value.absent()
              : Value(expiresAt),
          descriptionExcerpt: excerpt == null
              ? const Value.absent()
              : Value(excerpt),
        ),
      );
    }
    return out;
  } on Object {
    return const [];
  }
}

String? _truncateDescription(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) {
    return null;
  }
  const maxLen = 400;
  if (collapsed.length <= maxLen) {
    return collapsed;
  }
  return '${collapsed.substring(0, maxLen)}\u2026';
}

DateTime? _parseAlertDate(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}
