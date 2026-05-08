import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/curator_content_pools.dart';
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/data/seed/tables/joke_categories_seed.dart';
import 'package:waddle_display/data/seed/tables/trivia_categories_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('loadCuratorContentPools groups joke rss and trivia ids', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await ensureDefaultTriviaCategories(db);

    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'j1',
            categoryId: 'dad',
            setup: 's',
            punchline: 'p',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'f1',
            url: 'http://a',
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g',
            title: 't',
            link: 'http://l',
            summary: const Value('hello summary'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 'q1',
            categoryId: 'science',
            question: 'Q?',
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'B',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'k/p1',
            sha256: 's1',
            relativePath: 'p1.bin',
            bytes: 10,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
            pixelWidth: const Value(800),
            pixelHeight: const Value(600),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p1',
            category: const Value('pexels'),
            mediaBlobKey: 'k/p1',
            photographerName: 'a',
            photographerUrl: 'b',
            pexelsPageUrl: 'c',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p2',
            category: const Value('nature'),
            mediaBlobKey: 'k/p2',
            photographerName: 'a',
            photographerUrl: 'b',
            pexelsPageUrl: 'c',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );
    await db.into(db.videos).insert(
          VideosCompanion.insert(
            id: 'v1',
            category: const Value('pexels'),
            mediaBlobKey: 'k/v1',
            photographerName: 'a',
            photographerUrl: 'b',
            pexelsPageUrl: 'c',
            durationSeconds: 20,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final loaded = await loadCuratorContentPools(db);
    final pools = loaded.pools;
    expect(loaded.photoMetrics['p1']!.pixelWidth, 800);
    expect(loaded.photoMetrics['p1']!.pixelHeight, 600);
    expect(loaded.rssArticleMetrics['a1']!.hasImage, isFalse);
    expect(loaded.rssArticleMetrics['a1']!.summaryLength, 13);
    expect(pools['joke'], contains('j1'));
    expect(pools['joke:dad'], ['j1']);
    expect(pools['rss'], ['a1']);
    expect(pools['rss:f1'], ['a1']);
    expect(pools['trivia'], contains('q1'));
    expect(pools['trivia:science'], ['q1']);
    expect(pools['pexels_photo'], unorderedEquals(['p1', 'p2']));
    expect(pools['pexels_photo:pexels'], ['p1']);
    expect(pools['pexels_photo:nature'], ['p2']);
    expect(pools['pexels_video'], ['v1']);
    expect(pools['pexels_video:pexels'], ['v1']);

    await db.close();
  });

  test('loadCuratorContentPools omits suppressed rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await ensureDefaultTriviaCategories(db);

    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'jv',
            categoryId: 'dad',
            setup: 'a',
            punchline: 'b',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
            suppressed: const Value(true),
          ),
        );
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'jvis',
            categoryId: 'dad',
            setup: 'c',
            punchline: 'd',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );

    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(id: 'f2', url: 'http://b'),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'ah',
            feedId: 'f2',
            guid: 'h',
            title: 'hid',
            link: 'http://x',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(2),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
            suppressed: const Value(true),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'ash',
            feedId: 'f2',
            guid: 's',
            title: 'shown',
            link: 'http://y',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(3),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(3),
          ),
        );

    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 'qh',
            categoryId: 'science',
            question: '?',
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(2),
            suppressed: const Value(true),
          ),
        );
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 'qs',
            categoryId: 'science',
            question: '??',
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'B',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(3),
          ),
        );

    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'k/ph',
            sha256: 'x',
            relativePath: 'ph.bin',
            bytes: 1,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'phhid',
            category: const Value('pexels'),
            mediaBlobKey: 'k/ph',
            photographerName: 'a',
            photographerUrl: 'b',
            pexelsPageUrl: 'c',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
            suppressed: const Value(true),
          ),
        );
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'k/pvis',
            sha256: 'y',
            relativePath: 'pvis.bin',
            bytes: 1,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'phvis',
            category: const Value('pexels'),
            mediaBlobKey: 'k/pvis',
            photographerName: 'a',
            photographerUrl: 'b',
            pexelsPageUrl: 'c',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );

    await db.into(db.videos).insert(
          VideosCompanion.insert(
            id: 'vhid',
            category: const Value('pexels'),
            mediaBlobKey: 'k/vhid',
            photographerName: 'a',
            photographerUrl: 'b',
            pexelsPageUrl: 'c',
            durationSeconds: 5,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
            suppressed: const Value(true),
          ),
        );
    await db.into(db.videos).insert(
          VideosCompanion.insert(
            id: 'vvis',
            category: const Value('pexels'),
            mediaBlobKey: 'k/vvis',
            photographerName: 'a',
            photographerUrl: 'b',
            pexelsPageUrl: 'c',
            durationSeconds: 10,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );

    final loaded = await loadCuratorContentPools(db);
    final pools = loaded.pools;
    expect(pools['joke'], unorderedEquals(['jvis']));
    expect(pools['joke:dad'], ['jvis']);
    expect(pools['rss'], ['ash']);
    expect(loaded.rssArticleMetrics.containsKey('ah'), isFalse);
    expect(loaded.rssArticleMetrics['ash'], isNotNull);
    expect(pools['trivia'], unorderedEquals(['qs']));
    expect(pools['pexels_photo'], unorderedEquals(['phvis']));
    expect(loaded.photoMetrics.containsKey('phhid'), isFalse);
    expect(pools['pexels_video'], unorderedEquals(['vvis']));

    await db.close();
  });
}
