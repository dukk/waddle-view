import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/clock.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/sleeper.dart';
import 'package:waddle_view/ticker/drift_ticker_schedule_repository.dart';
import 'package:waddle_view/ticker/ticker_condition_evaluator.dart';
import 'package:waddle_view/ticker/ticker_rotation_controller.dart';
import 'package:waddle_view/ticker/ticker_strip.dart';

import 'helpers/memory_database.dart';

void main() {
  testWidgets('shows em dash when label null', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerScreens).insert(
          TickerScreensCompanion.insert(id: 'z', enabled: const Value(false)),
        );
    final c = TickerRotationController(
      repository: DriftTickerScheduleRepository(db),
      evaluator: const TickerConditionEvaluator(),
      clock: FakeClock(DateTime(2026, 5, 10)),
      sleeper: FakeSleeper(),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TickerStrip(controller: c))),
    );
    expect(find.text('\u2014'), findsOneWidget);
    await db.close();
  });
}
