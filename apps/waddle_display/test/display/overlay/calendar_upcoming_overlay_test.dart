import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_display/display/overlay/calendar_upcoming_overlay.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_calendar_upcoming_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_clock_placement.dart';

import '../../helpers/fake_blob_store.dart';
import '../../helpers/memory_database.dart';

void main() {
  testWidgets('CalendarUpcomingOverlay shows heading and positioned list',
      (tester) async {
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
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
    const settings = CalendarUpcomingOverlaySettings(
      placement: ClockOverlayPlacement(
        x: 0.72,
        y: 0.05,
        scale: 0.4,
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
            child: CalendarUpcomingOverlay(
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

    expect(find.text('Upcoming events'), findsOneWidget);
    expect(find.text('Birthday party'), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, closeTo(576, 1.0));
    expect(positioned.top, closeTo(30, 0.01));

    await db.close();
  });

  testWidgets('CalendarUpcomingOverlay shows empty state when no events',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db, displayTimeZoneIana: 'Etc/UTC');
    final clock = FakeClock(DateTime.utc(2024, 6, 15, 9, 0));
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: CalendarUpcomingOverlay(
              db: db,
              blobs: FakeBlobStore(),
              settingsList: [CalendarUpcomingOverlaySettings.defaults],
              theme: theme,
              clock: clock,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upcoming events'), findsOneWidget);
    expect(find.text('No upcoming events.'), findsOneWidget);

    await db.close();
  });
}
