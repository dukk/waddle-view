import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/clock.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/dashboard/calendar_month_slide_widget.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  testWidgets('weekday header row height fits longest label at high text scale',
      (tester) async {
    const scale = 2.25;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          theme: ThemeData(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final weekdayStyle = theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                );
                final compactStyle = theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                );
                for (final compact in [false, true]) {
                  final style = compact ? compactStyle : weekdayStyle;
                  for (final label in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
                    final painter = TextPainter(
                      text: TextSpan(text: label, style: style),
                      textScaler: MediaQuery.textScalerOf(context),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                    )..layout();
                    final rowMin = calendarWeekdayHeaderRowMinHeight(
                      context,
                      style,
                      1.0,
                      compact,
                    );
                    expect(
                      rowMin,
                      greaterThanOrEqualTo(painter.height),
                      reason:
                          'header row must not clip $label (compact=$compact)',
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  });

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
            blobs: FakeBlobStore(),
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
            startMs: DateTime(2024, 6, 16, 15, 0),
            endMs: DateTime(2024, 6, 16, 17, 0),
            updatedAtMs: DateTime(2024, 6, 1),
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
            blobs: FakeBlobStore(),
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

  testWidgets('groups only next 5 days of events by relative day labels',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.batch((batch) {
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'g1',
          title: 'Today standup',
          startMs: DateTime(2024, 6, 15, 9, 0),
          endMs: DateTime(2024, 6, 15, 9, 30),
          updatedAtMs: DateTime(2024, 6, 1),
        ),
      );
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'g2',
          title: 'Tomorrow planning',
          startMs: DateTime(2024, 6, 16, 10, 0),
          endMs: DateTime(2024, 6, 16, 11, 0),
          updatedAtMs: DateTime(2024, 6, 1),
        ),
      );
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'g3',
          title: 'Tuesday retro',
          startMs: DateTime(2024, 6, 18, 15, 0),
          endMs: DateTime(2024, 6, 18, 16, 0),
          updatedAtMs: DateTime(2024, 6, 1),
        ),
      );
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'g4',
          title: 'Outside range',
          startMs: DateTime(2024, 6, 21, 12, 0),
          endMs: DateTime(2024, 6, 21, 13, 0),
          updatedAtMs: DateTime(2024, 6, 1),
        ),
      );
    });
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime(2024, 6, 15, 8, 0));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CalendarMonthSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('Today standup'), findsOneWidget);
    expect(find.text('Tomorrow planning'), findsOneWidget);
    expect(find.text('Tuesday retro'), findsOneWidget);
    expect(find.text('Outside range'), findsNothing);

    await db.close();
  });

  testWidgets('shows location line when set', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e2',
            title: 'Meetup',
            startMs: DateTime(2024, 6, 19, 10, 0),
            endMs: DateTime(2024, 6, 19, 11, 0),
            location: const Value('Hall A'),
            updatedAtMs: DateTime(2024, 6, 1),
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
            blobs: FakeBlobStore(),
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
                blobs: FakeBlobStore(),
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
            startMs: DateTime(2024, 6, 16, 15, 0),
            endMs: DateTime(2024, 6, 16, 17, 0),
            updatedAtMs: DateTime(2024, 6, 1),
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
                blobs: FakeBlobStore(),
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

  testWidgets('uses accent day styling for today and days with events',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'accent-1',
            title: 'Accent day event',
            startMs: DateTime(2024, 6, 16, 15, 0),
            endMs: DateTime(2024, 6, 16, 17, 0),
            updatedAtMs: DateTime(2024, 6, 1),
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
            blobs: FakeBlobStore(),
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final day16Decoration = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.text('16'),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.border != null);
    final border = day16Decoration.border as Border;
    expect(border.top.color, theme.colorScheme.primary);

    final day15Decorations = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.text('15'),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .toList();
    final todayDecoration =
        day15Decorations.firstWhere((decoration) => decoration.color != null);
    expect(todayDecoration.color, theme.colorScheme.primaryContainer);

    await db.close();
  });
}
