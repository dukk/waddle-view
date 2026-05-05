import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/api/local_rest_server.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/dashboard/admin_setup_slide_widget.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  testWidgets(
    'shows admin URL and password during bootstrap',
    (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.dashboardKv).insert(
          DashboardKvCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '0',
          ),
        );
    final keyFile = await _tempKeyFile('first-password');

    const spec = ParsedWidgetSpec(type: 'admin_setup', slot: 'main', config: {});
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: TickerMode(
            enabled: false,
            child: AdminSetupSlideWidget(
              db: db,
              adminBaseUrl: 'http://192.168.1.4:8787',
              setupPasswordFile: keyFile,
              spec: spec,
              theme: theme,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('/admin/login'), findsOneWidget);
    expect(find.textContaining('first-password'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
    },
    skip: true,
  );

  testWidgets(
    'hides bootstrap password when setup done',
    (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.dashboardKv).insert(
          DashboardKvCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '1',
          ),
        );
    final keyFile = await _tempKeyFile('first-password');

    const spec = ParsedWidgetSpec(type: 'admin_setup', slot: 'main', config: {});
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: TickerMode(
            enabled: false,
            child: AdminSetupSlideWidget(
              db: db,
              adminBaseUrl: 'http://192.168.1.4:8787',
              setupPasswordFile: keyFile,
              spec: spec,
              theme: theme,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('first-password'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
    },
    skip: true,
  );
}

Future<File> _tempKeyFile(String value) async {
  final dir = await Directory.systemTemp.createTemp('wv_setup_widget_');
  final file = File('${dir.path}/waddle_api.key');
  await file.writeAsString('$value\n', flush: true);
  return file;
}
