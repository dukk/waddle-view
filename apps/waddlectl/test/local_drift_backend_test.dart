import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddlectl/local_drift_backend.dart';

void main() {
  test('LocalDriftBackend config round-trip on temp sqlite', () async {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_db');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // Best-effort; temp dir may be locked or already removed.
      }
    });
    final dbFile = File(p.join(tmp.path, 'waddle_display.db'));
    final db = AppDatabase(createQueryExecutorForFile(dbFile));
    final backend = LocalDriftBackend(db);
    addTearDown(() async {
      await backend.close();
    });

    await backend.setConfig('waddlectl.test_key', 'hello');
    expect(await backend.getConfig('waddlectl.test_key'), 'hello');
    final rows = await backend.listConfig();
    expect(rows.any((e) => e['key'] == 'waddlectl.test_key'), isTrue);
    await backend.unsetConfig('waddlectl.test_key');
    expect(await backend.getConfig('waddlectl.test_key'), isNull);
  });

  test('reject-term CRUD + rescan + format', () async {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_db_reject');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // Best-effort cleanup of locked temp dirs.
      }
    });
    final dbFile = File(p.join(tmp.path, 'waddle_display.db'));
    final db = AppDatabase(createQueryExecutorForFile(dbFile));
    final backend = LocalDriftBackend(db);
    addTearDown(() async {
      await backend.close();
    });

    // Wipe out the seeded defaults so we can drive the test deterministically.
    await db.delete(db.rejectTerms).go();

    // Seed an RSS article that will match a future block term.
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'rejfeed',
            url: 'https://example.test/rss',
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'reject_a1',
            feedId: 'rejfeed',
            guid: 'g1',
            title: 'CussWord in the headline',
            link: 'https://x.test',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    // Invalid action throws.
    expect(
      () => backend.upsertRejectTerm(term: 'cussword', action: 'shrug'),
      throwsArgumentError,
    );

    final id = await backend.upsertRejectTerm(
      term: 'CussWord',
      action: 'block',
    );
    expect(id, isNotEmpty);

    final list = await backend.listRejectTerms();
    expect(list.single['term'], 'cussword');
    expect(list.single['action'], 'block');

    final res1 = await backend.rescanRejectContent();
    expect(res1['rss_articles_marked'], 1);
    expect(res1['total_marked'], 1);

    final res2 = await backend.rescanRejectContent();
    expect(res2['total_marked'], 0,
        reason: 'idempotent: already-suppressed rows are not re-counted');

    expect(
      () => backend.setRejectCensorFormat('rainbows'),
      throwsArgumentError,
    );
    await backend.setRejectCensorFormat('bracketed_token');
    expect(await backend.getRejectCensorFormat(), 'bracketed_token');

    final removedByTerm = await backend.removeRejectTermByTerm('cussword');
    expect(removedByTerm, 1);
    expect(await backend.listRejectTerms(), isEmpty);

    // Re-add and remove by id this time.
    final id2 = await backend.upsertRejectTerm(
      term: 'cussword',
      action: 'censor',
    );
    final removedById = await backend.removeRejectTermById(id2);
    expect(removedById, 1);
  });

  test('updateScreen mutates row', () async {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_db2');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // Best-effort; temp dir may be locked or already removed.
      }
    });
    final dbFile = File(p.join(tmp.path, 'waddle_display.db'));
    final db = AppDatabase(createQueryExecutorForFile(dbFile));
    final backend = LocalDriftBackend(db);
    addTearDown(() async {
      await backend.close();
    });

    await db
        .into(db.screens)
        .insert(
          ScreensCompanion.insert(
            id: 'waddlectl_test_screen',
            name: 'T',
            screenType: 'clock',
          ),
        );

    await backend.updateScreen(
      id: 'waddlectl_test_screen',
      name: 'Renamed',
      minDwellSeconds: 10,
      maxDwellSeconds: 14,
    );
    final row = await backend.describeScreen('waddlectl_test_screen');
    expect(row!['name'], 'Renamed');
    expect(row['min_dwell_seconds'], 10);
    expect(row['max_dwell_seconds'], 14);
  });
}
