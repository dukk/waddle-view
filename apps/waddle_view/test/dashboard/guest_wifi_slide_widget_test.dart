import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/dashboard/guest_wifi_slide_widget.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  testWidgets('shows headline, QR fields, and labels when KV configured', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.dashboardKv).insert(
          DashboardKvCompanion.insert(
            key: 'dashboard.guest_wifi.connection',
            value: 'WIFI:T:WPA;S:Lobby;P:guestpass;;',
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'guest_wifi',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            db: db,
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
    expect(find.text('SSID'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('respects custom kvKey and headline', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.dashboardKv).insert(
          DashboardKvCompanion.insert(
            key: 'wifi.custom',
            value: 'WIFI:T:WPA;S:Zone;P:secret;;',
          ),
        );
    final spec = ParsedWidgetSpec(
      type: 'guest_wifi',
      slot: 'main',
      config: {
        'kvKey': 'wifi.custom',
        'headline': 'Lobby WiFi',
      },
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            db: db,
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

  testWidgets('shows not configured when KV value is invalid', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.dashboardKv).insert(
          DashboardKvCompanion.insert(
            key: 'dashboard.guest_wifi.connection',
            value: 'not-a-wifi-string',
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'guest_wifi',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            db: db,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guest Wi‑Fi not configured'), findsOneWidget);
  });

  testWidgets('shows not configured when KV missing', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const spec = ParsedWidgetSpec(
      type: 'guest_wifi',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: GuestWifiSlideWidget(
            db: db,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guest Wi‑Fi not configured'), findsOneWidget);
  });
}
