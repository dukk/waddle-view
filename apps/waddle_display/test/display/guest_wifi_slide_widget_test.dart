import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/display/screens/guest_wifi/guest_wifi_slide_widget.dart';

void main() {
  testWidgets('shows headline, QR fields, and labels when connection configured', (
    tester,
  ) async {
    const spec = ParsedWidgetSpec(
      type: 'wifi',
      slot: 'main',
      config: {
        'connection': 'WIFI:T:WPA;S:Lobby;P:guestpass;;',
      },
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guest WiFi'), findsOneWidget);
    expect(find.text('Lobby'), findsOneWidget);
    expect(find.text('WPA'), findsOneWidget);
    expect(find.text('guestpass'), findsOneWidget);
    expect(find.text('SSID:'), findsOneWidget);
    expect(find.text('Security:'), findsOneWidget);
    expect(find.text('Password:'), findsOneWidget);
  });

  testWidgets('respects custom headline', (tester) async {
    const spec = ParsedWidgetSpec(
      type: 'wifi',
      slot: 'main',
      config: {
        'headline': 'Lobby WiFi',
        'connection': 'WIFI:T:WPA;S:Zone;P:secret;;',
      },
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lobby WiFi'), findsOneWidget);
    expect(find.text('Zone'), findsOneWidget);
  });

  testWidgets('shows not configured when connection value is invalid', (
    tester,
  ) async {
    const spec = ParsedWidgetSpec(
      type: 'wifi',
      slot: 'main',
      config: {
        'connection': 'not-a-wifi-string',
      },
    );
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wi‑Fi not configured'), findsOneWidget);
  });

  testWidgets('labels are bold and values use a monospaced font', (
    tester,
  ) async {
    const spec = ParsedWidgetSpec(
      type: 'wifi',
      slot: 'main',
      config: {
        'connection': 'WIFI:T:WPA;S:Lobby;P:guestpass;;',
      },
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in <String>['SSID:', 'Security:', 'Password:']) {
      final widget = tester.widget<Text>(find.text(label));
      expect(
        widget.style?.fontWeight,
        FontWeight.bold,
        reason: '$label should be bold',
      );
    }

    for (final value in <String>['Lobby', 'WPA', 'guestpass']) {
      final widget = tester.widget<Text>(find.text(value));
      expect(
        widget.style?.fontFamily,
        kGuestWifiValueMonospaceFontFamily,
        reason:
            '$value should set a primary monospaced fontFamily so the fallback '
            'list actually applies (otherwise Roboto renders ASCII and the '
            'fallback never engages)',
      );
      final fallback = widget.style?.fontFamilyFallback ?? const <String>[];
      expect(
        fallback,
        equals(kGuestWifiValueMonospaceFontFamilyFallback),
        reason: '$value should use the monospaced font fallback',
      );
    }
  });

  testWidgets('shows not configured when connection missing', (tester) async {
    const spec = ParsedWidgetSpec(
      type: 'wifi',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wi‑Fi not configured'), findsOneWidget);
  });
}
