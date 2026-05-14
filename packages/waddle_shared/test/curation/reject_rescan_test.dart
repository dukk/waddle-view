import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/curation/reject_rescan.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';

import '../helpers/memory_database.dart';

void main() {
  test('rescan marks rss/joke/trivia rows on block-term matches', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    final repo = RejectTermRepository(db);
    await repo.upsert(
      RejectTermInput.parse(rawTerm: 'forbidden', rawAction: 'block')!,
    );
    await repo.upsert(
      RejectTermInput.parse(rawTerm: 'mild', rawAction: 'censor')!,
    );

    final cat = 'general';
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
      RssFeedSourcesCompanion.insert(id: 'f1', url: 'https://x/feed.xml'),
    );

    await db.into(db.rssArticles).insert(
      RssArticlesCompanion.insert(
        id: 'a_bad',
        feedId: 'f1',
        guid: 'g1',
        title: 'A forbidden tale',
        link: 'https://x/1',
        summary: const Value('summary'),
        publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
      ),
    );
    await db.into(db.rssArticles).insert(
      RssArticlesCompanion.insert(
        id: 'a_ok',
        feedId: 'f1',
        guid: 'g2',
        title: 'A mild tale',
        link: 'https://x/2',
        summary: const Value('summary'),
        publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
      ),
    );
    await db.into(db.jokes).insert(
      JokesCompanion.insert(
        id: 'j_bad',
        categoryId: cat,
        setup: 'why did the forbidden chicken cross',
        punchline: 'because',
        createdAtMs: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    await db.into(db.jokes).insert(
      JokesCompanion.insert(
        id: 'j_ok',
        categoryId: cat,
        setup: 'why did the chicken cross',
        punchline: 'mild reasons',
        createdAtMs: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    await db.into(db.triviaQuestions).insert(
      TriviaQuestionsCompanion.insert(
        id: 'q_bad',
        categoryId: cat,
        question: 'forbidden trivia?',
        optionA: 'yes',
        optionB: 'no',
        optionC: 'maybe',
        optionD: 'always',
        correctOption: 'A',
        createdAtMs: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );

    final result = await rescanContentForBlockTerms(db);
    expect(result.rssArticlesMarked, 1);
    expect(result.jokesMarked, 1);
    expect(result.triviaQuestionsMarked, 1);

    final aBad = await (db.select(db.rssArticles)
          ..where((t) => t.id.equals('a_bad')))
        .getSingle();
    expect(aBad.suppressed, isTrue);
    final aOk = await (db.select(db.rssArticles)
          ..where((t) => t.id.equals('a_ok')))
        .getSingle();
    expect(aOk.suppressed, isFalse, reason: 'censor terms do not block');

    final jOk =
        await (db.select(db.jokes)..where((t) => t.id.equals('j_ok')))
            .getSingle();
    expect(jOk.suppressed, isFalse);

    final repeat = await rescanContentForBlockTerms(db);
    expect(repeat.totalMarked, 0,
        reason: 'idempotent: already-suppressed rows are skipped');

    await db.close();
  });

  test('rescan marks photo/video rows on media match (censor terms count too)',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    final repo = RejectTermRepository(db);
    await repo.upsert(
      RejectTermInput.parse(rawTerm: 'damn', rawAction: 'censor')!,
    );

    await db.into(db.photos).insert(
      PhotosCompanion.insert(
        id: 'p1',
        mediaBlobKey: 'b/p1',
        photographerName: 'Jane Damn-Smith',
        photographerUrl: 'https://example.com/people/jane',
        pexelsPageUrl: 'https://pexels.com/photo/clean',
        altText: const Value('A nice scene'),
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );
    await db.into(db.photos).insert(
      PhotosCompanion.insert(
        id: 'p2',
        mediaBlobKey: 'b/p2',
        photographerName: 'Anonymous',
        photographerUrl: 'https://example.com/p/anon',
        pexelsPageUrl: 'https://example.com/photos/holy-damn-river_2024.jpg',
        altText: const Value('safe alt'),
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );
    await db.into(db.photos).insert(
      PhotosCompanion.insert(
        id: 'p3',
        mediaBlobKey: 'b/p3',
        photographerName: 'Bob',
        photographerUrl: 'https://example.com/people/bob',
        pexelsPageUrl: 'https://example.com/photo/safe',
        altText: const Value('clear skies'),
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );
    await db.into(db.videos).insert(
      VideosCompanion.insert(
        id: 'v1',
        mediaBlobKey: 'b/v1',
        photographerName: 'Carla',
        photographerUrl: 'https://example.com/people/carla',
        pexelsPageUrl: 'https://example.com/videos/damn-it.mp4',
        altText: const Value(''),
        durationSeconds: 10,
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );

    final result = await rescanContentForBlockTerms(db);
    expect(result.photosMarked, 2);
    expect(result.videosMarked, 1);

    final p1 =
        await (db.select(db.photos)..where((t) => t.id.equals('p1')))
            .getSingle();
    final p2 =
        await (db.select(db.photos)..where((t) => t.id.equals('p2')))
            .getSingle();
    final p3 =
        await (db.select(db.photos)..where((t) => t.id.equals('p3')))
            .getSingle();
    expect(p1.suppressed, isTrue);
    expect(p2.suppressed, isTrue);
    expect(p3.suppressed, isFalse);

    final v1 =
        await (db.select(db.videos)..where((t) => t.id.equals('v1')))
            .getSingle();
    expect(v1.suppressed, isTrue);

    await db.close();
  });

  test('rescan no-op when reject list is empty', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    final result = await rescanContentForBlockTerms(db);
    expect(result.totalMarked, 0);
    await db.close();
  });
}
