import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/calendar_mealviewer/mealviewer_calendar_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/config/mealviewer_kv.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

class _MenuClient extends http.BaseClient {
  _MenuClient(this._body);

  final String _body;
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    if (request.url.path.contains('/api/v4/school/')) {
      return http.StreamedResponse(
        Stream.value(_body.codeUnits),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(
      Stream.value('{}'.codeUnits),
      404,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _MemoryBlobStore implements BlobStore {
  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  Future<List<int>> readBytes(BlobRef ref) async => const [];

  @override
  Future<BlobRef> putBytes(
    List<int> bytes, {
    required String logicalKey,
  }) async => BlobRef(logicalKey);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

AppDatabase _openDb() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

Future<void> _seedCategories(AppDatabase db, Iterable<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.contentCategories)
        .insertOnConflictUpdate(
          ContentCategoriesCompanion.insert(id: id, label: id),
        );
  }
}

Future<void> _seedIntegration(
  AppDatabase db, {
  required String configJson,
  int pollSeconds = 0,
}) async {
  await db
      .into(db.integrations)
      .insertOnConflictUpdate(
        IntegrationsCompanion.insert(
          id: kDefaultCalendarMealviewerIntegrationId,
          integrationType: kMealviewerCalendarProviderId,
          enabled: const Value(true),
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

void main() {
  late String menuJson;

  setUp(() {
    menuJson = File(
      'test/calendar_mealviewer/fixtures/elmwood_menu_sample.json',
    ).readAsStringSync();
  });

  test('disabled integration performs no HTTP', () async {
    final db = _openDb();
    await _seedIntegration(
      db,
      configJson:
          '{"schools":[{"schoolSlug":"ElmwoodElementary","label":"Elmwood",'
          '"categoryIds":["school"]}]}',
    );
    await (db.update(db.integrations)
          ..where((t) => t.id.equals(kDefaultCalendarMealviewerIntegrationId)))
        .write(const IntegrationsCompanion(enabled: Value(false)));
    final http = _MenuClient(menuJson);
    final p = MealviewerCalendarDataProvider(httpClient: http);
    await p.collect(await _ctx(db));
    expect(http.requests, 0);
    await db.close();
  });

  test('collect upserts menu blocks with categories', () async {
    final db = _openDb();
    await _seedCategories(db, ['school', 'lunch']);
    await _seedIntegration(
      db,
      configJson:
          '{"schools":[{"schoolSlug":"ElmwoodElementary","label":"Elmwood",'
          '"categoryIds":["school","lunch"]}],"pastDays":3650,"futureDays":3650}',
    );
    final http = _MenuClient(menuJson);
    final p = MealviewerCalendarDataProvider(httpClient: http);
    await p.collect(await _ctx(db));
    expect(http.requests, 1);
    final rows = await db.select(db.calendarEvents).get();
    expect(rows.length, 2);
    expect(
      rows.every(
        (r) => r.source == mealviewerCalendarEventSource('ElmwoodElementary'),
      ),
      isTrue,
    );
    final junction = await db.select(db.calendarEventCategories).get();
    expect(junction.length, 4);
    await db.close();
  });
}
