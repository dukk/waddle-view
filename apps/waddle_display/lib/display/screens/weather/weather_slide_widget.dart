import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../../theme/display_theme.dart';
import '../../dashboard_viewport_scope.dart';

String? weatherLocationIdForSpec(ParsedWidgetSpec spec) {
  final raw = (spec.config['locationId'] as String?)?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
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
    final locationQuery = db.select(db.weatherLocations)
      ..where((t) => t.enabled.equals(true))
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
          stream: (db.select(db.weatherCurrentData)
                ..where((t) => t.locationId.equals(location.id)))
              .watchSingleOrNull(),
          builder: (context, dataSnapshot) {
            final weather = dataSnapshot.data;
            if (weather == null) {
              return _empty('Weather unavailable');
            }
            final hourly = _parseHourly(weather.hourlyJson);
            final s = DashboardViewportScope.scaleOf(context);
            final hourlyTileWidth = 132 * s;
            final hourlyTileHeight = _uniformHourlyTileHeight(
              context: context,
              items: hourly.take(6).toList(),
              tileWidth: hourlyTileWidth,
              scale: s,
            );
            final currentDescription = (weather.currentDescription ?? '').trim();
            final currentIcon = _iconForWeather(
              description: currentDescription,
            );
            return StreamBuilder<List<WeatherGovActiveAlert>>(
              stream: (db.select(db.weatherGovActiveAlerts)
                    ..where((t) => t.locationId.equals(location.id))
                    ..orderBy([
                      (t) => OrderingTerm.asc(t.severity),
                      (t) => OrderingTerm.asc(t.event),
                    ]))
                  .watch(),
              builder: (context, alertSnapshot) {
                final alerts = alertSnapshot.data ?? const <WeatherGovActiveAlert>[];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(location.name, style: theme.textTheme.headlineSmall),
                    if (alerts.isNotEmpty) ...[
                      SizedBox(height: 12 * s),
                      Text(
                        'Active alerts',
                        style: theme.textTheme.titleMedium,
                      ),
                      SizedBox(height: 10 * s),
                      ...alerts.map(
                        (a) => Padding(
                          padding: EdgeInsets.only(bottom: 10 * s),
                          child: _weatherGovAlertCard(
                            context: context,
                            alert: a,
                            scale: s,
                            theme: theme,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 16 * s),
                    Icon(
                      currentIcon,
                      size: 42 * s,
                      color: primaryAccent,
                    ),
                    SizedBox(height: 10 * s),
                    Text(
                      _formatTemp(weather.currentTemp),
                      style: theme.textTheme.displaySmall,
                    ),
                    SizedBox(height: 10 * s),
                    Text(currentDescription, style: theme.textTheme.titleLarge),
                    SizedBox(height: 24 * s),
                    Text(
                      'Hourly forecast (3-hour steps)',
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: 14 * s),
                    Wrap(
                      spacing: 24 * s,
                      runSpacing: 14 * s,
                      alignment: WrapAlignment.center,
                      children: hourly.take(6).map((item) {
                        final dt = (item['dt'] as num?)?.toInt();
                        final hourText = _hourText(dt);
                        final description = (item['description'] as String?) ?? '';
                        return SizedBox(
                          width: hourlyTileWidth,
                          height: hourlyTileHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12 * s),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * s,
                                vertical: 8 * s,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(hourText, style: theme.textTheme.bodySmall),
                                  SizedBox(height: 4 * s),
                                  Icon(
                                    _iconForWeather(
                                      code: item['icon'] as String?,
                                      description: description,
                                    ),
                                    size: 20 * s,
                                    color: iconColor,
                                  ),
                                  SizedBox(height: 4 * s),
                                  Text(
                                    _formatTemp(item['temp']),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  SizedBox(height: 2 * s),
                                  Text(
                                    description,
                                    style: theme.textTheme.bodySmall,
                                    softWrap: true,
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
            );
          },
        );
      },
    );
  }

  Widget _weatherGovAlertCard({
    required BuildContext context,
    required WeatherGovActiveAlert alert,
    required double scale,
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
          horizontal: 14 * scale,
          vertical: 10 * scale,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: accent,
              size: 26 * scale,
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.event,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (headline.isNotEmpty) ...[
                    SizedBox(height: 4 * scale),
                    Text(headline, style: theme.textTheme.bodyMedium),
                  ],
                  if (expiry != null) ...[
                    SizedBox(height: 4 * scale),
                    Text(
                      'Until ${_formatAlertExpiryLocal(expiry)}',
                      style: theme.textTheme.bodySmall,
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
    final local = DateTime.fromMillisecondsSinceEpoch(dtSeconds * 1000).toLocal();
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

  double _uniformHourlyTileHeight({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
    required double tileWidth,
    required double scale,
  }) {
    const fallback = 144.0;
    if (items.isEmpty) {
      return fallback * scale;
    }
    final bodyStyle = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    final tempStyle = theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16);
    final textScaler = MediaQuery.textScalerOf(context);
    final maxDescriptionHeight = items
        .map((item) => (item['description'] as String?)?.trim() ?? '')
        .map(
          (text) => _measureTextHeight(
            text: text,
            style: bodyStyle,
            maxWidth: tileWidth - (20 * scale),
            textScaler: textScaler,
          ),
        )
        .fold<double>(0, (prev, h) => h > prev ? h : prev);
    final hourHeight = _measureTextHeight(
      text: '12 PM',
      style: bodyStyle,
      maxWidth: tileWidth - (20 * scale),
      textScaler: textScaler,
    );
    final tempHeight = _measureTextHeight(
      text: '99°',
      style: tempStyle,
      maxWidth: tileWidth - (20 * scale),
      textScaler: textScaler,
    );
    final fixedHeight =
        (8 * scale) + // top padding
        hourHeight +
        (4 * scale) +
        (20 * scale) + // icon
        (4 * scale) +
        tempHeight +
        (2 * scale) +
        (8 * scale); // bottom padding
    final computed = fixedHeight + maxDescriptionHeight;
    final minimum = fallback * scale;
    return computed > minimum ? computed : minimum;
  }

  double _measureTextHeight({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text.isEmpty ? ' ' : text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    return painter.height;
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
    if (value.contains('snow') || value.contains('sleet') || value.contains('ice')) {
      return Icons.ac_unit;
    }
    if (value.contains('thunder') || value.contains('storm')) {
      return Icons.thunderstorm;
    }
    if (value.contains('rain') || value.contains('drizzle') || value.contains('shower')) {
      return Icons.umbrella;
    }
    if (value.contains('cloud') || value.contains('overcast')) {
      return Icons.cloud;
    }
    if (value.contains('fog') || value.contains('mist') || value.contains('haze')) {
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
