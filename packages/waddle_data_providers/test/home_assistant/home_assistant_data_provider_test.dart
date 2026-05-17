import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_data_providers/home_assistant/home_assistant_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

class _HaClient extends http.BaseClient {
  _HaClient(this.onRequest);

  final http.Response Function(Uri uri) onRequest;
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sends += 1;
    final response = onRequest(request.url);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
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

Future<DataWriteContextImpl> _ctx(
  AppDatabase db,
  InMemorySecretStore secrets, {
  String? token,
}) async {
  if (token != null) {
    await secrets.write(
      providerAccessTokenSecretKey(kHomeAssistantProviderId),
      token,
    );
  }
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: _MemoryBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

AppDatabase _openDb() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Future<void> _seedProvider(
  AppDatabase db, {
  bool enabled = true,
}) async {
  await db.into(db.integrations).insert(
        IntegrationsCompanion.insert(
          id: kHomeAssistantProviderId,
          integrationType: kHomeAssistantProviderId,
          pollSeconds: const Value(60),
          enabled: Value(enabled),
          baseUrl: const Value('http://ha.local:8123'),
        ),
      );
}

String _stateBody({
  required String state,
  String friendlyName = 'Test',
}) {
  return jsonEncode({
    'entity_id': 'sensor.test',
    'state': state,
    'attributes': {'friendly_name': friendlyName},
    'last_updated': '2016-05-30T21:50:30.529465+00:00',
  });
}

void main() {
  test('collect skips when access token missing', () async {
    final db = _openDb();
    await db.customStatement('SELECT 1');
    await _seedProvider(db);
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 's1',
            entityId: 'sensor.temp',
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore());
    final client = _HaClient((_) => http.Response(_stateBody(state: '1'), 200));
    final provider = HomeAssistantDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 0);
    expect(await db.select(db.homeAssistantEntityStates).get(), isEmpty);
    await db.close();
  });

  test('collect skips when provider disabled', () async {
    final db = _openDb();
    await db.customStatement('SELECT 1');
    await _seedProvider(db, enabled: false);
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 's1',
            entityId: 'sensor.temp',
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore(), token: 'ha-token');
    final client = _HaClient((_) => http.Response(_stateBody(state: '1'), 200));
    final provider = HomeAssistantDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 0);
    await db.close();
  });

  test('collect upserts state for enabled entity', () async {
    final db = _openDb();
    await db.customStatement('SELECT 1');
    await _seedProvider(db);
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 's1',
            entityId: 'sensor.kitchen_temp',
            displayName: const Value('Kitchen'),
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore(), token: 'ha-token');
    final client = _HaClient((uri) {
      expect(uri.path, endsWith('/api/states/sensor.kitchen_temp'));
      return http.Response(_stateBody(state: '22.1', friendlyName: 'Kitchen'), 200);
    });
    final provider = HomeAssistantDataProvider(httpClient: client, nowMs: () => 1000);

    await provider.collect(ctx);

    expect(client.sends, 1);
    final rows = await db.select(db.homeAssistantEntityStates).get();
    expect(rows.length, 1);
    expect(rows.single.state, '22.1');
    expect(rows.single.observedAtMs, 1000);
    await db.close();
  });

  test('collect continues after 404', () async {
    final db = _openDb();
    await db.customStatement('SELECT 1');
    await _seedProvider(db);
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 's1',
            entityId: 'sensor.missing',
          ),
        );
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 's2',
            entityId: 'sensor.ok',
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore(), token: 'ha-token');
    final client = _HaClient((uri) {
      if (uri.path.endsWith('sensor.missing')) {
        return http.Response('not found', 404);
      }
      return http.Response(_stateBody(state: '5'), 200);
    });
    final provider = HomeAssistantDataProvider(httpClient: client);

    await provider.collect(ctx);

    expect(client.sends, 2);
    final rows = await db.select(db.homeAssistantEntityStates).get();
    expect(rows.length, 1);
    expect(rows.single.entityId, 'sensor.ok');
    await db.close();
  });

  test('binary_sensor upserts runtime signal', () async {
    final db = _openDb();
    await db.customStatement('SELECT 1');
    await _seedProvider(db);
    await db.into(db.interestsHomeAssistantEntities).insert(
          InterestsHomeAssistantEntitiesCompanion.insert(
            id: 'b1',
            entityId: 'binary_sensor.motion',
          ),
        );
    final ctx = await _ctx(db, InMemorySecretStore(), token: 'ha-token');
    final client = _HaClient(
      (_) => http.Response(_stateBody(state: 'on'), 200),
    );
    final provider = HomeAssistantDataProvider(httpClient: client);

    await provider.collect(ctx);

    final signals = await db.select(db.runtimeSignals).get();
    expect(signals.length, 1);
    expect(signals.single.id, 'binary_sensor.motion');
    expect(signals.single.sourcePluginId, kHomeAssistantProviderId);
    expect(jsonDecode(signals.single.valueJson), isTrue);
    await db.close();
  });
}
