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
            createdAtMs: 1,
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
            publishedAt: 1,
            fetchedAt: 1,
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
            createdAtMs: 1,
          ),
        );

    final pools = await loadCuratorContentPools(db);
    expect(pools['joke'], contains('j1'));
    expect(pools['joke:dad'], ['j1']);
    expect(pools['rss'], ['a1']);
    expect(pools['rss:f1'], ['a1']);
    expect(pools['trivia'], contains('q1'));
    expect(pools['trivia:science'], ['q1']);

    await db.close();
  });
}
