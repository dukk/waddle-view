import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';

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
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(location.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  '${weather.currentTemp ?? '--'}°',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  weather.currentDescription ?? '',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: hourly.take(6).map((item) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item['temp'] ?? '--'}°',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          (item['description'] as String?) ?? '',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
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

  Widget _empty(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
