import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_view/config/provider_config_resolver.dart';
import 'package:waddle_view/data/data_write_context.dart';
import 'package:waddle_view/data/providers/trivia_data_provider.dart';
import 'package:waddle_view/data/providers/trivia_id.dart';
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

Map<String, dynamic> _triviaRow({
  required String categoryId,
  required String correct,
}) {
  return {
    'categoryId': categoryId,
    'question': 'Capital of France?',
    'A': 'London',
    'B': 'Paris',
    'C': 'Berlin',
    'D': 'Madrid',
    'correct': correct,
  };
}

void main() {
  test('collect inserts trivia from API and respects daily cap', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'trivia',
            providerType: 'trivia',
            pollSeconds: const Value(1),
            configJson: const Value('{"questionsPerDay":2}'),
            baseUrl: const Value('http://api.local/v1'),
          ),
        );
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(
            id: 'science',
            label: 'Science',
          ),
        );
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(
            id: 'history',
            label: 'History',
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:trivia', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final apiPayload = _chatJson(
      jsonEncode([
        _triviaRow(categoryId: 'science', correct: 'B'),
        _triviaRow(categoryId: 'history', correct: 'B'),
      ]),
    );

    final fixedNow = DateTime(2026, 5, 4, 12);
    final provider = TriviaDataProvider(
      httpClient: _FakeOpenAi(apiPayload),
      now: () => fixedNow,
    );

    await provider.collect(ctx);
    final rows = await db.select(db.triviaQuestions).get();
    expect(rows.length, 2);
    final batches = await db.select(db.triviaGenerationBatches).get();
    expect(batches.length, 1);
    expect(batches.single.questionsRequested, 2);

    await provider.collect(ctx);
    final rows2 = await db.select(db.triviaQuestions).get();
    expect(rows2.length, 2);
  });

  test('collect skips unknown categoryId in response', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'trivia',
            providerType: 'trivia',
            pollSeconds: const Value(1),
            configJson: const Value('{"questionsPerDay":5}'),
            baseUrl: const Value('http://api.local/v1'),
          ),
        );
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(id: 'ok', label: 'Ok'),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:trivia', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final apiPayload = _chatJson(
      jsonEncode([
        _triviaRow(categoryId: 'nope', correct: 'B'),
        _triviaRow(categoryId: 'ok', correct: 'B'),
      ]),
    );

    final provider = TriviaDataProvider(
      httpClient: _FakeOpenAi(apiPayload),
      now: () => DateTime(2026, 1, 1),
    );
    await provider.collect(ctx);

    final rows = await db.select(db.triviaQuestions).get();
    expect(rows.length, 1);
    expect(rows.single.categoryId, 'ok');
  });

  test('collect skips item when correct option invalid', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'trivia',
            providerType: 'trivia',
            pollSeconds: const Value(1),
            configJson: const Value('{"questionsPerDay":5}'),
            baseUrl: const Value('http://api.local/v1'),
          ),
        );
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(id: 'ok', label: 'Ok'),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:trivia', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final bad = Map<String, dynamic>.from(_triviaRow(categoryId: 'ok', correct: 'B'));
    bad['correct'] = 'X';
    final apiPayload = _chatJson(jsonEncode([bad]));

    final provider = TriviaDataProvider(
      httpClient: _FakeOpenAi(apiPayload),
      now: () => DateTime(2026, 1, 1),
    );
    await provider.collect(ctx);

    expect(await db.select(db.triviaQuestions).get(), isEmpty);
  });

  test('collect purges questions older than questionRetentionDays', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final t = DateTime(2026, 9, 1, 10);
    final oldMs = t.subtract(const Duration(days: 20)).millisecondsSinceEpoch;
    final recentMs = t.subtract(const Duration(days: 2)).millisecondsSinceEpoch;

    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'trivia',
            providerType: 'trivia',
            pollSeconds: const Value(1),
            configJson: const Value(
              '{"questionsPerDay":5,"questionRetentionDays":14}',
            ),
          ),
        );
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(
            id: 'dad',
            label: 'Dad',
            minQuestions: const Value(1),
            maxQuestions: const Value(100),
          ),
        );
    const qOld = 'old?';
    const qNew = 'new?';
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: triviaStableId('dad', qOld, 'a', 'b', 'c', 'd', 'A'),
            categoryId: 'dad',
            question: qOld,
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(oldMs),
          ),
        );
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: triviaStableId('dad', qNew, 'a', 'b', 'c', 'd', 'A'),
            categoryId: 'dad',
            question: qNew,
            optionA: 'a',
            optionB: 'b',
            optionC: 'c',
            optionD: 'd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(recentMs),
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:trivia', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final provider = TriviaDataProvider(
      httpClient: _InterceptClient(onSend: () {}),
      now: () => t,
    );
    await provider.collect(ctx);

    final rows = await db.select(db.triviaQuestions).get();
    expect(rows, hasLength(1));
    expect(rows.single.question, qNew);
  });

  test('parse strips markdown fence from model content', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'trivia',
            providerType: 'trivia',
            pollSeconds: const Value(1),
            configJson: const Value('{"questionsPerDay":1}'),
            baseUrl: const Value('http://api.local/v1'),
          ),
        );
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(id: 'dad', label: 'Dad'),
        );

    final secrets = InMemorySecretStore();
    await secrets.write('${ProviderConfigResolver.accessTokenKey}:trivia', 't');
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final fenced = _chatJson(
      '```json\n${jsonEncode([
        _triviaRow(categoryId: 'dad', correct: 'C'),
      ])}\n```',
    );

    final provider = TriviaDataProvider(
      httpClient: _FakeOpenAi(fenced),
      now: () => DateTime(2026, 1, 1),
    );
    await provider.collect(ctx);

    final rows = await db.select(db.triviaQuestions).get();
    expect(rows.length, 1);
    expect(rows.single.correctOption, 'C');
    expect(
      rows.single.id,
      triviaStableId(
        'dad',
        'Capital of France?',
        'London',
        'Paris',
        'Berlin',
        'Madrid',
        'C',
      ),
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

