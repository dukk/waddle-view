import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/photo_category_assignments.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test(
    'replacePhotoCategoryAssignments resolves display labels to ids',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await warmDatabase(db);
      await ensureInitialSeed(db);
      await db
          .into(db.photos)
          .insert(
            PhotosCompanion.insert(
              id: 'p1',
              category: const Value('general'),
              dataProvider: const Value(kMediaDataProviderPhotoOneDrive),
              mediaBlobKey: 'blob',
              photographerName: 'a',
              photographerUrl: '',
              pageUrl: '',
              fetchedAtMs: DateTime.utc(2020),
            ),
          );

      await replacePhotoCategoryAssignments(
        db,
        photoId: 'p1',
        categoryIds: const ['Family'],
      );

      final junction = await (db.select(
        db.photoCategories,
      )..where((t) => t.photoId.equals('p1'))).get();
      expect(junction.map((r) => r.categoryId).toList(), ['family']);

      final photo = await (db.select(
        db.photos,
      )..where((t) => t.id.equals('p1'))).getSingle();
      expect(photo.category, 'family');
    },
  );
}
