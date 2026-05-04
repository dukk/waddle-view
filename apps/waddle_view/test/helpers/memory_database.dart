import 'package:drift/native.dart';
import 'package:waddle_view/persistence/database.dart';

AppDatabase openMemoryDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

Future<void> warmDatabase(AppDatabase db) async {
  await db.customStatement('select 1');
}
