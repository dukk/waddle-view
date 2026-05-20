import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:waddle_display/display/overlay/qr_code_overlay.dart';
import 'package:waddle_shared/persistence/display_overlay_clock_placement.dart';
import 'package:waddle_shared/persistence/display_overlay_qr_code_settings.dart';

void main() {
  testWidgets('QrCodeOverlay shows QR at placement with title', (tester) async {
    const settings = QrCodeOverlaySettings(
      placement: ClockOverlayPlacement(
        x: 0.5,
        y: 0.1,
        scale: 0.25,
        opacity: 1.0,
      ),
      payload: 'https://example.com',
      template: 'http',
      templateFields: {'url': 'https://example.com'},
      title: 'Scan here',
      description: 'Example link',
    );
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: QrCodeOverlay(
              settingsList: const [settings],
              theme: theme,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan here'), findsOneWidget);
    expect(find.text('Example link'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, closeTo(400, 0.01));
    expect(positioned.top, closeTo(60, 0.01));
    expect(positioned.width, closeTo(150, 0.01));
  });

  testWidgets('QrCodeOverlay hides when payload empty', (tester) async {
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: QrCodeOverlay(
              settingsList: const [QrCodeOverlaySettings.defaults],
              theme: theme,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
  });
}
