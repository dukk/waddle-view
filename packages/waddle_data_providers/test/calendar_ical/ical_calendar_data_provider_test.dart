import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_data_providers/calendar_ical/ical_calendar_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/config/ical_kv.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

class _IcsClient extends http.BaseClient {
  _IcsClient(this.body);

  final String body;
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    return http.StreamedResponse(
      Stream.value(body.codeUnits),
      200,
      headers: {'content-type': 'text/calendar; charset=utf-8'},
    );
  }
}

class _MemoryBlobStore implements BlobStore {
  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  Future<List<int>> readBytes(BlobRef ref) async => const [];

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async =>
      BlobRef(logicalKey);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

AppDatabase _openDb() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Future<void> _seedCategories(AppDatabase db, Iterable<String> ids) async {
  for (final id in ids) {
    await db.into(db.contentCategories).insertOnConflictUpdate(
          ContentCategoriesCompanion.insert(id: id, label: id),
        );
  }
}

Future<void> _seedProvider(
  AppDatabase db, {
  required String configJson,
  int pollSeconds = 0,
  bool enabled = true,
}) async {
  await db.into(db.integrations).insertOnConflictUpdate(
        IntegrationsCompanion.insert(
          id: kDefaultCalendarIcalIntegrationId,
          integrationType: kIcalCalendarProviderId,
          enabled: Value(enabled),
          pollSeconds: Value(pollSeconds),
          configJson: Value(configJson),
        ),
      );
}

Future<DataWriteContextImpl> _ctx(AppDatabase db) async {
  final secrets = InMemorySecretStore();
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: _MemoryBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

const _sampleIcs = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Waddle//Test//EN
BEGIN:VEVENT
UID:ics-1
SUMMARY:Meet
DTSTART:20300601T140000Z
DTEND:20300601T150000Z
END:VEVENT
END:VCALENDAR
''';

void main() {
  test('IcalCalendarExtraConfig parses feeds', () {
    final c = IcalCalendarExtraConfig.parse(
      '{"feeds":[{"id":"w","url":"https://x/y.ics","category":"work","enabled":false}],'
      '"pastDays":3,"futureDays":5}',
    );
    expect(c.feeds.length, 1);
    expect(c.feeds.single.id, 'w');
    expect(c.feeds.single.url, 'https://x/y.ics');
    expect(c.feeds.single.categoryId, 'work');
    expect(c.feeds.single.enabled, isFalse);
    expect(c.pastDays, 3);
    expect(c.futureDays, 5);
  });

  test('disabled integration performs no HTTP', () async {
    final db = _openDb();
    await _seedProvider(
      db,
      enabled: false,
      configJson:
          '{"feeds":[{"id":"w","url":"https://example.com/c.ics"}]}',
    );
    final http = _IcsClient(_sampleIcs);
    final p = IcalCalendarDataProvider(httpClient: http);
    await p.collect(await _ctx(db));
    expect(http.requests, 0);
    await db.close();
  });

  test('collect upserts events from ICS URL', () async {
    final db = _openDb();
    await _seedCategories(db, ['work']);
    await _seedProvider(
      db,
      configJson:
          '{"feeds":[{"id":"work","url":"https://example.com/work.ics",'
          '"categoryId":"work"}],"pastDays":3650,"futureDays":3650}',
    );
    final http = _IcsClient(_sampleIcs);
    final p = IcalCalendarDataProvider(httpClient: http);
    await p.collect(await _ctx(db));
    expect(http.requests, 1);
    final rows = await db.select(db.calendarEvents).get();
    expect(rows.length, 1);
    expect(rows.single.title, 'Meet');
    expect(rows.single.source, icalCalendarEventSource('work'));
    expect(rows.single.icalUid, 'ics-1');
    expect(rows.single.categoryId, 'work');
    await db.close();
  });

  test('poll gate skips second collect within pollSeconds', () async {
    final db = _openDb();
    await _seedProvider(
      db,
      pollSeconds: 3600,
      configJson:
          '{"feeds":[{"id":"w","url":"https://example.com/c.ics"}],'
          '"pastDays":3650,"futureDays":3650}',
    );
    var clock = 20_000_000_000;
    final http = _IcsClient(_sampleIcs);
    final p = IcalCalendarDataProvider(httpClient: http, nowMs: () => clock);
    await p.collect(await _ctx(db));
    expect(http.requests, 1);
    clock += 1000;
    await p.collect(await _ctx(db));
    expect(http.requests, 1);
    clock = 20_000_000_000 + (3600 * 1000) + 1;
    await p.collect(await _ctx(db));
    expect(http.requests, 2);
    await db.close();
  });
}
