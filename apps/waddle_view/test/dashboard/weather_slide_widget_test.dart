import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/dashboard/weather_slide_widget.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('weatherLocationIdForSpec chooses explicit locationId override', () {
    const spec = ParsedWidgetSpec(
      type: 'weather',
      slot: 'main',
      config: {'locationId': 'atlanta_ga'},
    );
    expect(
      weatherLocationIdForSpec(spec),
      'atlanta_ga',
    );
  });

  testWidgets('renders weather from weather tables', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.weatherLocations).insert(
          WeatherLocationsCompanion.insert(
            id: 'salt_lake_city_ut',
            name: 'Salt Lake City, UT',
            latitude: 40.7608,
            longitude: -111.8910,
          ),
        );
    await db.into(db.weatherCurrentData).insert(
          WeatherCurrentDataCompanion.insert(
            locationId: 'salt_lake_city_ut',
            observedAtMs: 1234,
            currentTemp: const Value(72.2),
            currentDescription: const Value('sunny'),
            hourlyJson: Value(
              jsonEncode([
                {'temp': 73.0, 'description': 'hour1'},
                {'temp': 74.0, 'description': 'hour2'},
              ]),
            ),
          ),
        );
    await db.into(db.weatherLocations).insert(
          WeatherLocationsCompanion.insert(
            id: 'atlanta_ga',
            name: 'Atlanta, GA',
            latitude: 33.7490,
            longitude: -84.3880,
          ),
        );
    await db.into(db.weatherCurrentData).insert(
          WeatherCurrentDataCompanion.insert(
            locationId: 'atlanta_ga',
            observedAtMs: 1235,
            currentTemp: const Value(65.1),
            currentDescription: const Value('cloudy'),
            hourlyJson: Value(
              jsonEncode([
                {'temp': 66.0, 'description': 'hour1'},
              ]),
            ),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'weather',
      slot: 'main',
      config: {'locationId': 'atlanta_ga'},
    );
    const slide = ResolvedSlide(
      screenId: 'weather',
      dwellMs: 10000,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"weather","slot":"main","config":{"locationId":"atlanta_ga"}}]}',
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WeatherSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Atlanta, GA'), findsOneWidget);
    expect(find.textContaining('65.1'), findsOneWidget);
    expect(find.textContaining('cloudy'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });
}
