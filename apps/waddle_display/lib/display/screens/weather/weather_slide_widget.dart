import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart'
    show
        kDisplayTextScaleNormal,
        kDisplayTextScaleOptions,
        kDisplayTextScaleScreenKvKey,
        linearFactorForDisplayTextScaleOption,
        normalizeDisplayTextScaleOption;

import '../../../curator/screen_program_curator.dart';
import '../../../theme/display_theme.dart';
import '../../dashboard_viewport_scope.dart';

String? weatherLocationIdForSpec(ParsedWidgetSpec spec) {
  final raw = (spec.config['locationId'] as String?)?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}

/// Linear multiplier to apply to [MediaQuery.textScaler] so hourly forecast
/// matches one semantic **screen** text-size step below the effective
/// `display.text_scale.screen` value ([rawScreenScaleKv], or implicit normal).
@visibleForTesting
double weatherHourlyForecastScreenTextRatio(String? rawScreenScaleKv) {
  final currentId = normalizeDisplayTextScaleOption(rawScreenScaleKv);
  var i = kDisplayTextScaleOptions.indexOf(currentId);
  if (i < 0) {
    i = kDisplayTextScaleOptions.indexOf(kDisplayTextScaleNormal);
  }
  final down = i > 0 ? i - 1 : 0;
  final curF = linearFactorForDisplayTextScaleOption(
    kDisplayTextScaleOptions[i],
  );
  final downF = linearFactorForDisplayTextScaleOption(
    kDisplayTextScaleOptions[down],
  );
  if (curF <= 0) {
    return 1.0;
  }
  return downF / curF;
}

/// Base horizontal gap between hourly forecast tiles (scaled by viewport + text).
@visibleForTesting
const double kWeatherHourlyForecastTileSpacing = 12;

/// Base vertical gap when hourly tiles wrap to a second row.
@visibleForTesting
const double kWeatherHourlyForecastTileRunSpacing = 8;

@immutable
final class _HourlyForecastTextScaler extends TextScaler {
  const _HourlyForecastTextScaler(this._parent, this._ratio)
    : assert(_ratio > 0);

  final TextScaler _parent;
  final double _ratio;

  @override
  double scale(double fontSize) => _parent.scale(fontSize) * _ratio;

  @override
  @Deprecated('Use scale() or a linear TextScaler where possible.')
  double get textScaleFactor => _parent.textScaleFactor * _ratio;

  @override
  bool operator ==(Object other) {
    return other is _HourlyForecastTextScaler &&
        other._parent == _parent &&
        other._ratio == _ratio;
  }

  @override
  int get hashCode => Object.hash(_parent, _ratio);
}

