import 'dart:async' show StreamController, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/dashboard/dashboard_data_access.dart';
import 'package:waddle_view/dashboard/dashboard_data_bound_shell.dart';
import 'package:waddle_view/dashboard/dashboard_slot_descriptor.dart';
import 'package:waddle_view/theme/tv_overscan.dart';

void main() {
  testWidgets('header tracks DashboardDataAccess stream', (tester) async {
    final fake = FakeDashboardDataAccess();
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: DashboardDataBoundShell(
            data: fake,
            overscan: const TvOverscanInsets(),
            slots: const [
              DashboardSlotDescriptor(id: 'main', label: 'Main'),
            ],
            body: const Text('body'),
            ticker: const Text('ticker'),
            headerFallback: 'fallback',
          ),
        ),
      ),
    );

    expect(find.text('fallback'), findsOneWidget);

    fake.headerCtrl.add('Live title');
    await tester.pump();
    expect(find.text('Live title'), findsOneWidget);
    expect(find.text('fallback'), findsNothing);
  });
}

class FakeDashboardDataAccess implements DashboardDataAccess {
  FakeDashboardDataAccess();

  final headerCtrl = StreamController<String?>.broadcast();
  final _slotCtrls = <String, StreamController<String?>>{};

  @override
  Stream<String?> watchHeaderTitle() => headerCtrl.stream;

  @override
  Stream<String?> watchSlotSubtitle(String slotId) {
    return _slotCtrls
        .putIfAbsent(slotId, () => StreamController<String?>.broadcast())
        .stream;
  }

  void dispose() {
    headerCtrl.close();
    for (final c in _slotCtrls.values) {
      unawaited(c.close());
    }
  }
}
