import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/content_deletion_repository.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

class _MemBlobStore implements BlobStore {
  final Map<String, List<int>> _data = {};

  @override
  Future<void> delete(BlobRef ref) async => _data.remove(ref.storageKey);

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    final key = 'stored/$logicalKey';
    _data[key] = List<int>.from(bytes);
    return BlobRef(key);
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async =>
      List<int>.from(_data[ref.storageKey] ?? const []);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

void main() {
  Future<void> seedBlobMetadata(
    AppDatabase db, {
    required String blobKey,
    required String relativePath,
  }) async {
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: blobKey,
            sha256: 'abc',
            relativePath: relativePath,
            bytes: 3,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
  }

  Future<void> seedMinimalContent(AppDatabase db) async {
    const cat = 'general';
    await db.into(db.contentCategories).insert(
          ContentCategoriesCompanion.insert(id: cat, label: 'General'),
        );
    await db.into(db.interestsJokes).insert(
          InterestsJokesCompanion.insert(id: cat, label: 'General'),
        );
    await db.into(db.interestsTrivia).insert(
          InterestsTriviaCompanion.insert(id: cat, label: 'General'),
        );
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(id: 'f1', url: 'https://example.com/feed.xml'),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'loc1',
            name: 'Home',
            latitude: 0,
            longitude: 0,
          ),
        );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(id: 'sym1', symbol: 'AAPL'),
        );

    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'j1',
            categoryId: cat,
            setup: 'setup',
            punchline: 'punch',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.news).insert(
          NewsCompanion.insert(
            id: 'a1',
            sourceType: kNewsSourceTypeRss,
            sourceId: 'f1',
            guid: 'g1',
            title: 't',
            link: 'https://x/1',
            summary: const Value('s'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(2),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(3),
            imageBlobKey: const Value('blob/news1'),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p1',
            mediaBlobKey: 'blob/p1',
            photographerName: 'n',
            photographerUrl: 'https://x/p',
            pageUrl: 'https://x/photo',
            altText: const Value(''),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(4),
          ),
        );
    await db.into(db.videos).insert(
          VideosCompanion.insert(
            id: 'v1',
            mediaBlobKey: 'blob/v1',
            photographerName: 'n',
            photographerUrl: 'https://x/v',
            pexelsPageUrl: 'https://x/video',
            altText: const Value(''),
            durationSeconds: 1,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(5),
          ),
        );
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 'q1',
            categoryId: cat,
            question: 'q?',
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(6),
          ),
        );
    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'ev1',
            title: 'Meet',
            startMs: DateTime.fromMillisecondsSinceEpoch(10),
            endMs: DateTime.fromMillisecondsSinceEpoch(20),
            updatedAtMs: DateTime.fromMillisecondsSinceEpoch(10),
          ),
        );
    await db.into(db.stockQuotes).insert(
          StockQuotesCompanion.insert(
            symbolId: 'sym1',
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(7),
          ),
        );
    await db.into(db.weatherCurrent).insert(
          WeatherCurrentCompanion.insert(
            locationId: 'loc1',
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(8),
            currentIconBlobKey: const Value('blob/wx-icon'),
          ),
        );
    await db.into(db.weatherAlerts).insert(
          WeatherAlertsCompanion.insert(
            locationId: 'loc1',
            nwsAlertId: 'nws-1',
            event: 'Flood',
          ),
        );
  }

  test('deleteJoke removes row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    final repo = ContentDeletionRepository(db);

    expect(await repo.deleteJoke('missing'), 0);
    expect(await repo.deleteJoke('j1'), 1);
    expect(
      await (db.select(db.jokes)..where((t) => t.id.equals('j1'))).get(),
      isEmpty,
    );

    await db.close();
  });

  test('deleteRssArticle removes row and blob metadata when blobs provided', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    await seedBlobMetadata(
      db,
      blobKey: 'blob/news1',
      relativePath: 'stored/news1',
    );
    final blobs = _MemBlobStore();
    await blobs.putBytes([1, 2, 3], logicalKey: 'news1');
    final repo = ContentDeletionRepository(db, blobs: blobs);

    expect(await repo.deleteRssArticle('a1'), 1);
    expect(
      await (db.select(db.news)..where((t) => t.id.equals('a1'))).get(),
      isEmpty,
    );
    expect(
      await (db.select(db.blobMetadata)
            ..where((t) => t.blobKey.equals('blob/news1')))
          .get(),
      isEmpty,
    );

    await db.close();
  });

  test('deletePhoto and deleteVideo remove rows and blob metadata', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    await seedBlobMetadata(db, blobKey: 'blob/p1', relativePath: 'stored/p1');
    await seedBlobMetadata(db, blobKey: 'blob/v1', relativePath: 'stored/v1');
    final blobs = _MemBlobStore();
    final repo = ContentDeletionRepository(db, blobs: blobs);

    expect(await repo.deletePhoto('p1'), 1);
    expect(await repo.deleteVideo('v1'), 1);
    expect(
      await (db.select(db.photos)..where((t) => t.id.equals('p1'))).get(),
      isEmpty,
    );
    expect(
      await (db.select(db.videos)..where((t) => t.id.equals('v1'))).get(),
      isEmpty,
    );
    expect(
      await (db.select(db.blobMetadata)
            ..where((t) => t.blobKey.isIn(['blob/p1', 'blob/v1'])))
          .get(),
      isEmpty,
    );

    await db.close();
  });

  test('deleteTriviaQuestion and deleteCalendarEvent remove rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    final repo = ContentDeletionRepository(db);

    expect(await repo.deleteTriviaQuestion('q1'), 1);
    expect(await repo.deleteCalendarEvent('ev1'), 1);
    expect(
      await (db.select(db.triviaQuestions)..where((t) => t.id.equals('q1')))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.calendarEvents)..where((t) => t.id.equals('ev1')))
          .get(),
      isEmpty,
    );

    await db.close();
  });

  test('deleteStockQuote removes quote but not symbol interest', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    final repo = ContentDeletionRepository(db);

    expect(await repo.deleteStockQuote('sym1'), 1);
    expect(
      await (db.select(db.stockQuotes)..where((t) => t.symbolId.equals('sym1')))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.interestsStockSymbols)
            ..where((t) => t.id.equals('sym1')))
          .getSingleOrNull(),
      isNotNull,
    );

    await db.close();
  });

  test('deleteWeatherCurrent and deleteWeatherAlert remove rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    await seedBlobMetadata(
      db,
      blobKey: 'blob/wx-icon',
      relativePath: 'stored/wx',
    );
    final blobs = _MemBlobStore();
    final repo = ContentDeletionRepository(db, blobs: blobs);

    expect(await repo.deleteWeatherAlert('loc1', 'nws-1'), 1);
    expect(await repo.deleteWeatherCurrent('loc1'), 1);
    expect(
      await (db.select(db.weatherAlerts)
            ..where((t) => t.locationId.equals('loc1')))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.weatherCurrent)
            ..where((t) => t.locationId.equals('loc1')))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.interestsLocations)
            ..where((t) => t.id.equals('loc1')))
          .getSingleOrNull(),
      isNotNull,
    );

    await db.close();
  });
}
