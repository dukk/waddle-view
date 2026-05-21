import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/photo_nasa_mars_rover/mars_rover_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/integration_config_json.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

class _CaptureClient extends http.BaseClient {
  final List<Uri> uris = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    uris.add(request.url);
    if (request.url.path.contains('/photos')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'photos': [
            {
              'id': 42,
              'img_src': 'https://mars.nasa.gov/img.jpg',
              'camera': {'full_name': 'Front Hazcam'},
              'rover': {'name': 'Perseverance'},
            },
          ],
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.host == 'mars.nasa.gov') {
      return http.StreamedResponse(
        Stream.value(const [0xFF, 0xD8, 0xFF, 0xD9]),
        200,
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('')), 404);
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

void main() {
  test('collect stores mars rover photo', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultPhotoNasaMarsRoverIntegrationId,
            integrationType: kPhotoNasaMarsRoverIntegrationType,
            pollSeconds: const Value(0),
            enabled: const Value(true),
            configJson: Value(
              mergeBaseUrlIntoIntegrationConfig(
                '{"rovers":["perseverance"],"photosPerCollect":1,"maxDaysBack":3}',
                'https://api.nasa.gov',
              ),
            ),
          ),
        );
    await db.into(db.contentCategories).insertOnConflictUpdate(
          ContentCategoriesCompanion.insert(
            id: 'nasa_mars_perseverance',
            label: 'Mars Perseverance',
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write(
      providerAccessTokenSecretKey(kDefaultPhotoNasaMarsRoverIntegrationId),
      'KEY',
    );

    final client = _CaptureClient();
    final provider = NasaMarsRoverDataProvider(
      httpClient: client,
      nowUtc: () => DateTime.utc(2026, 5, 21),
    );
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: _MemoryBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await provider.collect(ctx);

    final row = await (db.select(db.photos)
          ..where((t) => t.id.equals('mars_perseverance_42')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.category, 'nasa_mars_perseverance');
    await db.close();
  });
}
