import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  test('GET/POST/PATCH/DELETE weather location', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/weather-locations'),
      headers: auth,
      body: jsonEncode({
        'id': 'sea',
        'name': 'Seattle',
        'latitude': 47.6,
        'longitude': -122.3,
        'include_weather': true,
        'include_weather_alerts': false,
        'include_local_news': false,
      }),
    );
    expect(create.statusCode, 200);

    final list = await http.get(
      Uri.parse('$base/v1/interests/weather-locations'),
      headers: auth,
    );
    expect(list.statusCode, 200);
    final items = (jsonDecode(list.body) as Map)['items'] as List;
    expect(items.length, 1);
    expect(items.first['id'], 'sea');
    expect(items.first['category'], 'general');

    final patch = await http.patch(
      Uri.parse('$base/v1/interests/weather-locations/sea'),
      headers: auth,
      body: jsonEncode({'name': 'Seattle, WA'}),
    );
    expect(patch.statusCode, 200);

    final listAfterPatch = await http.get(
      Uri.parse('$base/v1/interests/weather-locations'),
      headers: auth,
    );
    final patched =
        ((jsonDecode(listAfterPatch.body) as Map)['items'] as List).first
            as Map<String, dynamic>;
    expect(patched['category'], 'north_america');

    final del = await http.delete(
      Uri.parse('$base/v1/interests/weather-locations/sea'),
      headers: auth,
    );
    expect(del.statusCode, 200);

    final listAfter = await http.get(
      Uri.parse('$base/v1/interests/weather-locations'),
      headers: auth,
    );
    expect(((jsonDecode(listAfter.body) as Map)['items'] as List).length, 0);
  });

  test('DELETE weather location blocked when weather_current exists', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsLocations)
        .insert(
          InterestsLocationsCompanion.insert(
            id: 'loc',
            name: 'X',
            latitude: 1,
            longitude: 2,
            includeWeather: const Value(true),
          ),
        );
    await db
        .into(db.weatherCurrent)
        .insert(
          WeatherCurrentCompanion.insert(
            locationId: 'loc',
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/interests/weather-locations/loc'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 409);
  });

  test('RSS feed CRUD and delete blocked when articles exist', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['general']);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/rss-feeds'),
      headers: auth,
      body: jsonEncode({
        'id': 'f1',
        'url': 'https://example.com/rss.xml',
        'category': 'general',
      }),
    );
    expect(create.statusCode, 200);

    await db
        .into(db.news)
        .insert(
          NewsCompanion.insert(
            id: 'a1',
            sourceType: kNewsSourceTypeRss,
            sourceId: 'f1',
            guid: 'g1',
            title: 'T',
            link: 'https://example.com/a',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );

    final delBlocked = await http.delete(
      Uri.parse('$base/v1/interests/rss-feeds/f1'),
      headers: auth,
    );
    expect(delBlocked.statusCode, 409);
  });

  test('joke category requires curator category id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final missing = await http.post(
      Uri.parse('${h.baseUrl}/v1/interests/joke-categories'),
      headers: h.authHeaders,
      body: jsonEncode({'id': 'orphan', 'label': 'Orphan'}),
    );
    expect(missing.statusCode, 400);

    await seedContentCategoriesForTest(db, ['dad']);
    final ok = await http.post(
      Uri.parse('${h.baseUrl}/v1/interests/joke-categories'),
      headers: h.authHeaders,
      body: jsonEncode({'id': 'dad', 'label': 'Dad jokes'}),
    );
    expect(ok.statusCode, 200);
  });

  test('GET/POST/PATCH/DELETE home assistant entity', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/home-assistant-entities'),
      headers: auth,
      body: jsonEncode({
        'id': 'kitchen_temp',
        'entity_id': 'sensor.kitchen_temperature',
        'display_name': 'Kitchen',
        'enabled': true,
      }),
    );
    expect(create.statusCode, 200);

    final list = await http.get(
      Uri.parse('$base/v1/interests/home-assistant-entities'),
      headers: auth,
    );
    expect(list.statusCode, 200);
    final items = (jsonDecode(list.body) as Map)['items'] as List;
    expect(items.length, 1);
    expect(items.first['entity_id'], 'sensor.kitchen_temperature');

    final patch = await http.patch(
      Uri.parse('$base/v1/interests/home-assistant-entities/kitchen_temp'),
      headers: auth,
      body: jsonEncode({'display_name': 'Kitchen temp'}),
    );
    expect(patch.statusCode, 200);

    await db
        .into(db.homeAssistantEntityStates)
        .insert(
          HomeAssistantEntityStatesCompanion.insert(
            entityId: 'sensor.kitchen_temperature',
            state: '21',
            attributesJson: '{}',
            observedAtMs: 1,
          ),
        );

    final del = await http.delete(
      Uri.parse('$base/v1/interests/home-assistant-entities/kitchen_temp'),
      headers: auth,
    );
    expect(del.statusCode, 200);

    expect(await db.select(db.homeAssistantEntityStates).get(), isEmpty);
  });

  test('power_viewer can read interests but not write', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(
      database: db,
      role: kUserRolePowerViewer,
    );
    addTearDown(h.dispose);

    final read = await http.get(
      Uri.parse('${h.baseUrl}/v1/interests/stock-symbols'),
      headers: h.authHeaders,
    );
    expect(read.statusCode, 200);

    final write = await http.post(
      Uri.parse('${h.baseUrl}/v1/interests/stock-symbols'),
      headers: h.authHeaders,
      body: jsonEncode({'id': 'x', 'symbol': 'X'}),
    );
    expect(write.statusCode, 403);
  });

  test('GET/POST/PATCH/DELETE stock symbol', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/stock-symbols'),
      headers: auth,
      body: jsonEncode({
        'id': 'aapl',
        'symbol': 'aapl',
        'display_name': 'Apple',
        'enabled': true,
      }),
    );
    expect(create.statusCode, 200);

    final list = await http.get(
      Uri.parse('$base/v1/interests/stock-symbols'),
      headers: auth,
    );
    expect(list.statusCode, 200);
    final items = (jsonDecode(list.body) as Map)['items'] as List;
    expect(items.length, 1);
    expect(items.first['symbol'], 'AAPL');

    final patch = await http.patch(
      Uri.parse('$base/v1/interests/stock-symbols/aapl'),
      headers: auth,
      body: jsonEncode({'display_name': 'Apple Inc.', 'enabled': false}),
    );
    expect(patch.statusCode, 200);

    final del = await http.delete(
      Uri.parse('$base/v1/interests/stock-symbols/aapl'),
      headers: auth,
    );
    expect(del.statusCode, 200);
  });

  test('DELETE stock symbol blocked when quotes exist', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(id: 'sym', symbol: 'SYM'),
        );
    await db
        .into(db.stockQuotes)
        .insert(
          StockQuotesCompanion.insert(
            symbolId: 'sym',
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/interests/stock-symbols/sym'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 409);
  });

  test('GET/POST/PATCH/DELETE trivia category', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['science']);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/trivia-categories'),
      headers: auth,
      body: jsonEncode({
        'id': 'science',
        'label': 'Science',
        'is_seasonal': true,
        'start_month': 3,
        'start_day': 14,
        'end_month': 3,
        'end_day': 15,
        'min_questions': 5,
        'max_questions': 20,
      }),
    );
    expect(create.statusCode, 200);

    final list = await http.get(
      Uri.parse('$base/v1/interests/trivia-categories'),
      headers: auth,
    );
    expect(list.statusCode, 200);
    final items = (jsonDecode(list.body) as Map)['items'] as List;
    expect(items.length, 1);
    expect(items.first['is_seasonal'], isTrue);

    final patch = await http.patch(
      Uri.parse('$base/v1/interests/trivia-categories/science'),
      headers: auth,
      body: jsonEncode({'label': 'Science trivia', 'max_questions': 50}),
    );
    expect(patch.statusCode, 200);

    final del = await http.delete(
      Uri.parse('$base/v1/interests/trivia-categories/science'),
      headers: auth,
    );
    expect(del.statusCode, 200);
  });

  test('DELETE trivia category blocked when questions exist', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['science']);
    await db
        .into(db.interestsTrivia)
        .insert(
          InterestsTriviaCompanion.insert(id: 'science', label: 'Science'),
        );
    await db
        .into(db.triviaQuestions)
        .insert(
          TriviaQuestionsCompanion.insert(
            id: 'q1',
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
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/interests/trivia-categories/science'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 409);
  });

  test('joke category patch and delete', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['dad']);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/joke-categories'),
      headers: auth,
      body: jsonEncode({
        'id': 'dad',
        'label': 'Dad jokes',
        'is_seasonal': false,
        'min_jokes': 2,
        'max_jokes': 10,
      }),
    );
    expect(create.statusCode, 200);

    final patch = await http.patch(
      Uri.parse('$base/v1/interests/joke-categories/dad'),
      headers: auth,
      body: jsonEncode({'label': 'Dad joke classics', 'is_seasonal': true}),
    );
    expect(patch.statusCode, 200);

    final del = await http.delete(
      Uri.parse('$base/v1/interests/joke-categories/dad'),
      headers: auth,
    );
    expect(del.statusCode, 200);
  });

  test('rss feed patch updates poll and retry fields', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['general']);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/rss-feeds'),
      headers: auth,
      body: jsonEncode({
        'id': 'f1',
        'url': 'https://example.com/rss.xml',
        'category': 'general',
        'title': 'Example',
      }),
    );
    expect(create.statusCode, 200);

    final patch = await http.patch(
      Uri.parse('$base/v1/interests/rss-feeds/f1'),
      headers: auth,
      body: jsonEncode({
        'poll_seconds': 7200,
        'max_articles': 5,
        'enabled': false,
        'last_fetched_at': 1,
        'consecutive_failures': 2,
        'next_retry_at': 3,
      }),
    );
    expect(patch.statusCode, 200);

    final list = await http.get(
      Uri.parse('$base/v1/interests/rss-feeds'),
      headers: auth,
    );
    final item =
        ((jsonDecode(list.body) as Map)['items'] as List).first
            as Map<String, dynamic>;
    expect(item['poll_seconds'], 7200);
    expect(item['enabled'], isFalse);
  });

  test('weather location POST validates required fields and duplicate id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = '${h.baseUrl}/v1/interests/weather-locations';
    final auth = h.authHeaders;

    final missing = await http.post(
      Uri.parse(base),
      headers: auth,
      body: jsonEncode({'id': 'x', 'name': 'X'}),
    );
    expect(missing.statusCode, 400);

    final create = await http.post(
      Uri.parse(base),
      headers: auth,
      body: jsonEncode({
        'id': 'sea',
        'name': 'Seattle',
        'latitude': 47.6,
        'longitude': -122.3,
      }),
    );
    expect(create.statusCode, 200);

    final dup = await http.post(
      Uri.parse(base),
      headers: auth,
      body: jsonEncode({
        'id': 'sea',
        'name': 'Seattle 2',
        'latitude': 48,
        'longitude': -123,
      }),
    );
    expect(dup.statusCode, 409);

    final notFound = await http.patch(
      Uri.parse('$base/missing'),
      headers: auth,
      body: jsonEncode({'name': 'N'}),
    );
    expect(notFound.statusCode, 404);
  });

  test('stock symbol POST rejects duplicate id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final url = '${h.baseUrl}/v1/interests/stock-symbols';
    final body = jsonEncode({'id': 'sym', 'symbol': 'SYM'});
    expect(
      (await http.post(Uri.parse(url), headers: h.authHeaders, body: body))
          .statusCode,
      200,
    );
    expect(
      (await http.post(Uri.parse(url), headers: h.authHeaders, body: body))
          .statusCode,
      409,
    );
  });

  test('home assistant POST rejects duplicate entity_id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final url = '${h.baseUrl}/v1/interests/home-assistant-entities';
    final body = jsonEncode({
      'id': 'a',
      'entity_id': 'sensor.temp',
      'display_name': 'Temp',
    });
    expect(
      (await http.post(Uri.parse(url), headers: h.authHeaders, body: body))
          .statusCode,
      200,
    );
    final dup = await http.post(
      Uri.parse(url),
      headers: h.authHeaders,
      body: jsonEncode({
        'id': 'b',
        'entity_id': 'sensor.temp',
        'display_name': 'Temp 2',
      }),
    );
    expect(dup.statusCode, 409);
  });

  test('trivia category POST rejects invalid category id format', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['science']);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/interests/trivia-categories'),
      headers: h.authHeaders,
      body: jsonEncode({'id': 'Bad-ID', 'label': 'Bad'}),
    );
    expect(res.statusCode, 400);
  });

  test('interests endpoints reject non-json bodies', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/interests/stock-symbols'),
      headers: h.authHeaders,
      body: '[]',
    );
    expect(res.statusCode, 400);
  });

  test('viewer cannot read interests', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db, role: kUserRoleViewer);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/interests/rss-feeds'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 403);
  });
}
