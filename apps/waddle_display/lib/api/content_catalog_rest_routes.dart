import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_display/api/api_key_auth.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

/// Paginated operator catalog for ingested content (`GET /v1/catalog/*`).
///
/// Requires [WaddlePermission.contentCatalogRead] or [WaddlePermission.contentModerate]
/// (see [route_permissions.dart]). Catalog-read-only roles never see suppressed rows
/// and cannot use `suppressed=true`.
void registerContentCatalogRoutes(Router r, {required AppDatabase db}) {
  r.get('/v1/catalog/jokes', (Request req) => _listJokes(db, req));
  r.get('/v1/catalog/trivia', (Request req) => _listTrivia(db, req));
  r.get('/v1/catalog/rss-articles', (Request req) => _listRssArticles(db, req));
  r.get('/v1/catalog/photos', (Request req) => _listPhotos(db, req));
  r.get('/v1/catalog/videos', (Request req) => _listVideos(db, req));
  r.get('/v1/catalog/stock-quotes', (Request req) => _listStockQuotes(db, req));
  r.get(
    '/v1/catalog/weather-current',
    (Request req) => _listWeatherCurrent(db, req),
  );
  r.get(
    '/v1/catalog/weather-alerts',
    (Request req) => _listWeatherAlerts(db, req),
  );
  r.get('/v1/catalog/alerts', (Request req) => _listOperatorAlerts(db, req));
  r.get(
    '/v1/catalog/calendar-events',
    (Request req) => _listCalendarEvents(db, req),
  );
  r.get(
    '/v1/catalog/quoterism-quotes',
    (Request req) => _listQuoterismQuotes(db, req),
  );
  r.get('/v1/catalog/tasks', (Request req) => _listTasks(db, req));
  r.get(
    '/v1/catalog/category-options',
    (Request req) => _listCatalogCategoryOptions(db, req),
  );
}

class _CatalogParams {
  _CatalogParams({
    required this.limit,
    required this.offset,
    this.suppressed,
    this.category,
    this.feedId,
    this.locationId,
  });

  final int limit;
  final int offset;
  final bool? suppressed;
  final String? category;
  final String? feedId;
  final String? locationId;

  static _CatalogParams parse(Request req) {
    final qp = req.url.queryParameters;
    final limitRaw = int.tryParse(qp['limit'] ?? '') ?? 25;
    final limit = limitRaw.clamp(1, 100);
    final offset = (int.tryParse(qp['offset'] ?? '') ?? 0).clamp(0, 1 << 30);
    final suppressedRaw = qp['suppressed']?.trim().toLowerCase();
    final bool? suppressed = suppressedRaw == null || suppressedRaw.isEmpty
        ? null
        : suppressedRaw == 'true'
        ? true
        : suppressedRaw == 'false'
        ? false
        : null;
    final category = qp['category']?.trim();
    final feedId = qp['feed_id']?.trim();
    final locationId = qp['location_id']?.trim();
    return _CatalogParams(
      limit: limit,
      offset: offset,
      suppressed: suppressed,
      category: category != null && category.isNotEmpty ? category : null,
      feedId: feedId != null && feedId.isNotEmpty ? feedId : null,
      locationId: locationId != null && locationId.isNotEmpty
          ? locationId
          : null,
    );
  }
}

const String _kCatalogJokeIntegrationType = 'joke_openai';

String _catalogQuoteIntegrationType(String quoteId) {
  if (quoteId.startsWith('bucket_quote_')) {
    return kManualEntrySource;
  }
  return kCatalogQuoterismIntegrationType;
}

String _catalogJokeIntegrationType(String jokeId) {
  if (jokeId.startsWith('bucket_joke_')) {
    return kManualEntrySource;
  }
  return _kCatalogJokeIntegrationType;
}

String _catalogTriviaIntegrationType(String triviaId, String? integrationId) {
  if (triviaId.startsWith('bucket_trivia_')) {
    return kManualEntrySource;
  }
  final raw = integrationId?.trim();
  if (raw == null || raw.isEmpty) {
    return kManualEntrySource;
  }
  if (raw == 'default_trivia_bucket') {
    return kManualEntrySource;
  }
  return raw;
}

const String _kCatalogNewsIntegrationType = 'news_rss';
const String _kCatalogStockIntegrationType = 'stock_finnhub';
const String _kCatalogWeatherCurrentIntegrationType = 'weather_openweathermap';
const String _kCatalogWeatherAlertsIntegrationType = 'weather_nws_alerts';

String? _queryNeedle(Request req, String key) {
  var raw = (req.url.queryParameters[key] ?? '').trim();
  if (raw.length > 200) {
    raw = raw.substring(0, 200);
  }
  return _likeNeedle(raw);
}

String? _likeNeedle(String q) {
  final stripped = q.replaceAll('%', '').replaceAll('_', '').trim();
  if (stripped.isEmpty) {
    return null;
  }
  return stripped;
}

Response _jsonCatalogForbidden() => Response(
  403,
  body: '{"error":"forbidden"}',
  headers: {'content-type': 'application/json'},
);

bool _catalogFullModeration(Request req) {
  final role = apiClientRole(req);
  if (role == null) return false;
  return userHasPermission(role, WaddlePermission.contentModerate);
}

_CatalogParams _catalogParamsActiveOnly(_CatalogParams p) => _CatalogParams(
  limit: p.limit,
  offset: p.offset,
  suppressed: false,
  category: p.category,
  feedId: p.feedId,
  locationId: p.locationId,
);

/// Returns `(error response, effective params, browse_only_json)`; on error, ignore other fields.
(Response?, _CatalogParams, bool) _prepareCatalogList(
  Request req,
  _CatalogParams parsed,
) {
  if (_catalogFullModeration(req)) {
    return (null, parsed, false);
  }
  if (parsed.suppressed == true) {
    return (_jsonCatalogForbidden(), parsed, true);
  }
  return (null, _catalogParamsActiveOnly(parsed), true);
}

