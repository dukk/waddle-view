import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/ical_kv.dart';
import 'package:waddle_shared/net/http_debug_uri.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';

import '../news_rss/rss_http_response_body_decode.dart';
import 'ical_calendar_extra_config.dart';
import 'ical_event_parse.dart';
import 'ical_feed_url.dart';

export 'ical_calendar_extra_config.dart';
export 'ical_event_parse.dart';

/// Syncs public or private ICS / iCal subscription URLs into [CalendarEvents].
class IcalCalendarDataProvider implements IDataProvider {
  IcalCalendarDataProvider({http.Client? httpClient, int Function()? nowMs})
    : _http = httpClient ?? http.Client(),
      _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kIcalCalendarProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(ctx.db.integrations)
              ..where((t) => t.id.equals(kDefaultCalendarIcalIntegrationId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      ctx.diagnostics.provider('calendar_ical: skip (disabled)');
      return;
    }

    final extra = IcalCalendarExtraConfig.parse(setting.configJson);
    final enabledFeeds = extra.feeds.where((f) => f.enabled).toList();
    if (enabledFeeds.isEmpty) {
      ctx.diagnostics.provider('calendar_ical: no enabled feeds');
      await _markCollectDone(ctx.db, _nowMs());
      return;
    }

    final nowMs = _nowMs();
    if (await _shouldSkipForPollWindow(ctx.db, nowMs, setting.pollSeconds)) {
      ctx.diagnostics.provider(
        'calendar_ical: skip poll gate pollSeconds=${setting.pollSeconds}',
      );
      return;
    }

    final window = _syncWindowUtc(extra);
    ctx.diagnostics.provider(
      'calendar_ical: collect feeds=${enabledFeeds.length} '
      'windowUtc=${window.$1.toIso8601String()}..${window.$2.toIso8601String()}',
    );

    var didSync = false;
    for (final feed in enabledFeeds) {
      final uri = normalizeIcalFeedUri(feed.url);
      if (uri == null) {
        ctx.diagnostics.provider(
          'calendar_ical: skip feed id=${feed.id} (invalid url)',
        );
        continue;
      }
      try {
        ctx.diagnostics.provider(
          'calendar_ical: GET feed id=${feed.id} ${safeHttpUriForLog(uri)}',
        );
        final res = await _http.get(uri);
        if (res.statusCode != 200) {
          ctx.diagnostics.provider(
            'calendar_ical: feed id=${feed.id} status=${res.statusCode} '
            '${safeHttpUriForLog(uri)}',
          );
          continue;
        }
        final body = decodeRssHttpResponseBody(res);
        final events = parseIcalFeedEvents(body);
        ctx.diagnostics.provider(
          'calendar_ical: feed id=${feed.id} parsed events=${events.length}',
        );
        await _purgeWindow(
          ctx.db,
          sourceTag: icalCalendarEventSource(feed.id),
          windowStart: window.$1,
          windowEndExclusive: window.$2,
        );
        var written = 0;
        for (final event in events) {
          if (!_eventOverlapsWindow(
            event,
            windowStart: window.$1,
            windowEndExclusive: window.$2,
          )) {
            continue;
          }
          await _upsertEvent(
            ctx.db,
            feedId: feed.id,
            event: event,
            categoryId: feed.categoryId,
          );
          written++;
        }
        ctx.diagnostics.provider(
          'calendar_ical: feed id=${feed.id} upserted=$written',
        );
        didSync = true;
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail(
          'calendar_ical: feed id=${feed.id}',
          e,
          st,
        );
      }
    }

    if (didSync) {
      await _markCollectDone(ctx.db, nowMs);
      ctx.diagnostics.provider('calendar_ical: collect ok, last_collect updated');
    } else {
      ctx.diagnostics.provider('calendar_ical: collect finished (no writes)');
    }
  }

  Future<bool> _shouldSkipForPollWindow(
    AppDatabase db,
    int nowMs,
    int pollSeconds,
  ) async {
    if (pollSeconds <= 0) {
      return false;
    }
    final lastRow = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(kIcalCalendarLastCollectKvKey)))
        .getSingleOrNull();
    final last = int.tryParse(lastRow?.value ?? '') ?? 0;
    return nowMs - last < pollSeconds * 1000;
  }

  (DateTime, DateTime) _syncWindowUtc(IcalCalendarExtraConfig extra) {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime.utc(now.year, now.month, now.day);
    final start = dayStart.subtract(Duration(days: extra.pastDays));
    final endExclusive = dayStart.add(Duration(days: extra.futureDays + 1));
    return (start, endExclusive);
  }

  Future<void> _markCollectDone(AppDatabase db, int nowMs) async {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
      ConfigKeyValuesCompanion.insert(
        key: kIcalCalendarLastCollectKvKey,
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

  bool _eventOverlapsWindow(
    ParsedIcalEvent event, {
    required DateTime windowStart,
    required DateTime windowEndExclusive,
  }) {
    return event.endUtc.isAfter(windowStart) &&
        event.startUtc.isBefore(windowEndExclusive);
  }

  Future<void> _upsertEvent(
    AppDatabase db, {
    required String feedId,
    required ParsedIcalEvent event,
    String? categoryId,
  }) async {
    final trimmedCat = categoryId?.trim();
    await db.into(db.calendarEvents).insertOnConflictUpdate(
      CalendarEventsCompanion.insert(
        id: icalCalendarEventRowId(feedId, event.uid),
        title: event.title,
        startMs: event.startUtc,
        endMs: event.endUtc,
        allDay: Value(event.allDay),
        location: Value(event.location),
        description: Value(event.description),
        source: Value(icalCalendarEventSource(feedId)),
        externalId: Value(event.uid),
        icalUid: Value(event.uid),
        categoryId: Value(
          trimmedCat != null && trimmedCat.isNotEmpty ? trimmedCat : null,
        ),
        updatedAtMs: DateTime.fromMillisecondsSinceEpoch(_nowMs()),
      ),
    );
  }
}
