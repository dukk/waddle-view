import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:waddle_display/persistence/database.dart';

AppDatabase openMemoryDatabase() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

Future<void> warmDatabase(AppDatabase db) async {
  await db.customStatement('select 1');
}
