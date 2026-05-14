import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/config/provider_access_token_env.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/secret_store.dart';
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import '../microsoft_graph/microsoft_graph_base_url.dart';
import '../microsoft_graph/microsoft_graph_oauth.dart';
import 'outlook_calendar_extra_config.dart';

const String kOutlookCalendarProviderId = 'calendar_outlook';

String _graphBodySnippet(String body, [int maxChars = 400]) {
  final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= maxChars) {
    return t;
  }
  return '${t.substring(0, maxChars)}…';
}

void _logGraphJsonError(String context, String body, CollectDiagnostics d) {
  try {
    final j = jsonDecode(body);
    if (j is Map<String, dynamic> && j['error'] is Map<String, dynamic>) {
      final e = j['error'] as Map<String, dynamic>;
      d.provider(
        '$context Graph error code=${e['code']} message=${e['message']}',
      );
      return;
    }
  } on Object {
    // fall through
  }
  d.provider('$context body=${_graphBodySnippet(body)}');
}

/// Path only — Graph `@odata.nextLink` query tokens must not be logged.
String _graphRequestLabel(String url) {
  try {
    final u = Uri.parse(url);
    return u.path.isEmpty ? '/' : u.path;
  } on Object {
    return '(invalid url)';
  }
}

/// Syncs Outlook / Exchange calendars via Microsoft Graph into [CalendarEvents].
class OutlookCalendarDataProvider implements IDataProvider {
  factory OutlookCalendarDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    MicrosoftGraphOAuth? oauth,
  }) {
    final client = httpClient ?? http.Client();
    final clock =
        nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
    return OutlookCalendarDataProvider._(
      client,
      clock,
      oauth,
    );
  }

  OutlookCalendarDataProvider._(this._http, this._nowMs, this._oauth);

  final http.Client _http;
  final int Function() _nowMs;
  final MicrosoftGraphOAuth? _oauth;

  CollectDiagnostics? _collectDiag;

  @override
  String get id => kOutlookCalendarProviderId;

  /// When within [pollSeconds], skip a full collect only if every account that
  /// has [OutlookAccountConfig.sources] already has a non-expired access token.
  /// Otherwise OAuth (device code / refresh) runs even between sync intervals.
  Future<bool> _shouldSkipForPollWindowOnly(
    AppDatabase db,
    SecretStore secrets,
    OutlookCalendarExtraConfig extra,
    int nowMs,
    int pollSeconds,
    CollectDiagnostics diagnostics,
  ) async {
    if (pollSeconds <= 0) {
      return false;
    }
    final lastRow =
        await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(kOutlookCalendarLastCollectKvKey)))
            .getSingleOrNull();
    final last = int.tryParse(lastRow?.value ?? '') ?? 0;
    if (nowMs - last >= pollSeconds * 1000) {
      return false;
    }

    for (final a in extra.accounts) {
      if (a.sources.isEmpty) {
        continue;
      }
      final access =
          await secrets.read(microsoftGraphAccessTokenSecret(a.graphAccountKey));
      final expiresRow =
          await (db.select(db.configKeyValues)
                ..where(
                  (t) => t.key.equals(
                    kMicrosoftGraphAccessTokenExpiresAtKvKey(a.graphAccountKey),
                  ),
                ))
              .getSingleOrNull();
      final expiresAt = int.tryParse(expiresRow?.value ?? '') ?? 0;
      final fresh = access != null &&
          access.isNotEmpty &&
          expiresAt > nowMs + kMicrosoftGraphAccessTokenSkewMs;
      if (!fresh) {
        diagnostics.provider(
          'outlook_calendar: poll window bypass (auth or token '
          'refresh needed for ${a.graphAccountKey} expiresAtMs=$expiresAt '
          'nowMs=$nowMs)',
        );
        return false;
      }
    }

    diagnostics.provider(
      'outlook_calendar: skip poll gate lastCollectMs=$last '
      'elapsedMs=${nowMs - last} needMs=${pollSeconds * 1000} '
      '(all accounts have fresh access tokens)',
    );
    return true;
  }

  @override
  Future<void> collect(DataWriteContext ctx) async {
    _collectDiag = ctx.diagnostics;
    try {
    final setting =
        await (ctx.db.select(
              ctx.db.providerSettings,
            )..where((t) => t.id.equals(kOutlookCalendarProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      _collectDiag!.provider('outlook_calendar: skip (disabled)');
      return;
    }

    _collectDiag!.provider(
      'outlook_calendar: collect start pollSeconds=${setting.pollSeconds}',
    );

    final nowMs = _nowMs();

    final clientId = readMicrosoftGraphClientIdFromEnvMap(ctx.env) ?? '';
    if (clientId.isEmpty) {
      _collectDiag!.provider(
        'outlook_calendar: skip (no $waddleMicrosoftGraphClientIdEnv)',
      );
      return;
    }

    final extra = OutlookCalendarExtraConfig.parse(setting.configJson);
    if (extra.accounts.isEmpty) {
      _collectDiag!.provider(
        'outlook_calendar: skip (no accounts in config_json)',
      );
      await _markCollectDone(ctx.db, nowMs);
      return;
    }

    if (await _shouldSkipForPollWindowOnly(
          ctx.db,
          ctx.secrets,
          extra,
          nowMs,
          setting.pollSeconds,
          _collectDiag!,
        )) {
      return;
    }

    final graphBase = _normalizeGraphBase(setting.baseUrl);
    final range = _syncWindowUtc(extra);
    final graphOAuth = _oauth ??
        MicrosoftGraphOAuth(
          httpClient: _http,
          nowMs: _nowMs,
          diagnostics: _collectDiag!,
        );
    _collectDiag!.provider(
      'outlook_calendar: graphBase=$graphBase accounts=${extra.accounts.length} '
      'windowUtc=${range.$1.toIso8601String()}..${range.$2.toIso8601String()} '
      '(exclusive end) pastDays=${extra.pastDays} futureDays=${extra.futureDays}',
    );

    var didSync = false;
    try {
      for (final account in extra.accounts) {
        if (account.sources.isEmpty) {
          _collectDiag!.provider(
            'outlook_calendar: account ${account.graphAccountKey} has no sources',
          );
          continue;
        }
        final token = await graphOAuth.ensureAccessToken(
          db: ctx.db,
          secrets: ctx.secrets,
          clientId: clientId,
          graphAccountKey: account.graphAccountKey,
        );
        if (token == null || token.isEmpty) {
          _collectDiag!.provider(
            'outlook_calendar: no token for ${account.graphAccountKey}',
          );
          continue;
        }

        _collectDiag!.provider(
          'outlook_calendar: token ok for ${account.graphAccountKey} '
          '(length=${token.length})',
        );

        await _purgeOutlookWindow(
          ctx.db,
          sourceTag: outlookCalendarEventSource(account.graphAccountKey),
          windowStart: range.$1,
          windowEndExclusive: range.$2,
        );

        for (final src in account.sources) {
          _collectDiag!.provider(
            'outlook_calendar: sync mailbox=${src.mailbox} '
            'account=${account.graphAccountKey} '
            'calendarFilters=${src.calendars.length}',
          );
          await _syncMailbox(
            ctx.db,
            graphBase: graphBase,
            accessToken: token,
            accountKey: account.graphAccountKey,
            src: src,
            windowStart: range.$1,
            windowEndExclusive: range.$2,
          );
        }
        didSync = true;
      }
      if (didSync) {
        _collectDiag!.provider('outlook_calendar: collect finished, marking last_collect');
        await _markCollectDone(ctx.db, nowMs);
      } else {
        _collectDiag!.provider(
          'outlook_calendar: collect finished with no successful sync',
        );
      }
    } on Object catch (e, st) {
      _collectDiag!.providerFail('outlook_calendar: collect', e, st);
    }
    } finally {
      _collectDiag = null;
    }
  }

  Future<void> _markCollectDone(AppDatabase db, int nowMs) async {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kOutlookCalendarLastCollectKvKey,
            value: '$nowMs',
          ),
        );
  }

  (DateTime, DateTime) _syncWindowUtc(OutlookCalendarExtraConfig extra) {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime.utc(now.year, now.month, now.day);
    final start = dayStart.subtract(Duration(days: extra.pastDays));
    final endExclusive = dayStart.add(Duration(days: extra.futureDays + 1));
    return (start, endExclusive);
  }

  String _normalizeGraphBase(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return kDefaultGraphBaseUrl;
    }
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  Future<void> _purgeOutlookWindow(
    AppDatabase db, {
    required String sourceTag,
    required DateTime windowStart,
    required DateTime windowEndExclusive,
  }) async {
    await (db.delete(db.calendarEvents)..where(
          (t) =>
              t.source.equals(sourceTag) &
              t.startMs.isBiggerOrEqualValue(windowStart) &
              t.startMs.isSmallerThanValue(windowEndExclusive),
        ))
        .go();
  }

  Future<void> _syncMailbox(
    AppDatabase db, {
    required String graphBase,
    required String accessToken,
    required String accountKey,
    required OutlookMailboxSource src,
    required DateTime windowStart,
    required DateTime windowEndExclusive,
  }) async {
    final mailbox = src.mailbox;
    final userPath = _userPathSegment(mailbox);
    final qStart = Uri.encodeQueryComponent(
      windowStart.toUtc().toIso8601String(),
    );
    final qEnd = Uri.encodeQueryComponent(
      windowEndExclusive.toUtc().toIso8601String(),
    );
    final query = 'startDateTime=$qStart&endDateTime=$qEnd';

    if (src.calendars.isEmpty) {
      final url = '$graphBase/$userPath/calendar/calendarView?$query';
      await _pullAndStoreEvents(
        db,
        url: url,
        accessToken: accessToken,
        accountKey: accountKey,
        mailbox: mailbox,
        forceCategoryId: src.defaultCategoryId,
        outlookCategoryMap: src.categoryMap,
      );
      return;
    }

    final calMap = await _fetchCalendarIdMap(
      graphBase: graphBase,
      userPath: userPath,
      accessToken: accessToken,
    );
    for (final entry in src.calendars) {
      final calId = _resolveCalendarId(calMap, entry.nameOrId);
      if (calId == null) {
        _collectDiag!.provider(
          'outlook_calendar: unknown calendar "${entry.nameOrId}" '
          'for $mailbox',
        );
        continue;
      }
      final url =
          '$graphBase/$userPath/calendars/${Uri.encodeComponent(calId)}/calendarView?$query';
      await _pullAndStoreEvents(
        db,
        url: url,
        accessToken: accessToken,
        accountKey: accountKey,
        mailbox: mailbox,
        forceCategoryId: entry.categoryId ?? src.defaultCategoryId,
        outlookCategoryMap: src.categoryMap,
      );
    }
  }

  String _userPathSegment(String mailbox) {
    final m = mailbox.trim();
    if (m.toLowerCase() == 'me') {
      return 'me';
    }
    return 'users/${Uri.encodeComponent(m)}';
  }

  Future<Map<String, String>> _fetchCalendarIdMap({
    required String graphBase,
    required String userPath,
    required String accessToken,
  }) async {
    final out = <String, String>{};
    var url = '$graphBase/$userPath/calendars?\$top=200';
    var listPage = 0;
    while (true) {
      listPage++;
      _collectDiag!.provider(
        'outlook_calendar: GET calendars page=$listPage '
        '${_graphRequestLabel(url)}',
      );
      final res = await _http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) {
        _collectDiag!.provider(
          'outlook_calendar: list calendars status=${res.statusCode} '
          '${_graphRequestLabel(url)}',
        );
        _logGraphJsonError('outlook_calendar: list calendars', res.body, _collectDiag!);
        break;
      }
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final values = m['value'];
      if (values is List<dynamic>) {
        _collectDiag!.provider(
          'outlook_calendar: list calendars page=$listPage '
          'calendarsInPage=${values.length}',
        );
        for (final e in values) {
          if (e is Map<String, dynamic>) {
            final id = e['id'];
            final name = e['name'];
            if (id is String && id.isNotEmpty) {
              out[id] = id;
              if (name is String && name.isNotEmpty) {
                out[name.toLowerCase()] = id;
              }
            }
          }
        }
      }
      final next = m['@odata.nextLink'];
      if (next is String && next.isNotEmpty) {
        url = next;
      } else {
        break;
      }
    }
    return out;
  }

  String? _resolveCalendarId(Map<String, String> calMap, String nameOrId) {
    final trimmed = nameOrId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (calMap.containsKey(trimmed)) {
      return calMap[trimmed];
    }
    return calMap[trimmed.toLowerCase()];
  }

  Future<void> _pullAndStoreEvents(
    AppDatabase db, {
    required String url,
    required String accessToken,
    required String accountKey,
    required String mailbox,
    String? forceCategoryId,
    Map<String, String> outlookCategoryMap = const {},
  }) async {
    var nextUrl = url;
    var viewPage = 0;
    while (true) {
      viewPage++;
      _collectDiag!.provider(
        'outlook_calendar: GET calendarView page=$viewPage '
        'mailbox=$mailbox ${_graphRequestLabel(nextUrl)}',
      );
      final res = await _http.get(
        Uri.parse(nextUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) {
        _collectDiag!.provider(
          'outlook_calendar: calendarView status=${res.statusCode} '
          'mailbox=$mailbox',
        );
        _logGraphJsonError('outlook_calendar: calendarView', res.body, _collectDiag!);
        break;
      }
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final values = m['value'];
      if (values is List<dynamic>) {
        _collectDiag!.provider(
          'outlook_calendar: calendarView page=$viewPage '
          'events=${values.length} mailbox=$mailbox',
        );
        for (final e in values) {
          if (e is Map<String, dynamic>) {
            await _upsertGraphEvent(
              db,
              accountKey: accountKey,
              mailbox: mailbox,
              event: e,
              forceCategoryId: forceCategoryId,
              outlookCategoryMap: outlookCategoryMap,
            );
          }
        }
      }
      final next = m['@odata.nextLink'];
      if (next is String && next.isNotEmpty) {
        nextUrl = next;
      } else {
        break;
      }
    }
  }

  Future<void> _upsertGraphEvent(
    AppDatabase db, {
    required String accountKey,
    required String mailbox,
    required Map<String, dynamic> event,
    String? forceCategoryId,
    Map<String, String> outlookCategoryMap = const {},
  }) async {
    final graphId = event['id'];
    if (graphId is! String || graphId.isEmpty) {
      return;
    }
    final subject = event['subject'];
    final title = subject is String && subject.isNotEmpty ? subject : '(no title)';
    final isAllDay = event['isAllDay'] == true;
    final startMap = event['start'];
    final endMap = event['end'];
    final start = _parseGraphDateTime(
      startMap is Map<String, dynamic> ? startMap : null,
      isAllDay: isAllDay,
    );
    final end = _parseGraphDateTime(
      endMap is Map<String, dynamic> ? endMap : null,
      isAllDay: isAllDay,
    );
    if (start == null || end == null) {
      return;
    }
    final loc = event['location'];
    String? location;
    if (loc is Map<String, dynamic>) {
      final dn = loc['displayName'];
      if (dn is String && dn.isNotEmpty) {
        location = dn;
      }
    }
    final preview = event['bodyPreview'];
    final description = preview is String && preview.isNotEmpty ? preview : null;

    final icalRaw = event['iCalUId'];
    final icalUid = icalRaw is String && icalRaw.trim().isNotEmpty
        ? icalRaw.trim()
        : null;

    final categoryId = _resolveOutlookStoredCategoryId(
      forceCategoryId: forceCategoryId,
      outlookCategoryMap: outlookCategoryMap,
      categoriesRaw: event['categories'],
    );

    final rowId = _stableEventId(accountKey, mailbox, graphId);
    final updated = _nowMs();

    await db.into(db.calendarEvents).insertOnConflictUpdate(
          CalendarEventsCompanion.insert(
            id: rowId,
            title: title,
            startMs: start,
            endMs: end,
            allDay: Value(isAllDay),
            location: Value(location),
            description: Value(description),
            source: Value(outlookCalendarEventSource(accountKey)),
            externalId: Value(graphId),
            icalUid: Value(icalUid),
            categoryId: Value(categoryId),
            updatedAtMs: DateTime.fromMillisecondsSinceEpoch(updated),
          ),
        );
  }

  String? _resolveOutlookStoredCategoryId({
    String? forceCategoryId,
    required Map<String, String> outlookCategoryMap,
    required Object? categoriesRaw,
  }) {
    final forced = forceCategoryId?.trim();
    if (forced != null && forced.isNotEmpty) {
      return forced;
    }
    if (categoriesRaw is List<dynamic>) {
      for (final c in categoriesRaw) {
        if (c is String && c.trim().isNotEmpty) {
          final label = c.trim();
          final mapped = outlookCategoryMap[label] ??
              outlookCategoryMap[label.toLowerCase()];
          if (mapped != null && mapped.trim().isNotEmpty) {
            return mapped.trim();
          }
        }
      }
    }
    return null;
  }

  DateTime? _parseGraphDateTime(
    Map<String, dynamic>? m, {
    required bool isAllDay,
  }) {
    if (m == null) {
      return null;
    }
    final dt = m['dateTime'];
    final date = m['date'];
    if (dt is String && dt.isNotEmpty) {
      return DateTime.tryParse(dt);
    }
    if (isAllDay && date is String && date.isNotEmpty) {
      return DateTime.tryParse('${date}T00:00:00');
    }
    return null;
  }

  String _stableEventId(String accountKey, String mailbox, String graphEventId) {
    final bytes = utf8.encode(
      'outlook_cal\x00$accountKey\x00$mailbox\x00$graphEventId',
    );
    return sha256.convert(bytes).toString();
  }
}
