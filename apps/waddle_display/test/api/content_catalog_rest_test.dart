import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

Future<void> _seedCatalogRows(AppDatabase db) async {
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
          id: 'j1',
          categoryId: cat,
          setup: 'alpha setup',
          punchline: 'beta punch',
          createdAtMs: DateTime.fromMillisecondsSinceEpoch(10),
        ),
      );
  await db.into(db.jokes).insert(
        JokesCompanion.insert(
          id: 'j2',
          categoryId: cat,
          setup: 'other',
          punchline: 'x',
          createdAtMs: DateTime.fromMillisecondsSinceEpoch(20),
          suppressed: const Value(true),
        ),
      );
}

Future<void> _seedExtendedCatalog(AppDatabase db) async {
  await _seedCatalogRows(db);
  await db.into(db.news).insert(
        NewsCompanion.insert(
          id: 'art2',
          sourceType: kNewsSourceTypeRss,
          sourceId: 'f1',
          guid: 'guid-two',
          title: 'Other headline',
          link: 'https://example.com/other',
          summary: const Value('deep summary text'),
          publishedAt: DateTime.fromMillisecondsSinceEpoch(100),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(101),
        ),
      );
  await db.into(db.news).insert(
        NewsCompanion.insert(
          id: 'art3',
          sourceType: kNewsSourceTypeRss,
          sourceId: 'f1',
          guid: 'g3',
          title: 'Sans summary',
          link: 'https://example.com/3',
          publishedAt: DateTime.fromMillisecondsSinceEpoch(102),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(103),
        ),
      );
  await db.into(db.triviaQuestions).insert(
        TriviaQuestionsCompanion.insert(
          id: 'tq1',
          categoryId: 'general',
          question: 'What color is sky?',
          optionA: 'Blue paint',
          optionB: 'Green',
          optionC: 'Yellow',
          optionD: 'Magenta',
          correctOption: 'A',
          createdAtMs: DateTime.fromMillisecondsSinceEpoch(50),
          integrationId: const Value('trivia_openai'),
        ),
      );
  await db.into(db.triviaQuestions).insert(
        TriviaQuestionsCompanion.insert(
          id: 'tq2',
          categoryId: 'general',
          question: 'Hidden?',
          optionA: 'a',
          optionB: 'b',
          optionC: 'c',
          optionD: 'd',
          correctOption: 'B',
          createdAtMs: DateTime.fromMillisecondsSinceEpoch(51),
          suppressed: const Value(true),
          integrationId: const Value('trivia_opentdb'),
        ),
      );
  await db.into(db.photos).insert(
        PhotosCompanion.insert(
          id: 'ph1',
          category: const Value('general'),
          dataProvider: const Value(kMediaDataProviderPhotoPexels),
          mediaBlobKey: 'blob-photo-1',
          photographerName: 'Pat Photo',
          photographerUrl: 'https://pexels.com/u',
          pexelsPageUrl: 'https://pexels.com/p/1',
          altText: const Value('mountain vista'),
          fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(200),
        ),
      );
  await db.into(db.videos).insert(
        VideosCompanion.insert(
          id: 'vid1',
          category: const Value('general'),
          dataProvider: const Value(kMediaDataProviderVideoPexels),
          mediaBlobKey: 'blob-video-1',
          photographerName: 'Pat Video',
          photographerUrl: 'https://pexels.com/vu',
          pexelsPageUrl: 'https://pexels.com/v/1',
          altText: const Value('ocean clip'),
          durationSeconds: 12,
          fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(201),
        ),
      );
  await db.into(db.interestsStockSymbols).insert(
        InterestsStockSymbolsCompanion.insert(
          id: 'sym_aapl',
          symbol: 'AAPL',
          displayName: const Value('Apple Inc'),
        ),
      );
  await db.into(db.interestsStockSymbols).insert(
        InterestsStockSymbolsCompanion.insert(
          id: 'sym_msft',
          symbol: 'MSFT',
          displayName: const Value('Microsoft'),
        ),
      );
  await db.into(db.stockQuotes).insert(
        StockQuotesCompanion.insert(
          symbolId: 'sym_aapl',
          currentPrice: const Value(111),
          observedAtMs: DateTime.fromMillisecondsSinceEpoch(300),
        ),
      );
  await db.into(db.stockQuotes).insert(
        StockQuotesCompanion.insert(
          symbolId: 'sym_msft',
          currentPrice: const Value(222),
          observedAtMs: DateTime.fromMillisecondsSinceEpoch(301),
        ),
      );
  await db.into(db.interestsLocations).insert(
        InterestsLocationsCompanion.insert(
          id: 'seattle',
          name: 'Seattle, WA',
          latitude: 47.6,
          longitude: -122.3,
          includeWeather: const Value(true),
        ),
      );
  await db.into(db.interestsLocations).insert(
        InterestsLocationsCompanion.insert(
          id: 'denver',
          name: 'Denver, CO',
          latitude: 39.7392,
          longitude: -104.9903,
          includeWeather: const Value(true),
        ),
      );
  await db.into(db.weatherCurrent).insert(
        WeatherCurrentCompanion.insert(
          locationId: 'seattle',
          observedAtMs: DateTime.fromMillisecondsSinceEpoch(500),
          currentTemp: const Value(12),
          currentDescription: const Value('light rain expected'),
          hourlyJson: const Value('[]'),
        ),
      );
  await db.into(db.weatherAlerts).insert(
        WeatherAlertsCompanion.insert(
          locationId: 'seattle',
          nwsAlertId: 'urn:test:1',
          event: 'Flood Watch',
          headline: const Value('water levels rising'),
          severity: const Value('Minor'),
          descriptionExcerpt: const Value('river flooding possible'),
          effectiveAt: Value(DateTime.fromMillisecondsSinceEpoch(400)),
        ),
      );
  await db.into(db.weatherAlerts).insert(
        WeatherAlertsCompanion.insert(
          locationId: 'denver',
          nwsAlertId: 'urn:test:2',
          event: 'Wind Advisory',
          headline: const Value('gusty winds'),
          severity: const Value('Moderate'),
          effectiveAt: Value(DateTime.fromMillisecondsSinceEpoch(350)),
        ),
      );
  await db.into(db.alerts).insert(
        AlertsCompanion.insert(
          title: 'Body match',
          body: 'contains needle token',
          createdAt: DateTime.fromMillisecondsSinceEpoch(900),
          severity: const Value('warning'),
          source: const Value('custom_source'),
        ),
      );
}

