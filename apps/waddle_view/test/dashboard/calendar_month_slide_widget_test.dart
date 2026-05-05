import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/clock.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/dashboard/calendar_month_slide_widget.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  testWidgets('shows compact month title and empty upcoming panel when no events',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime(2024, 6, 15, 9, 0));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CalendarMonthSlideWidget(
            db: db,
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jun 2024'), findsOneWidget);
    expect(find.text('Upcoming events'), findsOneWidget);
    expect(find.text('No upcoming events.'), findsOneWidget);
    expect(find.text('Birthday party'), findsNothing);

    await db.close();
  });

  testWidgets('lists upcoming events when present', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e1',
            title: 'Birthday party',
            startMs: DateTime(2024, 6, 16, 15, 0).millisecondsSinceEpoch,
            endMs: DateTime(2024, 6, 16, 17, 0).millisecondsSinceEpoch,
            updatedAtMs: DateTime(2024, 6, 1).millisecondsSinceEpoch,
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime(2024, 6, 15, 9, 0));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CalendarMonthSlideWidget(
            db: db,
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jun 2024'), findsOneWidget);
    expect(find.text('Upcoming events'), findsOneWidget);
    expect(find.text('Birthday party'), findsOneWidget);

    await db.close();
  });

  testWidgets('shows location line when set', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e2',
            title: 'Meetup',
            startMs: DateTime(2024, 6, 20, 10, 0).millisecondsSinceEpoch,
            endMs: DateTime(2024, 6, 20, 11, 0).millisecondsSinceEpoch,
            location: const Value('Hall A'),
            updatedAtMs: DateTime(2024, 6, 1).millisecondsSinceEpoch,
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime(2024, 6, 15));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CalendarMonthSlideWidget(
            db: db,
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hall A'), findsOneWidget);
    expect(find.text('Upcoming events'), findsOneWidget);

    await db.close();
  });

  testWidgets('does not overflow on short heights', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime(2024, 6, 15, 9, 0));

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 170,
              child: CalendarMonthSlideWidget(
                db: db,
                spec: spec,
                theme: theme,
                clock: clock,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Jun 2024'), findsOneWidget);

    await db.close();
  });

  testWidgets('does not overflow with large text scaling', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e3',
            title: 'Very long event title that wraps across lines',
            startMs: DateTime(2024, 6, 16, 15, 0).millisecondsSinceEpoch,
            endMs: DateTime(2024, 6, 16, 17, 0).millisecondsSinceEpoch,
            updatedAtMs: DateTime(2024, 6, 1).millisecondsSinceEpoch,
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime(2024, 6, 15, 9, 0));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 220,
              child: CalendarMonthSlideWidget(
                db: db,
                spec: spec,
                theme: theme,
                clock: clock,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Jun 2024'), findsOneWidget);

    await db.close();
  });
}
