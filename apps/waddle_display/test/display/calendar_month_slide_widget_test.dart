import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/display/content_category_material_icon.dart';
import 'package:waddle_display/display/screens/calendar_month/calendar_month_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';

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
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
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
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e1',
            title: 'Birthday party',
            startMs: DateTime.utc(2024, 6, 16, 15, 0),
            endMs: DateTime.utc(2024, 6, 16, 17, 0),
            updatedAtMs: DateTime.utc(2024, 6, 1),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
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

  testWidgets('shows category material icon when category_id is set',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await seedContentCategoriesForTest(db, ['cal_test_cat']);
    await (db.update(db.contentCategories)
          ..where((t) => t.id.equals('cal_test_cat')))
        .write(
      const ContentCategoriesCompanion(
        materialIconName: Value('event'),
      ),
    );
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'ic1',
            title: 'Categorized',
            startMs: DateTime.utc(2024, 6, 16, 15, 0),
            endMs: DateTime.utc(2024, 6, 16, 16, 0),
            categoryId: const Value('cal_test_cat'),
            updatedAtMs: DateTime.utc(2024, 6, 1),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
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
    expect(find.byIcon(contentCategoryMaterialIcon('event')), findsOneWidget);
    await db.close();
  });

  testWidgets('groups only next 5 days of events by relative day labels',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await db.batch((batch) {
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'g1',
          title: 'Today standup',
          startMs: DateTime.utc(2024, 6, 15, 9, 0),
          endMs: DateTime.utc(2024, 6, 15, 9, 30),
          updatedAtMs: DateTime.utc(2024, 6, 1),
        ),
      );
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'g2',
          title: 'Tomorrow planning',
          startMs: DateTime.utc(2024, 6, 16, 10, 0),
          endMs: DateTime.utc(2024, 6, 16, 11, 0),
          updatedAtMs: DateTime.utc(2024, 6, 1),
        ),
      );
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'g3',
          title: 'Tuesday retro',
          startMs: DateTime.utc(2024, 6, 18, 15, 0),
          endMs: DateTime.utc(2024, 6, 18, 16, 0),
          updatedAtMs: DateTime.utc(2024, 6, 1),
        ),
      );
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'g4',
          title: 'Outside range',
          startMs: DateTime.utc(2024, 6, 21, 12, 0),
          endMs: DateTime.utc(2024, 6, 21, 13, 0),
          updatedAtMs: DateTime.utc(2024, 6, 1),
        ),
      );
    });
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 8, 0));
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
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e2',
            title: 'Meetup',
            startMs: DateTime.utc(2024, 6, 16, 15, 0),
            endMs: DateTime.utc(2024, 6, 16, 17, 0),
            location: const Value('Hall A'),
            updatedAtMs: DateTime.utc(2024, 6, 1),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15));
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
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));

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
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e3',
            title: 'Very long event title that wraps across lines',
            startMs: DateTime.utc(2024, 6, 16, 15, 0),
            endMs: DateTime.utc(2024, 6, 16, 17, 0),
            updatedAtMs: DateTime.utc(2024, 6, 1),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));

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
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await db.batch((batch) {
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'accent-past',
          title: 'Past accent day event',
          startMs: DateTime.utc(2024, 6, 14, 15, 0),
          endMs: DateTime.utc(2024, 6, 14, 17, 0),
          updatedAtMs: DateTime.utc(2024, 6, 1),
        ),
      );
      batch.insert(
        db.calendarEvents,
        CalendarEventsCompanion.insert(
          id: 'accent-1',
          title: 'Accent day event',
          startMs: DateTime.utc(2024, 6, 16, 15, 0),
          endMs: DateTime.utc(2024, 6, 16, 17, 0),
          updatedAtMs: DateTime.utc(2024, 6, 1),
        ),
      );
    });
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
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
    expect(border.top.color, theme.colorScheme.secondaryContainer);

    final day14Decoration = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.text('14'),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.border != null);
    final pastBorder = day14Decoration.border as Border;
    expect(pastBorder.top.color, theme.colorScheme.secondaryContainer);

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
    expect(todayDecoration.color, theme.colorScheme.secondaryContainer);

    await db.close();
  });

  testWidgets('uses MediaQuery height when vertical max is unbounded',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: SingleChildScrollView(
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
    );
    await tester.pumpAndSettle();
    expect(find.text('Jun 2024'), findsOneWidget);
    await db.close();
  });

  testWidgets('accepts numeric leftFlex and rightFlex from config',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {'leftFlex': 2.0, 'rightFlex': 3.0},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
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
    await db.close();
  });

  testWidgets('replacing widget disposes timer', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
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
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
    await tester.pump();
    await db.close();
  });

  testWidgets('periodic timer elapses without throwing', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
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
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await db.close();
  });

  testWidgets('uses MediaQuery width when horizontal max is unbounded',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    const spec = ParsedWidgetSpec(
      type: 'calendar_month',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(500, 600)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
    );
    await tester.pumpAndSettle();
    expect(find.text('Jun 2024'), findsOneWidget);
    await db.close();
  });
}
