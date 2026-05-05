import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/dashboard/dashboard_viewport_scope.dart';

void main() {
  testWidgets('scaleOf defaults to 1 without scope', (tester) async {
    late double read;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          read = DashboardViewportScope.scaleOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(read, 1.0);
  });

  testWidgets('scaleOf returns scope value', (tester) async {
    late double read;
    await tester.pumpWidget(
      DashboardViewportScope(
        scale: 0.75,
        child: Builder(
          builder: (context) {
            read = DashboardViewportScope.scaleOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read, 0.75);
  });
}
