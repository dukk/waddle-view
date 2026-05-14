import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/content_suppression_repository.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  Future<void> seedMinimalContent(AppDatabase db) async {
    const cat = 'general';
    await db.into(db.contentCategories).insert(
          ContentCategoriesCompanion.insert(id: cat, label: 'General'),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(id: cat, label: 'General'),
        );
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(id: cat, label: 'General'),
        );
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(id: 'f1', url: 'https://example.com/feed.xml'),
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
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 't',
            link: 'https://x/1',
            summary: const Value('s'),
            publishedAt: DateTime.fromMillisecondsSinceEpoch(2),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(3),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'p1',
            mediaBlobKey: 'blob/p1',
            photographerName: 'n',
            photographerUrl: 'https://x/p',
            pexelsPageUrl: 'https://x/photo',
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
  }

  test('setJokeSuppressed toggles suppressed flag', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    final repo = ContentSuppressionRepository(db);

    expect(await repo.setJokeSuppressed('missing', true), 0);

    expect(await repo.setJokeSuppressed('j1', true), 1);
    final j =
        await (db.select(db.jokes)..where((t) => t.id.equals('j1'))).getSingle();
    expect(j.suppressed, isTrue);

    expect(await repo.setJokeSuppressed('j1', false), 1);
    final j2 =
        await (db.select(db.jokes)..where((t) => t.id.equals('j1'))).getSingle();
    expect(j2.suppressed, isFalse);

    await db.close();
  });

  test('setRssArticleSuppressed toggles suppressed flag', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    final repo = ContentSuppressionRepository(db);

    expect(await repo.setRssArticleSuppressed('a1', true), 1);
    final row =
        await (db.select(db.rssArticles)..where((t) => t.id.equals('a1')))
            .getSingle();
    expect(row.suppressed, isTrue);

    await db.close();
  });

  test('setPhotoSuppressed and setVideoSuppressed update rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    final repo = ContentSuppressionRepository(db);

    expect(await repo.setPhotoSuppressed('p1', true), 1);
    final p =
        await (db.select(db.photos)..where((t) => t.id.equals('p1'))).getSingle();
    expect(p.suppressed, isTrue);

    expect(await repo.setVideoSuppressed('v1', true), 1);
    final v =
        await (db.select(db.videos)..where((t) => t.id.equals('v1'))).getSingle();
    expect(v.suppressed, isTrue);

    await db.close();
  });

  test('setTriviaQuestionSuppressed toggles suppressed flag', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedMinimalContent(db);
    final repo = ContentSuppressionRepository(db);

    expect(await repo.setTriviaQuestionSuppressed('q1', true), 1);
    final q = await (db.select(db.triviaQuestions)
          ..where((t) => t.id.equals('q1')))
        .getSingle();
    expect(q.suppressed, isTrue);

    await db.close();
  });
}
