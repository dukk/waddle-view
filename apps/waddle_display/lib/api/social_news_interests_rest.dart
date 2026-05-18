import 'dart:convert';

import 'package:drift/drift.dart' show Expression, OrderingTerm, Value;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

/// Registers CRUD routes for Twitter or LinkedIn news sources (same shape as Facebook).
void registerSocialNewsInterestsRoutes(
  Router r, {
  required AppDatabase db,
  required Future<void> Function() onConfigChanged,
  required SocialNewsInterestsPlatform platform,
}) {
  final base = '/v1/interests/${platform.pathSegment}';

  r.get(base, (Request req) async {
    final rows = await platform.listRows(db);
    return _jsonOk({
      'items': [for (final row in rows) platform.toJson(row)],
    });
  });

  r.post(base, (Request req) async {
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final err = await platform.validateCreate(body, db);
    if (err != null) return _jsonErr(400, err);
    final id = '${body['id'] ?? ''}'.trim();
    final existing = await platform.findById(db, id);
    if (existing != null) return _jsonErr(409, 'id_exists');
    await platform.insert(db, body);
    await onConfigChanged();
    return _jsonOk({});
  });

  r.patch('$base/<id>', (Request req, String id) async {
    final existing = await platform.findById(db, id);
    if (existing == null) return _jsonErr(404, 'not_found');
    final body = await _readJsonObject(req);
    if (body == null) return _jsonErr(400, 'expected_json_object');
    final err = await platform.validatePatch(body, existing, db);
    if (err != null) return _jsonErr(400, err);
    await platform.update(db, id, body, existing);
    await onConfigChanged();
    return _jsonOk({});
  });

  r.delete('$base/<id>', (Request req, String id) async {
    final articles = await (db.select(db.news)
          ..where(
            (t) => Expression.and([
              t.sourceType.equals(platform.newsSourceType),
              t.sourceId.equals(id),
            ]),
          ))
        .get();
    if (articles.isNotEmpty) return _jsonErr(409, 'source_in_use_articles');
    final n = await platform.deleteById(db, id);
    if (n == 0) return _jsonErr(404, 'not_found');
    await onConfigChanged();
    return _jsonOk({});
  });
}

abstract class SocialNewsInterestsPlatform {
  String get pathSegment;
  String get newsSourceType;
  Set<String> get validTargetTypes;

  Future<List<dynamic>> listRows(AppDatabase db);
  Future<dynamic> findById(AppDatabase db, String id);
  Map<String, dynamic> toJson(dynamic row);
  Future<String?> validateCreate(Map<String, dynamic> body, AppDatabase db);
  Future<String?> validatePatch(
    Map<String, dynamic> body,
    dynamic existing,
    AppDatabase db,
  );
  Future<void> insert(AppDatabase db, Map<String, dynamic> body);
  Future<void> update(
    AppDatabase db,
    String id,
    Map<String, dynamic> body,
    dynamic existing,
  );
  Future<int> deleteById(AppDatabase db, String id);
}

final SocialNewsInterestsPlatform kTwitterInterestsPlatform =
    _TwitterInterestsPlatform();

final SocialNewsInterestsPlatform kLinkedinInterestsPlatform =
    _LinkedinInterestsPlatform();

class _TwitterInterestsPlatform extends SocialNewsInterestsPlatform {
  @override
  String get pathSegment => 'twitter-sources';

  @override
  String get newsSourceType => kNewsSourceTypeTwitter;

  @override
  Set<String> get validTargetTypes => const {'user'};

