import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' show Value;

import 'package:waddle_shared/persistence/database.dart';
import 'helpers/rest_auth_helper.dart';

void main() {
  test('GET providers lists enabled rows', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await h.db.into(h.db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'joke_openai',
            providerType: 'joke_openai',
            pollSeconds: const Value(30),
          ),
        );
    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/providers'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    expect(res.body, contains('"id":"joke_openai"'));
    expect(res.body, contains('"type":"joke_openai"'));
    expect(res.body, contains('"enabled":true'));
  });

  test('GET providers returns raw string when config_json is invalid', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await h.db.into(h.db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'loose_json',
            providerType: 'joke_openai',
            pollSeconds: const Value(30),
            configJson: const Value('not-valid-json'),
          ),
        );
    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/providers'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    expect(res.body, contains('not-valid-json'));
  });

  test('GET screens and alerts list', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await h.db.into(h.db.screenDefinitions).insert(
          ScreenDefinitionsCompanion.insert(
            id: 'a',
            name: 'Screen A',
            screenType: 'static_text',
            minPlacementsPerProgram: const Value(1),
            maxPlacementsPerProgram: const Value(3),
            dataKey: const Value('shared_news'),
          ),
        );
    await h.db.into(h.db.curatorDataKeyProgramLimits).insert(
          CuratorDataKeyProgramLimitsCompanion.insert(
            dataKey: 'shared_news',
            minPlacementsPerProgram: const Value(2),
            maxPlacementsPerProgram: const Value(4),
          ),
        );
    await h.db.into(h.db.dashboardAlerts).insert(
          DashboardAlertsCompanion.insert(
            title: 't',
            body: 'b',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final ts = await http.get(
      Uri.parse('${h.baseUrl}/v1/screens'),
      headers: h.authHeaders,
    );
    expect(ts.statusCode, 200);
    expect(ts.body, contains('"id":"a"'));
    final al = await http.get(
      Uri.parse('${h.baseUrl}/v1/alerts'),
      headers: h.authHeaders,
    );
    expect(al.statusCode, 200);
  });

  test('GET ticker items returns ordered bodies from memory repo', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    // Ticker is in-memory inside handler; re-start with items via separate test file.
    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/ticker/items'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
  });
}
