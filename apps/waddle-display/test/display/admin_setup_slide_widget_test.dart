import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_layout_parse.dart';
import 'package:waddle_display/display/screens/admin_setup/admin_setup_slide_widget.dart';
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('config key insert and select completes', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kAdminBootstrapDoneKvKey,
            value: '0',
          ),
        );
    final rows = await db.select(db.configKeyValues).get();
    expect(rows.single.value, '0');
    await db.close();
  });

  testWidgets(
    'shows admin URL and password during bootstrap',
    (tester) async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await db.into(db.configKeyValues).insert(
            ConfigKeyValuesCompanion.insert(
              key: kAdminBootstrapDoneKvKey,
              value: '0',
            ),
          );
      final keyFile = File(
        '${Directory.systemTemp.path}/wv_setup_pw_${DateTime.now().microsecondsSinceEpoch}.txt',
      )..writeAsStringSync('first-password\n', flush: true);
      addTearDown(() async {
        try {
          await keyFile.delete();
        } catch (_) {}
      });

      const spec = ParsedWidgetSpec(
        type: 'admin_setup',
        slot: 'main',
        config: {'showLoginQr': false},
      );
      final theme = ThemeData.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: AdminSetupSlideWidget(
              db: db,
              adminBaseUrl: 'http://192.168.1.4:8787',
              setupPasswordFile: keyFile,
              spec: spec,
              theme: theme,
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        });
        await tester.pump();
      }
      expect(find.text('Complete device setup'), findsOneWidget);
      expect(find.textContaining('/admin/login'), findsOneWidget);
      expect(find.textContaining('Install password'), findsOneWidget);
      final selectables =
          tester.widgetList<SelectableText>(find.byType(SelectableText));
      expect(
        selectables.map((s) => s.data).whereType<String>(),
        contains(contains('first-password')),
      );
      await db.close();
    },
  );

  testWidgets(
    'hides bootstrap password when setup done',
    (tester) async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await db.into(db.configKeyValues).insert(
            ConfigKeyValuesCompanion.insert(
              key: kAdminBootstrapDoneKvKey,
              value: '1',
            ),
          );
      final keyFile = File(
        '${Directory.systemTemp.path}/wv_setup_pw_${DateTime.now().microsecondsSinceEpoch}.txt',
      )..writeAsStringSync('first-password\n', flush: true);
      addTearDown(() async {
        try {
          await keyFile.delete();
        } catch (_) {}
      });

      const spec = ParsedWidgetSpec(
        type: 'admin_setup',
        slot: 'main',
        config: {'showLoginQr': false},
      );
      final theme = ThemeData.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: AdminSetupSlideWidget(
              db: db,
              adminBaseUrl: 'http://192.168.1.4:8787',
              setupPasswordFile: keyFile,
              spec: spec,
              theme: theme,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {});
      await tester.pump();
      expect(find.textContaining('first-password'), findsNothing);
      await db.close();
    },
  );
}
