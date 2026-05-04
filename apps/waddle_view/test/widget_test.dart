import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/dashboard/dashboard_shell.dart';
import 'package:waddle_view/dashboard/dashboard_slot_descriptor.dart';
import 'package:waddle_view/theme/tv_overscan.dart';

void main() {
  testWidgets('DashboardShell lays out header, body, and ticker', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardShell(
            overscan: TvOverscanInsets(),
            slots: [DashboardSlotDescriptor(id: 'a', label: 'A')],
            header: Text('hdr'),
            body: Text('body'),
            ticker: Text('tick'),
          ),
        ),
      ),
    );
    expect(find.text('hdr'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(find.text('tick'), findsOneWidget);
  });
}
