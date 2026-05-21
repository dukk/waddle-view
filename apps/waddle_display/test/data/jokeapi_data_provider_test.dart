import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_integrations/joke_jokeapi/jokeapi_data_provider.dart';
import 'package:waddle_integrations/joke_jokeapi/jokeapi_http.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _CapturingJokeApiClient extends http.BaseClient {
  _CapturingJokeApiClient(this._handler);
  final http.Response Function(http.BaseRequest request) _handler;
  Uri? lastUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    final res = _handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  Future<DataWriteContextImpl> dataCtx(AppDatabase db) async {
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, secrets);
    return DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
  }

  test('collect ingests twopart jokes from multi-joke response', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultJokeJokeapiIntegrationId,
            integrationType: 'joke_jokeapi',
            enabled: const Value(true),
            pollSeconds: const Value(0),
            configJson: const Value(
              '{"jokesPerPoll":2,"categoryMap":{"general":"Misc"}}',
            ),
          ),
        );
    await db.into(db.interestsJokes).insert(
          InterestsJokesCompanion.insert(id: 'general', label: 'General'),
        );

    final payload = jsonEncode({
      'error': false,
      'amount': 2,
      'jokes': [
        {
          'type': 'twopart',
          'setup': 'Setup one',
          'delivery': 'Punch one',
        },
        {
          'type': 'single',
          'joke': 'ignored',
        },
        {
          'type': 'twopart',
          'setup': 'Setup two',
          'delivery': 'Punch two',
        },
      ],
    });

    final client = _CapturingJokeApiClient(
      (_) => http.Response(payload, 200),
    );
    final provider = JokeApiDataProvider(
      httpClient: client,
      now: () => DateTime(2026, 5, 21),
    );
    await provider.collect(await dataCtx(db));

    final rows = await db.select(db.jokes).get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.setup), containsAll(['Setup one', 'Setup two']));
    expect(rows.every((r) => r.categoryId == 'general'), isTrue);
    expect(client.lastUri!.queryParameters['type'], 'twopart');
    expect(client.lastUri!.queryParameters['amount'], '2');
    await db.close();
  });

  test('collect applies blacklist and contains query params', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultJokeJokeapiIntegrationId,
            integrationType: 'joke_jokeapi',
            enabled: const Value(true),
            pollSeconds: const Value(0),
            configJson: const Value(
              '{"jokesPerPoll":1,"contains":"dev",'
              '"blacklistFlags":["nsfw","explicit"],'
              '"categoryMap":{"tech":"Programming"}}',
            ),
          ),
        );
    await db.into(db.interestsJokes).insert(
          InterestsJokesCompanion.insert(id: 'tech', label: 'Tech'),
        );

    final client = _CapturingJokeApiClient(
      (_) => http.Response(
        jsonEncode({
          'error': false,
          'type': 'twopart',
          'setup': 'Why?',
          'delivery': 'Because.',
        }),
        200,
      ),
    );
    final provider = JokeApiDataProvider(
      httpClient: client,
      now: () => DateTime(2026, 5, 21),
    );
    await provider.collect(await dataCtx(db));

    expect(client.lastUri!.path, endsWith('/Programming'));
    expect(client.lastUri!.queryParameters['contains'], 'dev');
    expect(
      client.lastUri!.queryParameters['blacklistFlags'],
      'nsfw,explicit',
    );
    await db.close();
  });

  test('collect skips when rate limit KV is active', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultJokeJokeapiIntegrationId,
            integrationType: 'joke_jokeapi',
            enabled: const Value(true),
            pollSeconds: const Value(0),
            configJson: const Value(
              '{"categoryMap":{"general":"Misc"}}',
            ),
          ),
        );
    await db.into(db.interestsJokes).insert(
          InterestsJokesCompanion.insert(id: 'general', label: 'General'),
        );

    final kv = IntegrationKvRepository(db);
    await kv.upsertIntegration(
      integrationId: kDefaultJokeJokeapiIntegrationId,
      key: kJokeApiRateLimitUntilKey,
      value: '${DateTime(2026, 5, 21, 12, 0, 1).millisecondsSinceEpoch}',
      valueType: kIntegrationKvTypeIntMs,
    );

    var called = false;
    final client = _CapturingJokeApiClient((_) {
      called = true;
      return http.Response('{}', 200);
    });
    final provider = JokeApiDataProvider(
      httpClient: client,
      now: () => DateTime(2026, 5, 21, 12),
    );
    await provider.collect(await dataCtx(db));

    expect(called, isFalse);
    expect(await db.select(db.jokes).get(), isEmpty);
    await db.close();
  });

  test('collect stores 429 backoff in KV', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultJokeJokeapiIntegrationId,
            integrationType: 'joke_jokeapi',
            enabled: const Value(true),
            pollSeconds: const Value(0),
            configJson: const Value(
              '{"categoryMap":{"general":"Misc"}}',
            ),
          ),
        );
    await db.into(db.interestsJokes).insert(
          InterestsJokesCompanion.insert(id: 'general', label: 'General'),
        );

    final client = _CapturingJokeApiClient(
      (_) => http.Response('', 429, headers: {'retry-after': '45'}),
    );
    final now = DateTime(2026, 5, 21, 12);
    final provider = JokeApiDataProvider(
      httpClient: client,
      now: () => now,
    );
    await provider.collect(await dataCtx(db));

    final kv = IntegrationKvRepository(db);
    final until = await kv.getIntegrationValue(
      kDefaultJokeJokeapiIntegrationId,
      kJokeApiRateLimitUntilKey,
    );
    expect(
      int.parse(until!),
      now.millisecondsSinceEpoch + 45 * 1000,
    );
    await db.close();
  });
}