  @override
  Future<List<dynamic>> listRows(AppDatabase db) => (db.select(db.interestsTwitterSources)
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();

  @override
  Future<InterestsTwitterSource?> findById(AppDatabase db, String id) =>
      (db.select(db.interestsTwitterSources)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  @override
  Map<String, dynamic> toJson(dynamic row) {
    final r = row as InterestsTwitterSource;
    return _socialSourceJson(r);
  }

  @override
  Future<String?> validateCreate(Map<String, dynamic> body, AppDatabase db) =>
      _validateSocialCreate(body, db, validTargetTypes);

  @override
  Future<String?> validatePatch(
    Map<String, dynamic> body,
    dynamic existing,
    AppDatabase db,
  ) =>
      _validateSocialPatch(body, existing as InterestsTwitterSource, db, validTargetTypes);

  @override
  Future<void> insert(AppDatabase db, Map<String, dynamic> body) async {
    final fields = _parseSocialFields(body, validTargetTypes);
    await db.into(db.interestsTwitterSources).insert(
          InterestsTwitterSourcesCompanion.insert(
            id: fields.id,
            targetType: fields.targetType,
            targetId: fields.targetId,
            accountId: fields.accountId,
            pollSeconds: Value(fields.pollSeconds),
            maxArticles: Value(fields.maxArticles),
            enabled: Value(fields.enabled),
            title: fields.title == null
                ? const Value.absent()
                : Value(fields.title),
          ),
        );
  }

  @override
  Future<void> update(
    AppDatabase db,
    String id,
    Map<String, dynamic> body,
    dynamic existing,
  ) async {
    final e = existing as InterestsTwitterSource;
    final c = _mergeSocialFields(body, e, validTargetTypes);
    await (db.update(db.interestsTwitterSources)..where((t) => t.id.equals(id)))
        .write(_twitterCompanion(c));
  }

  @override
  Future<int> deleteById(AppDatabase db, String id) =>
      (db.delete(db.interestsTwitterSources)..where((t) => t.id.equals(id))).go();
}

class _LinkedinInterestsPlatform extends SocialNewsInterestsPlatform {
  @override
  String get pathSegment => 'linkedin-sources';

  @override
  String get newsSourceType => kNewsSourceTypeLinkedin;

  @override
  Set<String> get validTargetTypes => const {'organization', 'member'};

  @override
  Future<List<dynamic>> listRows(AppDatabase db) => (db.select(db.interestsLinkedinSources)
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();

  @override
  Future<InterestsLinkedinSource?> findById(AppDatabase db, String id) =>
      (db.select(db.interestsLinkedinSources)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  @override
  Map<String, dynamic> toJson(dynamic row) {
    final r = row as InterestsLinkedinSource;
    return _socialSourceJson(r);
  }

  @override
  Future<String?> validateCreate(Map<String, dynamic> body, AppDatabase db) =>
      _validateSocialCreate(body, db, validTargetTypes);

  @override
  Future<String?> validatePatch(
    Map<String, dynamic> body,
    dynamic existing,
    AppDatabase db,
  ) =>
      _validateSocialPatch(
        body,
        existing as InterestsLinkedinSource,
        db,
        validTargetTypes,
      );

  @override
  Future<void> insert(AppDatabase db, Map<String, dynamic> body) async {
    final fields = _parseSocialFields(body, validTargetTypes);
    await db.into(db.interestsLinkedinSources).insert(
          InterestsLinkedinSourcesCompanion.insert(
            id: fields.id,
            targetType: fields.targetType,
            targetId: fields.targetId,
            accountId: fields.accountId,
            pollSeconds: Value(fields.pollSeconds),
            maxArticles: Value(fields.maxArticles),
            enabled: Value(fields.enabled),
            title: fields.title == null
                ? const Value.absent()
                : Value(fields.title),
          ),
        );
  }

  @override
  Future<void> update(
    AppDatabase db,
    String id,
    Map<String, dynamic> body,
    dynamic existing,
  ) async {
    final e = existing as InterestsLinkedinSource;
    final c = _mergeSocialFields(body, e, validTargetTypes);
    await (db.update(db.interestsLinkedinSources)..where((t) => t.id.equals(id)))
        .write(_linkedinCompanion(c));
  }

  @override
  Future<int> deleteById(AppDatabase db, String id) =>
      (db.delete(db.interestsLinkedinSources)..where((t) => t.id.equals(id))).go();
}

Map<String, dynamic> _socialSourceJson(dynamic row) => {
      'id': row.id as String,
      'target_type': row.targetType as String,
      'target_id': row.targetId as String,
      'account_id': row.accountId as String,
      'title': row.title as String?,
      'poll_seconds': row.pollSeconds as int,
      'max_articles': row.maxArticles as int,
      'enabled': row.enabled as bool,
      'last_fetched_at': (row.lastFetchedAt as DateTime?)?.millisecondsSinceEpoch,
      'consecutive_failures': row.consecutiveFailures as int,
      'next_retry_at': (row.nextRetryAt as DateTime?)?.millisecondsSinceEpoch,
    };

class _SocialFields {
  _SocialFields({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.accountId,
    required this.pollSeconds,
    required this.maxArticles,
    required this.enabled,
    this.title,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String accountId;
  final int pollSeconds;
  final int maxArticles;
  final bool enabled;
  final String? title;
}

_SocialFields _parseSocialFields(
  Map<String, dynamic> body,
  Set<String> validTargetTypes,
) {
  final id = '${body['id'] ?? ''}'.trim();
  final targetType = '${body['target_type'] ?? ''}'.trim().toLowerCase();
  final targetId = '${body['target_id'] ?? ''}'.trim();
  final accountId = '${body['account_id'] ?? ''}'.trim();
  final poll = _parseInt(body['poll_seconds']) ?? 3600;
  final maxArticles = _parseInt(body['max_articles']) ?? 3;
  final enabled = _parseBool(body['enabled']) ?? true;
  final titleRaw = body['title'];
  final title = titleRaw == null ? null : '$titleRaw'.trim();
  if (id.isEmpty ||
      targetId.isEmpty ||
      accountId.isEmpty ||
      !validTargetTypes.contains(targetType)) {
    throw StateError('invalid');
  }
  return _SocialFields(
    id: id,
    targetType: targetType,
    targetId: targetId,
    accountId: accountId,
    pollSeconds: poll.clamp(60, 86400 * 7),
    maxArticles: maxArticles.clamp(1, 50),
    enabled: enabled,
    title: title == null || title.isEmpty ? null : title,
  );
}

class _MergedSocial {
  _MergedSocial({
    required this.targetType,
    required this.targetId,
    required this.accountId,
    required this.pollSeconds,
    required this.maxArticles,
    required this.enabled,
    required this.title,
    required this.lastFetchedAt,
    required this.consecutiveFailures,
    required this.nextRetryAt,
  });

  final String targetType;
  final String targetId;
  final String accountId;
  final int pollSeconds;
  final int maxArticles;
  final bool enabled;
  final String? title;
  final DateTime? lastFetchedAt;
  final int consecutiveFailures;
  final DateTime? nextRetryAt;
}

_MergedSocial _mergeSocialFields(
  Map<String, dynamic> body,
  dynamic existing,
  Set<String> validTargetTypes,
) {
  final targetType = body.containsKey('target_type')
      ? '${body['target_type']}'.trim().toLowerCase()
      : existing.targetType as String;
  if (!validTargetTypes.contains(targetType)) {
    throw StateError('invalid_target_type');
  }
  final targetId = body.containsKey('target_id')
      ? '${body['target_id']}'.trim()
      : existing.targetId as String;
  final accountId = body.containsKey('account_id')
      ? '${body['account_id']}'.trim()
      : existing.accountId as String;
  final poll = body.containsKey('poll_seconds')
      ? (_parseInt(body['poll_seconds']) ?? existing.pollSeconds as int)
      : existing.pollSeconds as int;
  final maxArticles = body.containsKey('max_articles')
      ? (_parseInt(body['max_articles']) ?? existing.maxArticles as int)
      : existing.maxArticles as int;
  final enabled = body.containsKey('enabled')
      ? (_parseBool(body['enabled']) ?? existing.enabled as bool)
      : existing.enabled as bool;
  String? title;
  if (body.containsKey('title')) {
    final raw = body['title'];
    title = raw == null ? null : '$raw'.trim();
    if (title != null && title.isEmpty) title = null;
  } else {
    title = existing.title as String?;
  }
  DateTime? lastFetched = existing.lastFetchedAt as DateTime?;
  if (body.containsKey('last_fetched_at')) {
    final ms = _parseInt(body['last_fetched_at']);
    lastFetched = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
  var failures = existing.consecutiveFailures as int;
  if (body.containsKey('consecutive_failures')) {
    failures = _parseInt(body['consecutive_failures']) ?? failures;
  }
  DateTime? nextRetry = existing.nextRetryAt as DateTime?;
  if (body.containsKey('next_retry_at')) {
    final ms = _parseInt(body['next_retry_at']);
    nextRetry = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return _MergedSocial(
    targetType: targetType,
    targetId: targetId,
    accountId: accountId,
    pollSeconds: poll.clamp(60, 86400 * 7),
    maxArticles: maxArticles.clamp(1, 50),
    enabled: enabled,
    title: title,
    lastFetchedAt: lastFetched,
    consecutiveFailures: failures,
    nextRetryAt: nextRetry,
  );
}

InterestsTwitterSourcesCompanion _twitterCompanion(_MergedSocial c) =>
    InterestsTwitterSourcesCompanion(
      targetType: Value(c.targetType),
      targetId: Value(c.targetId),
      accountId: Value(c.accountId),
      pollSeconds: Value(c.pollSeconds),
      maxArticles: Value(c.maxArticles),
      enabled: Value(c.enabled),
      title: Value(c.title),
      lastFetchedAt: Value(c.lastFetchedAt),
      consecutiveFailures: Value(c.consecutiveFailures),
      nextRetryAt: Value(c.nextRetryAt),
    );

InterestsLinkedinSourcesCompanion _linkedinCompanion(_MergedSocial c) =>
    InterestsLinkedinSourcesCompanion(
      targetType: Value(c.targetType),
      targetId: Value(c.targetId),
      accountId: Value(c.accountId),
      pollSeconds: Value(c.pollSeconds),
      maxArticles: Value(c.maxArticles),
      enabled: Value(c.enabled),
      title: Value(c.title),
      lastFetchedAt: Value(c.lastFetchedAt),
      consecutiveFailures: Value(c.consecutiveFailures),
      nextRetryAt: Value(c.nextRetryAt),
    );

Future<String?> _validateSocialCreate(
  Map<String, dynamic> body,
  AppDatabase db,
  Set<String> validTargetTypes,
) async {
  try {
    final fields = _parseSocialFields(body, validTargetTypes);
    if (!_isValidInterestCategoryId(fields.id)) {
      return 'invalid_id';
    }
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(fields.accountId)))
        .getSingleOrNull();
    if (account == null) return 'unknown_account_id';
    return null;
  } on StateError {
    return 'id_target_type_target_id_account_id_required';
  }
}

Future<String?> _validateSocialPatch(
  Map<String, dynamic> body,
  dynamic existing,
  AppDatabase db,
  Set<String> validTargetTypes,
) async {
  try {
    final c = _mergeSocialFields(body, existing, validTargetTypes);
    if (c.targetId.isEmpty) return 'invalid_target_id';
    if (c.accountId.isEmpty) return 'invalid_account_id';
    if (body.containsKey('account_id')) {
      final account = await (db.select(db.integrationAccounts)
            ..where((t) => t.id.equals(c.accountId)))
          .getSingleOrNull();
      if (account == null) return 'unknown_account_id';
    }
    return null;
  } on StateError {
    return 'invalid_target_type';
  }
}

bool _isValidInterestCategoryId(String id) =>
    RegExp(r'^[a-z][a-z0-9_]{0,62}$').hasMatch(id);

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
