import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/curator_content_pools.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/seed/joke_category_seed.dart';
import 'package:waddle_view/seed/trivia_category_seed.dart';

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
}
