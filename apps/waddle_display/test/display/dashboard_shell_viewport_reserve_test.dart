import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/dashboard_shell.dart';
import 'package:waddle_display/theme/tv_overscan.dart';
import 'package:waddle_shared/display/display_viewport_reserve.dart';

void main() {
  testWidgets('viewport reserve shrinks body area inside shell', (tester) async {
    final bodyKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1920,
            height: 1080,
            child: DashboardShell(
              overscan: const TvOverscanInsets(
                fractionOfShortestSide: 0,
                minimum: 0,
              ),
              body: ColoredBox(
                key: bodyKey,
                color: Colors.red,
                child: const SizedBox.expand(),
              ),
              ticker: const SizedBox(height: 10, child: ColoredBox(color: Colors.blue)),
              viewportReserve: const DisplayViewportReservePct(top: 10),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bodyBox = tester.renderObject<RenderBox>(
      find.byKey(bodyKey),
    );
    final shellBox = tester.renderObject<RenderBox>(
      find.byType(DashboardShell),
    );
    expect(bodyBox.size.height, lessThan(shellBox.size.height * 0.95));
  });
}
