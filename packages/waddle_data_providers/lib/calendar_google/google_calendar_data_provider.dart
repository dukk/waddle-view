import 'package:waddle_shared/net/http_debug_uri.dart';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/config/provider_access_token_env.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/secret_store.dart';
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import '../shared/calendar_provider_calendar_entry.dart';
import 'google_calendar_extra_config.dart';
import 'google_oauth.dart';

const String kGoogleCalendarProviderId = 'calendar_google';
const String kDefaultGoogleCalendarBaseUrl = 'https://www.googleapis.com/calendar/v3';

class GoogleCalendarDataProvider implements IDataProvider {
  factory GoogleCalendarDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    GoogleOAuth? oauth,
  }) {
    final client = httpClient ?? http.Client();
    final clock = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
    return GoogleCalendarDataProvider._(
      client,
      clock,
      oauth,
    );
  }

  GoogleCalendarDataProvider._(this._http, this._nowMs, this._oauth);

  final http.Client _http;
  final int Function() _nowMs;
  final GoogleOAuth? _oauth;

  @override
  String get id => kGoogleCalendarProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting = await (ctx.db.select(ctx.db.providerSettings)
          ..where((t) => t.id.equals(kGoogleCalendarProviderId)))
        .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      ctx.diagnostics.provider('google_calendar: skip (disabled)');
      return;
    }

    final nowMs = _nowMs();
    final clientId = readGoogleClientIdFromEnvMap(ctx.env) ?? '';
    if (clientId.isEmpty) {
      ctx.diagnostics.provider(
        'google_calendar: skip (no $waddleGoogleClientIdEnv)',
      );
      return;
    }

    final extra = GoogleCalendarExtraConfig.parse(setting.configJson);
    if (extra.accounts.isEmpty) {
      ctx.diagnostics.provider('google_calendar: no accounts, mark collect done');
      await _markCollectDone(ctx.db, nowMs);
      return;
    }

    if (await _shouldSkipForPollWindowOnly(
      ctx.db,
      ctx.secrets,
      extra,
      nowMs,
      setting.pollSeconds,
    )) {
      ctx.diagnostics.provider(
        'google_calendar: skip poll gate pollSeconds=${setting.pollSeconds}',
      );
      return;
    }

    final base = _normalizeBase(setting.baseUrl);
    final window = _syncWindowUtc(extra);
    final googleOAuth = _oauth ??
        GoogleOAuth(
          httpClient: _http,
          nowMs: _nowMs,
          diagnostics: ctx.diagnostics,
        );
    ctx.diagnostics.provider(
      'google_calendar: collect base=${safeHttpUriForLog(Uri.parse(base))} '
      'accounts=${extra.accounts.length} '
      'windowUtc=${window.$1.toIso8601String()}..${window.$2.toIso8601String()}',
    );
    var didSync = false;
    for (final account in extra.accounts) {
      if (account.sources.isEmpty) {
        ctx.diagnostics.provider(
          'google_calendar: account ${account.googleAccountKey} has no sources',
        );
        continue;
      }
      final token = await googleOAuth.ensureAccessToken(
        db: ctx.db,
        secrets: ctx.secrets,
        clientId: clientId,
        googleAccountKey: account.googleAccountKey,
      );
      if (token == null || token.isEmpty) {
        ctx.diagnostics.provider(
          'google_calendar: no token for ${account.googleAccountKey}',
        );
        continue;
      }
      ctx.diagnostics.provider(
        'google_calendar: token ok for ${account.googleAccountKey}',
      );

      await _purgeWindow(
        ctx.db,
        sourceTag: googleCalendarEventSource(account.googleAccountKey),
        windowStart: window.$1,
        windowEndExclusive: window.$2,
      );
      final calendarMap = await _fetchCalendarIdMap(
        base,
        token,
        diagnostics: ctx.diagnostics,
      );
      for (final src in account.sources) {
        final filters = _resolvedGoogleCalendarEntries(src);
        for (final entry in filters) {
          final calendarId =
              _resolveCalendarId(calendarMap, entry.nameOrId) ?? entry.nameOrId;
          ctx.diagnostics.provider(
            'google_calendar: sync calendar=$calendarId account=${account.googleAccountKey}',
          );
          await _pullAndStoreEvents(
            ctx.db,
            diagnostics: ctx.diagnostics,
            baseUrl: base,
            accessToken: token,
            googleAccountKey: account.googleAccountKey,
            calendarId: calendarId,
            windowStart: window.$1,
            windowEndExclusive: window.$2,
            forceCategoryId: entry.categoryId,
          );
          didSync = true;
        }
      }
    }
    if (didSync) {
      ctx.diagnostics.provider('google_calendar: collect ok, last_collect updated');
      await _markCollectDone(ctx.db, nowMs);
    } else {
      ctx.diagnostics.provider('google_calendar: collect finished (no sync writes)');
    }
  }

  Future<bool> _shouldSkipForPollWindowOnly(
    AppDatabase db,
    SecretStore secrets,
    GoogleCalendarExtraConfig extra,
    int nowMs,
    int pollSeconds,
  ) async {
    if (pollSeconds <= 0) {
      return false;
    }
    final lastRow = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(kGoogleCalendarLastCollectKvKey)))
        .getSingleOrNull();
    final last = int.tryParse(lastRow?.value ?? '') ?? 0;
    if (nowMs - last >= pollSeconds * 1000) {
      return false;
    }
    for (final a in extra.accounts) {
      if (a.sources.isEmpty) {
        continue;
      }
      final access = await secrets.read(googleAccessTokenSecret(a.googleAccountKey));
      final expiresRow = await (db.select(db.configKeyValues)
            ..where(
              (t) =>
                  t.key.equals(kGoogleAccessTokenExpiresAtKvKey(a.googleAccountKey)),
            ))
          .getSingleOrNull();
      final expiresAt = int.tryParse(expiresRow?.value ?? '') ?? 0;
      final fresh =
          access != null && access.isNotEmpty && expiresAt > nowMs + kGoogleAccessTokenSkewMs;
      if (!fresh) {
        return false;
      }
    }
    return true;
  }

  String _normalizeBase(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return kDefaultGoogleCalendarBaseUrl;
    }
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  (DateTime, DateTime) _syncWindowUtc(GoogleCalendarExtraConfig extra) {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime.utc(now.year, now.month, now.day);
    final start = dayStart.subtract(Duration(days: extra.pastDays));
    final endExclusive = dayStart.add(Duration(days: extra.futureDays + 1));
    return (start, endExclusive);
  }

  Future<void> _markCollectDone(AppDatabase db, int nowMs) async {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kGoogleCalendarLastCollectKvKey,
            value: '$nowMs',
          ),
        );
  }

  Future<void> _purgeWindow(
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

  Future<Map<String, String>> _fetchCalendarIdMap(
    String baseUrl,
    String accessToken, {
    required CollectDiagnostics diagnostics,
  }) async {
    final out = <String, String>{'primary': 'primary'};
    var url = '$baseUrl/users/me/calendarList?maxResults=250';
    var page = 0;
    while (true) {
      page++;
      final listUri = Uri.parse(url);
      diagnostics.provider(
        'google_calendar: GET calendarList page=$page ${safeHttpUriForLog(listUri)}',
      );
      final res = await _http.get(
        listUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) {
        diagnostics.provider(
          'google_calendar: calendarList status=${res.statusCode}',
        );
        break;
      }
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final items = m['items'];
      if (items is List<dynamic>) {
        for (final e in items) {
          if (e is! Map<String, dynamic>) {
            continue;
          }
          final id = e['id'];
          final summary = e['summary'];
          if (id is String && id.isNotEmpty) {
            out[id] = id;
            if (summary is String && summary.isNotEmpty) {
              out[summary.toLowerCase()] = id;
            }
          }
        }
      }
      final next = m['nextPageToken'];
      if (next is String && next.isNotEmpty) {
        url = '$baseUrl/users/me/calendarList?maxResults=250&pageToken=${Uri.encodeQueryComponent(next)}';
      } else {
        break;
      }
    }
    return out;
  }

  List<ProviderCalendarEntry> _resolvedGoogleCalendarEntries(
    GoogleCalendarSourceConfig src,
  ) {
    if (src.calendars.isEmpty) {
      return [
        ProviderCalendarEntry(
          nameOrId: 'primary',
          categoryId: src.defaultCategoryId,
        ),
      ];
    }
    return src.calendars
        .map(
          (e) => ProviderCalendarEntry(
            nameOrId: e.nameOrId,
            categoryId: e.categoryId ?? src.defaultCategoryId,
          ),
        )
        .toList();
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
    required CollectDiagnostics diagnostics,
    required String baseUrl,
    required String accessToken,
    required String googleAccountKey,
    required String calendarId,
    required DateTime windowStart,
    required DateTime windowEndExclusive,
    String? forceCategoryId,
  }) async {
    var url =
        '$baseUrl/calendars/${Uri.encodeComponent(calendarId)}/events?singleEvents=true&orderBy=startTime&maxResults=250'
        '&timeMin=${Uri.encodeQueryComponent(windowStart.toUtc().toIso8601String())}'
        '&timeMax=${Uri.encodeQueryComponent(windowEndExclusive.toUtc().toIso8601String())}';
    var eventPage = 0;
    while (true) {
      eventPage++;
      final eventsUri = Uri.parse(url);
      diagnostics.provider(
        'google_calendar: GET events page=$eventPage calendar=$calendarId '
        '${safeHttpUriForLog(eventsUri)}',
      );
      final res = await _http.get(
        eventsUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) {
        diagnostics.provider(
          'google_calendar: events status=${res.statusCode} calendar=$calendarId',
        );
        break;
      }
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final items = m['items'];
      if (items is List<dynamic>) {
        diagnostics.provider(
          'google_calendar: events page=$eventPage calendar=$calendarId count=${items.length}',
        );
        for (final e in items) {
          if (e is Map<String, dynamic>) {
            await _upsertEvent(
              db,
              googleAccountKey: googleAccountKey,
              calendarId: calendarId,
              event: e,
              forceCategoryId: forceCategoryId,
            );
          }
        }
      }
      final next = m['nextPageToken'];
      if (next is String && next.isNotEmpty) {
        url =
            '$baseUrl/calendars/${Uri.encodeComponent(calendarId)}/events?singleEvents=true&orderBy=startTime&maxResults=250&pageToken=${Uri.encodeQueryComponent(next)}'
            '&timeMin=${Uri.encodeQueryComponent(windowStart.toUtc().toIso8601String())}'
            '&timeMax=${Uri.encodeQueryComponent(windowEndExclusive.toUtc().toIso8601String())}';
      } else {
        break;
      }
    }
  }

  Future<void> _upsertEvent(
    AppDatabase db, {
    required String googleAccountKey,
    required String calendarId,
    required Map<String, dynamic> event,
    String? forceCategoryId,
  }) async {
    final eventId = event['id'];
    if (eventId is! String || eventId.isEmpty) {
      return;
    }
    final start = _parseEventDateTime(event['start']);
    final end = _parseEventDateTime(event['end']);
    if (start == null || end == null) {
      return;
    }
    final summary = event['summary'];
    final title = summary is String && summary.trim().isNotEmpty
        ? summary.trim()
        : '(no title)';
    final locationRaw = event['location'];
    final descriptionRaw = event['description'];
    final allDay = _isAllDay(event['start']);
    final icalRaw = event['iCalUID'] ?? event['iCalUid'];
    final icalUid = icalRaw is String && icalRaw.trim().isNotEmpty
        ? icalRaw.trim()
        : null;
    final trimmedForce = forceCategoryId?.trim();
    final categoryId =
        trimmedForce != null && trimmedForce.isNotEmpty ? trimmedForce : null;
    await db.into(db.calendarEvents).insertOnConflictUpdate(
          CalendarEventsCompanion.insert(
            id: googleCalendarEventRowId(googleAccountKey, calendarId, eventId),
            title: title,
            startMs: start,
            endMs: end,
            allDay: Value(allDay),
            location: Value(
              locationRaw is String && locationRaw.isNotEmpty ? locationRaw : null,
            ),
            description: Value(
              descriptionRaw is String && descriptionRaw.isNotEmpty
                  ? descriptionRaw
                  : null,
            ),
            source: Value(googleCalendarEventSource(googleAccountKey)),
            externalId: Value(eventId),
            icalUid: Value(icalUid),
            categoryId: Value(categoryId),
            updatedAtMs: DateTime.fromMillisecondsSinceEpoch(_nowMs()),
          ),
        );
  }

  DateTime? _parseEventDateTime(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final dt = raw['dateTime'];
    if (dt is String && dt.isNotEmpty) {
      return DateTime.tryParse(dt);
    }
    final date = raw['date'];
    if (date is String && date.isNotEmpty) {
      return DateTime.tryParse('${date}T00:00:00');
    }
    return null;
  }

  bool _isAllDay(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return false;
    }
    final date = raw['date'];
    final dateTime = raw['dateTime'];
    return date is String && date.isNotEmpty && (dateTime is! String || dateTime.isEmpty);
  }
}
