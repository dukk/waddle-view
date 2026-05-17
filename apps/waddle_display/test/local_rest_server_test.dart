import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/tables/interests_jokes_seed.dart';

import 'helpers/memory_database.dart';
import 'helpers/rest_auth_helper.dart';

Future<void> _seedContentTypes(AppDatabase db) async {
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
  await db.into(db.jokes).insert(
        JokesCompanion.insert(
          id: 'rest_j1',
          categoryId: cat,
          setup: 'x',
          punchline: 'y',
          createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
  await db.into(db.rssArticles).insert(
        RssArticlesCompanion.insert(
          id: 'rest_a1',
          feedId: 'f1',
          guid: 'g1',
          title: 't',
          link: 'https://x/1',
          publishedAt: DateTime.fromMillisecondsSinceEpoch(2),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(3),
        ),
      );
  await db.into(db.photos).insert(
        PhotosCompanion.insert(
          id: 'rest_p1',
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
          id: 'rest_v1',
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
          id: 'rest_q1',
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

void main() {
  test('health is public; providers require session', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final health = await http.get(Uri.parse('${h.baseUrl}/v1/health'));
    expect(health.statusCode, 200);
    final healthBody = jsonDecode(health.body) as Map<String, dynamic>;
    expect(healthBody['status'], 'ok');
    expect(healthBody['app'], 'waddle_display');
    expect(healthBody['schema_version'], isA<int>());

    final denied = await http.get(Uri.parse('${h.baseUrl}/v1/integrations'));
    expect(denied.statusCode, 401);

    final ok = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations'),
      headers: h.authHeaders,
    );
    expect(ok.statusCode, 200);
  });

  test('PATCH content suppression updates row', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await ensureDefaultInterestsJokes(h.db);
    await h.db.into(h.db.jokes).insert(
          JokesCompanion.insert(
            id: 'rest_j1',
            categoryId: 'dad',
            setup: 'x',
            punchline: 'y',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final uri = Uri.parse('${h.baseUrl}/v1/content/jokes/rest_j1');
    final res = await http.patch(
      uri,
      headers: h.authHeaders,
      body: '{"suppressed":true}',
    );
    expect(res.statusCode, 200);
    final row = await (h.db.select(h.db.jokes)
          ..where((t) => t.id.equals('rest_j1')))
        .getSingle();
    expect(row.suppressed, isTrue);
  });

  test('PATCH content suppression for rss photos videos trivia', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedContentTypes(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    for (final path in [
      '/v1/content/rss-articles/rest_a1',
      '/v1/content/photos/rest_p1',
      '/v1/content/videos/rest_v1',
      '/v1/content/trivia/rest_q1',
    ]) {
      final res = await http.patch(
        Uri.parse('${h.baseUrl}$path'),
        headers: h.authHeaders,
        body: '{"suppressed":true}',
      );
      expect(res.statusCode, 200, reason: path);
    }
  });

  test('PATCH content suppression validates body', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final badType = await http.patch(
      Uri.parse('${h.baseUrl}/v1/content/jokes/missing'),
      headers: h.authHeaders,
      body: '{"suppressed":"yes"}',
    );
    expect(badType.statusCode, 400);
    expect(badType.body, contains('suppressed_must_be_bool'));

    final notFound = await http.patch(
      Uri.parse('${h.baseUrl}/v1/content/jokes/missing'),
      headers: h.authHeaders,
      body: '{"suppressed":true}',
    );
    expect(notFound.statusCode, 404);
  });

  test('reject-terms REST CRUD and format', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final list0 = await http.get(
      Uri.parse('${h.baseUrl}/v1/reject-terms'),
      headers: h.authHeaders,
    );
    expect(list0.statusCode, 200);

    final post = await http.post(
      Uri.parse('${h.baseUrl}/v1/reject-terms'),
      headers: h.authHeaders,
      body: jsonEncode({'term': 'badword', 'action': 'block'}),
    );
    expect(post.statusCode, 200);
    final id = (jsonDecode(post.body) as Map)['id'] as String;

    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/reject-terms/$id'),
      headers: h.authHeaders,
      body: jsonEncode({'term': 'badword', 'action': 'censor'}),
    );
    expect(patch.statusCode, 200);

    final format = await http.put(
      Uri.parse('${h.baseUrl}/v1/reject-terms/format'),
      headers: h.authHeaders,
      body: jsonEncode({'format': kRejectCensorFormatFirstLast}),
    );
    expect(format.statusCode, 200);

    final rescan = await http.post(
      Uri.parse('${h.baseUrl}/v1/reject-terms/rescan'),
      headers: h.authHeaders,
    );
    expect(rescan.statusCode, 200);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/reject-terms/$id'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);

    final missing = await http.delete(
      Uri.parse('${h.baseUrl}/v1/reject-terms/ghost'),
      headers: h.authHeaders,
    );
    expect(missing.statusCode, 404);
  });

  test('reject-terms rejects invalid payloads', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);

    final badJson = await http.post(
      Uri.parse('${h.baseUrl}/v1/reject-terms'),
      headers: h.authHeaders,
      body: '{',
    );
    expect(badJson.statusCode, 400);

    final badTerm = await http.post(
      Uri.parse('${h.baseUrl}/v1/reject-terms'),
      headers: h.authHeaders,
      body: jsonEncode({'term': '', 'action': 'block'}),
    );
    expect(badTerm.statusCode, 400);

    final badFormat = await http.put(
      Uri.parse('${h.baseUrl}/v1/reject-terms/format'),
      headers: h.authHeaders,
      body: jsonEncode({'format': 'unknown'}),
    );
    expect(badFormat.statusCode, 400);

    final notString = await http.put(
      Uri.parse('${h.baseUrl}/v1/reject-terms/format'),
      headers: h.authHeaders,
      body: jsonEncode({'format': 1}),
    );
    expect(notString.statusCode, 400);
  });

  test('PATCH content suppression rejects invalid json', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/content/jokes/x'),
      headers: h.authHeaders,
      body: '{',
    );
    expect(res.statusCode, 400);
    expect(res.body, contains('invalid_json'));
  });

  test('CORS adds headers for allowed origin', () async {
    const origin = 'http://localhost:5173';
    final h = await RestTestHarness.start(
      seedCorsOrigins: [origin],
    );
    addTearDown(h.dispose);

    final preflight = await http.Client().send(
      http.Request('OPTIONS', Uri.parse('${h.baseUrl}/v1/health'))
        ..headers['Origin'] = origin,
    );
    expect(preflight.statusCode, 204);
    expect(preflight.headers['access-control-allow-origin'], origin);

    final get = await http.get(
      Uri.parse('${h.baseUrl}/v1/health'),
      headers: {'Origin': origin},
    );
    expect(get.statusCode, 200);
    expect(get.headers['access-control-allow-origin'], origin);
  });
}
