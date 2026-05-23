import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/tasks_trello/tasks_trello_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/integration_config_json.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

class _TrelloClient extends http.BaseClient {
  _TrelloClient(this.onRequest);

  final http.Response Function(Uri uri) onRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
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
  String? apiKey,
  String? token,
}) async {
  const integrationId = kDefaultTasksTrelloIntegrationId;
  if (apiKey != null) {
    await secrets.write(trelloApiKeySecretKey(integrationId), apiKey);
  }
  if (token != null) {
    await secrets.write(providerAccessTokenSecretKey(integrationId), token);
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

Future<void> _seedIntegration(AppDatabase db, {String? boardIdsJson}) async {
  await db.into(db.integrations).insert(
        IntegrationsCompanion.insert(
          id: kDefaultTasksTrelloIntegrationId,
          integrationType: kTasksTrelloProviderId,
          pollSeconds: const Value(0),
          enabled: const Value(true),
          configJson: Value(
            mergeBaseUrlIntoIntegrationConfig(
              boardIdsJson ?? '{"boardIds":["board1"],"requestTimeoutMs":5000}',
              'https://api.trello.com/1',
            ),
          ),
        ),
      );
}

void main() {
  test('collect skips when API key or token missing', () async {
    final db = _openDb();
    await db.customStatement('SELECT 1');
    await _seedIntegration(db);
    final client = _TrelloClient((_) => http.Response('[]', 200));
    final provider = TasksTrelloDataProvider(httpClient: client);

    await provider.collect(await _ctx(db, InMemorySecretStore()));
    expect(await db.select(db.taskLists).get(), isEmpty);

    await provider.collect(
      await _ctx(db, InMemorySecretStore(), apiKey: 'key'),
    );
    expect(await db.select(db.taskLists).get(), isEmpty);
  });

  test('collect syncs lists and cards for configured board', () async {
    final db = _openDb();
    await db.customStatement('SELECT 1');
    await _seedIntegration(db);
    final client = _TrelloClient((uri) {
      if (uri.path.endsWith('/lists')) {
        return http.Response(
          jsonEncode([
            {'id': 'list1', 'name': 'To Do', 'pos': 1},
          ]),
          200,
        );
      }
      if (uri.path.contains('/cards')) {
        return http.Response(
          jsonEncode([
            {
              'id': 'card1',
              'name': 'Ship feature',
              'desc': 'Details',
              'due': '2025-06-15T12:00:00.000Z',
              'closed': false,
              'pos': 2,
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 404);
    });
    final provider = TasksTrelloDataProvider(httpClient: client, nowMs: () => 1_700_000_000_000);
    await provider.collect(
      await _ctx(
        db,
        InMemorySecretStore(),
        apiKey: 'api-key',
        token: 'member-token',
      ),
    );

    final lists = await db.select(db.taskLists).get();
    expect(lists, hasLength(1));
    expect(lists.single.label, 'To Do');
    expect(lists.single.boardKey, 'board1');

    final tasks = await db.select(db.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Ship feature');
    expect(tasks.single.completed, isFalse);
  });
}
