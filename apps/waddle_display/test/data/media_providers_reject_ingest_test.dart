import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/photo_pexels/pexels_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

const _jpegBytes = <int>[0xFF, 0xD8, 0xFF, 0xD9];

http.StreamedResponse _jsonResponse(Object body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

http.StreamedResponse _bytesResponse(List<int> bytes) {
  return http.StreamedResponse(Stream.value(bytes), 200);
}

class _CuratedPhotosClient extends http.BaseClient {
  _CuratedPhotosClient(this.curated);
  final List<Map<String, dynamic>> curated;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'images.test') {
      return _bytesResponse(_jpegBytes);
    }
    if (u.path == '/v1/curated') {
      return _jsonResponse({'photos': curated, 'next_page': null});
    }
    if (u.path == '/v1/videos/popular') {
      return _jsonResponse({'videos': const [], 'next_page': null});
    }
    return _jsonResponse(const {});
  }
}

Future<InMemorySecretStore> _secretsWithKey() async => InMemorySecretStore();

Future<void> _ensurePexels(AppDatabase db) async {
  await db.into(db.integrations).insert(
        IntegrationsCompanion.insert(
          id: kDefaultPhotoPexelsIntegrationId,
          integrationType: 'photo_pexels',
          pollSeconds: const Value(0),
        ),
      );
}

Future<DataWriteContext> _ctx(AppDatabase db, InMemorySecretStore secrets) async {
  await secrets.write(providerAccessTokenSecretKey(kDefaultPhotoPexelsIntegrationId), 'k');
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

void main() {
  test(
    'Pexels marks photo suppressed when photographer name matches a reject term',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await db.delete(db.rejectTerms).go();
      await RejectTermRepository(db).upsert(
        RejectTermInput.parse(rawTerm: 'damn', rawAction: 'censor')!,
      );
      await _ensurePexels(db);

      final blocked = <String, dynamic>{
        'id': 1001,
        'url': 'https://www.pexels.com/photo/1001/',
        'photographer': 'Jane Damn-Smith',
        'photographer_url': 'https://www.pexels.com/@damn',
        'alt': 'A nice scene',
        'width': 1200,
        'height': 900,
        'src': {'large': 'http://images.test/1001.jpg'},
      };
      final clean = <String, dynamic>{
        'id': 1002,
        'url': 'https://www.pexels.com/photo/1002/',
        'photographer': 'Bob Safe',
        'photographer_url': 'https://www.pexels.com/@bob',
        'alt': 'Clear skies',
        'width': 1200,
        'height': 900,
        'src': {'large': 'http://images.test/1002.jpg'},
      };

      final client = _CuratedPhotosClient([blocked, clean]);
      final secrets = await _secretsWithKey();
      await PexelsPhotosDataProvider(httpClient: client, nowMs: () => 1)
          .collect(await _ctx(db, secrets));

      final p1 = await (db.select(db.photos)
            ..where((t) => t.id.equals('1001')))
          .getSingleOrNull();
      final p2 = await (db.select(db.photos)
            ..where((t) => t.id.equals('1002')))
          .getSingleOrNull();
      expect(p1 != null, isTrue, reason: 'photo 1001 row inserted');
      expect(p1!.suppressed, isTrue);
      expect(p2 != null, isTrue, reason: 'photo 1002 row inserted');
      expect(p2!.suppressed, isFalse);

      await db.close();
    },
  );

  test('Pexels media: no reject terms => suppressed=false', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    await _ensurePexels(db);

    final clean = <String, dynamic>{
      'id': 2001,
      'url': 'https://www.pexels.com/photo/2001/',
      'photographer': 'Carol',
      'photographer_url': 'https://www.pexels.com/@carol',
      'alt': 'sunny morning',
      'width': 1200,
      'height': 900,
      'src': {'large': 'http://images.test/2001.jpg'},
    };
    final client = _CuratedPhotosClient([clean]);
    final secrets = await _secretsWithKey();
    await PexelsPhotosDataProvider(httpClient: client, nowMs: () => 1)
        .collect(await _ctx(db, secrets));

    final p = await (db.select(db.photos)
          ..where((t) => t.id.equals('2001')))
        .getSingle();
    expect(p.suppressed, isFalse);
    await db.close();
  });
}