class WeatherSlideWidget extends StatelessWidget {
  const WeatherSlideWidget({
    super.key,
    required this.db,
    required this.slide,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final palette = theme.extension<PaletteTertiaryLayers>();
    final iconColor =
        palette?.iconColor ??
        theme.iconTheme.color ??
        theme.colorScheme.onSurfaceVariant;
    final primaryAccent = palette?.accent1 ?? theme.colorScheme.secondary;
    final configuredLocationId = weatherLocationIdForSpec(spec);
    final locationQuery = db.select(db.interestsLocations)
      ..where((t) => t.includeWeather.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return StreamBuilder<List<dynamic>>(
      stream: locationQuery.watch(),
      builder: (context, snapshot) {
        final locations = snapshot.data ?? const <dynamic>[];
        if (locations.isEmpty) {
          return _empty('Weather unavailable');
        }
        dynamic location = locations.first;
        if (configuredLocationId != null) {
          for (final candidate in locations) {
            if (candidate.id == configuredLocationId) {
              location = candidate;
              break;
            }
          }
        }
        return StreamBuilder<dynamic>(
          stream:
              (db.select(db.weatherCurrent)
                    ..where((t) => t.locationId.equals(location.id)))
                  .watchSingleOrNull(),
          builder: (context, dataSnapshot) {
            final weather = dataSnapshot.data;
            if (weather == null) {
              return _empty('Weather unavailable');
            }
            final hourly = _parseHourly(weather.hourlyJson);
            final s = DashboardViewportScope.scaleOf(context);
            final textScaler = MediaQuery.textScalerOf(context);
            final currentDescription = (weather.currentDescription ?? '')
                .trim();
            final currentIcon = _iconForWeather(
              description: currentDescription,
            );
            return StreamBuilder<List<WeatherGovActiveAlert>>(
              stream:
                  (db.select(db.weatherAlerts)
                        ..where((t) => t.locationId.equals(location.id))
                        ..orderBy([
                          (t) => OrderingTerm.asc(t.severity),
                          (t) => OrderingTerm.asc(t.event),
                        ]))
                      .watch(),
              builder: (context, alertSnapshot) {
                final alerts =
                    alertSnapshot.data ?? const <WeatherGovActiveAlert>[];
                final horizontalPad = textScaler.scale(24 * s);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              location.name,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                          ),
                          SizedBox(width: textScaler.scale(12 * s)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                currentIcon,
                                size: textScaler.scale(56 * s),
                                color: primaryAccent,
                              ),
                              SizedBox(width: textScaler.scale(12 * s)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTemp(weather.currentTemp),
                                    style: theme.textTheme.displayMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w200,
                                          height: 1.05,
                                        ),
                                  ),
                                  SizedBox(height: textScaler.scale(4 * s)),
                                  Text(
                                    currentDescription,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w400,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (alerts.isNotEmpty) ...[
                        SizedBox(height: textScaler.scale(16 * s)),
                        Text(
                          'Active alerts',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: textScaler.scale(10 * s)),
                        ...alerts.map(
                          (a) => Padding(
                            padding: EdgeInsets.only(
                              bottom: textScaler.scale(10 * s),
                            ),
                            child: _weatherGovAlertCard(
                              alert: a,
                              scale: s,
                              textScaler: textScaler,
                              theme: theme,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: textScaler.scale(28 * s)),
                      StreamBuilder<ConfigKeyValue?>(
                        stream:
                            (db.select(db.configKeyValues)..where(
                                  (t) => t.key.equals(
                                    kDisplayTextScaleScreenKvKey,
                                  ),
                                ))
                                .watchSingleOrNull(),
                        builder: (context, kvSnap) {
                          final ratio = weatherHourlyForecastScreenTextRatio(
                            kvSnap.data?.value,
                          );
                          final parentMq = MediaQuery.of(context);
                          final hourlyScaler = _HourlyForecastTextScaler(
                            parentMq.textScaler,
                            ratio,
                          );
                          return MediaQuery(
                            data: parentMq.copyWith(textScaler: hourlyScaler),
                            child: Builder(
                              builder: (context) {
                                final ts = MediaQuery.textScalerOf(context);
                                final tileW = ts.scale(132 * s);
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Hourly forecast',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: ts.scale(14 * s)),
                                    Wrap(
                                      spacing: ts.scale(
                                        kWeatherHourlyForecastTileSpacing * s,
                                      ),
                                      runSpacing: ts.scale(
                                        kWeatherHourlyForecastTileRunSpacing * s,
                                      ),
                                      alignment: WrapAlignment.center,
                                      children: hourly.take(6).map((item) {
                                        final dt = (item['dt'] as num?)
                                            ?.toInt();
                                        final hourText = _hourText(dt);
                                        final description =
                                            (item['description'] as String?) ??
                                            '';
                                        return SizedBox(
                                          width: tileW,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(12 * s),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: ts.scale(10 * s),
                                                vertical: ts.scale(8 * s),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    hourText,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(
                                                    height: ts.scale(6 * s),
                                                  ),
                                                  Icon(
                                                    _iconForWeather(
                                                      code:
                                                          item['icon']
                                                              as String?,
                                                      description: description,
                                                    ),
                                                    size: ts.scale(22 * s),
                                                    color: iconColor,
                                                  ),
                                                  SizedBox(
                                                    height: ts.scale(6 * s),
                                                  ),
                                                  Text(
                                                    _formatTemp(item['temp']),
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(
                                                    height: ts.scale(4 * s),
                                                  ),
                                                  Text(
                                                    description,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall,
                                                    softWrap: true,
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _weatherGovAlertCard({
    required WeatherGovActiveAlert alert,
    required double scale,
    required TextScaler textScaler,
    required ThemeData theme,
  }) {
    final accent = _severityColor(theme, alert.severity);
    final headline = (alert.headline ?? '').trim();
    final expiry = alert.expiresAt;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12 * scale),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: textScaler.scale(14 * scale),
          vertical: textScaler.scale(10 * scale),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: accent,
              size: textScaler.scale(26 * scale),
            ),
            SizedBox(width: textScaler.scale(10 * scale)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.event,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (headline.isNotEmpty) ...[
                    SizedBox(height: textScaler.scale(4 * scale)),
                    Text(headline, style: theme.textTheme.bodyLarge),
                  ],
                  if (expiry != null) ...[
                    SizedBox(height: textScaler.scale(4 * scale)),
                    Text(
                      'Until ${_formatAlertExpiryLocal(expiry)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(ThemeData theme, String? severity) {
    switch ((severity ?? '').toLowerCase().trim()) {
      case 'extreme':
        return theme.colorScheme.error;
      case 'severe':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.secondary;
    }
  }

  String _formatAlertExpiryLocal(DateTime t) {
    final local = t.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }

  List<Map<String, dynamic>> _parseHourly(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on Object {
      return const [];
    }
  }

  String _hourText(int? dtSeconds) {
    if (dtSeconds == null || dtSeconds <= 0) {
      return '--';
    }
    final local = DateTime.fromMillisecondsSinceEpoch(
      dtSeconds * 1000,
    ).toLocal();
    final hour = local.hour;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final twelveHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelveHour $suffix';
  }

  String _formatTemp(dynamic raw) {
    if (raw is num) {
      return '${raw.round()}\u00B0';
    }
    return '--\u00B0';
  }

  IconData _iconForWeather({String? code, String? description}) {
    final normalizedCode = (code ?? '').trim();
    if (normalizedCode.isNotEmpty) {
      if (normalizedCode.contains('01')) {
        return Icons.wb_sunny;
      }
      if (normalizedCode.contains('02') ||
          normalizedCode.contains('03') ||
          normalizedCode.contains('04')) {
        return Icons.cloud;
      }
      if (normalizedCode.contains('09') || normalizedCode.contains('10')) {
        return Icons.umbrella;
      }
      if (normalizedCode.contains('11')) {
        return Icons.thunderstorm;
      }
      if (normalizedCode.contains('13')) {
        return Icons.ac_unit;
      }
      if (normalizedCode.contains('50')) {
        return Icons.foggy;
      }
    }
    final value = (description ?? '').toLowerCase();
    if (value.contains('snow') ||
        value.contains('sleet') ||
        value.contains('ice')) {
      return Icons.ac_unit;
    }
    if (value.contains('thunder') || value.contains('storm')) {
      return Icons.thunderstorm;
    }
    if (value.contains('rain') ||
        value.contains('drizzle') ||
        value.contains('shower')) {
      return Icons.umbrella;
    }
    if (value.contains('cloud') || value.contains('overcast')) {
      return Icons.cloud;
    }
    if (value.contains('fog') ||
        value.contains('mist') ||
        value.contains('haze')) {
      return Icons.foggy;
    }
    return Icons.wb_sunny;
  }

  Widget _empty(String text) {
    return Builder(
      builder: (context) {
        final s = DashboardViewportScope.scaleOf(context);
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Text(
            text,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
