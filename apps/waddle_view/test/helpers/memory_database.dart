import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:waddle_view/persistence/database.dart';

var _didConfigureDriftForTests = false;

AppDatabase openMemoryDatabase() {
  if (!_didConfigureDriftForTests) {
    // Tests intentionally open many short-lived databases. Suppress the
    // expensive warning stack traces that can flood output and stall runs.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _didConfigureDriftForTests = true;
  }
  return AppDatabase(NativeDatabase.memory());
}

Future<void> warmDatabase(AppDatabase db) async {
  await db.customStatement('select 1');
}