void main() {
  test('GET /v1/catalog/jokes paginates and filters', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final page = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?limit=1&offset=0&setup=alpha'),
      headers: h.authHeaders,
    );
    expect(page.statusCode, 200);
    final body = jsonDecode(page.body) as Map<String, dynamic>;
    expect(body['total'], 1);
    expect((body['items'] as List).length, 1);
    expect((body['items'] as List).first['id'], 'j1');
    expect((body['items'] as List).first['integration_type'], 'joke_openai');

    final all = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?limit=50&offset=0'),
      headers: h.authHeaders,
    );
    expect(all.statusCode, 200);
    final allBody = jsonDecode(all.body) as Map<String, dynamic>;
    expect(allBody['total'], 2);

    final suppressed = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?suppressed=true'),
      headers: h.authHeaders,
    );
    expect(suppressed.statusCode, 200);
    final supBody = jsonDecode(suppressed.body) as Map<String, dynamic>;
    expect(supBody['total'], 1);
    expect((supBody['items'] as List).first['id'], 'j2');
  });

  test('GET /v1/catalog/alerts paginates and filters', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.alerts).insert(
          AlertsCompanion.insert(
            title: 'Sign-in',
            body: 'Use code ABC',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
            source: const Value('google_calendar'),
          ),
        );
    await db.into(db.alerts).insert(
          AlertsCompanion.insert(
            title: 'Other',
            body: 'Nothing',
            createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        );
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final page = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/alerts?limit=1&offset=0&title=Sign'),
      headers: h.authHeaders,
    );
    expect(page.statusCode, 200);
    final body = jsonDecode(page.body) as Map<String, dynamic>;
    expect(body['total'], 1);
    expect((body['items'] as List).length, 1);
    expect((body['items'] as List).first['title'], 'Sign-in');

    final all = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/alerts?limit=50&offset=0'),
      headers: h.authHeaders,
    );
    expect(all.statusCode, 200);
    final allBody = jsonDecode(all.body) as Map<String, dynamic>;
    expect(allBody['total'], 2);
  });

  test('GET /v1/catalog/* covers trivia, rss-articles, media, stocks, weather', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedExtendedCatalog(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final longNeedle = '${List.filled(220, 'x').join()}needle';

    final jokesClamp = await http.get(
      Uri.parse('$base/v1/catalog/jokes?limit=500&offset=0'),
      headers: auth,
    );
    expect(jokesClamp.statusCode, 200);
    expect(
      (jsonDecode(jokesClamp.body) as Map<String, dynamic>)['limit'],
      100,
    );

    final jokesPunch = await http.get(
      Uri.parse('$base/v1/catalog/jokes?punchline=beta'),
      headers: auth,
    );
    expect(jokesPunch.statusCode, 200);
    expect((jsonDecode(jokesPunch.body) as Map<String, dynamic>)['total'], 1);

    final jokesSupFalse = await http.get(
      Uri.parse('$base/v1/catalog/jokes?suppressed=false'),
      headers: auth,
    );
    expect(jokesSupFalse.statusCode, 200);
    expect((jsonDecode(jokesSupFalse.body) as Map<String, dynamic>)['total'], 1);

    final jokesLongNeedle = await http.get(
      Uri.parse('$base/v1/catalog/jokes?setup=$longNeedle'),
      headers: auth,
    );
    expect(jokesLongNeedle.statusCode, 200);

    final jokesCategory = await http.get(
      Uri.parse('$base/v1/catalog/jokes?category=general'),
      headers: auth,
    );
    expect(jokesCategory.statusCode, 200);
    expect((jsonDecode(jokesCategory.body) as Map<String, dynamic>)['total'], 2);

    final trivia = await http.get(
      Uri.parse(
        '$base/v1/catalog/trivia?question=sky&option_a=Blue&integration_type=openai',
      ),
      headers: auth,
    );
    expect(trivia.statusCode, 200);
    final triviaBody = jsonDecode(trivia.body) as Map<String, dynamic>;
    expect(triviaBody['total'], 1);
    expect((triviaBody['items'] as List).single['id'], 'tq1');

    final triviaOpts = await http.get(
      Uri.parse(
        '$base/v1/catalog/trivia?option_b=Green&option_c=Yellow&option_d=Magenta',
      ),
      headers: auth,
    );
    expect(triviaOpts.statusCode, 200);
    expect((jsonDecode(triviaOpts.body) as Map<String, dynamic>)['total'], 1);

    final triviaSup = await http.get(
      Uri.parse('$base/v1/catalog/trivia?suppressed=true'),
      headers: auth,
    );
    expect(triviaSup.statusCode, 200);
    expect((jsonDecode(triviaSup.body) as Map<String, dynamic>)['total'], 1);

    final rss = await http.get(
      Uri.parse(
        '$base/v1/catalog/rss-articles?title=head&summary=deep&link=example&guid=guid&feed_id=f1',
      ),
      headers: auth,
    );
    expect(rss.statusCode, 200);
    expect((jsonDecode(rss.body) as Map<String, dynamic>)['total'], 1);

    final rssSummaryOnly = await http.get(
      Uri.parse('$base/v1/catalog/rss-articles?summary=deep'),
      headers: auth,
    );
    expect(rssSummaryOnly.statusCode, 200);
    expect((jsonDecode(rssSummaryOnly.body) as Map<String, dynamic>)['total'], 1);

    final photos = await http.get(
      Uri.parse(
        '$base/v1/catalog/photos?alt_text=mountain&photographer_name=Pat&data_provider=pexels&category=general',
      ),
      headers: auth,
    );
    expect(photos.statusCode, 200);
    expect((jsonDecode(photos.body) as Map<String, dynamic>)['total'], 1);

    final videos = await http.get(
      Uri.parse(
        '$base/v1/catalog/videos?alt_text=ocean&photographer_name=Pat&data_provider=pexels&category=general',
      ),
      headers: auth,
    );
    expect(videos.statusCode, 200);
    expect((jsonDecode(videos.body) as Map<String, dynamic>)['total'], 1);

    final stocks = await http.get(
      Uri.parse('$base/v1/catalog/stock-quotes?symbol=AAPL&display_name=Apple'),
      headers: auth,
    );
    expect(stocks.statusCode, 200);
    final stocksBody = jsonDecode(stocks.body) as Map<String, dynamic>;
    expect(stocksBody['total'], 1);
    expect((stocksBody['items'] as List).single['symbol_id'], 'sym_aapl');

    final stockByDisplayName = await http.get(
      Uri.parse('$base/v1/catalog/stock-quotes?display_name=Microsoft'),
      headers: auth,
    );
    expect(stockByDisplayName.statusCode, 200);
    expect(
      (jsonDecode(stockByDisplayName.body) as Map<String, dynamic>)['total'],
      1,
    );

    final stocksMiss = await http.get(
      Uri.parse('$base/v1/catalog/stock-quotes?symbol=ZZZNOMATCH'),
      headers: auth,
    );
    expect(stocksMiss.statusCode, 200);
    expect((jsonDecode(stocksMiss.body) as Map<String, dynamic>)['total'], 0);

    final wxLoc = await http.get(
      Uri.parse('$base/v1/interests/weather-locations'),
      headers: auth,
    );
    expect(wxLoc.statusCode, 200);
    expect((jsonDecode(wxLoc.body) as Map<String, dynamic>)['items'], hasLength(2));

    final wxCur = await http.get(
      Uri.parse(
        '$base/v1/catalog/weather-current?location_id=seattle&description=rain',
      ),
      headers: auth,
    );
    expect(wxCur.statusCode, 200);
    expect((jsonDecode(wxCur.body) as Map<String, dynamic>)['total'], 1);

    final wxCurName = await http.get(
      Uri.parse('$base/v1/catalog/weather-current?location_name=Seattle'),
      headers: auth,
    );
    expect(wxCurName.statusCode, 200);

    final wxCurGhost = await http.get(
      Uri.parse('$base/v1/catalog/weather-current?location_name=ZZNoTown'),
      headers: auth,
    );
    expect(wxCurGhost.statusCode, 200);

    final wxAlert = await http.get(
      Uri.parse(
        '$base/v1/catalog/weather-alerts?event=Flood&headline=water&severity=Minor&excerpt=river&location_name=Seattle',
      ),
      headers: auth,
    );
    expect(wxAlert.statusCode, 200);
    expect((jsonDecode(wxAlert.body) as Map<String, dynamic>)['total'], 1);

    final wxAlertLoc = await http.get(
      Uri.parse('$base/v1/catalog/weather-alerts?location_id=denver'),
      headers: auth,
    );
    expect(wxAlertLoc.statusCode, 200);
    expect((jsonDecode(wxAlertLoc.body) as Map<String, dynamic>)['total'], 1);

    final opAlertsAll = await http.get(
      Uri.parse('$base/v1/catalog/alerts?limit=50'),
      headers: auth,
    );
    expect(opAlertsAll.statusCode, 200);
    expect((jsonDecode(opAlertsAll.body) as Map<String, dynamic>)['total'], 1);

    // `_likeNeedle` strips `_` from query needles; use `custom` not `custom_source`.
    final opAlerts = await http.get(
      Uri.parse('$base/v1/catalog/alerts').replace(
        queryParameters: {
          'title': 'Body',
          'body': 'needle',
          'source': 'custom',
          'severity': 'warn',
        },
      ),
      headers: auth,
    );
    expect(opAlerts.statusCode, 200);
    expect((jsonDecode(opAlerts.body) as Map<String, dynamic>)['total'], 1);
  });

  test('viewer cannot read catalog', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db, role: kUserRoleViewer);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 403);
  });

  test('power_viewer can read catalog without suppressed rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db, role: kUserRolePowerViewer);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?limit=50&offset=0'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['total'], 1);
    final items = body['items'] as List;
    expect(items.length, 1);
    expect((items.first as Map)['id'], 'j1');
    expect((items.first as Map).containsKey('suppressed'), isFalse);
  });

  test('power_viewer cannot use suppressed=true on catalog', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db, role: kUserRolePowerViewer);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/catalog/jokes?suppressed=true'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 403);
  });

  test('power_viewer cannot PATCH content suppression', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedCatalogRows(db);
    final h = await RestTestHarness.start(database: db, role: kUserRolePowerViewer);
    addTearDown(h.dispose);

    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/content/jokes/j1'),
      headers: h.authHeaders,
      body: '{"suppressed":true}',
    );
    expect(res.statusCode, 403);
  });
}
