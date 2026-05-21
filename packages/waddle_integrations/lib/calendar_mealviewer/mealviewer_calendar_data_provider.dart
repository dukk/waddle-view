import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/mealviewer_kv.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';

import '../shared/calendar_event_upsert.dart';
import 'mealviewer_api_client.dart';
import 'mealviewer_calendar_extra_config.dart';
import 'mealviewer_menu_parse.dart';

export 'mealviewer_api_client.dart';
export 'mealviewer_calendar_extra_config.dart';
export 'mealviewer_menu_parse.dart';

const String kMealviewerCalendarLastCollectKvKey =
    'provider.calendar_mealviewer.last_collect_ms';

/// Syncs MealViewer school lunch menus into [CalendarEvents].
class MealviewerCalendarDataProvider implements IDataProvider {
  MealviewerCalendarDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    MealviewerApiClient Function(String baseUrl, {http.Client? client})?
        apiClientFactory,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _apiClientFactory = apiClientFactory ??
            ((base, {client}) => MealviewerApiClient(
                  httpClient: client,
                  baseUrl: base,
                ));

  final http.Client _http;
  final int Function() _nowMs;
  final MealviewerApiClient Function(String baseUrl, {http.Client? client})
      _apiClientFactory;

  @override
  String get id => kMealviewerCalendarProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final settings = await enabledIntegrationsForType(ctx.db, id);
    if (settings.isEmpty) {
      ctx.diagnostics.provider('calendar_mealviewer: no enabled integrations');
      return;
    }

    final nowMs = _nowMs();
    for (final setting in settings) {
      if (!setting.enabled) {
        continue;
      }
      final extra = MealviewerCalendarExtraConfig.parse(setting.configJson);
      if (extra.schools.isEmpty) {
        ctx.diagnostics.provider(
          'calendar_mealviewer: integration=${setting.id} no schools',
        );
        await _markCollectDone(ctx.db, setting.id, nowMs);
        continue;
      }
      if (await _shouldSkipForPollWindow(
        ctx.db,
        setting.id,
        nowMs,
        setting.pollSeconds,
      )) {
        ctx.diagnostics.provider(
          'calendar_mealviewer: skip poll gate integration=${setting.id} '
          'pollSeconds=${setting.pollSeconds}',
        );
        continue;
      }

      final window = _syncWindowUtc(extra);
      final api = _apiClientFactory(extra.baseUrl, client: _http);
      ctx.diagnostics.provider(
        'calendar_mealviewer: collect integration=${setting.id} '
        'schools=${extra.schools.length} '
        'windowUtc=${window.$1.toIso8601String()}..${window.$2.toIso8601String()}',
      );

      var didSync = false;
      for (final school in extra.schools) {
        try {
          ctx.diagnostics.provider(
            'calendar_mealviewer: GET school=${school.schoolSlug} '
            '${api.menuUriForLog(school.schoolSlug, window.$1, window.$3)}',
          );
          await _purgeWindow(
            ctx.db,
            sourceTag: mealviewerCalendarEventSource(school.schoolSlug),
            windowStart: window.$1,
            windowEndExclusive: window.$2,
          );
          final menu = await api.fetchSchoolMenu(
            schoolSlug: school.schoolSlug,
            rangeStartUtc: window.$1,
            rangeEndUtc: window.$3,
          );
          if (menu == null) {
            ctx.diagnostics.provider(
              'calendar_mealviewer: school=${school.schoolSlug} no menu data',
            );
            continue;
          }
          final events = parseMealviewerMenuEvents(
            root: menu,
            schoolLabel: school.label,
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
              schoolSlug: school.schoolSlug,
              event: event,
              categoryIds: school.categoryIds,
            );
            written++;
          }
          ctx.diagnostics.provider(
            'calendar_mealviewer: school=${school.schoolSlug} upserted=$written',
          );
          didSync = true;
        } on Object catch (e, st) {
          ctx.diagnostics.providerFail(
            'calendar_mealviewer: school=${school.schoolSlug}',
            e,
            st,
          );
        }
      }

      if (didSync) {
        await _markCollectDone(ctx.db, setting.id, nowMs);
        ctx.diagnostics.provider(
          'calendar_mealviewer: integration=${setting.id} collect ok',
        );
      } else {
        ctx.diagnostics.provider(
          'calendar_mealviewer: integration=${setting.id} finished (no writes)',
        );
      }
    }
  }

  Future<bool> _shouldSkipForPollWindow(
    AppDatabase db,
    String integrationId,
    int nowMs,
    int pollSeconds,
  ) async {
    if (pollSeconds <= 0) {
      return false;
    }
    final lastValue = await IntegrationKvRepository(db).getIntegrationValue(
      integrationId,
      kMealviewerCalendarLastCollectKvKey,
    );
    final last = int.tryParse(lastValue ?? '') ?? 0;
    return nowMs - last < pollSeconds * 1000;
  }

  /// Returns `(windowStart, windowEndExclusive, rangeEndInclusive)` in UTC.
  (DateTime, DateTime, DateTime) _syncWindowUtc(
    MealviewerCalendarExtraConfig extra,
  ) {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime.utc(now.year, now.month, now.day);
    final start = dayStart.subtract(Duration(days: extra.pastDays));
    final endExclusive = dayStart.add(Duration(days: extra.futureDays + 1));
    final rangeEndInclusive = endExclusive.subtract(const Duration(days: 1));
    return (start, endExclusive, rangeEndInclusive);
  }

  Future<void> _markCollectDone(
    AppDatabase db,
    String integrationId,
    int nowMs,
  ) async {
    await IntegrationKvRepository(db).upsertIntegration(
      integrationId: integrationId,
      key: kMealviewerCalendarLastCollectKvKey,
      value: '$nowMs',
      valueType: kIntegrationKvTypeIntMs,
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
    ParsedMealviewerMenuEvent event, {
    required DateTime windowStart,
    required DateTime windowEndExclusive,
  }) {
    return event.endUtc.isAfter(windowStart) &&
        event.startUtc.isBefore(windowEndExclusive);
  }

  Future<void> _upsertEvent(
    AppDatabase db, {
    required String schoolSlug,
    required ParsedMealviewerMenuEvent event,
    List<String> categoryIds = const [],
  }) async {
    await upsertCalendarEventWithCategories(
      db,
      companion: CalendarEventsCompanion.insert(
        id: mealviewerCalendarEventRowId(
          schoolSlug: schoolSlug,
          dateKey: event.dateKey,
          blockKey: event.blockKey,
        ),
        title: event.title,
        startMs: event.startUtc,
        endMs: event.endUtc,
        allDay: const Value(true),
        description: Value(event.description),
        source: Value(mealviewerCalendarEventSource(schoolSlug)),
        externalId: Value(event.externalId),
        updatedAtMs: DateTime.fromMillisecondsSinceEpoch(_nowMs()),
      ),
      categoryIds: categoryIds,
    );
  }
}
