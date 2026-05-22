import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/content_category_resolve.dart';

import '../helpers/memory_database.dart';

void main() {
  test('resolveCategoryIdFromConfigMap prefers label then id', () {
    final map = {'news': 'news', 'News': 'news'};
    expect(
      resolveCategoryIdFromConfigMap({'categoryName': 'News'}, map),
      'news',
    );
    expect(
      resolveCategoryIdFromConfigMap({'categoryId': 'news'}, map),
      'news',
    );
  });

  test('resolveCategoryIdsFromConfigMap preserves order', () {
    final map = {'a': 'id_a', 'b': 'id_b'};
    expect(
      resolveCategoryIdsFromConfigMap(
        {'categoryNames': ['a', 'b']},
        map,
      ),
      ['id_a', 'id_b'],
    );
  });

  test('resolveCategoryIdsFromConfigMap uses categoryName when names absent', () {
    final map = {'Science': 'science'};
    expect(
      resolveCategoryIdsFromConfigMap({'categoryName': 'Science'}, map),
      ['science'],
    );
  });

  test('resolveContentCategoryId resolves label and id from database', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['work'], label: 'Work');

    expect(await resolveContentCategoryId(db, 'Work'), 'work');
    expect(await resolveContentCategoryId(db, 'work'), 'work');
    expect(await resolveContentCategoryId(db, 'missing'), isNull);
    expect(await resolveContentCategoryId(db, '  '), isNull);
  });

  test('resolveContentCategoryIds deduplicates and skips unknown', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['a', 'b']);

    expect(
      await resolveContentCategoryIds(db, ['a', 'a', 'b', 'unknown', '']),
      ['a', 'b'],
    );
  });

  test('resolveCategoryFromConfig prefers categoryNames list', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['news', 'sports'], label: 'News');

    expect(
      await resolveCategoryFromConfig(db, {
        'categoryNames': ['News', 'sports'],
      }),
      'news',
    );
    expect(
      await resolveCategoryNamesListFromConfig(db, {
        'categoryName': 'sports',
      }),
      ['sports'],
    );
    expect(
      await resolveCategoryFromConfig(db, {'categoryId': 'news'}),
      'news',
    );
    expect(await resolveCategoryFromConfig(db, const {}), isNull);
  });
}
