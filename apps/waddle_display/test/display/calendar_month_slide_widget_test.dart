import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/display/content_category_material_icon.dart';
import 'package:waddle_display/display/screens/calendar_month/calendar_month_slide_widget.dart';
import 'package:waddle_display/display/screens/calendar_month/calendar_upcoming_layout.dart';
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

  testWidgets('upcoming list shows large timed marker matching grid accent',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'marker-e',
            title: 'Marker match',
            startMs: DateTime.utc(2024, 6, 16, 15, 0),
            endMs: DateTime.utc(2024, 6, 16, 16, 0),
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
    final keyFinder =
        find.byKey(const ValueKey<String>('calendar_upcoming_marker_marker-e'));
    expect(keyFinder, findsOneWidget);
    final decorated = tester.widget<DecoratedBox>(keyFinder);
    final deco = decorated.decoration as BoxDecoration;
    expect(
      deco.color,
      calendarEventMarkerAccent(
        theme.colorScheme,
        CalendarEvent(
          id: 'marker-e',
          title: 'Marker match',
          startMs: DateTime.utc(2024, 6, 16, 15, 0),
          endMs: DateTime.utc(2024, 6, 16, 16, 0),
          allDay: false,
          source: 'local',
          updatedAtMs: DateTime.utc(2024, 6, 1),
        ),
      ),
    );
    expect(deco.shape, BoxShape.circle);
    final inner = tester.widget<SizedBox>(
      find.descendant(of: keyFinder, matching: find.byType(SizedBox)).first,
    );
    expect(inner.width, greaterThanOrEqualTo(8.0));
    expect(inner.height, greaterThanOrEqualTo(8.0));

    await db.close();
  });

  testWidgets('upcoming list shows large all-day square marker',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'marker-ad',
            title: 'All-day list marker',
            startMs: DateTime.utc(2024, 6, 16),
            endMs: DateTime.utc(2024, 6, 17),
            allDay: const Value(true),
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
    final keyFinder =
        find.byKey(const ValueKey<String>('calendar_upcoming_marker_marker-ad'));
    expect(keyFinder, findsOneWidget);
    final deco =
        tester.widget<DecoratedBox>(keyFinder).decoration as BoxDecoration;
    expect(deco.shape, isNot(BoxShape.circle));
    expect(deco.borderRadius, isNotNull);
    expect(
      deco.color,
      calendarEventMarkerAccent(
        theme.colorScheme,
        CalendarEvent(
          id: 'marker-ad',
          title: 'All-day list marker',
          startMs: DateTime.utc(2024, 6, 16),
          endMs: DateTime.utc(2024, 6, 17),
          allDay: true,
          source: 'local',
          updatedAtMs: DateTime.utc(2024, 6, 1),
        ),
      ),
    );

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

  testWidgets('shows timed markers on days with events and keeps today fill',
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

    int circleMarkerCountForInMonthDay(int day) {
      final column = find.descendant(
        of: find.byKey(calendarMonthInMonthDayCellKey(day)),
        matching: find.byType(Column),
      );
      var count = 0;
      for (final w in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: column,
          matching: find.byType(DecoratedBox),
        ),
      )) {
        final d = w.decoration;
        if (d is BoxDecoration && d.shape == BoxShape.circle) {
          count++;
        }
      }
      return count;
    }

    expect(circleMarkerCountForInMonthDay(16), greaterThanOrEqualTo(1));
    expect(circleMarkerCountForInMonthDay(14), greaterThanOrEqualTo(1));
    expect(circleMarkerCountForInMonthDay(15), 0);

    final day16Outer = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(calendarMonthInMonthDayCellKey(16)),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(day16Outer.decoration, isA<BoxDecoration>());
    expect((day16Outer.decoration as BoxDecoration).border, isNull);

    final day15Outer = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(calendarMonthInMonthDayCellKey(15)),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((day15Outer.decoration as BoxDecoration).color,
        theme.colorScheme.secondaryContainer);

    await db.close();
  });

  testWidgets('shows top squares for all-day events in month grid',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'allday-grid',
            title: 'Company holiday',
            startMs: DateTime.utc(2024, 6, 20),
            endMs: DateTime.utc(2024, 6, 21),
            allDay: const Value(true),
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

    int squareMarkerCountForInMonthDay(int day) {
      final column = find.descendant(
        of: find.byKey(calendarMonthInMonthDayCellKey(day)),
        matching: find.byType(Column),
      );
      var count = 0;
      for (final w in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: column,
          matching: find.byType(DecoratedBox),
        ),
      )) {
        final d = w.decoration;
        if (d is BoxDecoration &&
            d.shape != BoxShape.circle &&
            d.borderRadius != null) {
          count++;
        }
      }
      return count;
    }

    expect(squareMarkerCountForInMonthDay(20), greaterThanOrEqualTo(1));
    expect(squareMarkerCountForInMonthDay(16), 0);

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
