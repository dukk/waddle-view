import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/display/screens/local_api/local_api_slide_widget.dart';
import 'package:waddle_display/theme/display_theme.dart';

void main() {
  testWidgets('shows base URL, headline, and API key hint', (tester) async {
    const spec = ParsedWidgetSpec(type: 'local_api', slot: 'main', config: {});
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: LocalApiSlideWidget(
            baseUrl: 'https://127.0.0.1:8787',
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );

    expect(find.text('Local REST API'), findsOneWidget);
    expect(find.text('https://127.0.0.1:8787'), findsOneWidget);
    expect(find.textContaining('/v1/adoption/request'), findsOneWidget);
    expect(find.textContaining('api_key'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.api_outlined));
    expect(icon.color, NavyCoralPalette.dustyDenim);
  });

  testWidgets('respects custom headline from config', (tester) async {
    const spec = ParsedWidgetSpec(
      type: 'local_api',
      slot: 'main',
      config: {'headline': 'REST'},
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: LocalApiSlideWidget(
            baseUrl: 'http://localhost:8787',
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );

    expect(find.text('REST'), findsOneWidget);
    expect(find.text('Local REST API'), findsNothing);
  });
}
