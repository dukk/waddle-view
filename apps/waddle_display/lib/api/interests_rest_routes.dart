import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/persistence/database.dart';

bool _isValidInterestCategoryId(String id) {
  return RegExp(r'^[a-z][a-z0-9_]{0,62}$').hasMatch(id);
}

Future<Map<String, dynamic>?> _readJsonObject(Request req) async {
  try {
    final decoded = jsonDecode(await req.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  } catch (_) {
    return null;
  }
}

Response _jsonOk(Object body) => Response.ok(
      jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );

Response _jsonErr(int status, String error) => Response(
      status,
      body: '{"error":"$error"}',
      headers: {'content-type': 'application/json'},
    );

bool? _parseBool(dynamic raw) {
  if (raw == null) return null;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final s = '$raw'.trim().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}

int? _parseInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw'.trim());
}

double? _parseDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

Future<bool> _curatorCategoryExists(AppDatabase db, String id) async {
  final row = await (db.select(db.contentCategories)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  return row != null;
}

void registerInterestsRestRoutes(
  Router r, {
  required AppDatabase db,
  required Future<void> Function() onConfigChanged,
}) {
  r.get('/v1/interests/weather-locations', (Request req) async {
    final rows = await (db.select(db.interestsLocations)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return _jsonOk({
      'items': [
        for (final row in rows)
          {
            'id': row.id,
            'name': row.name,
            'latitude': row.latitude,
            'longitude': row.longitude,
            'enabled': row.enabled,
            'include_active_weather_alerts': row.includeActiveWeatherAlerts,
          },
      ],
    });
  });

  r.post('/v1/interests/weather-locations', (Request req) async {
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final id = '${body['id'] ?? ''}'.trim();
    final name = '${body['name'] ?? ''}'.trim();
    final lat = _parseDouble(body['latitude']);
    final lon = _parseDouble(body['longitude']);
    if (id.isEmpty || name.isEmpty || lat == null || lon == null) {
      return _jsonErr(400, 'id_name_latitude_longitude_required');
    }
    final existing = await (db.select(db.interestsLocations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing != null) return _jsonErr(409, 'id_exists');
    final enabled = _parseBool(body['enabled']) ?? true;
    final alerts = _parseBool(body['include_active_weather_alerts']) ?? true;
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: id,
            name: name,
            latitude: lat,
            longitude: lon,
            enabled: Value(enabled),
            includeActiveWeatherAlerts: Value(alerts),
          ),
        );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.patch('/v1/interests/weather-locations/<id>', (Request req, String id) async {
    final existing = await (db.select(db.interestsLocations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return _jsonErr(404, 'not_found');
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final name = body.containsKey('name')
        ? '${body['name']}'.trim()
        : existing.name;
    if (name.isEmpty) return _jsonErr(400, 'invalid_name');
    final lat = body.containsKey('latitude')
        ? _parseDouble(body['latitude'])
        : existing.latitude;
    final lon = body.containsKey('longitude')
        ? _parseDouble(body['longitude'])
        : existing.longitude;
    if (lat == null || lon == null) return _jsonErr(400, 'invalid_coordinates');
    final enabled = body.containsKey('enabled')
        ? (_parseBool(body['enabled']) ?? existing.enabled)
        : existing.enabled;
    final alerts = body.containsKey('include_active_weather_alerts')
        ? (_parseBool(body['include_active_weather_alerts']) ??
            existing.includeActiveWeatherAlerts)
        : existing.includeActiveWeatherAlerts;
    await (db.update(db.interestsLocations)..where((t) => t.id.equals(id))).write(
      InterestsLocationsCompanion(
        name: Value(name),
        latitude: Value(lat),
        longitude: Value(lon),
        enabled: Value(enabled),
        includeActiveWeatherAlerts: Value(alerts),
      ),
    );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.delete('/v1/interests/weather-locations/<id>', (Request req, String id) async {
    final cur = await (db.select(db.weatherCurrent)
          ..where((t) => t.locationId.equals(id)))
        .get();
    if (cur.isNotEmpty) return _jsonErr(409, 'location_in_use_weather_current');
    final alerts = await (db.select(db.weatherAlerts)
          ..where((t) => t.locationId.equals(id)))
        .get();
    if (alerts.isNotEmpty) return _jsonErr(409, 'location_in_use_weather_alerts');
    final n =
        await (db.delete(db.interestsLocations)..where((t) => t.id.equals(id))).go();
    if (n == 0) return _jsonErr(404, 'not_found');
    await onConfigChanged();
    return _jsonOk({});
  });

  r.get('/v1/interests/rss-feeds', (Request req) async {
    final rows = await (db.select(db.interestsRssFeeds)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return _jsonOk({
      'items': [
        for (final row in rows)
          {
            'id': row.id,
            'url': row.url,
            'title': row.title,
            'category': row.category,
            'poll_seconds': row.pollSeconds,
            'max_articles': row.maxArticles,
            'enabled': row.enabled,
            'last_fetched_at': row.lastFetchedAt?.millisecondsSinceEpoch,
            'consecutive_failures': row.consecutiveFailures,
            'next_retry_at': row.nextRetryAt?.millisecondsSinceEpoch,
          },
      ],
    });
  });

  r.post('/v1/interests/rss-feeds', (Request req) async {
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final id = '${body['id'] ?? ''}'.trim();
    final url = '${body['url'] ?? ''}'.trim();
    if (id.isEmpty || url.isEmpty) return _jsonErr(400, 'id_and_url_required');
    final existing = await (db.select(db.interestsRssFeeds)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing != null) return _jsonErr(409, 'id_exists');
    final category = '${body['category'] ?? 'general'}'.trim();
    final poll = _parseInt(body['poll_seconds']) ?? 3600;
    final maxArticles = _parseInt(body['max_articles']) ?? 3;
    final enabled = _parseBool(body['enabled']) ?? true;
    final titleRaw = body['title'];
    final title = titleRaw == null ? null : '$titleRaw'.trim();
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: id,
            url: url,
            category: Value(category.isEmpty ? 'general' : category),
            pollSeconds: Value(poll.clamp(60, 86400 * 7)),
            maxArticles: Value(maxArticles.clamp(1, 50)),
            enabled: Value(enabled),
            title: title == null || title.isEmpty
                ? const Value.absent()
                : Value(title),
          ),
        );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.patch('/v1/interests/rss-feeds/<id>', (Request req, String id) async {
    final existing = await (db.select(db.interestsRssFeeds)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return _jsonErr(404, 'not_found');
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final url = body.containsKey('url') ? '${body['url']}'.trim() : existing.url;
    if (url.isEmpty) return _jsonErr(400, 'invalid_url');
    final category = body.containsKey('category')
        ? '${body['category']}'.trim()
        : existing.category;
    final poll = body.containsKey('poll_seconds')
        ? (_parseInt(body['poll_seconds']) ?? existing.pollSeconds)
        : existing.pollSeconds;
    final maxArticles = body.containsKey('max_articles')
        ? (_parseInt(body['max_articles']) ?? existing.maxArticles)
        : existing.maxArticles;
    final enabled = body.containsKey('enabled')
        ? (_parseBool(body['enabled']) ?? existing.enabled)
        : existing.enabled;
    String? title;
    if (body.containsKey('title')) {
      final raw = body['title'];
      title = raw == null ? null : '$raw'.trim();
      if (title != null && title.isEmpty) title = null;
    } else {
      title = existing.title;
    }
    DateTime? lastFetched = existing.lastFetchedAt;
    if (body.containsKey('last_fetched_at')) {
      final ms = _parseInt(body['last_fetched_at']);
      lastFetched = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    }
    var failures = existing.consecutiveFailures;
    if (body.containsKey('consecutive_failures')) {
      failures = _parseInt(body['consecutive_failures']) ?? failures;
    }
    DateTime? nextRetry = existing.nextRetryAt;
    if (body.containsKey('next_retry_at')) {
      final ms = _parseInt(body['next_retry_at']);
      nextRetry = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    }
    await (db.update(db.interestsRssFeeds)..where((t) => t.id.equals(id))).write(
      InterestsRssFeedsCompanion(
        url: Value(url),
        category: Value(category.isEmpty ? 'general' : category),
        pollSeconds: Value(poll.clamp(60, 86400 * 7)),
        maxArticles: Value(maxArticles.clamp(1, 50)),
        enabled: Value(enabled),
        title: Value(title),
        lastFetchedAt: Value(lastFetched),
        consecutiveFailures: Value(failures),
        nextRetryAt: Value(nextRetry),
      ),
    );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.delete('/v1/interests/rss-feeds/<id>', (Request req, String id) async {
    final articles = await (db.select(db.rssArticles)
          ..where((t) => t.feedId.equals(id)))
        .get();
    if (articles.isNotEmpty) return _jsonErr(409, 'feed_in_use_articles');
    final n =
        await (db.delete(db.interestsRssFeeds)..where((t) => t.id.equals(id))).go();
    if (n == 0) return _jsonErr(404, 'not_found');
    await onConfigChanged();
    return _jsonOk({});
  });

  r.get('/v1/interests/stock-symbols', (Request req) async {
    final rows = await (db.select(db.interestsStockSymbols)
          ..orderBy([(t) => OrderingTerm.asc(t.symbol)]))
        .get();
    return _jsonOk({
      'items': [
        for (final row in rows)
          {
            'id': row.id,
            'symbol': row.symbol,
            'display_name': row.displayName,
            'enabled': row.enabled,
          },
      ],
    });
  });

  r.post('/v1/interests/stock-symbols', (Request req) async {
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final id = '${body['id'] ?? ''}'.trim();
    final symbol = '${body['symbol'] ?? ''}'.trim().toUpperCase();
    if (id.isEmpty || symbol.isEmpty) return _jsonErr(400, 'id_and_symbol_required');
    final existing = await (db.select(db.interestsStockSymbols)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing != null) return _jsonErr(409, 'id_exists');
    final displayName = '${body['display_name'] ?? ''}'.trim();
    final enabled = _parseBool(body['enabled']) ?? true;
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: id,
            symbol: symbol,
            displayName: Value(displayName),
            enabled: Value(enabled),
          ),
        );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.patch('/v1/interests/stock-symbols/<id>', (Request req, String id) async {
    final existing = await (db.select(db.interestsStockSymbols)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return _jsonErr(404, 'not_found');
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final symbol = body.containsKey('symbol')
        ? '${body['symbol']}'.trim().toUpperCase()
        : existing.symbol;
    if (symbol.isEmpty) return _jsonErr(400, 'invalid_symbol');
    final displayName = body.containsKey('display_name')
        ? '${body['display_name']}'.trim()
        : existing.displayName;
    final enabled = body.containsKey('enabled')
        ? (_parseBool(body['enabled']) ?? existing.enabled)
        : existing.enabled;
    await (db.update(db.interestsStockSymbols)..where((t) => t.id.equals(id))).write(
      InterestsStockSymbolsCompanion(
        symbol: Value(symbol),
        displayName: Value(displayName),
        enabled: Value(enabled),
      ),
    );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.delete('/v1/interests/stock-symbols/<id>', (Request req, String id) async {
    final quotes = await (db.select(db.stockQuotes)
          ..where((t) => t.symbolId.equals(id)))
        .get();
    if (quotes.isNotEmpty) return _jsonErr(409, 'symbol_in_use_quotes');
    final n =
        await (db.delete(db.interestsStockSymbols)..where((t) => t.id.equals(id)))
            .go();
    if (n == 0) return _jsonErr(404, 'not_found');
    await onConfigChanged();
    return _jsonOk({});
  });

  r.get('/v1/interests/home-assistant-entities', (Request req) async {
    final rows = await (db.select(db.interestsHomeAssistantEntities)
          ..orderBy([(t) => OrderingTerm.asc(t.entityId)]))
        .get();
    return _jsonOk({
      'items': [
        for (final row in rows)
          {
            'id': row.id,
            'entity_id': row.entityId,
            'display_name': row.displayName,
            'enabled': row.enabled,
          },
      ],
    });
  });

  r.post('/v1/interests/home-assistant-entities', (Request req) async {
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final id = '${body['id'] ?? ''}'.trim();
    final entityId = '${body['entity_id'] ?? ''}'.trim();
    if (id.isEmpty || entityId.isEmpty) {
      return _jsonErr(400, 'id_and_entity_id_required');
    }
    final existingId = await (db.select(db.interestsHomeAssistantEntities)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existingId != null) return _jsonErr(409, 'id_exists');
    final existingEntity = await (db.select(db.interestsHomeAssistantEntities)
          ..where((t) => t.entityId.equals(entityId)))
        .getSingleOrNull();
    if (existingEntity != null) return _jsonErr(409, 'entity_id_exists');
    final displayName = '${body['display_name'] ?? ''}'.trim();
    final enabled = _parseBool(body['enabled']) ?? true;
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: id,
            entityId: entityId,
            displayName: Value(displayName),
            enabled: Value(enabled),
          ),
        );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.patch('/v1/interests/home-assistant-entities/<id>', (
    Request req,
    String id,
  ) async {
    final existing = await (db.select(db.interestsHomeAssistantEntities)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return _jsonErr(404, 'not_found');
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final entityId = body.containsKey('entity_id')
        ? '${body['entity_id']}'.trim()
        : existing.entityId;
    if (entityId.isEmpty) return _jsonErr(400, 'invalid_entity_id');
    if (entityId != existing.entityId) {
      final clash = await (db.select(db.interestsHomeAssistantEntities)
            ..where((t) => t.entityId.equals(entityId)))
          .getSingleOrNull();
      if (clash != null) return _jsonErr(409, 'entity_id_exists');
    }
    final displayName = body.containsKey('display_name')
        ? '${body['display_name']}'.trim()
        : existing.displayName;
    final enabled = body.containsKey('enabled')
        ? (_parseBool(body['enabled']) ?? existing.enabled)
        : existing.enabled;
    await (db.update(db.interestsHomeAssistantEntities)
          ..where((t) => t.id.equals(id)))
        .write(
      InterestsHomeAssistantEntitiesCompanion(
        entityId: Value(entityId),
        displayName: Value(displayName),
        enabled: Value(enabled),
      ),
    );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.delete('/v1/interests/home-assistant-entities/<id>', (
    Request req,
    String id,
  ) async {
    final row = await (db.select(db.interestsHomeAssistantEntities)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return _jsonErr(404, 'not_found');
    await (db.delete(db.homeAssistantEntityStates)
          ..where((t) => t.entityId.equals(row.entityId)))
        .go();
    final n = await (db.delete(db.interestsHomeAssistantEntities)
          ..where((t) => t.id.equals(id)))
        .go();
    if (n == 0) return _jsonErr(404, 'not_found');
    await onConfigChanged();
    return _jsonOk({});
  });

  r.get('/v1/interests/joke-categories', (Request req) async {
    final rows = await (db.select(db.interestsJokes)
          ..orderBy([(t) => OrderingTerm.asc(t.label)]))
        .get();
    return _jsonOk({
      'items': [for (final row in rows) _jokeCategoryJson(row)],
    });
  });

  r.post('/v1/interests/joke-categories', (Request req) async {
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final id = '${body['id'] ?? ''}'.trim();
    final label = '${body['label'] ?? ''}'.trim();
    if (id.isEmpty || label.isEmpty) return _jsonErr(400, 'id_and_label_required');
    if (!_isValidInterestCategoryId(id)) {
      return _jsonErr(400, 'invalid_category_id');
    }
    if (!await _curatorCategoryExists(db, id)) {
      return _jsonErr(400, 'curator_category_not_found');
    }
    final existing =
        await (db.select(db.interestsJokes)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (existing != null) return _jsonErr(409, 'id_exists');
    await db.into(db.interestsJokes).insert(_jokeCategoryCompanionFromBody(id, label, body));
    await onConfigChanged();
    return _jsonOk({});
  });

  r.patch('/v1/interests/joke-categories/<id>', (Request req, String id) async {
    final existing =
        await (db.select(db.interestsJokes)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (existing == null) return _jsonErr(404, 'not_found');
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final label = body.containsKey('label')
        ? '${body['label']}'.trim()
        : existing.label;
    if (label.isEmpty) return _jsonErr(400, 'invalid_label');
    await (db.update(db.interestsJokes)..where((t) => t.id.equals(id))).write(
      _jokeCategoryCompanionPatch(existing, label, body),
    );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.delete('/v1/interests/joke-categories/<id>', (Request req, String id) async {
    final jokes = await (db.select(db.jokes)..where((t) => t.categoryId.equals(id)))
        .get();
    if (jokes.isNotEmpty) return _jsonErr(409, 'category_in_use_jokes');
    final n = await (db.delete(db.interestsJokes)..where((t) => t.id.equals(id))).go();
    if (n == 0) return _jsonErr(404, 'not_found');
    await onConfigChanged();
    return _jsonOk({});
  });

  r.get('/v1/interests/trivia-categories', (Request req) async {
    final rows = await (db.select(db.interestsTrivia)
          ..orderBy([(t) => OrderingTerm.asc(t.label)]))
        .get();
    return _jsonOk({
      'items': [for (final row in rows) _triviaCategoryJson(row)],
    });
  });

  r.post('/v1/interests/trivia-categories', (Request req) async {
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final id = '${body['id'] ?? ''}'.trim();
    final label = '${body['label'] ?? ''}'.trim();
    if (id.isEmpty || label.isEmpty) return _jsonErr(400, 'id_and_label_required');
    if (!_isValidInterestCategoryId(id)) {
      return _jsonErr(400, 'invalid_category_id');
    }
    if (!await _curatorCategoryExists(db, id)) {
      return _jsonErr(400, 'curator_category_not_found');
    }
    final existing =
        await (db.select(db.interestsTrivia)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (existing != null) return _jsonErr(409, 'id_exists');
    await db.into(db.interestsTrivia).insert(_triviaCategoryCompanionFromBody(id, label, body));
    await onConfigChanged();
    return _jsonOk({});
  });

  r.patch('/v1/interests/trivia-categories/<id>', (Request req, String id) async {
    final existing =
        await (db.select(db.interestsTrivia)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (existing == null) return _jsonErr(404, 'not_found');
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final label = body.containsKey('label')
        ? '${body['label']}'.trim()
        : existing.label;
    if (label.isEmpty) return _jsonErr(400, 'invalid_label');
    await (db.update(db.interestsTrivia)..where((t) => t.id.equals(id))).write(
      _triviaCategoryCompanionPatch(existing, label, body),
    );
    await onConfigChanged();
    return _jsonOk({});
  });

  r.delete('/v1/interests/trivia-categories/<id>', (Request req, String id) async {
    final questions =
        await (db.select(db.triviaQuestions)..where((t) => t.categoryId.equals(id)))
            .get();
    if (questions.isNotEmpty) return _jsonErr(409, 'category_in_use_trivia');
    final n =
        await (db.delete(db.interestsTrivia)..where((t) => t.id.equals(id))).go();
    if (n == 0) return _jsonErr(404, 'not_found');
    await onConfigChanged();
    return _jsonOk({});
  });
}

Map<String, dynamic> _jokeCategoryJson(InterestsJoke row) => {
      'id': row.id,
      'label': row.label,
      'is_seasonal': row.isSeasonal,
      'start_month': row.startMonth,
      'start_day': row.startDay,
      'end_month': row.endMonth,
      'end_day': row.endDay,
      'category_prompt': row.categoryPrompt,
      'min_jokes': row.minJokes,
      'max_jokes': row.maxJokes,
    };

InterestsJokesCompanion _jokeCategoryCompanionFromBody(
  String id,
  String label,
  Map<String, dynamic> body,
) {
  final seasonal = _parseBool(body['is_seasonal']) ?? false;
  return InterestsJokesCompanion.insert(
    id: id,
    label: label,
    isSeasonal: Value(seasonal),
    startMonth: _optionalIntValue(body['start_month']),
    startDay: _optionalIntValue(body['start_day']),
    endMonth: _optionalIntValue(body['end_month']),
    endDay: _optionalIntValue(body['end_day']),
    categoryPrompt: _optionalStringValue(body['category_prompt']),
    minJokes: Value(_parseInt(body['min_jokes'])?.clamp(1, 1000) ?? 10),
    maxJokes: Value(_parseInt(body['max_jokes'])?.clamp(1, 1000) ?? 100),
  );
}

InterestsJokesCompanion _jokeCategoryCompanionPatch(
  InterestsJoke existing,
  String label,
  Map<String, dynamic> body,
) {
  return InterestsJokesCompanion(
    label: Value(label),
    isSeasonal: body.containsKey('is_seasonal')
        ? Value(_parseBool(body['is_seasonal']) ?? existing.isSeasonal)
        : const Value.absent(),
    startMonth: body.containsKey('start_month')
        ? _optionalIntValue(body['start_month'])
        : const Value.absent(),
    startDay: body.containsKey('start_day')
        ? _optionalIntValue(body['start_day'])
        : const Value.absent(),
    endMonth: body.containsKey('end_month')
        ? _optionalIntValue(body['end_month'])
        : const Value.absent(),
    endDay: body.containsKey('end_day')
        ? _optionalIntValue(body['end_day'])
        : const Value.absent(),
    categoryPrompt: body.containsKey('category_prompt')
        ? _optionalStringValue(body['category_prompt'])
        : const Value.absent(),
    minJokes: body.containsKey('min_jokes')
        ? Value(_parseInt(body['min_jokes'])?.clamp(1, 1000) ?? existing.minJokes)
        : const Value.absent(),
    maxJokes: body.containsKey('max_jokes')
        ? Value(_parseInt(body['max_jokes'])?.clamp(1, 1000) ?? existing.maxJokes)
        : const Value.absent(),
  );
}

Map<String, dynamic> _triviaCategoryJson(InterestsTriviaData row) => {
      'id': row.id,
      'label': row.label,
      'is_seasonal': row.isSeasonal,
      'start_month': row.startMonth,
      'start_day': row.startDay,
      'end_month': row.endMonth,
      'end_day': row.endDay,
      'category_prompt': row.categoryPrompt,
      'min_questions': row.minQuestions,
      'max_questions': row.maxQuestions,
    };

InterestsTriviaCompanion _triviaCategoryCompanionFromBody(
  String id,
  String label,
  Map<String, dynamic> body,
) {
  final seasonal = _parseBool(body['is_seasonal']) ?? false;
  return InterestsTriviaCompanion.insert(
    id: id,
    label: label,
    isSeasonal: Value(seasonal),
    startMonth: _optionalIntValue(body['start_month']),
    startDay: _optionalIntValue(body['start_day']),
    endMonth: _optionalIntValue(body['end_month']),
    endDay: _optionalIntValue(body['end_day']),
    categoryPrompt: _optionalStringValue(body['category_prompt']),
    minQuestions: Value(_parseInt(body['min_questions'])?.clamp(1, 1000) ?? 10),
    maxQuestions: Value(_parseInt(body['max_questions'])?.clamp(1, 1000) ?? 100),
  );
}

InterestsTriviaCompanion _triviaCategoryCompanionPatch(
  InterestsTriviaData existing,
  String label,
  Map<String, dynamic> body,
) {
  return InterestsTriviaCompanion(
    label: Value(label),
    isSeasonal: body.containsKey('is_seasonal')
        ? Value(_parseBool(body['is_seasonal']) ?? existing.isSeasonal)
        : const Value.absent(),
    startMonth: body.containsKey('start_month')
        ? _optionalIntValue(body['start_month'])
        : const Value.absent(),
    startDay: body.containsKey('start_day')
        ? _optionalIntValue(body['start_day'])
        : const Value.absent(),
    endMonth: body.containsKey('end_month')
        ? _optionalIntValue(body['end_month'])
        : const Value.absent(),
    endDay: body.containsKey('end_day')
        ? _optionalIntValue(body['end_day'])
        : const Value.absent(),
    categoryPrompt: body.containsKey('category_prompt')
        ? _optionalStringValue(body['category_prompt'])
        : const Value.absent(),
    minQuestions: body.containsKey('min_questions')
        ? Value(
            _parseInt(body['min_questions'])?.clamp(1, 1000) ??
                existing.minQuestions,
          )
        : const Value.absent(),
    maxQuestions: body.containsKey('max_questions')
        ? Value(
            _parseInt(body['max_questions'])?.clamp(1, 1000) ??
                existing.maxQuestions,
          )
        : const Value.absent(),
  );
}

Value<int?> _optionalIntValue(dynamic raw) {
  if (raw == null) return const Value(null);
  return Value(_parseInt(raw));
}

Value<String?> _optionalStringValue(dynamic raw) {
  if (raw == null) return const Value(null);
  final s = '$raw'.trim();
  return Value(s.isEmpty ? null : s);
}
