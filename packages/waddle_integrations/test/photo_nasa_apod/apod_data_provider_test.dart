import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/photo_nasa_apod/apod_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/integration_config_json.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

class _ApodClient extends http.BaseClient {
  _ApodClient(this.onRequest);

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
            id: kDefaultPhotoNasaApodIntegrationId,
            integrationType: kPhotoNasaApodIntegrationType,
            pollSeconds: const Value(0),
            enabled: const Value(true),
            configJson: Value(
              mergeBaseUrlIntoIntegrationConfig(null, 'https://api.nasa.gov'),
            ),
          ),
        );
    final client = _ApodClient((_) => http.Response('', 404));
    final provider = NasaApodDataProvider(httpClient: client);
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

  test('collect stores APOD image', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultPhotoNasaApodIntegrationId,
            integrationType: kPhotoNasaApodIntegrationType,
            pollSeconds: const Value(0),
            enabled: const Value(true),
            configJson: Value(
              mergeBaseUrlIntoIntegrationConfig(
                '{"retentionDays":30,"category":"nasa_apod","hd":false}',
                'https://api.nasa.gov',
              ),
            ),
          ),
        );
    await db.into(db.contentCategories).insertOnConflictUpdate(
          ContentCategoriesCompanion.insert(
            id: 'nasa_apod',
            label: 'NASA APOD',
          ),
        );

    final secrets = InMemorySecretStore();
    await _seedApiKey(secrets, kDefaultPhotoNasaApodIntegrationId);

    const jpeg = <int>[0xFF, 0xD8, 0xFF, 0xD9];
    final client = _ApodClient((uri) {
      if (uri.host == 'api.nasa.gov' && uri.path == '/planetary/apod') {
        return http.Response(
          jsonEncode({
            'date': '2026-05-21',
            'title': 'Test Nebula',
            'explanation': 'A test image.',
            'media_type': 'image',
            'url': 'https://apod.nasa.gov/img.jpg',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response.bytes(jpeg, 200);
    });

    final provider = NasaApodDataProvider(
      httpClient: client,
      nowUtc: () => DateTime.utc(2026, 5, 21, 12),
    );
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: _MemoryBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await provider.collect(ctx);

    final row = await (db.select(db.photos)
          ..where((t) => t.id.equals('apod_2026-05-21')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.dataProvider, kMediaDataProviderPhotoNasaApod);
    expect(row.category, 'nasa_apod');
    await db.close();
  });
}
