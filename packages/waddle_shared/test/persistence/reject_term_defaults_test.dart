import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_defaults.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('fresh database seeds default reject terms', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    final rows = await db.select(db.rejectTerms).get();
    expect(rows.length, greaterThanOrEqualTo(kDefaultRejectTermSeeds.length));

    final seededIds = kDefaultRejectTermSeeds.map((s) => s.id).toSet();
    final dbIds = rows.map((r) => r.id).toSet();
    expect(dbIds.containsAll(seededIds), isTrue);

    final block = rows.firstWhere((r) => r.id == 'default_fuck');
    expect(block.action, kRejectTermActionBlock);
    final censor = rows.firstWhere((r) => r.id == 'default_damn');
    expect(censor.action, kRejectTermActionCensor);
  });
}
