import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/content_category_resolve.dart';

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
}
