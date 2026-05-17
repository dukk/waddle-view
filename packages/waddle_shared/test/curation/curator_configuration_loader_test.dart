import 'package:test/test.dart';
import 'package:waddle_shared/curation/curator_configuration_loader.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('loadCuratorConfigurationInputs maps seeded configs members and rules', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);

    final inputs = await loadCuratorConfigurationInputs(db);
    expect(inputs.isNotEmpty, isTrue);

    final bootstrap = inputs.singleWhere((c) => c.id == 'bootstrap');
    expect(bootstrap.layer, kCuratorLayerExclusive);
    expect(bootstrap.rules, isNotEmpty);
    expect(bootstrap.screenMemberIds, isNotEmpty);

    final evening = inputs.singleWhere((c) => c.id == 'evening');
    expect(evening.layer, kCuratorLayerBase);
    expect(evening.tickerMemberIds, isNotEmpty);

    await db.close();
  });
}
