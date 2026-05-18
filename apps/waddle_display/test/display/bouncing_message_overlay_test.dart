import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/bouncing_message_overlay.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';

void main() {
  group('integrateBouncingMessagePosition', () {
    test('right edge uses full rendered width', () {
      const areaW = 400.0;
      const textW = 120.0;
      final maxX = areaW - textW;

      var x = 50.0;
      var vx = 300.0;
      for (var i = 0; i < 200; i++) {
        final state = integrateBouncingMessagePosition(
          x: x,
          y: 40,
          vx: vx,
          vy: 0,
          dt: 0.016,
          speed: 1,
          areaW: areaW,
          areaH: 300,
          textW: textW,
          textH: 40,
        );
        x = state.x;
        vx = state.vx;
        expect(x, greaterThanOrEqualTo(0));
        expect(x, lessThanOrEqualTo(maxX + 0.01));
        expect(x + textW, lessThanOrEqualTo(areaW + 0.01));
      }
    });

    test('reflects when approaching right edge', () {
      const areaW = 300.0;
      const textW = 80.0;
      final maxX = areaW - textW;
      final state = integrateBouncingMessagePosition(
        x: maxX - 5,
        y: 10,
        vx: 500,
        vy: 0,
        dt: 0.05,
        speed: 1,
        areaW: areaW,
        areaH: 200,
        textW: textW,
        textH: 40,
      );
      expect(state.x, maxX);
      expect(state.vx, lessThan(0));
    });
  });

  testWidgets('measures rendered text and keeps full message visible', (tester) async {
    const message = 'Happy Birthday Waddle!!';
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: BouncingMessageOverlay(
              settings: BouncingMessageScheduleSettings.defaults,
              text: message,
              fallbackColor: Colors.white,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(message), findsOneWidget);
    expect(tester.takeException(), isNull);

    final textBox = tester.renderObject<RenderBox>(find.text(message));
    expect(textBox.size.width, greaterThan(200));
    expect(textBox.size.height, greaterThan(30));

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text(message), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('positions text and advances on ticker ticks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: BouncingMessageOverlay(
              settings: BouncingMessageScheduleSettings.defaults,
              text: 'Hello',
              fallbackColor: Colors.white,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('bouncing_message_positioned')), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('blank message renders single space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: BouncingMessageOverlay(
              settings: BouncingMessageScheduleSettings.defaults,
              text: '   ',
              fallbackColor: Colors.white,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(' '), findsOneWidget);
  });
}
