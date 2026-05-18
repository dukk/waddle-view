import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/display/dashboard_data_bound_shell.dart';
import 'package:waddle_display/display/display_viewport.dart';
import 'package:waddle_display/theme/tv_overscan.dart';

void main() {
  testWidgets('DashboardDataBoundShell lays out body and ticker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: DashboardDataBoundShell(
            overscan: const TvOverscanInsets(),
            viewportConfig: const DisplayViewportConfig(
              aspectRatio: DashboardAspectRatio.ultrawide21x9,
              orientation: DashboardOrientation.vertical,
            ),
            body: const Text('body'),
            ticker: const Text('ticker'),
          ),
        ),
      ),
    );

    expect(find.text('body'), findsOneWidget);
    expect(find.text('ticker'), findsOneWidget);
  });

  testWidgets('DashboardDataBoundShell omits ticker when showTicker is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: DashboardDataBoundShell(
            overscan: const TvOverscanInsets(),
            viewportConfig: const DisplayViewportConfig(
              aspectRatio: DashboardAspectRatio.ultrawide21x9,
              orientation: DashboardOrientation.vertical,
            ),
            showTicker: false,
            body: const Text('body'),
            ticker: const Text('ticker'),
          ),
        ),
      ),
    );

    expect(find.text('body'), findsOneWidget);
    expect(find.text('ticker'), findsNothing);
  });
}
