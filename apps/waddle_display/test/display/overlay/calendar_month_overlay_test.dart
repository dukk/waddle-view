import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_display/display/overlay/calendar_month_overlay.dart';
import 'package:waddle_display/display/screens/calendar_month/calendar_month_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_calendar_month_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_clock_placement.dart';

import '../../helpers/fake_blob_store.dart';
import '../../helpers/memory_database.dart';

void main() {
  testWidgets('CalendarMonthOverlay shows month title and positioned grid',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
    const settings = CalendarMonthOverlaySettings(
      placement: ClockOverlayPlacement(
        x: 0.05,
        y: 0.1,
        scale: 0.22,
        opacity: 1.0,
      ),
    );
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: CalendarMonthOverlay(
              db: db,
              blobs: FakeBlobStore(),
              settingsList: const [settings],
              theme: theme,
              clock: clock,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jun 2024'), findsOneWidget);
    expect(find.byKey(calendarMonthInMonthDayCellKey(15)), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, closeTo(40, 0.01));
    expect(positioned.top, closeTo(60, 0.01));

    await db.close();
  });

  testWidgets('CalendarMonthOverlay filters markers by categoryId',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    await seedContentCategoriesForTest(db, ['work']);
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e-work',
            title: 'Work meeting',
            startMs: DateTime.utc(2024, 6, 20, 14, 0),
            endMs: DateTime.utc(2024, 6, 20, 15, 0),
            categoryId: const Value('work'),
            updatedAtMs: DateTime.utc(2024, 6, 1),
          ),
        );
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
    final settings = CalendarMonthOverlaySettings(
      placement: const ClockOverlayPlacement(
        x: 0.05,
        y: 0.1,
        scale: 0.35,
        opacity: 1.0,
      ),
      categoryId: 'work',
    );
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: CalendarMonthOverlay(
              db: db,
              blobs: FakeBlobStore(),
              settingsList: [settings],
              theme: theme,
              clock: clock,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jun 2024'), findsOneWidget);
    expect(find.text('Work meeting'), findsNothing);

    await db.close();
  });
}
