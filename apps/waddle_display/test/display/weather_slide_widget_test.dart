import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/weather/weather_slide_widget.dart';
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/theme/display_theme.dart';

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
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1234),
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
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1235),
            currentTemp: const Value(65.1),
            currentDescription: const Value('cloudy'),
            hourlyJson: Value(
              jsonEncode([
                {'temp': 66.0, 'description': 'light rain'},
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
    final theme = DisplayTheme.build();
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
    expect(find.text('65°'), findsOneWidget);
    expect(find.text('cloudy'), findsOneWidget);
    expect(find.text('Hourly forecast (3-hour steps)'), findsOneWidget);
    expect(find.byIcon(Icons.cloud), findsOneWidget);
    expect(find.byIcon(Icons.umbrella), findsOneWidget);
    final cloudIcon = tester.widget<Icon>(find.byIcon(Icons.cloud));
    expect(cloudIcon.color, NavyCoralPalette.mutedTeal);
    final rainIcon = tester.widget<Icon>(find.byIcon(Icons.umbrella));
    expect(rainIcon.color, NavyCoralPalette.dustyDenim);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows NWS active alerts for slide location', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
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
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1235),
            currentTemp: const Value(65.1),
            currentDescription: const Value('cloudy'),
            hourlyJson: const Value('[]'),
          ),
        );
    await db.into(db.weatherGovActiveAlerts).insert(
          WeatherGovActiveAlertsCompanion.insert(
            locationId: 'atlanta_ga',
            nwsAlertId: 'urn:test:1',
            event: 'Heat Advisory',
            headline: const Value('Heat index values up to 105'),
            severity: const Value('Moderate'),
            expiresAt: Value(DateTime.utc(2026, 7, 15, 20, 0)),
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
    final theme = DisplayTheme.build();
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

    expect(find.text('Active alerts'), findsOneWidget);
    expect(find.textContaining('Heat Advisory'), findsOneWidget);
    expect(find.textContaining('Heat index values'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('uses theme fallbacks when PaletteTertiaryLayers is absent', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.weatherLocations).insert(
          WeatherLocationsCompanion.insert(
            id: 'only',
            name: 'Only City',
            latitude: 1,
            longitude: 2,
          ),
        );
    await db.into(db.weatherCurrentData).insert(
          WeatherCurrentDataCompanion.insert(
            locationId: 'only',
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
            currentTemp: const Value(55),
            currentDescription: const Value('fog'),
            hourlyJson: Value(
              jsonEncode([
                {'temp': 56.0, 'description': 'fog'},
              ]),
            ),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'weather',
      slot: 'main',
      config: {},
    );
    const slide = ResolvedSlide(
      screenId: 'weather',
      dwellMs: 10000,
      layoutJson: '{}',
    );
    final theme = ThemeData.light().copyWith(
      iconTheme: const IconThemeData(),
    );
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

    final fogIcons = tester.widgetList<Icon>(find.byIcon(Icons.foggy));
    final mainIcon = fogIcons.firstWhere((i) => i.size == 42);
    expect(mainIcon.color, theme.colorScheme.secondary);
    final hourlyIcon = fogIcons.firstWhere((i) => i.size == 20);
    expect(hourlyIcon.color, theme.colorScheme.onSurfaceVariant);
    await db.close();
  });
}
