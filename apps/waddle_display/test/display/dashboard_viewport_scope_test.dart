import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/dashboard_viewport_scope.dart';

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

  testWidgets('scaleOf updates when inherited scale changes in place', (
    tester,
  ) async {
    late double read;
    final key = GlobalKey<_DashboardScaleProbeState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _DashboardScaleProbe(
          key: key,
          onRead: (v) => read = v,
        ),
      ),
    );
    expect(read, 1.0);

    key.currentState!.setScale(0.5);
    await tester.pump();
    expect(read, 0.5);
  });
}

class _DashboardScaleProbe extends StatefulWidget {
  const _DashboardScaleProbe({super.key, required this.onRead});

  final void Function(double) onRead;

  @override
  State<_DashboardScaleProbe> createState() => _DashboardScaleProbeState();
}

class _DashboardScaleProbeState extends State<_DashboardScaleProbe> {
  double _scale = 1.0;

  void setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    return DashboardViewportScope(
      scale: _scale,
      child: Builder(
        builder: (context) {
          widget.onRead(DashboardViewportScope.scaleOf(context));
          return const SizedBox();
        },
      ),
    );
  }
}
