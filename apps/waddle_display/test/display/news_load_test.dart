import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/news/news_load.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('loadRssArticleImage returns absent when no image key', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsRssFeeds)
        .insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f1',
            url: 'http://t/feed',
            category: const Value('x'),
          ),
        );
    await db
        .into(db.news)
        .insert(
          NewsCompanion.insert(
            id: 'a1',
            sourceType: kNewsSourceTypeRss,
            sourceId: 'f1',
            guid: 'g',
            title: 't',
            link: 'http://t',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final article = await (db.select(
      db.news,
    )..where((t) => t.id.equals('a1'))).getSingle();
    final load = await loadRssArticleImage(db, FailingReadBlobStore(), article);
    expect(load.bytes, equals(null));
    expect(load.blobReadFailed, isFalse);
    await db.close();
  });

  test(
    'loadRssArticleImage marks blobReadFailed when BlobStore.readBytes throws',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await db
          .into(db.interestsRssFeeds)
          .insert(
            InterestsRssFeedsCompanion.insert(
              id: 'f1',
              url: 'http://t/feed',
              category: const Value('x'),
            ),
          );
      await db
          .into(db.blobMetadata)
          .insert(
            BlobMetadataCompanion.insert(
              blobKey: 'key1',
              sha256: 'path1',
              relativePath: 'path1',
              bytes: 4,
              capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          );
      await db
          .into(db.news)
          .insert(
            NewsCompanion.insert(
              id: 'a1',
              sourceType: kNewsSourceTypeRss,
              sourceId: 'f1',
              guid: 'g',
              title: 't',
              link: 'http://t',
              publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
              fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
              imageBlobKey: const Value('key1'),
            ),
          );
      final article = await (db.select(
        db.news,
      )..where((t) => t.id.equals('a1'))).getSingle();
      final load = await loadRssArticleImage(db, FailingReadBlobStore(), article);
      expect(load.bytes, equals(null));
      expect(load.blobReadFailed, isTrue);
      await db.close();
    },
  );

  test('loadRssArticleImage returns bytes when blob read succeeds', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsRssFeeds)
        .insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f1',
            url: 'http://t/feed',
            category: const Value('x'),
          ),
        );
    await db
        .into(db.blobMetadata)
        .insert(
          BlobMetadataCompanion.insert(
            blobKey: 'key1',
            sha256: 'path1',
            relativePath: 'path1',
            bytes: 4,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db
        .into(db.news)
        .insert(
          NewsCompanion.insert(
            id: 'a1',
            sourceType: kNewsSourceTypeRss,
            sourceId: 'f1',
            guid: 'g',
            title: 't',
            link: 'http://t',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
            imageBlobKey: const Value('key1'),
          ),
        );
    final article = await (db.select(
      db.news,
    )..where((t) => t.id.equals('a1'))).getSingle();

    final blobs = _OkBlobStore({
      'path1': [1, 2, 3, 4],
    });
    final load = await loadRssArticleImage(db, blobs, article);
    expect(load.blobReadFailed, isFalse);
    expect(load.bytes, Uint8List.fromList([1, 2, 3, 4]));
    await db.close();
  });

  test('resolveRssDisplayCategoryId prefers slide key then feed category', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsRssFeeds)
        .insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f1',
            url: 'http://t/feed',
            category: const Value('usa'),
          ),
        );
    await db
        .into(db.news)
        .insert(
          NewsCompanion.insert(
            id: 'a1',
            sourceType: kNewsSourceTypeRss,
            sourceId: 'f1',
            guid: 'g',
            title: 't',
            link: 'http://t',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final article = await (db.select(
      db.news,
    )..where((t) => t.id.equals('a1'))).getSingle();
    final slideCurated = ResolvedSlide(
      screenId: 'n',
      dwellMs: 1,
      layoutJson: '{}',
      randomChoices: const {
        ScreenProgramCurator.rssScreenCategoryChoiceKey: 'world',
      },
    );
    expect(
      await resolveRssDisplayCategoryId(db, slideCurated, article),
      'world',
    );
    const slidePlain = ResolvedSlide(
      screenId: 'n',
      dwellMs: 1,
      layoutJson: '{}',
    );
    expect(await resolveRssDisplayCategoryId(db, slidePlain, article), 'usa');
    expect(await resolveRssDisplayCategoryId(db, slidePlain, null), equals(null));
    await db.close();
  });
}

class _OkBlobStore implements BlobStore {
  _OkBlobStore(this._map);
  final Map<String, List<int>> _map;

  @override
  Future<BlobRef> putBytes(
    List<int> bytes, {
    required String logicalKey,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async =>
      List<int>.from(_map[ref.storageKey] ?? const []);

  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  File? tryLocalFile(BlobRef ref) => null;
}
