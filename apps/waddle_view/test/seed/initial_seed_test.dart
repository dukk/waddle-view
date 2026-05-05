import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:waddle_view/seed/initial_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureInitialSeed inserts weather provider and weather screen', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final provider = await (db.select(db.providerSettings)
          ..where((t) => t.id.equals('weather')))
        .getSingleOrNull();
    expect(provider, isNotNull);
    expect(provider!.providerType, 'weather');

    final screen = await (db.select(db.screenDefinitions)
          ..where((t) => t.id.equals('weather')))
        .getSingleOrNull();
    expect(screen, isNotNull);
    expect(screen!.layoutJson.contains('"type":"weather"'), isTrue);

    final locations = await (db.select(db.weatherLocations)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    expect(locations.map((e) => e.id), containsAll(<String>[
      'salt_lake_city_ut',
      'atlanta_ga',
    ]));
    await db.close();
  });
}
