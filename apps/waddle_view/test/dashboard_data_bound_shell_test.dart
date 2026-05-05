import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/dashboard/dashboard_data_bound_shell.dart';
import 'package:waddle_view/theme/tv_overscan.dart';

void main() {
  testWidgets('DashboardDataBoundShell lays out body and ticker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: DashboardDataBoundShell(
            overscan: const TvOverscanInsets(),
            body: const Text('body'),
            ticker: const Text('ticker'),
          ),
        ),
      ),
    );

    expect(find.text('body'), findsOneWidget);
    expect(find.text('ticker'), findsOneWidget);
  });
}
