import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  test('POST reset-defaults requires confirm=yes', () async {
    final harness = await RestTestHarness.start();
    addTearDown(() => harness.dispose());

    final res = await http.post(
      Uri.parse('${harness.baseUrl}/v1/display/catalog/reset-defaults'),
      headers: harness.authHeaders,
    );
    expect(res.statusCode, 400);
    expect(res.body, contains('confirm_required'));
  });

  test('POST reset-defaults removes custom catalog rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);

    await db
        .into(db.screens)
        .insert(
          ScreensCompanion.insert(
            id: 'custom_screen',
            label: 'Custom',
            screenType: 'static_text',
          ),
        );

    final harness = await RestTestHarness.start(database: db);
    addTearDown(() => harness.dispose());

    final res = await http.post(
      Uri.parse(
        '${harness.baseUrl}/v1/display/catalog/reset-defaults?confirm=yes',
      ),
      headers: harness.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['screens_seeded'], greaterThan(0));
    expect(body['tickers_seeded'], 5);
    expect(body['overlays_seeded'], 5);

    final custom = await (db.select(
      db.screens,
    )..where((t) => t.id.equals('custom_screen'))).getSingleOrNull();
    expect(custom, isNull);

    final welcome = await (db.select(
      db.screens,
    )..where((t) => t.id.equals('welcome'))).getSingleOrNull();
    expect(welcome, isNotNull);

    await db.close();
  });

  test('viewer role cannot reset catalog defaults', () async {
    final harness = await RestTestHarness.start(role: kUserRoleViewer);
    addTearDown(() => harness.dispose());

    final res = await http.post(
      Uri.parse(
        '${harness.baseUrl}/v1/display/catalog/reset-defaults?confirm=yes',
      ),
      headers: harness.authHeaders,
    );
    expect(res.statusCode, 403);
  });
}
