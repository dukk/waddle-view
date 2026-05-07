import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/pexels/pexels_attribution_overlay.dart';

void main() {
  testWidgets('renders attribution details and opens photographer url', (
    tester,
  ) async {
    String? openedUrl;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PexelsAttributionOverlay(
            photographerName: 'Alex Shooter',
            photographerUrl: 'https://www.pexels.com/@alex',
            altText: 'Sunrise on river',
            theme: ThemeData.dark(),
            scale: 1,
            onOpenUrl: (url) async {
              openedUrl = url;
            },
          ),
        ),
      ),
    );

    expect(find.text('Alex Shooter'), findsOneWidget);
    expect(find.textContaining('pexels.com/@alex'), findsOneWidget);
    expect(find.text('Sunrise on river'), findsOneWidget);

    await tester.tap(find.textContaining('pexels.com/@alex'));
    await tester.pump();
    expect(openedUrl, 'https://www.pexels.com/@alex');
  });
}
