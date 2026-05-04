import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/alerts/alert_overlay_host.dart';
import 'package:waddle_view/alerts/drift_alert_repository.dart';
import 'package:waddle_view/clock.dart';

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
}
