import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../../helpers/memory_database.dart';
import 'package:waddle_display/display/screens/kv/kv_list_slide_widget.dart';

void main() {
  testWidgets('kv_list shows items from integration KV', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedStubIntegrationForTest(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: 'default_general_openai',
            integrationType: 'general_openai',
          ),
        );
    final kv = IntegrationKvRepository(db);
    await kv.upsertIntegration(
      integrationId: 'default_general_openai',
      key: 'prompt.daily_summary.latest',
      value: '["Alpha","Beta"]',
      valueType: kIntegrationKvTypeJson,
    );

    const spec = ParsedWidgetSpec(
      type: 'kv_list',
      slot: 'left',
      config: {
        'integrationId': 'default_general_openai',
        'valueKey': 'prompt.daily_summary.latest',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KvListSlideWidget(
            db: db,
            spec: spec,
            theme: ThemeData(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    await db.close();
  });
}
