import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/trivia_opentdb/opentdb_trivia_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

class _FakeOpenTdb extends http.BaseClient {
  _FakeOpenTdb(this._body);
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

void main() {
  test('collect inserts multiple-choice and true_false rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: 'trivia_opentdb',
            providerType: 'trivia_opentdb',
            enabled: const Value(true),
            pollSeconds: const Value(1),
            configJson: const Value('{"amount":2}'),
          ),
        );
    await db.into(db.interestsTrivia).insert(
          InterestsTriviaCompanion.insert(id: 'science', label: 'Science'),
        );

    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, {});
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );

    final payload = jsonEncode({
      'response_code': 0,
      'results': [
        {
          'category': 'Science',
          'type': 'multiple',
          'difficulty': 'easy',
          'question': '2 &amp; 2 equals? Caf&eacute; &copy;',
          'correct_answer': '4',
          'incorrect_answers': ['3', '5', '6'],
        },
        {
          'category': 'Science',
          'type': 'boolean',
          'difficulty': 'easy',
          'question': 'The sky is blue.',
          'correct_answer': 'True',
          'incorrect_answers': ['False'],
        },
      ],
    });

    final provider = OpenTdbTriviaDataProvider(
      httpClient: _FakeOpenTdb(payload),
      now: () => DateTime(2026, 1, 1),
    );
    await provider.collect(ctx);

    final rows = await db.select(db.triviaQuestions).get();
    expect(rows, hasLength(2));
    final tf = rows.firstWhere((r) => r.optionC.isEmpty && r.optionD.isEmpty);
    expect(tf.optionC, isEmpty);
    expect(tf.optionD, isEmpty);
    final mc = rows.firstWhere((r) => r.optionC.isNotEmpty && r.optionD.isNotEmpty);
    expect(mc.question, '2 & 2 equals? Caf\u00E9 \u00A9');
    expect(mc.optionC, isNotNull);
    expect(mc.optionD, isNotNull);
  });
}
