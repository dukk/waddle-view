import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_view/config/provider_config_resolver.dart';
import 'package:waddle_view/data/data_write_context.dart';
import 'package:waddle_view/data/providers/joke_data_provider.dart';
import 'package:waddle_view/data/providers/joke_id.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _FakeOpenAi extends http.BaseClient {
  _FakeOpenAi(this._body);
  final String _body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(_body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

String _chatJson(String content) {
  return jsonEncode({
    'choices': [
      {
        'message': {'content': content},
      },
    ],
  });
}

void main() {
  test('collect generates missing category icon and stores mapping', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
            extraJson: const Value('{"jokesPerDay":1}'),
            baseUrl: const Value('http://api.local/v1'),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(
            id: 'dad',
            label: 'Dad',
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:jokes', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final apiPayload = _chatJson(
      jsonEncode([
        {
          'categoryId': 'dad',
          'setup': 'Why did the scarecrow win?',
          'punchline': 'He was outstanding in his field.',
        },
      ]),
    );
    final provider = JokeDataProvider(
      httpClient: _ImageAndChatOpenAi(apiPayload),
      now: () => DateTime(2026, 6, 1, 12),
    );

    await provider.collect(ctx);

    final iconRows = await db.customSelect(
      'SELECT category_type, category_id, blob_key '
      'FROM category_icons WHERE category_type = ? AND category_id = ?',
      variables: [
        const Variable<String>('joke'),
        const Variable<String>('dad'),
      ],
    ).get();
    expect(iconRows, hasLength(1));
    expect(iconRows.single.read<String>('blob_key'), isNotEmpty);
  });

  test('collect inserts jokes from API and respects daily cap', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
            extraJson: const Value('{"jokesPerDay":2}'),
            baseUrl: const Value('http://api.local/v1'),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(
            id: 'dad',
            label: 'Dad',
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(
            id: 'mom',
            label: 'Mom',
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:jokes', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final apiPayload = _chatJson(
      jsonEncode([
        {
          'categoryId': 'dad',
          'setup': 'Why did the scarecrow win?',
          'punchline': 'He was outstanding in his field.',
        },
        {
          'categoryId': 'mom',
          'setup': 'Why do moms bring spice racks?',
          'punchline': 'Because they know the recipe for calm.',
        },
      ]),
    );

    final fixedNow = DateTime(2026, 5, 4, 12);
    final provider = JokeDataProvider(
      httpClient: _FakeOpenAi(apiPayload),
      now: () => fixedNow,
    );

    await provider.collect(ctx);
    final rows = await db.select(db.jokes).get();
    expect(rows.length, 2);
    final batches = await db.select(db.jokeGenerationBatches).get();
    expect(batches.length, 1);
    expect(batches.single.jokesRequested, 2);

    await provider.collect(ctx);
    final rows2 = await db.select(db.jokes).get();
    expect(rows2.length, 2);
  });

  test('collect purges jokes older than jokeRetentionDays', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final t = DateTime(2026, 9, 1, 10);
    final oldMs = t.subtract(const Duration(days: 20)).millisecondsSinceEpoch;
    final recentMs = t.subtract(const Duration(days: 2)).millisecondsSinceEpoch;

    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
            extraJson: const Value(
              '{"jokesPerDay":5,"jokeRetentionDays":14}',
            ),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(
            id: 'dad',
            label: 'Dad',
            minJokes: const Value(1),
            maxJokes: const Value(100),
          ),
        );
    const oldSetup = 'old';
    const oldPunch = 'punch';
    const newSetup = 'new';
    const newPunch = 'p2';
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: jokeStableId('dad', oldSetup, oldPunch),
            categoryId: 'dad',
            setup: oldSetup,
            punchline: oldPunch,
            createdAtMs: oldMs,
          ),
        );
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: jokeStableId('dad', newSetup, newPunch),
            categoryId: 'dad',
            setup: newSetup,
            punchline: newPunch,
            createdAtMs: recentMs,
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:jokes', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final provider = JokeDataProvider(
      httpClient: _InterceptClient(onSend: () {}),
      now: () => t,
    );
    await provider.collect(ctx);

    final rows = await db.select(db.jokes).get();
    expect(rows, hasLength(1));
    expect(rows.single.setup, newSetup);
  });

  test('collect runs when prior batches are older than 2h window', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
            extraJson: const Value(
              '{"jokesPerDay":2,"maxJokesPerTwoHours":10}',
            ),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(
            id: 'dad',
            label: 'Dad',
            minJokes: const Value(1),
            maxJokes: const Value(100),
          ),
        );

    final now = DateTime(2026, 8, 1, 15);
    final oldMs =
        now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch;
    await db.into(db.jokeGenerationBatches).insert(
          JokeGenerationBatchesCompanion.insert(
            requestedAtMs: oldMs,
            jokesRequested: 10,
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:jokes', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    var httpCalls = 0;
    final payload = _chatJson(
      jsonEncode([
        {
          'categoryId': 'dad',
          'setup': 's',
          'punchline': 'p',
        },
        {
          'categoryId': 'dad',
          'setup': 's2',
          'punchline': 'p2',
        },
      ]),
    );
    final client = _CountingOpenAi(payload, onSend: () => httpCalls++);
    final provider = JokeDataProvider(httpClient: client, now: () => now);

    await provider.collect(ctx);
    expect(httpCalls, 2);
    expect(await db.select(db.jokes).get(), hasLength(2));
  });

  test('collect skips when inventory fills every category max', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final t = DateTime(2026, 3, 15, 12);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
            extraJson: const Value('{"jokesPerDay":50}'),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(
            id: 'solo',
            label: 'Solo',
            minJokes: const Value(1),
            maxJokes: const Value(1),
          ),
        );
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: jokeStableId('solo', 'x', 'y'),
            categoryId: 'solo',
            setup: 'x',
            punchline: 'y',
            createdAtMs: t.millisecondsSinceEpoch,
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:jokes', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    var httpCalls = 0;
    final client = _InterceptClient(onSend: () => httpCalls++);
    final provider = JokeDataProvider(httpClient: client, now: () => t);

    await provider.collect(ctx);
    expect(httpCalls, 0);
  });

  test('collect skips when 2h request budget is exhausted', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
            extraJson: const Value(
              '{"jokesPerDay":50,"maxJokesPerTwoHours":5}',
            ),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(id: 'dad', label: 'Dad'),
        );

    final t0 = DateTime(2026, 6, 1, 12).millisecondsSinceEpoch;
    await db.into(db.jokeGenerationBatches).insert(
          JokeGenerationBatchesCompanion.insert(
            requestedAtMs: t0,
            jokesRequested: 5,
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:jokes', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    var httpCalls = 0;
    final client = _InterceptClient(onSend: () => httpCalls++);
    final provider = JokeDataProvider(
      httpClient: client,
      now: () => DateTime(2026, 6, 1, 12, 30),
    );

    await provider.collect(ctx);
    expect(httpCalls, 0);
  });

  test('collect skips when no categories are eligible (seasonal)', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
            extraJson: const Value('{"jokesPerDay":5}'),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(
            id: 'christmas',
            label: 'Christmas',
            isSeasonal: const Value(true),
            startMonth: const Value(12),
            startDay: const Value(1),
            endMonth: const Value(1),
            endDay: const Value(6),
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:jokes', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    var httpCalls = 0;
    final client = _InterceptClient(onSend: () => httpCalls++);
    final summer = DateTime(2026, 7, 4);
    final provider = JokeDataProvider(httpClient: client, now: () => summer);

    await provider.collect(ctx);
    expect(httpCalls, 0);
    expect(await db.select(db.jokes).get(), isEmpty);
  });

  test('collect skips when API token missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(id: 'dad', label: 'Dad'),
        );

    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    var httpCalls = 0;
    final client = _InterceptClient(onSend: () => httpCalls++);
    final provider = JokeDataProvider(httpClient: client);

    await provider.collect(ctx);
    expect(httpCalls, 0);
  });

  test('parse strips markdown fence from model content', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'jokes',
            providerType: 'jokes',
            pollSeconds: const Value(1),
            extraJson: const Value('{"jokesPerDay":1}'),
          ),
        );
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(id: 'dad', label: 'Dad'),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:jokes', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final fenced = _chatJson(
      '```json\n${jsonEncode([
        {
          'categoryId': 'dad',
          'setup': 'A',
          'punchline': 'B',
        },
      ])}\n```',
    );

    final provider = JokeDataProvider(
      httpClient: _FakeOpenAi(fenced),
      now: () => DateTime(2026, 1, 1),
    );
    await provider.collect(ctx);

    final rows = await db.select(db.jokes).get();
    expect(rows.length, 1);
    expect(rows.single.setup, 'A');
    expect(
      rows.single.id,
      jokeStableId('dad', 'A', 'B'),
    );
  });
}

class _InterceptClient extends http.BaseClient {
  _InterceptClient({required this.onSend});
  final void Function() onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onSend();
    return http.StreamedResponse(Stream.value(utf8.encode('')), 500);
  }
}

class _CountingOpenAi extends http.BaseClient {
  _CountingOpenAi(this._body, {required this.onSend});
  final String _body;
  final void Function() onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onSend();
    return http.StreamedResponse(
      Stream.value(utf8.encode(_body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _ImageAndChatOpenAi extends http.BaseClient {
  _ImageAndChatOpenAi(this._chatBody);
  final String _chatBody;

  static const String _tinyPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2WZ6kAAAAASUVORK5CYII=';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith('/images/generations')) {
      final body = jsonEncode({
        'data': [
          {'b64_json': _tinyPngBase64},
        ],
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(_chatBody)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
