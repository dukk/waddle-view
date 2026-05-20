import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/bootstrap/deferred_config_changed.dart';
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  test('scheduleDeferredConfigChanged returns before slow work completes', () async {
    final gate = Completer<void>();
    var workStarted = false;

    final pending = scheduleDeferredConfigChanged(() async {
      workStarted = true;
      await gate.future;
    });

    await pending;
    expect(workStarted, isTrue);
    expect(gate.isCompleted, isFalse);

    gate.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('PATCH curator configuration responds before onConfigChanged work finishes',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);

    final gate = Completer<void>();
    var refreshStarted = false;

    final h = await RestTestHarness.start(
      database: db,
      onConfigChanged: () async {
        await scheduleDeferredConfigChanged(() async {
          refreshStarted = true;
          await gate.future;
        });
      },
    );
    addTearDown(h.dispose);

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/curator/configurations/evening'),
      headers: h.authHeaders,
      body: jsonEncode({'ticker_pixels_per_second': 42}),
    );

    expect(patch.statusCode, 200);
    expect(refreshStarted, isTrue);
    expect(gate.isCompleted, isFalse);

    gate.complete();
    await Future<void>.delayed(Duration.zero);
  });
}
