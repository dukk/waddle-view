import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/home_assistant/home_assistant_slide_widget.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_display/theme/display_theme.dart';

import '../helpers/memory_database.dart';

void main() {
  testWidgets('renders state and unit for enabled entities', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 'kitchen',
            entityId: 'sensor.kitchen_temperature',
            displayName: const Value('Kitchen'),
          ),
        );
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 'garage',
            entityId: 'binary_sensor.garage',
            enabled: const Value(false),
          ),
        );
    await db.into(db.homeAssistantEntityStates).insert(
          HomeAssistantEntityStatesCompanion.insert(
            entityId: 'sensor.kitchen_temperature',
            state: '21.5',
            attributesJson: '{"unit_of_measurement":"°C"}',
            observedAtMs: 1000,
          ),
        );

    const spec = ParsedWidgetSpec(
      type: 'home_assistant',
      slot: 'main',
      config: {},
    );
    const slide = ResolvedSlide(
      screenId: 'home_assistant',
      dwellMs: 10000,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"home_assistant","slot":"main","config":{}}]}',
    );
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: HomeAssistantSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('21.5 °C'), findsOneWidget);
    expect(find.textContaining('binary_sensor.garage'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows empty placeholder when no entities configured', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const spec = ParsedWidgetSpec(
      type: 'home_assistant',
      slot: 'main',
      config: {},
    );
    const slide = ResolvedSlide(
      screenId: 'home_assistant',
      dwellMs: 10000,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"home_assistant","slot":"main","config":{}}]}',
    );
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: HomeAssistantSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No Home Assistant entities configured'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });
}