Response _jsonOk(Object body) => Response.ok(
  jsonEncode(body),
  headers: {'content-type': 'application/json'},
);

Future<Response> _listJokes(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final browseOnly = prep.$3;
  final setupNeedle = _queryNeedle(req, 'setup');
  final punchlineNeedle = _queryNeedle(req, 'punchline');
  final rows =
      await (db.select(db.jokes)
            ..where((t) => _jokeWhere(t, p, setupNeedle, punchlineNeedle))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final total = await _countJokes(db, p, setupNeedle, punchlineNeedle);
  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'category_id': r.categoryId,
          'setup': r.setup,
          'punchline': r.punchline,
          'created_at_ms': r.createdAtMs.millisecondsSinceEpoch,
          if (!browseOnly) 'suppressed': r.suppressed,
          'integration_type': _catalogJokeIntegrationType(r.id),
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _jokeWhere(
  $JokesTable t,
  _CatalogParams p,
  String? setupNeedle,
  String? punchlineNeedle,
) {
  Expression<bool> e = const Constant(true);
  if (p.suppressed != null) {
    e = e & t.suppressed.equals(p.suppressed!);
  }
  if (p.category != null) {
    e = e & t.categoryId.equals(p.category!);
  }
  if (setupNeedle != null) {
    e = e & t.setup.like('%$setupNeedle%');
  }
  if (punchlineNeedle != null) {
    e = e & t.punchline.like('%$punchlineNeedle%');
  }
  return e;
}

Future<int> _countJokes(
  AppDatabase db,
  _CatalogParams p,
  String? setupNeedle,
  String? punchlineNeedle,
) async {
  final count = db.jokes.id.count();
  final row =
      await (db.selectOnly(db.jokes)
            ..addColumns([count])
            ..where(_jokeWhere(db.jokes, p, setupNeedle, punchlineNeedle)))
          .getSingle();
  return row.read(count) ?? 0;
}

Future<Response> _listTrivia(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final browseOnly = prep.$3;
  final questionNeedle = _queryNeedle(req, 'question');
  final optionANeedle = _queryNeedle(req, 'option_a');
  final optionBNeedle = _queryNeedle(req, 'option_b');
  final optionCNeedle = _queryNeedle(req, 'option_c');
  final optionDNeedle = _queryNeedle(req, 'option_d');
  final integrationTypeNeedle = _queryNeedle(req, 'integration_type');
  final rows =
      await (db.select(db.triviaQuestions)
            ..where(
              (t) => _triviaWhere(
                t,
                p,
                questionNeedle,
                optionANeedle,
                optionBNeedle,
                optionCNeedle,
                optionDNeedle,
                integrationTypeNeedle,
              ),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAtMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final total = await _countTrivia(
    db,
    p,
    questionNeedle,
    optionANeedle,
    optionBNeedle,
    optionCNeedle,
    optionDNeedle,
    integrationTypeNeedle,
  );
  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'category_id': r.categoryId,
          'question': r.question,
          'option_a': r.optionA,
          'option_b': r.optionB,
          'option_c': r.optionC,
          'option_d': r.optionD,
          'correct_option': r.correctOption,
          'created_at_ms': r.createdAtMs.millisecondsSinceEpoch,
          if (!browseOnly) 'suppressed': r.suppressed,
          'integration_type': _catalogTriviaIntegrationType(
            r.id,
            r.integrationId,
          ),
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _triviaWhere(
  $TriviaQuestionsTable t,
  _CatalogParams p,
  String? questionNeedle,
  String? optionANeedle,
  String? optionBNeedle,
  String? optionCNeedle,
  String? optionDNeedle,
  String? integrationTypeNeedle,
) {
  Expression<bool> e = const Constant(true);
  if (p.suppressed != null) {
    e = e & t.suppressed.equals(p.suppressed!);
  }
  if (p.category != null) {
    e = e & t.categoryId.equals(p.category!);
  }
  if (questionNeedle != null) {
    e = e & t.question.like('%$questionNeedle%');
  }
  if (optionANeedle != null) {
    e = e & t.optionA.like('%$optionANeedle%');
  }
  if (optionBNeedle != null) {
    e = e & t.optionB.like('%$optionBNeedle%');
  }
  if (optionCNeedle != null) {
    e = e & t.optionC.like('%$optionCNeedle%');
  }
  if (optionDNeedle != null) {
    e = e & t.optionD.like('%$optionDNeedle%');
  }
  if (integrationTypeNeedle != null) {
    e = e & t.integrationId.like('%$integrationTypeNeedle%');
  }
  return e;
}

Future<int> _countTrivia(
  AppDatabase db,
  _CatalogParams p,
  String? questionNeedle,
  String? optionANeedle,
  String? optionBNeedle,
  String? optionCNeedle,
  String? optionDNeedle,
  String? integrationTypeNeedle,
) async {
  final count = db.triviaQuestions.id.count();
  final row =
      await (db.selectOnly(db.triviaQuestions)
            ..addColumns([count])
            ..where(
              _triviaWhere(
                db.triviaQuestions,
                p,
                questionNeedle,
                optionANeedle,
                optionBNeedle,
                optionCNeedle,
                optionDNeedle,
                integrationTypeNeedle,
              ),
            ))
          .getSingle();
  return row.read(count) ?? 0;
}

Future<Response> _listRssArticles(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final browseOnly = prep.$3;
  final titleNeedle = _queryNeedle(req, 'title');
  final summaryNeedle = _queryNeedle(req, 'summary');
  final linkNeedle = _queryNeedle(req, 'link');
  final guidNeedle = _queryNeedle(req, 'guid');
  final rows =
      await (db.select(db.news)
            ..where(
              (t) => _rssWhere(
                t,
                p,
                titleNeedle,
                summaryNeedle,
                linkNeedle,
                guidNeedle,
              ),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final total = await _countRss(
    db,
    p,
    titleNeedle,
    summaryNeedle,
    linkNeedle,
    guidNeedle,
  );
  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'feed_id': r.sourceId,
          'guid': r.guid,
          'title': r.title,
          'link': r.link,
          'summary': r.summary,
          'published_at_ms': r.publishedAt.millisecondsSinceEpoch,
          'fetched_at_ms': r.fetchedAt.millisecondsSinceEpoch,
          'image_blob_key': r.imageBlobKey,
          if (!browseOnly) 'suppressed': r.suppressed,
          'integration_type': _kCatalogNewsIntegrationType,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _rssWhere(
  $NewsTable t,
  _CatalogParams p,
  String? titleNeedle,
  String? summaryNeedle,
  String? linkNeedle,
  String? guidNeedle,
) {
  Expression<bool> e = const Constant(true);
  if (p.suppressed != null) {
    e = e & t.suppressed.equals(p.suppressed!);
  }
  if (p.feedId != null) {
    e =
        e &
        t.sourceType.equals(kNewsSourceTypeRss) &
        t.sourceId.equals(p.feedId!);
  }
  if (titleNeedle != null) {
    e = e & t.title.like('%$titleNeedle%');
  }
  if (summaryNeedle != null) {
    e = e & (t.summary.isNotNull() & t.summary.like('%$summaryNeedle%'));
  }
  if (linkNeedle != null) {
    e = e & t.link.like('%$linkNeedle%');
  }
  if (guidNeedle != null) {
    e = e & t.guid.like('%$guidNeedle%');
  }
  return e;
}

Future<int> _countRss(
  AppDatabase db,
  _CatalogParams p,
  String? titleNeedle,
  String? summaryNeedle,
  String? linkNeedle,
  String? guidNeedle,
) async {
  final count = db.news.id.count();
  final row =
      await (db.selectOnly(db.news)
            ..addColumns([count])
            ..where(
              _rssWhere(
                db.news,
                p,
                titleNeedle,
                summaryNeedle,
                linkNeedle,
                guidNeedle,
              ),
            ))
          .getSingle();
  return row.read(count) ?? 0;
}

Future<Response> _listPhotos(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final browseOnly = prep.$3;
  final altNeedle = _queryNeedle(req, 'alt_text');
  final photographerNeedle = _queryNeedle(req, 'photographer_name');
  final dataProviderNeedle = _queryNeedle(req, 'data_provider');
  final rows =
      await (db.select(db.photos)
            ..where(
              (t) => _photoWhere(
                t,
                p,
                altNeedle,
                photographerNeedle,
                dataProviderNeedle,
              ),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.fetchedAtMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final total = await _countPhotos(
    db,
    p,
    altNeedle,
    photographerNeedle,
    dataProviderNeedle,
  );
  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'category': r.category,
          'data_provider': r.dataProvider,
          'media_blob_key': r.mediaBlobKey,
          'photographer_name': r.photographerName,
          'photographer_url': r.photographerUrl,
          'page_url': r.pageUrl,
          'alt_text': r.altText,
          'fetched_at_ms': r.fetchedAtMs.millisecondsSinceEpoch,
          if (!browseOnly) 'suppressed': r.suppressed,
          'integration_type': r.dataProvider,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _photoWhere(
  $PhotosTable t,
  _CatalogParams p,
  String? altNeedle,
  String? photographerNeedle,
  String? dataProviderNeedle,
) {
  Expression<bool> e = const Constant(true);
  if (p.suppressed != null) {
    e = e & t.suppressed.equals(p.suppressed!);
  }
  if (p.category != null) {
    e = e & t.category.equals(p.category!);
  }
  if (altNeedle != null) {
    e = e & t.altText.like('%$altNeedle%');
  }
  if (photographerNeedle != null) {
    e = e & t.photographerName.like('%$photographerNeedle%');
  }
  if (dataProviderNeedle != null) {
    e = e & t.dataProvider.like('%$dataProviderNeedle%');
  }
  return e;
}

Future<int> _countPhotos(
  AppDatabase db,
  _CatalogParams p,
  String? altNeedle,
  String? photographerNeedle,
  String? dataProviderNeedle,
) async {
  final count = db.photos.id.count();
  final row =
      await (db.selectOnly(db.photos)
            ..addColumns([count])
            ..where(
              _photoWhere(
                db.photos,
                p,
                altNeedle,
                photographerNeedle,
                dataProviderNeedle,
              ),
            ))
          .getSingle();
  return row.read(count) ?? 0;
}

Future<Response> _listVideos(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final browseOnly = prep.$3;
  final altNeedle = _queryNeedle(req, 'alt_text');
  final photographerNeedle = _queryNeedle(req, 'photographer_name');
  final dataProviderNeedle = _queryNeedle(req, 'data_provider');
  final rows =
      await (db.select(db.videos)
            ..where(
              (t) => _videoWhere(
                t,
                p,
                altNeedle,
                photographerNeedle,
                dataProviderNeedle,
              ),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.fetchedAtMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final total = await _countVideos(
    db,
    p,
    altNeedle,
    photographerNeedle,
    dataProviderNeedle,
  );
  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'category': r.category,
          'data_provider': r.dataProvider,
          'media_blob_key': r.mediaBlobKey,
          'photographer_name': r.photographerName,
          'photographer_url': r.photographerUrl,
          'pexels_page_url': r.pexelsPageUrl,
          'alt_text': r.altText,
          'duration_seconds': r.durationSeconds,
          'fetched_at_ms': r.fetchedAtMs.millisecondsSinceEpoch,
          if (!browseOnly) 'suppressed': r.suppressed,
          'integration_type': r.dataProvider,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _videoWhere(
  $VideosTable t,
  _CatalogParams p,
  String? altNeedle,
  String? photographerNeedle,
  String? dataProviderNeedle,
) {
  Expression<bool> e = const Constant(true);
  if (p.suppressed != null) {
    e = e & t.suppressed.equals(p.suppressed!);
  }
  if (p.category != null) {
    e = e & t.category.equals(p.category!);
  }
  if (altNeedle != null) {
    e = e & t.altText.like('%$altNeedle%');
  }
  if (photographerNeedle != null) {
    e = e & t.photographerName.like('%$photographerNeedle%');
  }
  if (dataProviderNeedle != null) {
    e = e & t.dataProvider.like('%$dataProviderNeedle%');
  }
  return e;
}

Future<int> _countVideos(
  AppDatabase db,
  _CatalogParams p,
  String? altNeedle,
  String? photographerNeedle,
  String? dataProviderNeedle,
) async {
  final count = db.videos.id.count();
  final row =
      await (db.selectOnly(db.videos)
            ..addColumns([count])
            ..where(
              _videoWhere(
                db.videos,
                p,
                altNeedle,
                photographerNeedle,
                dataProviderNeedle,
              ),
            ))
          .getSingle();
  return row.read(count) ?? 0;
}

Expression<bool> _stockQuotesWhere(
  $StockQuotesTable q,
  List<String>? symbolFilterIds,
) {
  Expression<bool> e = const Constant(true);
  if (symbolFilterIds != null) {
    if (symbolFilterIds.isEmpty) {
      e = e & const Constant(false);
    } else {
      e = e & q.symbolId.isIn(symbolFilterIds);
    }
  }
  return e;
}

Future<Response> _listStockQuotes(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final symbolNeedle = _queryNeedle(req, 'symbol');
  final displayNameNeedle = _queryNeedle(req, 'display_name');
  List<String>? symbolFilterIds;
  if (symbolNeedle != null || displayNameNeedle != null) {
    symbolFilterIds =
        await (db.select(db.interestsStockSymbols)..where((s) {
              Expression<bool> e = const Constant(true);
              if (symbolNeedle != null) {
                e = e & s.symbol.like('%$symbolNeedle%');
              }
              if (displayNameNeedle != null) {
                e = e & s.displayName.like('%$displayNameNeedle%');
              }
              return e;
            }))
            .map((s) => s.id)
            .get();
  }
  final pred = _stockQuotesWhere(db.stockQuotes, symbolFilterIds);

  final rows =
      await (db.select(db.stockQuotes)
            ..where((q) => _stockQuotesWhere(q, symbolFilterIds))
            ..orderBy([(q) => OrderingTerm.desc(q.observedAtMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final countCol = db.stockQuotes.symbolId.count();
  final totalRow =
      await (db.selectOnly(db.stockQuotes)
            ..addColumns([countCol])
            ..where(pred))
          .getSingle();
  final total = totalRow.read(countCol) ?? 0;

  final symIds = rows.map((r) => r.symbolId).toSet().toList();
  final symbols = symIds.isEmpty
      ? <String, (String, String)>{}
      : {
          for (final s in await (db.select(
            db.interestsStockSymbols,
          )..where((t) => t.id.isIn(symIds))).get())
            s.id: (s.symbol, s.displayName),
        };

  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'symbol_id': r.symbolId,
          'symbol': symbols[r.symbolId]?.$1 ?? r.symbolId,
          'display_name': symbols[r.symbolId]?.$2 ?? '',
          'current_price': r.currentPrice,
          'change_amount': r.changeAmount,
          'percent_change': r.percentChange,
          'high_of_day': r.highOfDay,
          'low_of_day': r.lowOfDay,
          'open_price': r.openPrice,
          'previous_close': r.previousClose,
          'quoted_at_ms': r.quotedAtMs?.millisecondsSinceEpoch,
          'observed_at_ms': r.observedAtMs.millisecondsSinceEpoch,
          'integration_type': _kCatalogStockIntegrationType,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _weatherCurrentWhere(
  $WeatherCurrentTable t,
  _CatalogParams p,
  String? descriptionNeedle,
  Set<String>? locNameMatch,
) {
  Expression<bool> e = const Constant(true);
  if (p.locationId != null) {
    e = e & t.locationId.equals(p.locationId!);
  }
  if (locNameMatch != null && locNameMatch.isNotEmpty) {
    e = e & t.locationId.isIn(locNameMatch.toList());
  }
  if (descriptionNeedle != null) {
    e =
        e &
        (t.currentDescription.isNotNull() &
            t.currentDescription.like('%$descriptionNeedle%'));
  }
  return e;
}

Future<Response> _listWeatherCurrent(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final descriptionNeedle = _queryNeedle(req, 'description');
  final locationNameNeedle = _queryNeedle(req, 'location_name');
  Set<String>? locNameMatch;
  if (locationNameNeedle != null) {
    locNameMatch =
        (await (db.select(db.interestsLocations)
                  ..where((l) => l.name.like('%$locationNameNeedle%')))
                .map((l) => l.id)
                .get())
            .toSet();
  }

  final pred = _weatherCurrentWhere(
    db.weatherCurrent,
    p,
    descriptionNeedle,
    locNameMatch,
  );

  final rows =
      await (db.select(db.weatherCurrent)
            ..where(
              (t) =>
                  _weatherCurrentWhere(t, p, descriptionNeedle, locNameMatch),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.observedAtMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final countCol = db.weatherCurrent.locationId.count();
  final totalRow =
      await (db.selectOnly(db.weatherCurrent)
            ..addColumns([countCol])
            ..where(pred))
          .getSingle();
  final total = totalRow.read(countCol) ?? 0;

  final locIds = rows.map((r) => r.locationId).toSet().toList();
  final names = locIds.isEmpty
      ? <String, String>{}
      : {
          for (final l in await (db.select(
            db.interestsLocations,
          )..where((t) => t.id.isIn(locIds))).get())
            l.id: l.name,
        };

  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'location_id': r.locationId,
          'location_name': names[r.locationId] ?? r.locationId,
          'observed_at_ms': r.observedAtMs.millisecondsSinceEpoch,
          'current_temp': r.currentTemp,
          'current_description': r.currentDescription,
          'current_icon_blob_key': r.currentIconBlobKey,
          'hourly_json': r.hourlyJson,
          'integration_type': _kCatalogWeatherCurrentIntegrationType,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _weatherAlertWhere(
  $WeatherAlertsTable t,
  _CatalogParams p,
  String? eventNeedle,
  String? headlineNeedle,
  String? severityNeedle,
  String? excerptNeedle,
  Set<String>? locNameMatch,
) {
  Expression<bool> e = const Constant(true);
  if (p.locationId != null) {
    e = e & t.locationId.equals(p.locationId!);
  }
  if (locNameMatch != null && locNameMatch.isNotEmpty) {
    e = e & t.locationId.isIn(locNameMatch.toList());
  }
  if (eventNeedle != null) {
    e = e & t.event.like('%$eventNeedle%');
  }
  if (headlineNeedle != null) {
    e = e & (t.headline.isNotNull() & t.headline.like('%$headlineNeedle%'));
  }
  if (severityNeedle != null) {
    e = e & (t.severity.isNotNull() & t.severity.like('%$severityNeedle%'));
  }
  if (excerptNeedle != null) {
    e =
        e &
        (t.descriptionExcerpt.isNotNull() &
            t.descriptionExcerpt.like('%$excerptNeedle%'));
  }
  return e;
}

Future<Response> _listWeatherAlerts(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final eventNeedle = _queryNeedle(req, 'event');
  final headlineNeedle = _queryNeedle(req, 'headline');
  final severityNeedle = _queryNeedle(req, 'severity');
  final excerptNeedle = _queryNeedle(req, 'excerpt');
  final locationNameNeedle = _queryNeedle(req, 'location_name');
  Set<String>? locNameMatch;
  if (locationNameNeedle != null) {
    locNameMatch =
        (await (db.select(db.interestsLocations)
                  ..where((l) => l.name.like('%$locationNameNeedle%')))
                .map((l) => l.id)
                .get())
            .toSet();
  }

  final pred = _weatherAlertWhere(
    db.weatherAlerts,
    p,
    eventNeedle,
    headlineNeedle,
    severityNeedle,
    excerptNeedle,
    locNameMatch,
  );

  final rows =
      await (db.select(db.weatherAlerts)
            ..where(
              (t) => _weatherAlertWhere(
                t,
                p,
                eventNeedle,
                headlineNeedle,
                severityNeedle,
                excerptNeedle,
                locNameMatch,
              ),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.effectiveAt)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final countCol = countAll();
  final totalRow =
      await (db.selectOnly(db.weatherAlerts)
            ..addColumns([countCol])
            ..where(pred))
          .getSingle();
  final total = totalRow.read(countCol) ?? 0;

  final locIds = rows.map((r) => r.locationId).toSet().toList();
  final names = locIds.isEmpty
      ? <String, String>{}
      : {
          for (final l in await (db.select(
            db.interestsLocations,
          )..where((t) => t.id.isIn(locIds))).get())
            l.id: l.name,
        };

  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'location_id': r.locationId,
          'location_name': names[r.locationId] ?? r.locationId,
          'nws_alert_id': r.nwsAlertId,
          'event': r.event,
          'headline': r.headline,
          'severity': r.severity,
          'effective_at_ms': r.effectiveAt?.millisecondsSinceEpoch,
          'expires_at_ms': r.expiresAt?.millisecondsSinceEpoch,
          'description_excerpt': r.descriptionExcerpt,
          'integration_type': _kCatalogWeatherAlertsIntegrationType,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _operatorAlertWhere(
  $AlertsTable t,
  _CatalogParams p,
  String? titleNeedle,
  String? bodyNeedle,
  String? sourceNeedle,
  String? severityNeedle,
) {
  Expression<bool> e = const Constant(true);
  if (titleNeedle != null) {
    e = e & t.title.like('%$titleNeedle%');
  }
  if (bodyNeedle != null) {
    e = e & t.body.like('%$bodyNeedle%');
  }
  if (sourceNeedle != null) {
    e = e & t.source.like('%$sourceNeedle%');
  }
  if (severityNeedle != null) {
    e = e & t.severity.like('%$severityNeedle%');
  }
  return e;
}

Future<Response> _listOperatorAlerts(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final titleNeedle = _queryNeedle(req, 'title');
  final bodyNeedle = _queryNeedle(req, 'body');
  final sourceNeedle = _queryNeedle(req, 'source');
  final severityNeedle = _queryNeedle(req, 'severity');
  final pred = _operatorAlertWhere(
    db.alerts,
    p,
    titleNeedle,
    bodyNeedle,
    sourceNeedle,
    severityNeedle,
  );
  final rows =
      await (db.select(db.alerts)
            ..where(
              (t) => _operatorAlertWhere(
                t,
                p,
                titleNeedle,
                bodyNeedle,
                sourceNeedle,
                severityNeedle,
              ),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final countCol = countAll();
  final totalRow =
      await (db.selectOnly(db.alerts)
            ..addColumns([countCol])
            ..where(pred))
          .getSingle();
  final total = totalRow.read(countCol) ?? 0;

  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'title': r.title,
          'body': r.body,
          'qr_payload': r.qrPayload,
          'severity': r.severity,
          'priority': r.priority,
          'created_at_ms': r.createdAt.millisecondsSinceEpoch,
          'expires_at_ms': r.expiresAt?.millisecondsSinceEpoch,
          'dismissed_at_ms': r.dismissedAt?.millisecondsSinceEpoch,
          'source': r.source,
          'integration_type': r.source,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

String _calendarCatalogIntegrationType(String source) {
  if (source.startsWith('google_calendar:')) {
    return 'calendar_google';
  }
  if (source.startsWith('outlook_calendar:')) {
    return 'calendar_outlook';
  }
  if (source.startsWith('ical_feed:')) {
    return 'calendar_ical';
  }
  return source;
}

Expression<bool> _calendarEventWhere(
  AppDatabase db,
  $CalendarEventsTable t,
  _CatalogParams p,
  String? titleNeedle,
  String? locationNeedle,
  String? descriptionNeedle,
  String? sourceNeedle,
) {
  Expression<bool> e = const Constant(true);
  if (p.category != null) {
    final category = p.category!;
    final junctionMatch = existsQuery(
      db.select(db.calendarEventCategories)..where(
        (j) => j.eventId.equalsExp(t.id) & j.categoryId.equals(category),
      ),
    );
    e = e & (t.categoryId.equals(category) | junctionMatch);
  }
  if (titleNeedle != null) {
    e = e & t.title.like('%$titleNeedle%');
  }
  if (locationNeedle != null) {
    e = e & (t.location.isNotNull() & t.location.like('%$locationNeedle%'));
  }
  if (descriptionNeedle != null) {
    e =
        e &
        (t.description.isNotNull() &
            t.description.like('%$descriptionNeedle%'));
  }
  if (sourceNeedle != null) {
    e = e & t.source.like('%$sourceNeedle%');
  }
  return e;
}

Future<Response> _listCalendarEvents(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final titleNeedle = _queryNeedle(req, 'title');
  final locationNeedle = _queryNeedle(req, 'location');
  final descriptionNeedle = _queryNeedle(req, 'description');
  final sourceNeedle = _queryNeedle(req, 'source');
  final pred = _calendarEventWhere(
    db,
    db.calendarEvents,
    p,
    titleNeedle,
    locationNeedle,
    descriptionNeedle,
    sourceNeedle,
  );

  final rows =
      await (db.select(db.calendarEvents)
            ..where(
              (t) => _calendarEventWhere(
                db,
                t,
                p,
                titleNeedle,
                locationNeedle,
                descriptionNeedle,
                sourceNeedle,
              ),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.startMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final countCol = countAll();
  final totalRow =
      await (db.selectOnly(db.calendarEvents)
            ..addColumns([countCol])
            ..where(pred))
          .getSingle();
  final total = totalRow.read(countCol) ?? 0;

  final eventIds = rows.map((r) => r.id).toList();
  final categoryIdsByEvent = <String, List<String>>{};
  if (eventIds.isNotEmpty) {
    final junctionRows = await (db.select(
      db.calendarEventCategories,
    )..where((j) => j.eventId.isIn(eventIds))).get();
    for (final j in junctionRows) {
      categoryIdsByEvent.putIfAbsent(j.eventId, () => []).add(j.categoryId);
    }
  }

  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'title': r.title,
          'start_ms': r.startMs.millisecondsSinceEpoch,
          'end_ms': r.endMs.millisecondsSinceEpoch,
          'all_day': r.allDay,
          'location': r.location,
          'description': r.description,
          'source': r.source,
          'integration_type': _calendarCatalogIntegrationType(r.source),
          'category_id': r.categoryId,
          'category_ids':
              categoryIdsByEvent[r.id] ??
              (r.categoryId != null ? [r.categoryId!] : <String>[]),
          'external_id': r.externalId,
          'ical_uid': r.icalUid,
          'updated_at_ms': r.updatedAtMs.millisecondsSinceEpoch,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Future<Response> _listQuoterismQuotes(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final browseOnly = prep.$3;
  final textNeedle = _queryNeedle(req, 'text');
  final authorNeedle = _queryNeedle(req, 'author_name');

  final rows =
      await (db.select(db.quoterismQuotes)
            ..where(
              (t) => _quoterismQuoteWhere(t, p, textNeedle, authorNeedle, db),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.fetchedAtMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final total = await _countQuoterismQuotes(db, p, textNeedle, authorNeedle);

  final quoteIds = rows.map((r) => r.id).toList();
  final categoryIdsByQuote = <String, List<String>>{};
  if (quoteIds.isNotEmpty) {
    final junction = await (db.select(
      db.quoterismQuoteCategories,
    )..where((j) => j.quoteId.isIn(quoteIds))).get();
    for (final j in junction) {
      categoryIdsByQuote.putIfAbsent(j.quoteId, () => []).add(j.categoryId);
    }
  }

  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'text': r.quoteText,
          'author_id': r.authorId,
          'author_name': r.authorName,
          'author_slug': r.authorSlug,
          'author_image_blob_key': r.authorImageBlobKey,
          'quoterism_created_at_ms':
              r.quoterismCreatedAtMs?.millisecondsSinceEpoch,
          'fetched_at_ms': r.fetchedAtMs.millisecondsSinceEpoch,
          'category_ids': categoryIdsByQuote[r.id] ?? const <String>[],
          if (!browseOnly) 'suppressed': r.suppressed,
          'integration_type': _catalogQuoteIntegrationType(r.id),
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

Expression<bool> _quoterismQuoteWhere(
  $QuoterismQuotesTable t,
  _CatalogParams p,
  String? textNeedle,
  String? authorNeedle,
  AppDatabase db,
) {
  Expression<bool> e = const Constant(true);
  if (p.suppressed != null) {
    e = e & t.suppressed.equals(p.suppressed!);
  }
  if (p.category != null) {
    final cat = p.category!;
    e =
        e &
        t.id.isInQuery(
          db.selectOnly(db.quoterismQuoteCategories)
            ..addColumns([db.quoterismQuoteCategories.quoteId])
            ..where(db.quoterismQuoteCategories.categoryId.equals(cat)),
        );
  }
  if (textNeedle != null) {
    e = e & t.quoteText.like('%$textNeedle%');
  }
  if (authorNeedle != null) {
    e = e & t.authorName.like('%$authorNeedle%');
  }
  return e;
}

Future<int> _countQuoterismQuotes(
  AppDatabase db,
  _CatalogParams p,
  String? textNeedle,
  String? authorNeedle,
) async {
  final row =
      await (db.selectOnly(db.quoterismQuotes)
            ..addColumns([db.quoterismQuotes.id.count()])
            ..where(
              _quoterismQuoteWhere(
                db.quoterismQuotes,
                p,
                textNeedle,
                authorNeedle,
                db,
              ),
            ))
          .getSingle();
  return row.read<int>(db.quoterismQuotes.id.count()) ?? 0;
}

Future<Response> _listTasks(AppDatabase db, Request req) async {
  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final p = prep.$2;
  final boardKey = (req.url.queryParameters['board_key'] ?? '').trim();
  final taskListId = (req.url.queryParameters['task_list_id'] ?? '').trim();
  final integrationId = (req.url.queryParameters['integration_id'] ?? '')
      .trim();
  final titleNeedle = _queryNeedle(req, 'title');
  final descriptionNeedle = _queryNeedle(req, 'description');

  Set<String>? listIdsForBoard;
  if (boardKey.isNotEmpty) {
    final listRows = await (db.select(
      db.taskLists,
    )..where((l) => l.boardKey.equals(boardKey))).get();
    listIdsForBoard = listRows.map((r) => r.id).toSet();
    if (listIdsForBoard.isEmpty) {
      return _jsonOk({
        'items': <Map<String, Object?>>[],
        'total': 0,
        'limit': p.limit,
        'offset': p.offset,
      });
    }
  }

  Expression<bool> taskWhere($TasksTable tbl) {
    Expression<bool> e = const Constant(true);
    if (listIdsForBoard != null) {
      e = e & tbl.taskListId.isIn(listIdsForBoard);
    }
    if (taskListId.isNotEmpty) {
      e = e & tbl.taskListId.equals(taskListId);
    }
    if (integrationId.isNotEmpty) {
      e = e & tbl.integrationId.equals(integrationId);
    }
    if (titleNeedle != null) {
      e = e & tbl.title.like('%$titleNeedle%');
    }
    if (descriptionNeedle != null) {
      e =
          e &
          (tbl.description.isNotNull() &
              tbl.description.like('%$descriptionNeedle%'));
    }
    return e;
  }

  final pred = taskWhere(db.tasks);
  final rows =
      await (db.select(db.tasks)
            ..where((t) => taskWhere(t))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAtMs)])
            ..limit(p.limit, offset: p.offset))
          .get();
  final countCol = countAll();
  final totalRow =
      await (db.selectOnly(db.tasks)
            ..addColumns([countCol])
            ..where(pred))
          .getSingle();
  final total = totalRow.read(countCol) ?? 0;

  final listIds = rows.map((r) => r.taskListId).toSet();
  final listsById = <String, TaskList>{};
  if (listIds.isNotEmpty) {
    final listRows = await (db.select(
      db.taskLists,
    )..where((l) => l.id.isIn(listIds))).get();
    for (final list in listRows) {
      listsById[list.id] = list;
    }
  }

  return _jsonOk({
    'items': [
      for (final r in rows)
        {
          'id': r.id,
          'title': r.title,
          'description': r.description,
          'task_list_id': r.taskListId,
          'list_label': listsById[r.taskListId]?.label,
          'board_key': listsById[r.taskListId]?.boardKey,
          'column_order': listsById[r.taskListId]?.columnOrder,
          'due_at_ms': r.dueAtMs?.millisecondsSinceEpoch,
          'completed': r.completed,
          'position': r.position,
          'integration_type': r.integrationType,
          'integration_id': r.integrationId,
          'external_id': r.externalId,
          'updated_at_ms': r.updatedAtMs.millisecondsSinceEpoch,
        },
    ],
    'total': total,
    'limit': p.limit,
    'offset': p.offset,
  });
}

const Set<String> _kCatalogCategoryOptionKinds = {
  'calendar_events',
  'jokes',
  'trivia',
  'photos',
  'videos',
  'quoterism_quotes',
};

/// Scope for category-options: suppressed + integration needles, never [category].
_CatalogParams _categoryOptionsScope(_CatalogParams parsed) => _CatalogParams(
  limit: parsed.limit,
  offset: parsed.offset,
  suppressed: parsed.suppressed,
);

Future<Response> _listCatalogCategoryOptions(
  AppDatabase db,
  Request req,
) async {
  final kind = req.url.queryParameters['kind']?.trim() ?? '';
  if (kind.isEmpty) {
    return Response(
      400,
      body: '{"error":"missing_kind"}',
      headers: {'content-type': 'application/json'},
    );
  }
  if (!_kCatalogCategoryOptionKinds.contains(kind)) {
    return Response(
      400,
      body: '{"error":"invalid_kind"}',
      headers: {'content-type': 'application/json'},
    );
  }

  final parsed = _CatalogParams.parse(req);
  final prep = _prepareCatalogList(req, parsed);
  if (prep.$1 != null) return prep.$1!;
  final scope = _categoryOptionsScope(prep.$2);

  final ids = switch (kind) {
    'jokes' => await _distinctJokeCategoryIds(db, scope),
    'trivia' => await _distinctTriviaCategoryIds(db, req, scope),
    'photos' => await _distinctPhotoCategoryIds(db, req, scope),
    'videos' => await _distinctVideoCategoryIds(db, req, scope),
    'calendar_events' => await _distinctCalendarCategoryIds(db, req, scope),
    'quoterism_quotes' => await _distinctQuoterismCategoryIds(db, req, scope),
    _ => <String>{},
  };

  final items = await _labeledCategoryItems(db, ids);
  return _jsonOk({'items': items});
}

Future<List<Map<String, String>>> _labeledCategoryItems(
  AppDatabase db,
  Set<String> ids,
) async {
  if (ids.isEmpty) return [];
  final sortedIds = ids.toList()..sort();
  final rows = await (db.select(
    db.contentCategories,
  )..where((c) => c.id.isIn(sortedIds))).get();
  final labelById = {for (final r in rows) r.id: r.label};
  final items = [
    for (final id in sortedIds) {'id': id, 'label': labelById[id] ?? id},
  ];
  items.sort(
    (a, b) => a['label']!.toLowerCase().compareTo(b['label']!.toLowerCase()),
  );
  return items;
}

Future<Set<String>> _distinctJokeCategoryIds(
  AppDatabase db,
  _CatalogParams scope,
) async {
  final col = db.jokes.categoryId;
  final rows =
      await (db.selectOnly(db.jokes)
            ..addColumns([col])
            ..where(_jokeWhere(db.jokes, scope, null, null))
            ..groupBy([col]))
          .get();
  return _nonEmptyCategoryIds(rows, col);
}

Future<Set<String>> _distinctTriviaCategoryIds(
  AppDatabase db,
  Request req,
  _CatalogParams scope,
) async {
  final integrationTypeNeedle = _queryNeedle(req, 'integration_type');
  final col = db.triviaQuestions.categoryId;
  final rows =
      await (db.selectOnly(db.triviaQuestions)
            ..addColumns([col])
            ..where(
              _triviaWhere(
                db.triviaQuestions,
                scope,
                null,
                null,
                null,
                null,
                null,
                integrationTypeNeedle,
              ),
            )
            ..groupBy([col]))
          .get();
  return _nonEmptyCategoryIds(rows, col);
}

Future<Set<String>> _distinctPhotoCategoryIds(
  AppDatabase db,
  Request req,
  _CatalogParams scope,
) async {
  final dataProviderNeedle = _queryNeedle(req, 'data_provider');
  final col = db.photos.category;
  final rows =
      await (db.selectOnly(db.photos)
            ..addColumns([col])
            ..where(
              _photoWhere(db.photos, scope, null, null, dataProviderNeedle),
            )
            ..groupBy([col]))
          .get();
  return _nonEmptyCategoryIds(rows, col);
}

Future<Set<String>> _distinctVideoCategoryIds(
  AppDatabase db,
  Request req,
  _CatalogParams scope,
) async {
  final dataProviderNeedle = _queryNeedle(req, 'data_provider');
  final col = db.videos.category;
  final rows =
      await (db.selectOnly(db.videos)
            ..addColumns([col])
            ..where(
              _videoWhere(db.videos, scope, null, null, dataProviderNeedle),
            )
            ..groupBy([col]))
          .get();
  return _nonEmptyCategoryIds(rows, col);
}

Future<Set<String>> _distinctQuoterismCategoryIds(
  AppDatabase db,
  Request req,
  _CatalogParams scope,
) async {
  final textNeedle = _queryNeedle(req, 'text');
  final authorNeedle = _queryNeedle(req, 'author_name');
  final quoteIds =
      await (db.selectOnly(db.quoterismQuotes)
            ..addColumns([db.quoterismQuotes.id])
            ..where(
              _quoterismQuoteWhere(
                db.quoterismQuotes,
                scope,
                textNeedle,
                authorNeedle,
                db,
              ),
            ))
          .map((r) => r.read(db.quoterismQuotes.id)!)
          .get();
  if (quoteIds.isEmpty) return {};
  final col = db.quoterismQuoteCategories.categoryId;
  final rows =
      await (db.selectOnly(db.quoterismQuoteCategories)
            ..addColumns([col])
            ..where(db.quoterismQuoteCategories.quoteId.isIn(quoteIds))
            ..groupBy([col]))
          .get();
  return _nonEmptyCategoryIds(rows, col);
}

Future<Set<String>> _distinctCalendarCategoryIds(
  AppDatabase db,
  Request req,
  _CatalogParams scope,
) async {
  final titleNeedle = _queryNeedle(req, 'title');
  final locationNeedle = _queryNeedle(req, 'location');
  final descriptionNeedle = _queryNeedle(req, 'description');
  final sourceNeedle = _queryNeedle(req, 'source');
  final eventPred = _calendarEventWhere(
    db,
    db.calendarEvents,
    scope,
    titleNeedle,
    locationNeedle,
    descriptionNeedle,
    sourceNeedle,
  );

  final primaryCol = db.calendarEvents.categoryId;
  final primaryRows =
      await (db.selectOnly(db.calendarEvents)
            ..addColumns([primaryCol])
            ..where(eventPred & primaryCol.isNotNull())
            ..groupBy([primaryCol]))
          .get();
  final ids = _nonEmptyCategoryIds(primaryRows, primaryCol);

  final junctionCol = db.calendarEventCategories.categoryId;
  final junctionRows =
      await (db.selectOnly(db.calendarEventCategories)
            ..addColumns([junctionCol])
            ..where(
              db.calendarEventCategories.eventId.isInQuery(
                db.selectOnly(db.calendarEvents)
                  ..addColumns([db.calendarEvents.id])
                  ..where(eventPred),
              ),
            )
            ..groupBy([junctionCol]))
          .get();
  ids.addAll(_nonEmptyCategoryIds(junctionRows, junctionCol));
  return ids;
}

Set<String> _nonEmptyCategoryIds(
  List<TypedResult> rows,
  GeneratedColumn<String> col,
) {
  return {
    for (final r in rows)
      if ((r.read(col) ?? '').trim().isNotEmpty) r.read(col)!,
  };
}
