import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/general_openai/general_openai_data_provider.dart';
import 'package:waddle_integrations/general_openai/openai_responses_client.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/integrations/general_openai_kv_keys.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

class _FakeResponsesClient extends OpenAiResponsesClient {
  _FakeResponsesClient(this._handler);

  final Future<http.Response> Function(http.Request req) _handler;

  @override
  Future<OpenAiResponsesResult?> createResponse({
    required Uri uri,
    required String bearerToken,
    required Map<String, Object?> body,
  }) async {
    final req = http.Request('POST', uri)..body = jsonEncode(body);
    final res = await _handler(req);
    if (res.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final text = extractResponsesOutputText(decoded);
    if (text == null) {
      return null;
    }
    return OpenAiResponsesResult(outputText: text);
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

class _MemorySecrets implements SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<Map<String, String>> readAll() async => Map.from(_data);

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('collect stores latest KV on success', () async {
    await db
        .into(db.integrations)
        .insert(
          IntegrationsCompanion.insert(
            id: 'default_general_openai',
            integrationType: kGeneralOpenAiProviderId,
            enabled: const Value(true),
            pollSeconds: const Value(0),
            configJson: const Value(
              '{"prompts":[{"id":"daily","userPrompt":"Hi","pollSeconds":0}]}',
            ),
          ),
        );

    final provider = GeneralOpenAiDataProvider(
      responsesClient: _FakeResponsesClient((_) async {
        return http.Response(
          jsonEncode({'output_text': '{"items":["a"]}'}),
          200,
        );
      }),
      now: () => DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
    );

    final ctx = DataWriteContextImpl(
      db: db,
      blobs: _MemoryBlobStore(),
      secrets: _MemorySecrets(),
      resolve: (_) async => const ProviderRuntimeConfig(
        providerId: 'default_general_openai',
        integrationType: kGeneralOpenAiProviderId,
        pollSeconds: 0,
        accessToken: 'sk-test',
        configJson:
            '{"prompts":[{"id":"daily","userPrompt":"Hi","pollSeconds":0,"responseFormat":"json_object"}]}',
      ),
    );

    await provider.collect(ctx);

    final kv = IntegrationKvRepository(db);
    expect(
      await kv.getIntegrationValue(
        'default_general_openai',
        generalOpenAiPromptLatestKey('daily'),
      ),
      '{"items":["a"]}',
    );
  });

  test('collect skips when poll gate not elapsed', () async {
    const nowMs = 1_700_000_000_000;
    await db
        .into(db.integrations)
        .insert(
          IntegrationsCompanion.insert(
            id: 'default_general_openai',
            integrationType: kGeneralOpenAiProviderId,
            enabled: const Value(true),
            pollSeconds: const Value(0),
            configJson: const Value(
              '{"prompts":[{"id":"daily","userPrompt":"Hi","pollSeconds":3600}]}',
            ),
          ),
        );
    final kv = IntegrationKvRepository(db);
    await kv.upsertIntegration(
      integrationId: 'default_general_openai',
      key: generalOpenAiPromptLastCollectKey('daily'),
      value: '$nowMs',
    );

    var calls = 0;
    final provider = GeneralOpenAiDataProvider(
      responsesClient: _FakeResponsesClient((_) async {
        calls++;
        return http.Response(jsonEncode({'output_text': 'x'}), 200);
      }),
      now: () => DateTime.fromMillisecondsSinceEpoch(nowMs + 1000),
    );

    final ctx = DataWriteContextImpl(
      db: db,
      blobs: _MemoryBlobStore(),
      secrets: _MemorySecrets(),
      resolve: (_) async => const ProviderRuntimeConfig(
        providerId: 'default_general_openai',
        integrationType: kGeneralOpenAiProviderId,
        pollSeconds: 0,
        accessToken: 'sk-test',
        configJson:
            '{"prompts":[{"id":"daily","userPrompt":"Hi","pollSeconds":3600}]}',
      ),
    );

    await provider.collect(ctx);
    expect(calls, 0);
  });
}
