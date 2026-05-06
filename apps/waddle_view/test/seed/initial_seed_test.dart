import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:waddle_view/persistence/content_category_defaults.dart';
import 'package:waddle_view/persistence/tables.dart';
import 'package:waddle_view/seed/initial_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureInitialSeed is idempotent on second run', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final providers1 = await db.select(db.providerSettings).get();
    await ensureInitialSeed(db);
    final providers2 = await db.select(db.providerSettings).get();
    expect(providers2.length, providers1.length);
    await db.close();
  });

  test('ensureInitialSeed inserts news screens with data_key news', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final left = await (db.select(db.screenDefinitions)
          ..where((t) => t.id.equals('news')))
        .getSingleOrNull();
    final right = await (db.select(db.screenDefinitions)
          ..where((t) => t.id.equals('news_right')))
        .getSingleOrNull();
    final columns = await (db.select(db.screenDefinitions)
          ..where((t) => t.id.equals('news_columns')))
        .getSingleOrNull();
    expect(left, isNotNull);
    expect(right, isNotNull);
    expect(columns, isNotNull);
    expect(left!.dataKey, 'news');
    expect(right!.dataKey, 'news');
    expect(columns!.dataKey, 'news');
    expect(left.layoutJson.contains('"imageOnRight":true'), isFalse);
    expect(right.layoutJson.contains('"imageOnRight":true'), isTrue);
    expect(columns.layoutJson.contains('"type":"rss_article_columns"'), isTrue);
    expect(columns.layoutJson.contains('"columnCount":3'), isTrue);
    await db.close();
  });

  test('ensureInitialSeed seeds curator program keys in config_key_values', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final rows = await db.select(db.configKeyValues).get();
    final byKey = {for (final r in rows) r.key: r.value};
    expect(byKey[kCuratorProgramDurationSecondsKvKey], '180');
    expect(byKey[kCuratorHistoryDepthKvKey], '5');
    expect(byKey['curator.news.require_photo_for_curation'], 'true');
    await db.close();
  });

  test('ensureInitialSeed seeds content_categories with material icons', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final rows = await db.select(db.contentCategories).get();
    expect(rows.length, kContentCategoryDefaults.length);
    final tech = await (db.select(db.contentCategories)
          ..where((t) => t.id.equals('technology')))
        .getSingle();
    expect(tech.materialIconName, 'memory');
    expect(tech.iconBlobKey, isNull);
    await db.close();
  });

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
