import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/quote_quoterism/quoterism_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/integration_config_json.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

class _QuoterismClient extends http.BaseClient {
  _QuoterismClient(this.onRequest);

  final http.Response Function(Uri uri) onRequest;
  final List<Uri> uris = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    uris.add(request.url);
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

Future<void> _seedApiKey(InMemorySecretStore secrets, String integrationId) async {
  await secrets.write(
    providerAccessTokenSecretKey(integrationId),
    'TEST_KEY',
  );
}

void main() {
  test('collect skips without API key', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultQuoteQuoterismIntegrationId,
            integrationType: kQuoteQuoterismIntegrationType,
            pollSeconds: const Value(0),
            enabled: const Value(true),
            configJson: Value(
              mergeBaseUrlIntoIntegrationConfig(null, 'https://www.quoterism.com'),
            ),
          ),
        );
    final client = _QuoterismClient((_) => http.Response('', 404));
    final provider = QuoterismDataProvider(httpClient: client);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: _MemoryBlobStore(),
      secrets: InMemorySecretStore(),
      resolve: ProviderConfigResolver(db, InMemorySecretStore()).resolve,
    );
    await provider.collect(ctx);
    expect(client.uris, isEmpty);
    await db.close();
  });

  test('collect stores quote, categories, and author image', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultQuoteQuoterismIntegrationId,
            integrationType: kQuoteQuoterismIntegrationType,
            pollSeconds: const Value(0),
            enabled: const Value(true),
            configJson: Value(
              mergeBaseUrlIntoIntegrationConfig(
                '{"pageLimit":10,"pagesPerCollect":1,"fetchAuthorImages":true}',
                'https://www.quoterism.com',
              ),
            ),
          ),
        );

    final secrets = InMemorySecretStore();
    await _seedApiKey(secrets, kDefaultQuoteQuoterismIntegrationId);

    const jpeg = <int>[0xFF, 0xD8, 0xFF, 0xD9];
    final client = _QuoterismClient((uri) {
      if (uri.path == '/api/quotes' && uri.host == 'www.quoterism.com') {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'q1',
                'text': 'Hello world',
                'author': {
                  'id': 'a1',
                  'name': 'Ada',
                  'slug': 'ada',
                  'imageUrl': 'https://images.quoterism.com/authors/a1.jpg',
                },
                'categories': [
                  {'slug': 'wisdom', 'name': 'Wisdom'},
                ],
              },
            ],
            'pagination': {'hasNextPage': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (uri.path == '/api/quotes/q1') {
        return http.Response(
          jsonEncode({
            'id': 'q1',
            'text': 'Hello world',
            'categories': [
              {'slug': 'wisdom', 'name': 'Wisdom'},
            ],
          }),
          200,
        );
      }
      return http.Response.bytes(jpeg, 200);
    });

    final provider = QuoterismDataProvider(httpClient: client);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: _MemoryBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await provider.collect(ctx);

    final quotes = await db.select(db.quoterismQuotes).get();
    expect(quotes, hasLength(1));
    expect(quotes.single.quoteText, 'Hello world');
    expect(quotes.single.authorName, 'Ada');
    expect(quotes.single.authorImageBlobKey, isNotNull);

    final cats = await db.select(db.contentCategories).get();
    expect(cats.any((c) => c.id == 'quoterism_wisdom'), isTrue);

    final links = await db.select(db.quoterismQuoteCategories).get();
    expect(links, hasLength(1));
    expect(links.single.categoryId, 'quoterism_wisdom');

    await db.close();
  });
}
