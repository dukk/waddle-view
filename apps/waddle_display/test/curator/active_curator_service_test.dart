import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/active_curator_service.dart';
import 'package:waddle_display/curator/curator_membership_filter.dart';
import 'package:waddle_display/curator/curator_runtime_state_builder.dart';
import 'package:waddle_shared/auth/adoption_crypto.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('CuratorRuntimeStateBuilder reflects api_clients adoption', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    addTearDown(db.close);

    final builder = CuratorRuntimeStateBuilder(db: db);
    expect((await builder.build()).displayAdopted, isFalse);

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.apiClients).insert(
          ApiClientsCompanion.insert(
            id: 'c1',
            identifier: 'test',
            role: 'admin',
            apiKeyHash: hashAdoptionApiKey('key'),
            createdAtMs: now,
            updatedAtMs: now,
          ),
        );
    expect((await builder.build()).displayAdopted, isTrue);
  });

  test('ActiveCuratorService selects bootstrap when display not adopted', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    addTearDown(db.close);
    await ensureInitialSeed(db);

    final service = ActiveCuratorService(db: db);
    final sel = await service.resolveAt(DateTime(2026, 5, 13, 10));
    expect(sel.exclusive?.configuration.id, 'bootstrap');
    expect(sel.base, isNull);
  });

  test('ActiveCuratorService selects base daypart when adopted', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    addTearDown(db.close);
    await ensureInitialSeed(db);

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.apiClients).insert(
          ApiClientsCompanion.insert(
            id: 'c1',
            identifier: 'test',
            role: 'admin',
            apiKeyHash: hashAdoptionApiKey('key'),
            createdAtMs: now,
            updatedAtMs: now,
          ),
        );

    final service = ActiveCuratorService(db: db);
    final sel = await service.resolveAt(DateTime(2026, 5, 13, 19));
    expect(sel.exclusive, isNull);
    expect(sel.base, isNotNull);
    expect(sel.base!.configuration.id, 'evening');
  });

  test('CuratorMembershipFilter holds allow-lists', () {
    final filter = CuratorMembershipFilter()
      ..tickerTapeIds = {'ticker_time'}
      ..overlayIds = {'overlay_confetti'};
    expect(filter.tickerTapeIds, {'ticker_time'});
    expect(filter.overlayIds, {'overlay_confetti'});
  });
}
