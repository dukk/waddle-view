import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/alerts/alert_overlay_host.dart';
import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'helpers/memory_database.dart';

void main() {
  testWidgets('shows active alert from repository', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = DriftAlertRepository(db);
    await repo.insertAlert(title: 'Hello', body: 'World', qrPayload: 'https://x');
    final clock = FakeClock(DateTime.utc(2026, 1, 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertOverlayHost(
            repository: repo,
            clock: clock,
            child: const Text('base'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    await db.close();
  });

  testWidgets('Enter and numpad Enter dismiss active alert', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = DriftAlertRepository(db);
    await repo.insertAlert(title: 'First', body: 'one');
    final clock = FakeClock(DateTime.utc(2026, 1, 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertOverlayHost(
            repository: repo,
            clock: clock,
            child: const Text('base'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);

    await repo.insertAlert(title: 'Second', body: 'two');
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);

    await db.close();
  });

  testWidgets('severity icon respects display.alert.severity_icons JSON',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = DriftAlertRepository(db);
    await repo.insertAlert(title: 'Hdr', body: 'B', severity: 'warning');
    final clock = FakeClock(DateTime.utc(2026, 1, 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertOverlayHost(
            repository: repo,
            clock: clock,
            severityIconsKv: '{"warning":"favorite"}',
            child: const Text('base'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await db.close();
  });

  testWidgets('expiry shows countdown progress bar', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final t0 = DateTime.utc(2030, 1, 1, 12, 0, 0);
    await db.into(db.alerts).insert(
          AlertsCompanion.insert(
            title: 'Timed',
            body: 'Text',
            createdAt: t0,
            expiresAt: Value(t0.add(const Duration(seconds: 100))),
          ),
        );
    final repo = DriftAlertRepository(db);
    final clock = FakeClock(t0.add(const Duration(seconds: 30)));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertOverlayHost(
            repository: repo,
            clock: clock,
            child: const Text('base'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('alert_expiry_progress')),
      findsOneWidget,
    );
    await db.close();
  });
}
