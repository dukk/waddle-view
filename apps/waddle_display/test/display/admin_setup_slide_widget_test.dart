import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/display/screens/admin_setup/admin_setup_slide_widget.dart';

void main() {
  testWidgets('shows base URL and instance id', (tester) async {
    final instanceFile = File(
      '${Directory.systemTemp.path}/wv_inst_${DateTime.now().microsecondsSinceEpoch}.id',
    )..writeAsStringSync('instance-hex-id\n', flush: true);
    addTearDown(() async {
      try {
        await instanceFile.delete();
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
            adminBaseUrl: 'http://192.168.1.4:8787',
            instanceIdFile: instanceFile,
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
    expect(find.textContaining('waddle_controller'), findsWidgets);
    expect(find.textContaining('instance-hex-id'), findsOneWidget);
  });
}
