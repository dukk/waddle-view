import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/runtime/runtime_signal_repository.dart';

void main() {
  test('upsert and snapshot runtime signals', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = RuntimeSignalRepository(db);
    await repo.upsert(id: 'room.motion_detected', value: true);
    final snap = await repo.snapshot();
    expect(snap['room.motion_detected'], true);
    expect(await repo.boolValue('room.motion_detected'), isTrue);
  });
}
