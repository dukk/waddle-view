import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/bouncing_message_overlay.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';

void main() {
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
