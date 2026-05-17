import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database_stats_repository.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  Future<void> seed(AppDatabase db) async {
    await seedContentCategoriesForTest(db, ['general', 'news']);

    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f1',
            url: 'https://example.com/a.xml',
            category: const Value('general'),
            enabled: const Value(true),
            consecutiveFailures: const Value(2),
          ),
        );
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f2',
            url: 'https://example.com/b.xml',
            category: const Value('news'),
            enabled: const Value(false),
          ),
        );

    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 't1',
            link: 'https://x/1',
            summary: const Value('s'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
            imageBlobKey: const Value('img/a1'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a2',
            feedId: 'f1',
            guid: 'g2',
            title: 't2',
            link: 'https://x/2',
            summary: const Value('s'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(3),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(4),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a3',
            feedId: 'f2',
            guid: 'g3',
            title: 't3',
            link: 'https://x/3',
            summary: const Value('s'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(5),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(6),
            suppressed: const Value(true),
          ),
        );

    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p1',
            category: const Value('general'),
            mediaBlobKey: 'blob/p1',
            photographerName: 'n',
            photographerUrl: 'https://x/p',
            pexelsPageUrl: 'https://x/photo',
            altText: const Value(''),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(7),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p2',
            category: const Value('news'),
            mediaBlobKey: 'blob/p2',
            photographerName: 'n',
            photographerUrl: 'https://x/p',
            pexelsPageUrl: 'https://x/photo2',
            altText: const Value(''),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(8),
            suppressed: const Value(true),
          ),
        );

    await db.into(db.videos).insert(
          VideosCompanion.insert(
            id: 'v1',
            category: const Value('general'),
            mediaBlobKey: 'blob/v1',
            photographerName: 'n',
            photographerUrl: 'https://x/v',
            pexelsPageUrl: 'https://x/video',
            altText: const Value(''),
            durationSeconds: 10,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(9),
          ),
        );

    await db.into(db.interestsJokes).insert(
          InterestsJokesCompanion.insert(id: 'general', label: 'General'),
        );
    await db.into(db.interestsTrivia).insert(
          InterestsTriviaCompanion.insert(id: 'general', label: 'General'),
        );

    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'j1',
            categoryId: 'general',
            setup: 's',
            punchline: 'p',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(10),
          ),
        );
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'j2',
            categoryId: 'general',
            setup: 's2',
            punchline: 'p2',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(11),
            suppressed: const Value(true),
          ),
        );

    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 'q1',
            categoryId: 'general',
            question: 'q?',
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(12),
          ),
        );

    await db.into(db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: 'e1',
            title: 'Meeting',
            startMs: DateTime.fromMillisecondsSinceEpoch(100),
            endMs: DateTime.fromMillisecondsSinceEpoch(200),
            updatedAtMs: DateTime.fromMillisecondsSinceEpoch(200),
          ),
        );

    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'k1',
            sha256: '0' * 64,
            relativePath: 'a.bin',
            bytes: 100,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(13),
          ),
        );
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'k2',
            sha256: '1' * 64,
            relativePath: 'b.bin',
            bytes: 50,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(14),
          ),
        );
  }

  test('load returns expected aggregates and category breakdowns', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seed(db);

    final snap = await DatabaseStatsRepository(db).load();

    expect(snap.rssArticleTotal, 3);
    expect(snap.rssArticleActive, 2);
    expect(snap.rssArticleSuppressed, 1);
    expect(snap.rssArticlesWithImage, 1);
    expect(snap.rssArticlesWithoutImage, 2);

    expect(snap.rssFeedsEnabled, 1);
    expect(snap.rssFeedsDisabled, 1);
    expect(snap.rssFeedsWithConsecutiveFailures, 1);

    expect(snap.photoTotal, 2);
    expect(snap.photoActive, 1);
    expect(snap.photoSuppressed, 1);

    expect(snap.videoTotal, 1);
    expect(snap.videoActive, 1);

    expect(snap.jokeTotal, 2);
    expect(snap.jokeActive, 1);
    expect(snap.jokeSuppressed, 1);

    expect(snap.triviaTotal, 1);
    expect(snap.triviaActive, 1);

    expect(snap.calendarEventCount, 1);

    expect(snap.blobRowCount, 2);
    expect(snap.blobTotalBytes, 150);

    expect(snap.rssByCategory.length, 2);
    expect(snap.rssByCategory[0].categoryId, 'general');
    expect(snap.rssByCategory[0].count, 2);
    expect(snap.rssByCategory[1].categoryId, 'news');
    expect(snap.rssByCategory[1].count, 1);

    expect(snap.photosByCategory.length, 2);
    final photoGeneral =
        snap.photosByCategory.singleWhere((e) => e.categoryId == 'general');
    expect(photoGeneral.count, 1);
    final photoNews =
        snap.photosByCategory.singleWhere((e) => e.categoryId == 'news');
    expect(photoNews.count, 1);

    expect(snap.videosByCategory.single.count, 1);
    expect(snap.videosByCategory.single.categoryId, 'general');

    expect(snap.jokesByCategory.single.count, 2);
    expect(snap.triviaByCategory.single.count, 1);

    await db.close();
  });

  test('load on empty database returns zeros', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    final snap = await DatabaseStatsRepository(db).load();

    expect(snap.rssArticleTotal, 0);
    expect(snap.blobRowCount, 0);
    expect(snap.blobTotalBytes, 0);
    expect(snap.rssByCategory, isEmpty);

    await db.close();
  });
}
