import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/rss_article/rss_article_load.dart';
import 'package:waddle_display/display/slide_content_joke_trivia.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';

import '../helpers/memory_database.dart';

ResolvedSlide _slide(Map<String, String> choices) {
  return ResolvedSlide(
    screenId: 'screen',
    dwellMs: 10000,
    layoutJson: '{}',
    randomChoices: choices,
  );
}

ParsedWidgetSpec _spec(String type, String slot,
    [Map<String, dynamic>? cfg]) {
  return ParsedWidgetSpec(
    type: type,
    slot: slot,
    config: cfg ?? const <String, dynamic>{},
  );
}

void main() {
  setUp(() async {});

  test('loadJokeForSlide censors setup and punchline transiently', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    await RejectTermRepository(db).upsert(
      RejectTermInput.parse(rawTerm: 'damn', rawAction: 'censor')!,
    );

    await db.into(db.jokeCategories).insert(
      JokeCategoriesCompanion.insert(id: 'cat', label: 'cat'),
    );
    const setup = 'Why was the test so damn loud?';
    const punchline = 'Because it really was damn loud.';
    await db.into(db.jokes).insert(
      JokesCompanion.insert(
        id: 'j1',
        categoryId: 'cat',
        setup: setup,
        punchline: punchline,
        createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );

    final ctx = await RejectFilterContext.loadFromDb(db);
    final spec = _spec('joke', 'a');
    final result = await loadJokeForSlide(
      db,
      spec,
      _slide({spec.choiceKey: 'j1'}),
      rejectCtx: ctx,
    );
    expect(result, isNotNull);
    expect(result!.setup.contains('damn'), isFalse);
    expect(result.setup.contains('****'), isTrue);
    expect(result.punchline.contains('damn'), isFalse);

    final row =
        await (db.select(db.jokes)..where((t) => t.id.equals('j1')))
            .getSingle();
    expect(
      row.setup,
      setup,
      reason: 'database row text is untouched',
    );
    expect(row.punchline, punchline);

    await db.close();
  });

  test('loadTriviaForSlide censors question and options transiently',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    await RejectTermRepository(db).upsert(
      RejectTermInput.parse(rawTerm: 'damn', rawAction: 'censor')!,
    );

    await db.into(db.triviaCategories).insert(
      TriviaCategoriesCompanion.insert(id: 'cat', label: 'cat'),
    );
    await db.into(db.triviaQuestions).insert(
      TriviaQuestionsCompanion.insert(
        id: 'q1',
        categoryId: 'cat',
        question: 'damn question?',
        optionA: 'damn A',
        optionB: 'safe B',
        optionC: 'safe C',
        optionD: 'safe D',
        correctOption: 'A',
        createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );

    final ctx = await RejectFilterContext.loadFromDb(db);
    final spec = _spec('trivia', 'a');
    final r = await loadTriviaForSlide(
      db,
      spec,
      _slide({spec.choiceKey: 'q1'}),
      rejectCtx: ctx,
    );
    expect(r, isNotNull);
    expect(r!.question.contains('damn'), isFalse);
    expect(r.optionA.contains('damn'), isFalse);
    expect(r.optionB, 'safe B');

    await db.close();
  });

  test(
    'loadRssArticleForSlideChoice censors title and summary transiently',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await db.delete(db.rejectTerms).go();
      await RejectTermRepository(db).upsert(
        RejectTermInput.parse(rawTerm: 'damn', rawAction: 'censor')!,
      );

      await db.into(db.rssFeedSources).insert(
        RssFeedSourcesCompanion.insert(id: 'f1', url: 'https://x/feed.xml'),
      );
      const title = 'A damn story';
      const summary = 'Today the damn river overflowed.';
      await db.into(db.rssArticles).insert(
        RssArticlesCompanion.insert(
          id: 'a1',
          feedId: 'f1',
          guid: 'g1',
          title: title,
          link: 'https://x/1',
          summary: const Value(summary),
          publishedAt: DateTime.fromMillisecondsSinceEpoch(2),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
        ),
      );

      final spec = _spec('rss_article', 'a');
      final slide = _slide({spec.choiceKey: 'a1'});
      final ctx = await RejectFilterContext.loadFromDb(db);
      final r = await loadRssArticleForSlideChoice(
        db,
        spec,
        slide,
        spec.choiceKey,
        const <String>{},
        rejectCtx: ctx,
      );
      expect(r, isNotNull);
      expect(r!.title.contains('damn'), isFalse);
      expect(r.title.contains('****'), isTrue);
      expect(r.summary, isNotNull);
      expect(r.summary!.contains('damn'), isFalse);

      final row =
          await (db.select(db.rssArticles)..where((t) => t.id.equals('a1')))
              .getSingle();
      expect(row.title, title, reason: 'db row untouched');
      expect(row.summary, summary);

      await db.close();
    },
  );

  test('empty context returns rows unchanged', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    await db.into(db.jokeCategories).insert(
      JokeCategoriesCompanion.insert(id: 'cat', label: 'cat'),
    );
    await db.into(db.jokes).insert(
      JokesCompanion.insert(
        id: 'j1',
        categoryId: 'cat',
        setup: 'damn setup',
        punchline: 'damn punchline',
        createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );
    final spec = _spec('joke', 'a');
    final r = await loadJokeForSlide(
      db,
      spec,
      _slide({spec.choiceKey: 'j1'}),
      rejectCtx: const RejectFilterContext.empty(),
    );
    expect(r!.setup, 'damn setup');
    await db.close();
  });

  test('loadJokeForSlide random path filters by categoryId', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(id: 'c1', label: 'c1'),
        );
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'j_cat',
            categoryId: 'c1',
            setup: 's',
            punchline: 'p',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final spec = _spec('joke', 'main', {'categoryId': 'c1'});
    final joke = await loadJokeForSlide(
      db,
      spec,
      _slide({}),
      rejectCtx: const RejectFilterContext.empty(),
    );
    expect(joke?.id, 'j_cat');
    await db.close();
  });

  test('loadJokeForSlide random path without categoryId', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(id: 'c2', label: 'c2'),
        );
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 'j_any',
            categoryId: 'c2',
            setup: 's2',
            punchline: 'p2',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );
    final spec = _spec('joke', 'side', const {});
    final joke = await loadJokeForSlide(
      db,
      spec,
      _slide({}),
      rejectCtx: const RejectFilterContext.empty(),
    );
    expect(joke?.id, 'j_any');
    await db.close();
  });

  test('loadJokeForSlide returns null when curated id row missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final spec = _spec('joke', 'slot');
    final joke = await loadJokeForSlide(
      db,
      spec,
      _slide({spec.choiceKey: 'missing'}),
      rejectCtx: const RejectFilterContext.empty(),
    );
    expect(joke, isNull);
    await db.close();
  });

  test('loadTriviaForSlide random path filters by categoryId', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(id: 'tc', label: 'tc'),
        );
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 'tq_cat',
            categoryId: 'tc',
            question: 'q',
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final spec = _spec('trivia', 'main', {'categoryId': 'tc'});
    final q = await loadTriviaForSlide(
      db,
      spec,
      _slide({}),
      rejectCtx: const RejectFilterContext.empty(),
    );
    expect(q?.id, 'tq_cat');
    await db.close();
  });

  test('loadTriviaForSlide returns null when curated id row missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final spec = _spec('trivia', 'slot');
    final q = await loadTriviaForSlide(
      db,
      spec,
      _slide({spec.choiceKey: 'nope'}),
      rejectCtx: const RejectFilterContext.empty(),
    );
    expect(q, isNull);
    await db.close();
  });
}
