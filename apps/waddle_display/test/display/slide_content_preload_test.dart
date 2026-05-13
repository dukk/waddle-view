import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/slide_content_preload.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_display/data/seed/tables/content_categories_seed.dart';
import 'package:waddle_display/data/seed/tables/joke_categories_seed.dart';
import 'package:waddle_display/data/seed/tables/trivia_categories_seed.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('preloadResolvedSlideContent completes for joke layout', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_preload_joke',
            categoryId: 'dad',
            setup: 'S',
            punchline: 'P',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'jokes',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"joke","slot":"main","config":{}}]}',
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent completes for trivia layout', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't_preload_trivia',
            categoryId: 'science',
            question: 'Q?',
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"trivia","slot":"main","config":{}}]}',
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent warms pexels_photo blob bytes', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    blobs.seed('rel/photo1', [1, 2, 3, 4]);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'bk_preload_photo',
            sha256: 'abc',
            relativePath: 'rel/photo1',
            bytes: 4,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'photo_preload_1',
            mediaBlobKey: 'bk_preload_photo',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'pex',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"pexels_photo","slot":"a","config":{}}]}',
      randomChoices: {'a_pexels_photo': 'photo_preload_1'},
    );
    await preloadResolvedSlideContent(db: db, blobs: blobs, slide: slide);
    await db.close();
  });

  test('preloadResolvedSlideContent no-ops for empty widgets', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final slide = ResolvedSlide(
      screenId: 'empty',
      dwellMs: 1000,
      layoutJson: '{"widgets":[]}',
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent warms rss_article', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'feed_pre',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
            title: const Value('TF'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'art_pre',
            feedId: 'feed_pre',
            guid: 'g1',
            title: 'T',
            link: 'http://test.local/a',
            summary: const Value('S'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"rss_article","slot":"main","config":{}}]}',
      randomChoices: const {'main_rss_article': 'art_pre'},
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent warms rss_article_columns', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'feed_pre',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
            title: const Value('TF'),
          ),
        );
    for (final id in ['c1', 'c2']) {
      await db.into(db.rssArticles).insert(
            RssArticlesCompanion.insert(
              id: id,
              feedId: 'feed_pre',
              guid: 'g_$id',
              title: 'T',
              link: 'http://test.local/$id',
              summary: const Value('S'),
              publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
              fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          );
    }
    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"rss_article_columns","slot":"main","config":{"columnCount":2}}]}',
      randomChoices: const {
        'main_rss_article_columns_0': 'c1',
        'main_rss_article_columns_1': 'c2',
      },
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent warms rss_article_stack', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'feed_pre',
            url: 'http://test.local/feed.xml',
            category: const Value('test'),
            title: const Value('TF'),
          ),
        );
    for (final id in ['s1', 's2']) {
      await db.into(db.rssArticles).insert(
            RssArticlesCompanion.insert(
              id: id,
              feedId: 'feed_pre',
              guid: 'g_$id',
              title: 'T',
              link: 'http://test.local/$id',
              summary: const Value('S'),
              publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
              fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          );
    }
    final slide = ResolvedSlide(
      screenId: 'news',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"rss_article_stack","slot":"main","config":{}}]}',
      randomChoices: const {
        'main_rss_article_stack_0': 's1',
        'main_rss_article_stack_1': 's2',
      },
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent pexels_video no row skips materialize', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final slide = ResolvedSlide(
      screenId: 'vid',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"pexels_video","slot":"v","config":{}}]}',
      randomChoices: const {},
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent warms pexels_photo_collage slots', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    blobs.seed('rel/p0', [9, 9]);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'bk_c0',
            sha256: 'a',
            relativePath: 'rel/p0',
            bytes: 2,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'ph0',
            mediaBlobKey: 'bk_c0',
            photographerName: 'n',
            photographerUrl: 'https://example.com/p',
            pexelsPageUrl: 'https://example.com',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final slide = ResolvedSlide(
      screenId: 'col',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"pexels_photo_collage","slot":"c","config":{}}]}',
      randomChoices: const {'c_pexels_photo_collage_0': 'ph0'},
    );
    await preloadResolvedSlideContent(db: db, blobs: blobs, slide: slide);
    await db.close();
  });

  test('preloadResolvedSlideContent runs multiple widgets in parallel', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'j2',
            categoryId: 'dad',
            setup: 'S',
            punchline: 'P',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final slide = ResolvedSlide(
      screenId: 'multi',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":['
          '{"type":"joke","slot":"a","config":{}},'
          '{"type":"static_text","slot":"b","config":{"text":"Hi"}}'
          ']}',
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });

  test('preloadResolvedSlideContent ignores unknown widget types', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final slide = ResolvedSlide(
      screenId: 'x',
      dwellMs: 1000,
      layoutJson:
          '{"widgets":[{"type":"not_supported_xyz","slot":"z","config":{}}]}',
    );
    await preloadResolvedSlideContent(
      db: db,
      blobs: FakeBlobStore(),
      slide: slide,
    );
    await db.close();
  });
}
