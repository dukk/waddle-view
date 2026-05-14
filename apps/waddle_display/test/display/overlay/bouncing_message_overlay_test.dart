import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/bouncing_message_overlay.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';

void main() {
  testWidgets('BouncingMessageOverlay lays out bouncing layer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: BouncingMessageOverlay(
              settings: BouncingMessageScheduleSettings.parse('{}'),
              text: 'Hello',
              fallbackColor: Colors.deepPurple,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('bouncing_message_positioned')), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Hello'), findsOneWidget);
  });
}
